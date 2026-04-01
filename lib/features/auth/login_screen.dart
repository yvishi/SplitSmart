import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/haptics.dart';
import 'google_auth_service.dart';

/// Real Firebase phone-OTP + Google login screen.
///
/// Web flow:  signInWithPhoneNumber(phone, RecaptchaVerifier) → ConfirmationResult → /otp
/// Android:   verifyPhoneNumber(phone) → codeSent → /otp (via verificationId)
///
/// The OTP screen receives either a [ConfirmationResult] (web) or a
/// [verificationId] string (Android) in the GoRouter extra map.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Phone OTP ────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() { _sending = true; _error = null; });
    await Haptics.lightTap();

    final phone = '+91${_phoneCtrl.text.trim()}';

    if (kIsWeb) {
      await _sendOtpWeb(phone);
    } else {
      await _sendOtpAndroid(phone);
    }
  }

  // Web: signInWithPhoneNumber returns a ConfirmationResult used on OTP screen.
  // We do NOT pass a RecaptchaVerifier manually — Firebase creates an invisible
  // one internally (keyed to the 'recaptcha-container' div in index.html).
  Future<void> _sendOtpWeb(String phone) async {
    try {
      final confirmationResult =
          await FirebaseAuth.instance.signInWithPhoneNumber(phone);

      if (!mounted) return;
      setState(() => _sending = false);
      context.go(AppRoutes.otp, extra: {
        'phone': phone,
        'verificationId': '',
        'confirmationResult': confirmationResult,
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _mapError(e.code);
      });
    }
  }

  // Android: verifyPhoneNumber with codeSent callback.
  Future<void> _sendOtpAndroid(String phone) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),

      // Android auto-resolve (happens silently on test devices)
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        // AuthNotifier stream fires → router redirects
      },

      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _error = _mapError(e.code);
        });
      },

      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() => _sending = false);
        context.go(AppRoutes.otp, extra: {
          'phone': phone,
          'verificationId': verificationId,
          'confirmationResult': null,   // unused on Android
        });
      },

      codeAutoRetrievalTimeout: (_) {
        if (mounted) setState(() => _sending = false);
      },
    );
  }

  String _mapError(String code) => switch (code) {
        'invalid-phone-number' => 'Invalid phone number.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'quota-exceeded' => 'SMS quota exceeded. Try Google Sign-In.',
        'captcha-check-failed' => 'reCAPTCHA check failed. Please retry.',
        _ => 'Something went wrong. Please try again.',
      };

  // ── Google Sign-In ───────────────────────────────────────────────────────
  Future<void> _googleSignIn() async {
    setState(() { _sending = true; _error = null; });
    try {
      await GoogleAuthService.signIn();
      // AuthNotifier stream fires automatically
    } on GoogleSignInCancelledException {
      setState(() => _sending = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Google Sign-In failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chalk,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Spacing.base, Spacing.xl * 2, Spacing.base, Spacing.base),
            children: [
              // ── Branding ───────────────────────────────────────────────
              Text('SplitSmart',
                  style: AppTextStyles.displayMono(color: AppColors.forest)
                      .copyWith(fontSize: 28)),
              const SizedBox(height: Spacing.xs),
              Text('Split bills. Stay friends.',
                  style: AppTextStyles.body(color: AppColors.stone)),
              const SizedBox(height: Spacing.xl * 2),

              // ── Phone field ────────────────────────────────────────────
              Text('MOBILE NUMBER', style: AppTextStyles.overline()),
              const SizedBox(height: Spacing.sm),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.body(),
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.md),
                    child: Text('🇮🇳 +91',
                        style: AppTextStyles.bodyMedium()),
                  ),
                  hintText: '98765 43210',
                ),
                validator: (v) => (v == null || v.trim().length != 10)
                    ? 'Enter a valid 10-digit number'
                    : null,
              ),
              const SizedBox(height: Spacing.sm),

              // ── Error ──────────────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.rose,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(_error!,
                      style: AppTextStyles.caption(color: AppColors.ember)),
                ),
                const SizedBox(height: Spacing.sm),
              ],

              // ── Send OTP ───────────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendOtp,
                  child: _sending
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Get OTP via SMS'),
                ),
              ),
              const SizedBox(height: Spacing.base),

              // ── Divider ────────────────────────────────────────────────
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Text('or', style: AppTextStyles.caption()),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: Spacing.base),

              // ── Google ─────────────────────────────────────────────────
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  icon: const Text('G',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 18, color: Color(0xFF4285F4))),
                  label: const Text('Continue with Google'),
                  onPressed: _sending ? null : _googleSignIn,
                ),
              ),
              const SizedBox(height: Spacing.xl),

              Center(
                child: Text(
                  'New users will complete a profile after signing in.',
                  style: AppTextStyles.caption(),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
