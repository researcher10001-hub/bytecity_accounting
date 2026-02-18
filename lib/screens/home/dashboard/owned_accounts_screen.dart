import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:lucide_icons/lucide_icons.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/permission_service.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/user_provider.dart';
import '../../reports/ledger_screen.dart';
import '../../../core/utils/currency_formatter.dart';

class OwnedAccountsScreen extends StatefulWidget {
  const OwnedAccountsScreen({super.key});

  @override
  State<OwnedAccountsScreen> createState() => _OwnedAccountsScreenState();
}

class _OwnedAccountsScreenState extends State<OwnedAccountsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _refreshController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRefreshing = false;
  final Set<String> _loadingPins = {};

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    // Initial Fetch
    _refreshBalances();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshBalances() async {
    setState(() => _isRefreshing = true);
    _refreshController.repeat();

    try {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        // 1. Re-fetch user data to get updated pins
        final authProvider = context.read<AuthProvider>();
        await authProvider.checkSession();

        // Get updated user after session check
        final updatedUser = authProvider.user;

        if (updatedUser != null) {
          // 2. Fetch accounts with updated user (will sort with new pins)
          final accountProvider = context.read<AccountProvider>();
          await accountProvider.fetchAccounts(
            updatedUser,
            forceRefresh: true,
            skipLoading: true,
          );

          // 3. Fetch latest transactions to ensure balances are up to date
          final transactionProvider = context.read<TransactionProvider>();
          await transactionProvider.fetchHistory(
            updatedUser,
            forceRefresh: true,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _refreshController.stop();
        _refreshController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final accountProvider = context.watch<AccountProvider>();

    if (user == null) return const Scaffold(body: SizedBox());

    // ALL users see only their OWNED accounts here
    final myAccounts = accountProvider.accounts.where((account) {
      final hasPermission = PermissionService().isOwner(user, account);
      final matchesSearch = account.name.toLowerCase().contains(_searchQuery);
      return hasPermission && matchesSearch;
    }).toList();

    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    final Widget bodyContent = Column(
      children: [
        // Search Bar with Refresh Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search accounts...',
                      hintStyle: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      icon: Icon(
                        LucideIcons.search,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey[400],
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              // Refresh Button (Desktop only)
              if (isDesktop) ...[
                const SizedBox(width: 12),
                _isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF1E88E5),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _refreshBalances,
                        tooltip: 'Refresh pins and balances',
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFF1E88E5),
                          backgroundColor: const Color(0xFFE3F2FD),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
              ],
            ],
          ),
        ),

        // Loading Bar (visible during refresh)
        if (_isRefreshing)
          const LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
          ),

        Expanded(
          child: myAccounts.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No accounts assigned.'
                        : 'No accounts found.',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshBalances,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: myAccounts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final account = myAccounts[index];
                      final balance = account.balance;
                      final isPositive = balance >= 0;

                      return InkWell(
                        onTap: () {
                          if (MediaQuery.of(context).size.width >= 800) {
                            context.read<DashboardProvider>().setView(
                              DashboardView.ledger,
                              args: account.name,
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LedgerScreen(
                                  initialAccountName: account.name,
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isPositive
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.orange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet,
                                  color: isPositive
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      account.type,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '৳ ${CurrencyFormatter.format(balance.abs())}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPositive
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : Colors.orange.withValues(
                                              alpha: 0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isPositive ? 'Assets' : 'Liabilities',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isPositive
                                            ? Colors.blue
                                            : Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: _loadingPins.contains(account.name)
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.blue.shade700,
                                              ),
                                        ),
                                      )
                                    : Icon(
                                            user.pinnedAccountNames.contains(
                                                  account.name,
                                                )
                                                ? Icons.push_pin
                                                : Icons.push_pin_outlined,
                                            size: 18,
                                            color:
                                                user.pinnedAccountNames
                                                    .contains(account.name)
                                                ? const Color(0xFF1E88E5)
                                                : Colors.grey[400],
                                          )
                                          .animate(
                                            target:
                                                user.pinnedAccountNames
                                                    .contains(account.name)
                                                ? 1
                                                : 0,
                                          )
                                          .scale(
                                            begin: const Offset(0.8, 0.8),
                                            end: const Offset(1.1, 1.1),
                                            curve: Curves.easeOutBack,
                                          )
                                          .rotate(begin: -0.1, end: 0),
                                onPressed: () async {
                                  if (_loadingPins.contains(account.name)) {
                                    return;
                                  }

                                  final isPinned = user.pinnedAccountNames
                                      .contains(account.name);

                                  setState(() {
                                    _loadingPins.add(account.name);
                                  });

                                  try {
                                    final success = isPinned
                                        ? await context
                                              .read<UserProvider>()
                                              .unpinAccount(
                                                user.email,
                                                account.name,
                                              )
                                        : await context
                                              .read<UserProvider>()
                                              .pinAccount(
                                                user.email,
                                                account.name,
                                              );

                                    if (context.mounted && success) {
                                      // Update local user state
                                      final newPins = List<String>.from(
                                        user.pinnedAccountNames,
                                      );
                                      if (isPinned) {
                                        newPins.remove(account.name);
                                      } else {
                                        if (!newPins.contains(account.name)) {
                                          newPins.add(account.name);
                                        }
                                      }

                                      final updatedUser = user.copyWith(
                                        pinnedAccountNames: newPins,
                                      );

                                      // Update AuthProvider so all UI reflects the change
                                      context
                                          .read<AuthProvider>()
                                          .updateUserLocally(updatedUser);

                                      // Force account provider to re-sort
                                      context
                                          .read<AccountProvider>()
                                          .fetchAccounts(
                                            updatedUser,
                                            forceRefresh: true,
                                            skipLoading: true,
                                          );

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            newPins.isEmpty
                                                ? 'Account unpinned'
                                                : 'Account pinned to top',
                                          ),
                                          backgroundColor: Colors.blue[700],
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _loadingPins.remove(account.name);
                                      });
                                    }
                                  }
                                },
                                tooltip:
                                    user.pinnedAccountNames.contains(
                                      account.name,
                                    )
                                    ? 'Unpin'
                                    : 'Pin to top',
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                LucideIcons.chevronRight,
                                size: 18,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );

    if (isDesktop) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'My Accounts',
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(
                LucideIcons.refreshCw,
                color: Colors.black54,
                size: 20,
              ),
              onPressed: _refreshBalances,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: bodyContent,
    );
  }
}
