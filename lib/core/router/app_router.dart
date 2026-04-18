import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/complete_profile_screen.dart';
import '../../features/auth/auth_notifier.dart';
import '../../features/home/home_screen.dart';
import '../../features/groups/groups_screen.dart';
import '../../features/groups/group_detail_screen.dart';
import '../../features/settlements/settlements_screen.dart';
import '../../features/scanner/scanner_screen.dart';
import '../../features/scanner/item_review_screen.dart';
import '../../features/scanner/ocr_pipeline.dart';
import '../../features/expenses/add_expense_sheet.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/contacts/contacts_screen.dart';

// ─── Route paths ─────────────────────────────────────────────────────────────
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const otp = '/otp';
  static const completeProfile = '/complete-profile';
  static const home = '/home';
  static const groups = '/groups';
  static const groupDetail = '/groups/:id';
  static const scanner = '/scanner';
  static const itemReview = '/scanner/review';
  static const addExpense = '/add-expense';
  static const expenseDetail = '/expense/:id';
  static const settlements = '/settlements';
  static const settleUp = '/settle/:friendId';
  static const profile = '/profile';
  static const contacts = '/contacts';
}

// ─── Router provider ──────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  // Rebuild router whenever auth state changes
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthStateListenable(ref, authState),

    // ── Global auth redirect guard ────────────────────────────────────────
    redirect: (context, routerState) {
      final auth = ref.read(authStateProvider);
      final loc = routerState.matchedLocation;

      // Allow splash to always render its own transition
      if (loc == AppRoutes.splash) return null;

      return switch (auth) {
        AuthLoading() => AppRoutes.splash,
        AuthUnauthenticated() =>
          (loc == AppRoutes.login || loc == AppRoutes.otp)
              ? null
              : AppRoutes.login,
        AuthNeedsProfile() =>
          loc == AppRoutes.completeProfile ? null : AppRoutes.completeProfile,
        AuthAuthenticated() =>
          (loc == AppRoutes.login ||
                  loc == AppRoutes.otp ||
                  loc == AppRoutes.completeProfile)
              ? AppRoutes.home
              : null,
      };
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (_, state) {
          final extra = state.extra as Map? ?? {};
          return OtpScreen(
            phone: extra['phone'] as String? ?? '',
            verificationId: extra['verificationId'] as String? ?? '',
            confirmationResult: extra['confirmationResult'] as ConfirmationResult?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (_, __) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.groups,
        builder: (_, __) => const GroupsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => GroupDetailScreen(
              groupId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settlements,
        builder: (_, __) => const SettlementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.scanner,
        builder: (_, __) => const ScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.itemReview,
        builder: (_, state) {
          // Extra is a Map when coming from ScannerScreen:
          //   {'result': OcrResult, 'imageFile': File?}
          // Falls back to a bare OcrResult for any legacy callers.
          final extra = state.extra;
          final OcrResult result;
          File? imageFile;
          if (extra is Map) {
            result = (extra['result'] as OcrResult?) ??
                OcrResult(
                    items: const [], rawText: '', source: OcrSource.mlKitRegex);
            imageFile = extra['imageFile'] as File?;
          } else {
            result = (extra as OcrResult?) ??
                OcrResult(
                    items: const [], rawText: '', source: OcrSource.mlKitRegex);
          }
          return ItemReviewScreen(ocrResult: result, imageFile: imageFile);
        },
      ),
      GoRoute(
        path: AppRoutes.addExpense,
        builder: (_, state) {
          // When coming from ItemReviewScreen the extra is a Map:
          //   {
          //     'items': List<Map>   — [{name, price, qty}, ...]
          //     'total': double      — grand total (inc. tax + tip)
          //     'taxFraction': double
          //     'tipFraction': double
          //     'receiptImageUrl': String?
          //   }
          // When opened without scanner data, extra is null.
          final extra = state.extra as Map<String, dynamic>?;
          return _AddExpensePage(scannerData: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.contacts,
        builder: (_, __) => const ContactsScreen(),
      ),
    ],
  );
});

/// Makes GoRouter listen to AuthState changes so redirect fires on every change.
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref, AuthState _) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

/// Wraps [AddExpenseSheet] as a full-screen page so the /add-expense
/// route works both standalone and when pre-filled from the bill scanner.
class _AddExpensePage extends StatelessWidget {
  const _AddExpensePage({this.scannerData});
  final Map<String, dynamic>? scannerData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: AppBar(
        title: const Text('Add Expense'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
      ),
      body: SafeArea(
        child: AddExpenseSheet(
          scannerData: scannerData,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
          child: Text('$label — coming soon',
              style: Theme.of(context).textTheme.titleLarge)),
    );
  }
}
