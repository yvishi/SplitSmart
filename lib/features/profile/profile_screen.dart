import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/haptics.dart';
import '../../features/auth/auth_notifier.dart';
import '../../features/auth/user_repository.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_bottom_sheet.dart';

/// Profile + Settings screen.
/// Accessible from the Home bottom bar (far-right icon).
///
/// Sections:
///   1. Avatar + name + phone (read-only)
///   2. Edit name + UPI VPA
///   3. Sign out
///   4. Delete account (DestructiveButton — 400ms delay, sheet confirmation)
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _saving = false;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final auth = ref.read(authNotifierProvider);
    if (auth is AuthAuthenticated) {
      _nameCtrl.text = auth.profile.name;
      _upiCtrl.text = auth.profile.upiVpa;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    await Haptics.lightTap();

    final upiRaw = _upiCtrl.text.trim();
    final upiError = upiRaw.isNotEmpty && !upiRaw.contains('@');
    if (upiError) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('UPI ID must contain @',
              style: AppTextStyles.body(color: AppColors.white)),
          backgroundColor: AppColors.ember,
        ),
      );
      return;
    }

    await UserRepository.updateProfile(
      auth.profile.uid,
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      upiVpa: upiRaw.isEmpty ? null : upiRaw,
    );
    await ref.read(authNotifierProvider.notifier).refreshProfile();

    if (mounted) {
      setState(() { _saving = false; _editMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile saved',
              style: AppTextStyles.body(color: AppColors.white)),
          backgroundColor: AppColors.forest,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await AppBottomSheet.show(
      context,
      title: 'Sign out?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You\'ll be signed out from this device. Your data will stay safe.',
            style: AppTextStyles.body(color: AppColors.stone),
          ),
          const SizedBox(height: Spacing.base),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Haptics.lightTap();
                await ref.read(authNotifierProvider.notifier).signOut();
                // Router redirect takes care of navigation
              },
              child: const Text('Yes, sign out'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: AppTextStyles.body(color: AppColors.stone)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    await AppBottomSheet.show(
      context,
      title: 'Delete account?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppColors.rose,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '⚠️  This permanently deletes your profile and sign-in. '
              'Groups and expenses you\'re part of will remain for other members.',
              style: AppTextStyles.caption(color: AppColors.ember),
            ),
          ),
          const SizedBox(height: Spacing.base),
          DestructiveButton(
            label: 'Delete my account',
            onConfirm: () async {
              Navigator.of(context).pop();
              await ref.read(authNotifierProvider.notifier).deleteAccount();
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: AppTextStyles.body(color: AppColors.stone)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final profile =
        auth is AuthAuthenticated ? auth.profile : null;

    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          if (!_editMode)
            TextButton(
              onPressed: () => setState(() => _editMode = true),
              child: Text('Edit',
                  style: AppTextStyles.body(color: AppColors.forest)),
            )
          else
            TextButton(
              onPressed: () => setState(() {
                _editMode = false;
                _loadProfile(); // discard
              }),
              child: Text('Cancel',
                  style: AppTextStyles.body(color: AppColors.stone)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.base),
        children: [
          // ── Avatar + phone ───────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                AppAvatar(
                    name: profile?.name ?? '?',
                    size: 72),
                const SizedBox(height: Spacing.md),
                if (profile?.phone.isNotEmpty == true)
                  Text(
                    profile!.phone,
                    style: AppTextStyles.caption(color: AppColors.stone),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),

          // ── Name ─────────────────────────────────────────────────────────
          Text('DISPLAY NAME', style: AppTextStyles.overline()),
          const SizedBox(height: Spacing.sm),
          TextFormField(
            controller: _nameCtrl,
            enabled: _editMode,
            style: AppTextStyles.body(),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: Spacing.base),

          // ── UPI VPA ──────────────────────────────────────────────────────
          Text('UPI ID', style: AppTextStyles.overline()),
          const SizedBox(height: Spacing.sm),
          TextFormField(
            controller: _upiCtrl,
            enabled: _editMode,
            keyboardType: TextInputType.emailAddress,
            style: AppTextStyles.body(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              hintText: 'yourname@okaxis',
            ),
          ),
          const SizedBox(height: Spacing.lg),

          // ── Save button (edit mode only) ─────────────────────────────────
          if (_editMode)
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _saveProfile,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Save changes'),
              ),
            ),
          if (_editMode) const SizedBox(height: Spacing.base),

          // ── Divider ──────────────────────────────────────────────────────
          const Divider(),
          const SizedBox(height: Spacing.sm),

          // ── Contacts ─────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.people_outline, color: AppColors.forest),
            title: Text('Contacts', style: AppTextStyles.body()),
            subtitle: Text('Manage friends to add to groups',
                style: AppTextStyles.caption(color: AppColors.stone)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.stone),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Haptics.lightTap();
              context.go(AppRoutes.contacts);
            },
          ),

          const Divider(),
          const SizedBox(height: Spacing.sm),

          // ── Sign out ─────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.stone),
            title: Text('Sign out', style: AppTextStyles.body()),
            trailing: const Icon(Icons.chevron_right, color: AppColors.stone),
            contentPadding: EdgeInsets.zero,
            onTap: _signOut,
          ),

          const Divider(),
          const SizedBox(height: Spacing.sm),

          // ── Delete account ───────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: AppColors.ember),
            title: Text('Delete account',
                style: AppTextStyles.body(color: AppColors.ember)),
            contentPadding: EdgeInsets.zero,
            onTap: _deleteAccount,
          ),
          const SizedBox(height: Spacing.xl),

          // ── App version note ─────────────────────────────────────────────
          Center(
            child: Text(
              'SplitSmart V1.0 · Data stored securely in Firebase',
              style: AppTextStyles.caption(color: AppColors.subtle),
            ),
          ),
        ],
      ),
    );
  }
}
