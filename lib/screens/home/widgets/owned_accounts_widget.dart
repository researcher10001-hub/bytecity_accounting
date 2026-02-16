import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../reports/ledger_screen.dart';
import '../../../models/account_model.dart';

class OwnedAccountsWidget extends StatefulWidget {
  final String userEmail;
  const OwnedAccountsWidget({super.key, required this.userEmail});

  @override
  State<OwnedAccountsWidget> createState() => _OwnedAccountsWidgetState();
}

class _OwnedAccountsWidgetState extends State<OwnedAccountsWidget>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  DateTime? _lastRefreshTime;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _refreshRotationController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _refreshRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _refreshRotationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh(BuildContext context) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final accountProvider = context.read<AccountProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final userProvider = context.read<UserProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    _refreshRotationController.repeat();

    // Use forceRefresh to trigger loading state
    await accountProvider.fetchAccounts(user, forceRefresh: true);
    await transactionProvider.fetchHistory(user, forceRefresh: true);

    if (mounted) {
      _refreshRotationController.stop();
      // OPTIMIZATION: Removed client-side balance calculation
      // accountProvider.updateBalancesFromTransactions(
      //   transactionProvider.transactions,
      // );
      notificationProvider.refreshNotifications(
        user,
        transactionProvider,
        userProvider,
        accountProvider: accountProvider,
      );
      setState(() {
        _lastRefreshTime = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AccountProvider, GroupProvider, TransactionProvider>(
      builder: (context, accountProvider, groupProvider, transactionProvider, _) {
        final ownedAccounts = accountProvider.accounts
            .where(
              (acc) => acc.owners.any(
                (owner) =>
                    owner.toLowerCase() == widget.userEmail.toLowerCase(),
              ),
            )
            .toList();

        if (ownedAccounts.isEmpty) return const SizedBox.shrink();

        final filteredAccounts = ownedAccounts.where((acc) {
          return acc.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        // Calculate Grand Total
        double grandTotal = 0.0;
        for (var acc in ownedAccounts) {
          grandTotal += (acc.totalDebit - acc.totalCredit);
        }
        final isTotalPositive = grandTotal >= 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header / Toggle
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                    if (_isExpanded) {
                      _controller.forward();
                    } else {
                      _controller.reverse();
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isTotalPositive
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: isTotalPositive ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Account Balances',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${ownedAccounts.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                      if (_lastRefreshTime != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Last refreshed: ${DateFormat('hh:mm a').format(_lastRefreshTime!)}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red[50], // Light red background
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: _pulseAnimation.value,
                                  spreadRadius: _pulseAnimation.value / 2,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: RotationTransition(
                          turns: _refreshRotationController,
                          child: IconButton(
                            onPressed: () => _handleRefresh(context),
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                            tooltip: 'Refresh balances',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RotationTransition(
                        turns: Tween(begin: 0.0, end: 0.5).animate(_controller),
                        child: const Icon(
                          Icons.expand_more, // Always more, rotated to less
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizeTransition(
                sizeFactor: _expandAnimation,
                axisAlignment: -1.0,
                child: Column(
                  children: [
                    if (accountProvider.isLoading ||
                        transactionProvider.isLoading)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.redAccent,
                        ),
                      ),
                    const Divider(height: 1),
                    if (ownedAccounts.length > 5)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search accounts...',
                            hintStyle: GoogleFonts.inter(fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.all(8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredAccounts.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final acc = filteredAccounts[index];
                        // Balance logic: Simplified as requested, but accounting-correct
                        final balance = acc.totalDebit - acc.totalCredit;
                        final isNatural = _isNaturalBalance(acc, balance);

                        return ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    LedgerScreen(initialAccountName: acc.name),
                              ),
                            );
                          },
                          title: Text(
                            acc.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            groupProvider.getGroupNames(acc.groupIds),
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '৳ ${NumberFormat('#,##0.00').format(balance.abs())}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isNatural
                                      ? Colors.black87
                                      : Colors.red,
                                ),
                              ),
                              Text(
                                balance >= 0 ? 'DR' : 'CR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: balance >= 0
                                      ? Colors.blue
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isNaturalBalance(Account acc, double balance) {
    if (balance == 0) return true;
    final type = acc.type.toLowerCase();
    // Assets & Expenses usually have Debit (Positive)
    // Liabilities, Equity, Revenue usually have Credit (Negative)
    if (type.contains('asset') || type.contains('expense')) {
      return balance > 0;
    } else {
      return balance < 0;
    }
  }
}
