import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../core/constants/role_constants.dart';
import '../transaction/transaction_entry_screen.dart';
import '../settings/settings_screen.dart';
import '../reports/transaction_history_screen.dart';
import '../reports/ledger_screen.dart';
import '../search/search_voucher_screen.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../admin/accounts_screen.dart';
import 'widgets/desktop_scaffold.dart';
import 'widgets/message_card.dart';
import 'widgets/action_grid.dart';
import '../../widgets/user_identity_widget.dart';
import 'dashboard/owned_accounts_screen.dart';
import '../../services/permission_service.dart';

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
    await context.read<AccountProvider>().fetchAccounts(user);
    await context.read<TransactionProvider>().fetchHistory(user);

    if (context.mounted) {
      context.read<AccountProvider>().updateBalancesFromTransactions(
        context.read<TransactionProvider>().transactions,
      );

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
    const navItemCount = 4; // Home, Trans, Accounts, Settings

    // Safety check: Reset to 0 if out of bounds
    var effectiveIndex = _currentIndex;
    if (effectiveIndex >= navItemCount) {
      effectiveIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          // Desktop Layout
          return DesktopScaffold(
            role: role,
            currentIndex: effectiveIndex,
            onNavIndexChanged: (index) {
              if (index < navItemCount) {
                setState(() => _currentIndex = index);
              }
            },
            body: _buildBody(role, effectiveIndex),
          );
        } else {
          // Mobile Layout
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
                    'ByteCityBD Accounting',
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
            bottomNavigationBar: _buildCustomBottomBar(effectiveIndex, role),
            floatingActionButton: _shouldShowFAB(role)
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

  Widget _buildBody(String rawRole, int currentIndex) {
    final role = rawRole.trim();

    // Unified Dashboard for index 0 (Home)
    if (currentIndex == 0) {
      final user = context.watch<AuthProvider>().user;

      return SingleChildScrollView(
        child: Column(
          children: [
            const MessageCard(),
            const SizedBox(height: 16),

            // Owned Accounts Summary Button
            if (user != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Consumer<AccountProvider>(
                  builder: (context, provider, child) {
                    // ALL users: show only OWNED accounts
                    final myAccounts = provider.accounts.where((a) {
                      return PermissionService().isOwner(user, a);
                    }).toList();

                    final countLabel = '${myAccounts.length} Own Accounts';

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OwnedAccountsScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade800,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Balances',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    countLabel,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Action Grid
            ActionGrid(userRole: role),

            const SizedBox(height: 32),
            // Padding for floating bottom bar
            const SizedBox(height: 80),
          ],
        ),
      );
    }

    final bool isAdmin =
        role.trim().toLowerCase() == AppRoles.admin.toLowerCase();

    // Other tabs based on new fixed indices
    switch (currentIndex) {
      case 1: // Trans (Admin) or Search (Non-Admin)
        if (isAdmin) {
          return const TransactionHistoryScreen();
        } else {
          return const SearchVoucherScreen();
        }
      case 2: // Accounts (Admin) or Ledger (Non-Admin)
        if (isAdmin) {
          return const AccountsScreen();
        } else {
          return const LedgerScreen();
        }
      case 3: // Settings (Admin) or History (Non-Admin)
        if (isAdmin) {
          return const SettingsScreen();
        } else {
          return const TransactionHistoryScreen();
        }
      default:
        return const SizedBox();
    }
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
                  isAdmin ? Icons.swap_horiz_rounded : Icons.search_rounded,
                  isAdmin ? 'Trans.' : 'Search',
                  currentIndex == 1,
                ),
                const SizedBox(width: 60), // Space for FAB
                _buildNavItem(
                  2,
                  isAdmin
                      ? Icons.account_balance_wallet_rounded
                      : Icons.analytics_rounded,
                  isAdmin ? 'Accounts' : 'Ledger',
                  currentIndex == 2,
                ),
                _buildDivider(),
                _buildNavItem(
                  3,
                  isAdmin ? Icons.settings_rounded : Icons.history_rounded,
                  isAdmin ? 'Settings' : 'History',
                  currentIndex == 3,
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
    bool isSelected,
  ) {
    final color = isSelected
        ? const Color(0xFF1E88E5)
        : const Color(0xFF94A3B8);
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
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
            color: const Color(0xFF3182CE).withOpacity(0.4),
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
      ..color = Colors.black.withOpacity(0.08)
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
