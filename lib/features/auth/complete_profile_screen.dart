import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/haptics.dart';
import 'auth_notifier.dart';
import 'user_repository.dart';

/// Shown after first sign-in when no Firestore profile exists yet.
///
/// Fields:
///  - Name (required, all users)
///  - Phone (required for Google users; auto-set for OTP users)
///  - Email (optional for all users; auto-filled for Google users)
///  - UPI VPA (optional)
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  /// True when signed in via Google/email (no Firebase phone number).
  bool get _isGoogleUser {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
    return phone == null || phone.isEmpty;
  }

  @override
  void initState() {
    super.initState();
    // Auto-fill email for Google users
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _isGoogleUser) {
      _emailCtrl.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() { _saving = true; _error = null; });
    await Haptics.lightTap();

    final user = FirebaseAuth.instance.currentUser!;
    try {
      // Phone: OTP users use Firebase Auth phone; Google users enter manually.
      String phone;
      if (_isGoogleUser) {
        final raw = _phoneCtrl.text.trim();
        phone = raw.startsWith('+') ? raw : '+91$raw';
      } else {
        phone = user.phoneNumber!;
      }

      // Email: use manually entered value (or auto-filled Google email)
      final email = _emailCtrl.text.trim();

      await UserRepository.createProfile(
        uid: user.uid,
        name: _nameCtrl.text.trim(),
        phone: phone,
        email: email,
        upiVpa: _upiCtrl.text.trim(),
      );
      await ref.read(authNotifierProvider.notifier).profileCreated();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save profile. Check your connection.';
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
            padding: const EdgeInsets.all(Spacing.base),
            children: [
              const SizedBox(height: Spacing.xl),

              // ── Heading ─────────────────────────────────────────────────
              Text('One last step', style: AppTextStyles.title()),
              const SizedBox(height: Spacing.xs),
              Text(
                'Tell us your name so friends can find you.',
                style: AppTextStyles.body(color: AppColors.stone),
              ),
              const SizedBox(height: Spacing.xl * 2),

              // ── Name (required) ──────────────────────────────────────────
              Text('YOUR NAME', style: AppTextStyles.overline()),
              const SizedBox(height: Spacing.sm),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.body(),
                decoration: const InputDecoration(
                  hintText: 'e.g. Arjun Kapoor',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name cannot be empty';
                  if (v.trim().length < 2) return 'Name too short';
                  return null;
                },
              ),
              const SizedBox(height: Spacing.base),

              // ── Phone (required for Google users only) ───────────────────
              if (_isGoogleUser) ...[
                Text('PHONE NUMBER', style: AppTextStyles.overline()),
                const SizedBox(height: Spacing.sm),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d+]'))
                  ],
                  style: AppTextStyles.body(),
                  decoration: const InputDecoration(
                    hintText: '+91 98765 43210',
                    prefixIcon: Icon(Icons.phone_outlined),
                    helperText: 'Friends can find you by this number',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: Spacing.base),
              ],

              // ── Email (optional, auto-filled for Google users) ───────────
              Text('EMAIL (OPTIONAL)', style: AppTextStyles.overline()),
              const SizedBox(height: Spacing.sm),
              TextFormField(
                controller: _emailCtrl,
                // Read-only for Google users (already auto-filled from their account)
                readOnly: _isGoogleUser && _emailCtrl.text.isNotEmpty,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.body(),
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  helperText: _isGoogleUser ? 'Auto-filled from your Google account' : null,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: Spacing.base),

              // ── UPI VPA (optional) ───────────────────────────────────────
              Text('UPI ID (OPTIONAL)', style: AppTextStyles.overline()),
              const SizedBox(height: Spacing.sm),
              TextFormField(
                controller: _upiCtrl,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.body(),
                decoration: const InputDecoration(
                  hintText: 'yourname@okaxis',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  helperText: 'Used by friends to pay you directly via UPI',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!v.contains('@')) return 'Enter a valid UPI ID (must contain @)';
                  return null;
                },
              ),
              const SizedBox(height: Spacing.xl),

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
              if (_error != null) const SizedBox(height: Spacing.sm),

              // ── Save & Continue ──────────────────────────────────────────
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Let\'s go →'),
                ),
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
