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
import '../reports/ledger_screen.dart';
import '../reports/transaction_history_screen.dart';
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

  @override
  void initState() {
    super.initState();
    // Global Caching: Pre-fetch data once on Home Load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        _initialFetch(auth.user!);
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = user.role;
    final navItems = _getNavItems(role);
    // Safety check: Reset to 0 if out of bounds (e.g. role change)
    var effectiveIndex = _currentIndex;
    if (effectiveIndex >= navItems.length) {
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
              if (index < navItems.length) {
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
                const SizedBox(width: 4),
                // Notification Icon
                const SizedBox(width: 8),
              ],
            ),
            body: _buildBody(role, effectiveIndex),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: effectiveIndex,
              onTap: (index) {
                if (index < navItems.length) {
                  setState(() => _currentIndex = index);
                }
              },
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF1E88E5),
              unselectedItemColor: Colors.grey[400],
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedLabelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              items: navItems,
            ),
            floatingActionButton: _shouldShowFAB(role)
                ? FloatingActionButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TransactionEntryScreen(),
                        ),
                      );
                      // Refresh on return
                      if (context.mounted) {
                        await context.read<AccountProvider>().fetchAccounts(
                          user,
                        );
                        await context.read<TransactionProvider>().fetchHistory(
                          user,
                          forceRefresh: true,
                        );
                        if (context.mounted) {
                          context
                              .read<NotificationProvider>()
                              .refreshNotifications(
                                user,
                                context.read<TransactionProvider>(),
                                context.read<UserProvider>(),
                                accountProvider: context
                                    .read<AccountProvider>(),
                              );
                        }
                      }
                    },
                    backgroundColor: const Color(0xFF1E88E5),
                    elevation: 4,
                    child: const Icon(Icons.add, color: Colors.white),
                  )
                : null,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
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
          ],
        ),
      );
    }

    // Other tabs based on role
    if (role.toLowerCase() == AppRoles.admin.toLowerCase()) {
      switch (currentIndex) {
        case 1:
          return const TransactionHistoryScreen();
        case 2:
          return const LedgerScreen();
        case 3:
          return const AccountsScreen();
        case 4:
          return const SettingsScreen();
        default:
          return const SizedBox();
      }
    } else if (role.toLowerCase() == AppRoles.management.toLowerCase()) {
      switch (currentIndex) {
        case 1:
          return const TransactionHistoryScreen();
        case 2:
          return const LedgerScreen();
        case 3:
          return const SettingsScreen();
        default:
          return const SizedBox();
      }
    } else if (role.toLowerCase() ==
        AppRoles.businessOperationsAssociate.toLowerCase()) {
      switch (currentIndex) {
        case 1:
          return const TransactionHistoryScreen();
        case 2:
          return const SettingsScreen();
        default:
          return const SizedBox();
      }
    } else {
      // Viewer
      switch (currentIndex) {
        case 1:
          return const TransactionHistoryScreen();
        case 2:
          return const SettingsScreen();
        default:
          return const SizedBox();
      }
    }
  }

  List<BottomNavigationBarItem> _getNavItems(String role) {
    final homeItem = const BottomNavigationBarItem(
      icon: Icon(Icons.home_rounded),
      label: 'Home',
    );
    final historyItem = const BottomNavigationBarItem(
      icon: Icon(Icons.history_rounded),
      label: 'History',
    );

    final normalizedRole = role.trim().toLowerCase();

    if (normalizedRole == AppRoles.admin.toLowerCase()) {
      return [
        homeItem,
        const BottomNavigationBarItem(
          icon: Icon(Icons.swap_horiz_rounded),
          label: 'Trans.',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.analytics_rounded),
          label: 'Reports',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Accounts',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ];
    } else if (normalizedRole == AppRoles.management.toLowerCase()) {
      return [
        homeItem,
        historyItem,
        const BottomNavigationBarItem(
          icon: Icon(Icons.analytics_rounded),
          label: 'Reports',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ];
    } else {
      // BOA / Viewer
      return [
        homeItem,
        historyItem,
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ];
    }
  }

  bool _shouldShowFAB(String rawRole) {
    // Management and BOA (and Admin?) can enter transactions
    final role = rawRole.trim().toLowerCase();
    return role == AppRoles.management.toLowerCase() ||
        role == AppRoles.businessOperationsAssociate.toLowerCase() ||
        role == AppRoles.admin.toLowerCase();
  }
}
