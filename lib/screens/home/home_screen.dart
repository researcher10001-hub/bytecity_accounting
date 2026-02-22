import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';

import '../../core/constants/role_constants.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import '../../services/permission_service.dart';

import '../transaction/transaction_entry_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../reports/transaction_history_screen.dart';
import '../notifications/notifications_screen.dart';
import '../reports/ledger_screen.dart';
import '../search/search_voucher_screen.dart';
import '../admin/pending_transactions_screen.dart';
import '../admin/erp_sync_queue_screen.dart';
import '../admin/users_screen.dart';
import '../admin/accounts_screen.dart';
import '../admin/account_groups_screen.dart';
import '../admin/audit_dashboard_screen.dart';
import '../admin/sub_category_management_screen.dart';
import '../admin/erp_settings_screen.dart';
import '../profile/profile_screen.dart';

import 'widgets/desktop_scaffold.dart';
import 'widgets/message_card.dart';
import 'widgets/action_grid.dart';
import 'dashboard/owned_accounts_screen.dart';
import '../../widgets/user_identity_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Global Caching: Pre-fetch data once on Home Load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        _initialFetch(auth.user!);
        _startAutoRefresh(auth.user!);
      }
    });
  }

  void _startAutoRefresh(User user) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) return;

      context.read<NotificationProvider>().refreshNotifications(
            user,
            context.read<TransactionProvider>(),
            context.read<UserProvider>(),
            accountProvider: context.read<AccountProvider>(),
            silent: true,
          );
    });
  }

  Future<void> _initialFetch(User user) async {
    final accountProvider = context.read<AccountProvider>();
    // Stale-while-revalidate: Load from cache (already done in constructor), then fetch fresh silently
    await accountProvider.fetchAccounts(
      user,
      forceRefresh: true,
      skipLoading: true,
    );
    await context.read<TransactionProvider>().fetchHistory(
          user,
          accountProvider: accountProvider,
          forceRefresh: true,
          skipLoading: true,
        );

    if (context.mounted) {
      // OPTIMIZATION: Removed client-side balance calculation
      // context.read<AccountProvider>().updateBalancesFromTransactions(
      //   context.read<TransactionProvider>().transactions,
      // );

      context.read<UserProvider>().fetchUsers(); // Pre-fetch users
      context.read<NotificationProvider>().refreshNotifications(
            user,
            context.read<TransactionProvider>(),
            context.read<UserProvider>(),
            accountProvider: context.read<AccountProvider>(),
          );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = user.role;
    // Dynamic navItemCount based on sidebar length
    final items = (role == AppRoles.admin || role == 'Admin')
        ? 6
        : (role == AppRoles.management || role == 'Management')
            ? 5
            : 4;

    // Safety check: Reset to 0 if out of bounds
    var effectiveIndex = _currentIndex;
    if (effectiveIndex >= items) {
      effectiveIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          // Desktop Layout
          return DesktopScaffold(
            role: role,
            onNavIndexChanged: (index) {
              setState(() => _currentIndex = index);
              // DashboardProvider view switching is now handled directly within SideMenu's onTap
              // but we still keep index in sync for mobile bottom bar transitions
            },
            body: Consumer<DashboardProvider>(
              builder: (context, dp, _) => _buildDesktopBody(
                user,
                role,
                dp.currentView,
                dp.currentArguments,
              ),
            ),
          );
        } else {
          // Mobile Layout
          final List<DashboardView> views;
          if (role == AppRoles.admin || role == 'Admin') {
            views = [
              DashboardView.home,
              DashboardView.transactionEntry,
              DashboardView.transactions,
              DashboardView.ledger,
              DashboardView.ownedAccounts,
              DashboardView.search,
              DashboardView.settings,
            ];
          } else if (role == AppRoles.management || role == 'Management') {
            views = [
              DashboardView.home,
              DashboardView.transactionEntry,
              DashboardView.transactions,
              DashboardView.ledger,
              DashboardView.ownedAccounts,
              DashboardView.search,
              DashboardView.settings,
            ];
          } else {
            views = [
              DashboardView.home,
              DashboardView.transactionEntry,
              DashboardView.transactions,
              DashboardView.ledger,
              DashboardView.ownedAccounts,
            ];
          }
          final currentView = effectiveIndex >= views.length
              ? DashboardView.home
              : views[effectiveIndex];

          return Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'BC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BC Math',
                    style: GoogleFonts.inter(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              actions: [
                // User Identity Widget
                UserIdentityWidget(user: user),
                // Notification Icon
                const SizedBox(width: 8),
              ],
            ),
            body: _buildBody(role, effectiveIndex),
            bottomNavigationBar: currentView == DashboardView.ledger
                ? null
                : _buildCustomBottomBar(effectiveIndex, role),
            floatingActionButton: currentView == DashboardView.ledger
                ? null
                : _shouldShowFAB(role)
                    ? _buildGradientFAB()
                    : null,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            extendBody: true,
          );
        }
      },
    );
  }

  Widget _buildDesktopBody(
    User user,
    String role,
    DashboardView view, [
    dynamic args,
  ]) {
    switch (view) {
      case DashboardView.home:
        return _buildDashboardHome(user, role);
      case DashboardView.transactions:
        return const TransactionHistoryScreen();
      case DashboardView.search:
        return const SearchVoucherScreen();
      case DashboardView.settings:
        return const SettingsScreen();
      case DashboardView.ledger:
        return LedgerScreen(initialAccountName: args as String?);
      case DashboardView.pending:
        return const PendingTransactionsScreen();
      case DashboardView.erpSync:
        return const ERPSyncQueueScreen();
      case DashboardView.ownedAccounts:
        return const OwnedAccountsScreen();
      case DashboardView.transactionEntry:
        return TransactionEntryScreen(transaction: args as TransactionModel?);
      case DashboardView.manageUsers:
        return const UsersScreen();
      case DashboardView.chartOfAccounts:
        return const AccountsScreen();
      case DashboardView.manageGroups:
        return const AccountGroupsScreen();
      case DashboardView.auditDashboard:
        return const AuditDashboardScreen();
      case DashboardView.subCategories:
        return const SubCategoryManagementScreen();
      case DashboardView.erpSettings:
        return const ERPSettingsScreen();
      case DashboardView.transactionDetail:
        final dictArgs = args as Map<String, dynamic>?;
        return TransactionDetailScreen(
          transaction: dictArgs?['transaction'] as TransactionModel,
          allTransactions:
              dictArgs?['allTransactions'] as List<TransactionModel>?,
        );
      case DashboardView.profile:
        return const ProfileScreen();
      case DashboardView.messages:
        return const NotificationScreen();
    }
  }

  Widget _buildDashboardHome(User user, String role) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const MessageCard(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer<AccountProvider>(
              builder: (context, provider, child) {
                final myAccounts = provider.accounts.where((a) {
                  return PermissionService().isOwner(user, a);
                }).toList();
                final countLabel = '${myAccounts.length} Own Accounts';

                return InkWell(
                  onTap: () {
                    // Check if we're on mobile or desktop
                    if (MediaQuery.of(context).size.width < 800) {
                      // Mobile: Push screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OwnedAccountsScreen(),
                        ),
                      );
                    } else {
                      // Desktop: Use provider
                      context.read<DashboardProvider>().setView(
                            DashboardView.ownedAccounts,
                          );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Accounts',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                countLabel,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ActionGrid(userRole: role),
          const SizedBox(height: 24),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildBody(String rawRole, int currentIndex) {
    final role = rawRole.trim();
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox();

    // Map index to DashboardView based on role
    // This must match the order in SideMenu._getNavItemsForRole
    final List<DashboardView> views;
    if (role == AppRoles.admin || role == 'Admin') {
      views = [
        DashboardView.home,
        DashboardView.transactionEntry,
        DashboardView.transactions,
        DashboardView.ledger,
        DashboardView.ownedAccounts,
        DashboardView.search,
        DashboardView.settings,
      ];
    } else if (role == AppRoles.management || role == 'Management') {
      views = [
        DashboardView.home,
        DashboardView.transactionEntry,
        DashboardView.transactions,
        DashboardView.ledger,
        DashboardView.ownedAccounts,
        DashboardView.search,
        DashboardView.settings, // Added Settings
      ];
    } else {
      views = [
        DashboardView.home,
        DashboardView.transactionEntry,
        DashboardView.transactions,
        DashboardView.ledger,
        DashboardView.ownedAccounts,
      ];
    }

    if (currentIndex >= views.length) {
      return _buildDashboardHome(user, role);
    }

    final currentView = views[currentIndex];

    // Use the same desktop body logic for consistency
    return _buildDesktopBody(user, role, currentView);
  }

  Widget _buildCustomBottomBar(int currentIndex, String role) {
    final bool isAdmin =
        role.trim().toLowerCase() == AppRoles.admin.toLowerCase();

    return Container(
      height: 100, // Sufficient height for the bulge
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Background with Convex shape
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width - 32, 70),
            painter: _ConvexPillBackgroundPainter(),
          ),
          // Navigation Items
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home', currentIndex == 0),
                _buildDivider(),
                _buildNavItem(
                  1,
                  isAdmin ? Icons.history_rounded : Icons.search_rounded,
                  isAdmin ? 'History' : 'Search',
                  currentIndex == 1,
                  onTapOverride: isAdmin
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionHistoryScreen(),
                            ),
                          );
                        }
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SearchVoucherScreen(),
                            ),
                          );
                        },
                ),
                const SizedBox(width: 60), // Space for FAB
                _buildNavItem(
                  2,
                  isAdmin ? Icons.search_rounded : Icons.analytics_rounded,
                  isAdmin ? 'Search' : 'Ledger',
                  currentIndex == 2,
                  onTapOverride: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isAdmin
                            ? const SearchVoucherScreen()
                            : const LedgerScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildNavItem(
                  3,
                  isAdmin ? Icons.settings_rounded : Icons.history_rounded,
                  isAdmin ? 'Settings' : 'History',
                  currentIndex == 3,
                  onTapOverride: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isAdmin
                            ? const SettingsScreen()
                            : const TransactionHistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool isSelected, {
    VoidCallback? onTapOverride,
  }) {
    final color =
        isSelected ? const Color(0xFF1E88E5) : const Color(0xFF94A3B8);
    return Expanded(
      child: InkWell(
        onTap: onTapOverride ?? () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 30, color: Colors.grey[200]);
  }

  Widget _buildGradientFAB() {
    return Container(
      width: 64,
      height: 64,
      margin: const EdgeInsets.only(
        top: 95,
      ), // Push it even further down into the bulge
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF4299E1), Color(0xFF3182CE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3182CE).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () async {
          final user = context.read<AuthProvider>().user;
          if (user == null) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionEntryScreen(),
            ),
          );
          if (mounted && context.mounted) {
            await context.read<AccountProvider>().fetchAccounts(user);
            await context.read<TransactionProvider>().fetchHistory(
                  user,
                  forceRefresh: true,
                );
            if (context.mounted) {
              context.read<NotificationProvider>().refreshNotifications(
                    user,
                    context.read<TransactionProvider>(),
                    context.read<UserProvider>(),
                    accountProvider: context.read<AccountProvider>(),
                  );
            }
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  bool _shouldShowFAB(String rawRole) {
    // Management and BOA (and Admin?) can enter transactions
    final role = rawRole.trim().toLowerCase();
    return role == AppRoles.management.toLowerCase() ||
        role == AppRoles.businessOperationsAssociate.toLowerCase() ||
        role == AppRoles.admin.toLowerCase();
  }
}

// Custom Painter for the Convex Pill Background
class _ConvexPillBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final path = Path();
    const cornerRadius = 32.0;
    const bulgeRadius = 45.0; // Slightly wider bulge
    const bulgeHeight = 18.0; // Slightly taller bulge to match image better

    // The shape is a pill with a central outward bulge
    path.moveTo(cornerRadius, 0);
    // Top flat part before bulge
    path.lineTo(size.width / 2 - bulgeRadius, 0);

    // The concave/convex bulge
    path.quadraticBezierTo(
      size.width / 2,
      -bulgeHeight * 2,
      size.width / 2 + bulgeRadius,
      0,
    );

    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.lineTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Draw shadow first
    canvas.drawPath(path.shift(const Offset(0, 8)), shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
