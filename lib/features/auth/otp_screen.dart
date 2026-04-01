import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/haptics.dart';

/// Real OTP verification screen — works on both web and Android.
///
/// Web:     receives [confirmationResult] → calls confirmationResult.confirm(smsCode)
/// Android: receives [verificationId]    → builds PhoneAuthCredential → signInWithCredential
///
/// Both paths: AuthNotifier stream fires → router redirects to /home or /complete-profile.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.verificationId,
    this.confirmationResult,   // web only
  });

  final String phone;
  final String verificationId;           // Android
  final ConfirmationResult? confirmationResult; // web

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _verifying = false;
  String? _error;
  int _resendSeconds = 28;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusNodes.first.requestFocus());
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
        _startResendTimer();
      } else {
        setState(() => _canResend = true);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length != 6) return;
    FocusScope.of(context).unfocus();
    setState(() { _verifying = true; _error = null; });
    await Haptics.lightTap();

    try {
      if (widget.confirmationResult != null) {
        // ── Web path ──────────────────────────────────────────────────
        await widget.confirmationResult!.confirm(_otp);
      } else {
        // ── Android path ──────────────────────────────────────────────
        final credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: _otp,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      // AuthNotifier stream fires → router handles redirect to /home or /complete-profile
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      await Haptics.deletion();
      setState(() {
        _verifying = false;
        _error = switch (e.code) {
          'invalid-verification-code' =>
            'Incorrect OTP. Check your SMS and try again.',
          'session-expired' =>
            'OTP expired. Go back and request a new one.',
          'too-many-requests' => 'Too many attempts. Please wait.',
          'code-expired'     => 'Code expired. Please request a new one.',
          _ => 'Verification failed. Please try again.',
        };
      });
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.isEmpty) {
      if (index > 0) _focusNodes[index - 1].requestFocus();
      return;
    }
    if (index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      _verify(); // auto-submit on last digit
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Spacing.base),
            Text('Enter the 6-digit code sent to',
                style: AppTextStyles.body(color: AppColors.stone)),
            Text(widget.phone, style: AppTextStyles.bodyMedium()),
            const SizedBox(height: Spacing.xl),

            // ── 6 OTP boxes ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 46,
                  height: 56,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: AppTextStyles.subtitle().copyWith(fontSize: 22),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(
                          color: _error != null
                              ? AppColors.ember
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(
                            color: AppColors.forest, width: 2),
                      ),
                    ),
                    onChanged: (v) => _onDigitChanged(i, v),
                  ),
                );
              }),
            ),
            const SizedBox(height: Spacing.md),

            // ── Error ────────────────────────────────────────────────────
            if (_error != null)
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
            const SizedBox(height: Spacing.xl),

            // ── Verify button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_verifying || _otp.length < 6) ? null : _verify,
                child: _verifying
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Verify & Continue'),
              ),
            ),
            const SizedBox(height: Spacing.base),

            // ── Resend ───────────────────────────────────────────────────
            Center(
              child: _canResend
                  ? TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Resend OTP',
                          style: AppTextStyles.body(color: AppColors.forest)),
                    )
                  : Text(
                      'Resend in ${_resendSeconds}s',
                      style: AppTextStyles.caption(color: AppColors.stone),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
