import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';

import '../../providers/account_provider.dart';

import '../../providers/dashboard_provider.dart';
import '../transaction/transaction_entry_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import '../../core/utils/currency_formatter.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  DateTimeRange? _dateRange;
  String _selectedViewFilter = 'My History';
  void initState() {
    super.initState();
    // Default to show TODAY's transactions
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      final accountProvider = context.read<AccountProvider>();
      context.read<TransactionProvider>().fetchHistory(
            user,
            accountProvider: accountProvider,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final provider = context.watch<TransactionProvider>();

    if (user == null) return const SizedBox.shrink();

    // Use the filtered list from Provider
    final userProvider = context.watch<UserProvider>();
    // 1. Get transactions visible to role
    final roleBasedList = provider.getVisibleTransactions(user);

    // 2. Strict Filter for "My History" / "Owned Accounts" / "All Transactions" + Date Filter
    final bool canViewOthers =
        user.isAdmin || user.role == 'management' || user.role == 'viewer';

    final allTransactions = roleBasedList.where((tx) {
      final txOwner = tx.createdBy.trim().toLowerCase();
      final me = user.email.trim().toLowerCase();
      final isCreator = txOwner == me || txOwner.isEmpty;

      bool isOwnedAccount = false;
      if (_selectedViewFilter == 'Owned Accounts') {
        final accountProvider = context.read<AccountProvider>();
        isOwnedAccount = tx.details.any((d) {
          try {
            final realAccount = accountProvider.accounts.firstWhere(
              (a) => a.name == d.account?.name,
            );
            return realAccount.owners.any((o) => o.toLowerCase() == me);
          } catch (e) {
            return false;
          }
        });
      }

      bool isVisible = false;
      if (!canViewOthers || _selectedViewFilter == 'My History') {
        isVisible = isCreator;
      } else if (_selectedViewFilter == 'Owned Accounts') {
        isVisible = isCreator || isOwnedAccount;
      } else if (_selectedViewFilter == 'All Transactions') {
        isVisible =
            true; // Role-based list already filters for Admin/Mgmt/Viewer
      }

      if (!isVisible) return false;

      // Date Filter with Normalization
      if (_dateRange != null) {
        final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
        if (txDate.isBefore(_dateRange!.start) ||
            txDate.isAfter(_dateRange!.end)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 3. Split into Active and Removed
    // Note: We bypass the strict "My History" filter for Removed items
    // that if I deleted/edited a transaction (even if I didn't create the original),
    // I can still see it in the Removed tab.
    // However, for now, let's keep it simple and debug the visibility.
    print(
      "DEBUG: History Screen - Total Visibile (Role): ${roleBasedList.length}",
    );
    print(
      "DEBUG: History Screen - Total My History: ${allTransactions.length}",
    );

    final activeTransactions = allTransactions
        .where((tx) => tx.status != TransactionStatus.deleted)
        .toList();

    // For Removed tab, we might want to show items where I am the 'lastActionBy' (deleter)
    // OR the creator.
    // But 'allTransactions' already filtered by 'createdBy == me'.
    // If I edited someone else's transaction, I created the NEW one, but not the OLD one.
    // So the OLD one is filtered out by 'allTransactions'.

    // Fix: We need a separate list for Removed transactions that includes items
    // where I am the creator OR I am the one who deleted it (lastActionBy)
    // OR I am an owner of one of the accounts in the transaction.

    final removedTransactions = roleBasedList.where((tx) {
      if (tx.status != TransactionStatus.deleted) return false;

      // Removed Date Filter: Show all removed/deleted items regardless of date
      // This ensures users can find old transactions they just deleted/edited.

      final me = user.email.trim().toLowerCase();
      final isCreator = tx.createdBy.trim().toLowerCase() == me;
      final isDeleter = (tx.lastActionBy ?? '').trim().toLowerCase() == me;

      // Check if I am an owner of any account in this transaction
      bool isOwnedAccount = false;
      final accountProvider = context.read<AccountProvider>();
      isOwnedAccount = tx.details.any((d) {
        try {
          final realAccount = accountProvider.accounts.firstWhere(
            (a) => a.name == d.account?.name,
          );
          return realAccount.owners.any((o) => o.toLowerCase() == me);
        } catch (e) {
          return false;
        }
      });

      bool isVisible = false;
      if (!canViewOthers || _selectedViewFilter == 'My History') {
        isVisible = isCreator ||
            isDeleter ||
            isOwnedAccount; // Keep original "My History" logic for removed which is broader
      } else if (_selectedViewFilter == 'Owned Accounts') {
        isVisible = isCreator || isDeleter || isOwnedAccount;
      } else if (_selectedViewFilter == 'All Transactions') {
        isVisible =
            true; // Role-based list already filters for Admin/Mgmt/Viewer
      }

      if (isVisible) {
        print(
          "DEBUG: Showing Removed TX: ${tx.voucherNo} (Creator: $isCreator, Deleter: $isDeleter, Owner: $isOwnedAccount)",
        );
      }
      return isVisible;
    }).toList();

    print(
      "DEBUG: Active Count: ${activeTransactions.length}, Removed Count: ${removedTransactions.length}",
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'History',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: const Color(0xFF1E293B),
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
          actions: [
            if (canViewOthers)
              PopupMenuButton<String>(
                tooltip: 'View Filter',
                child: Center(
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedViewFilter == 'My History'
                              ? LucideIcons.user
                              : _selectedViewFilter == 'Owned Accounts'
                                  ? LucideIcons.briefcase
                                  : LucideIcons.globe,
                          size: 14,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedViewFilter,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.chevronDown,
                            size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                onSelected: (String newValue) {
                  setState(() {
                    _selectedViewFilter = newValue;
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'My History',
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.user,
                          size: 16,
                          color: _selectedViewFilter == 'My History'
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'My History',
                          style: GoogleFonts.inter(
                            fontWeight: _selectedViewFilter == 'My History'
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: _selectedViewFilter == 'My History'
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'Owned Accounts',
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.briefcase,
                          size: 16,
                          color: _selectedViewFilter == 'Owned Accounts'
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Owned Accounts',
                          style: GoogleFonts.inter(
                            fontWeight: _selectedViewFilter == 'Owned Accounts'
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: _selectedViewFilter == 'Owned Accounts'
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'All Transactions',
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.globe,
                          size: 16,
                          color: _selectedViewFilter == 'All Transactions'
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'All Transactions',
                          style: GoogleFonts.inter(
                            fontWeight:
                                _selectedViewFilter == 'All Transactions'
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                            color: _selectedViewFilter == 'All Transactions'
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            IconButton(
              icon: Icon(
                LucideIcons.calendar,
                size: 20,
                color: _dateRange != null
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
              ),
              tooltip: 'Date Filter',
              onPressed: () => _showDateFilterDialog(context),
            ),
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              tooltip: 'Refresh',
              onPressed: () {
                final accountProvider = context.read<AccountProvider>();
                provider.fetchHistory(
                  user,
                  forceRefresh: true,
                  accountProvider: accountProvider,
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12, // Made text smaller
            ),
            tabs: [
              const Tab(text: 'Active'),
              Tab(
                child: Builder(
                  builder: (context) {
                    final int tabIndex = DefaultTabController.of(context).index;
                    final bool isSelected = tabIndex == 1;
                    return Text(
                      'Removed',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF64748B),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Date Filter removed from here, now in AppBar via dialog
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // TabBar View
            Expanded(
              child: TabBarView(
                children: [
                  _buildTransactionList(
                    activeTransactions,
                    userProvider,
                    user,
                    provider.isLoading,
                  ),
                  _buildTransactionList(
                    removedTransactions,
                    userProvider,
                    user,
                    provider.isLoading,
                    isRemoved: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(
    List<TransactionModel> transactions,
    UserProvider userProvider,
    User currentUser,
    bool isLoading, {
    bool isRemoved = false,
  }) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isRemoved ? Colors.grey.shade50 : Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRemoved ? LucideIcons.trash2 : LucideIcons.history,
                size: 48,
                color: isRemoved ? Colors.grey.shade300 : Colors.blue.shade300,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(
              isRemoved ? 'No removed transactions' : 'No transactions found',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _buildTransactionCard(
          tx,
          transactions, // Pass contextual list
          userProvider,
          currentUser,
          isRemoved: isRemoved,
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: (index * 50).ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
      },
    );
  }

  Widget _buildTransactionCard(
    TransactionModel tx,
    List<TransactionModel> transactions,
    UserProvider userProvider,
    User currentUser, {
    bool isRemoved = false,
  }) {
    // Footer Type Logic
    String typeLabel = '';
    IconData typeIcon = LucideIcons.tag;
    switch (tx.type) {
      case VoucherType.payment:
        typeLabel = 'Payment';
        break;
      case VoucherType.receipt:
        typeLabel = 'Receipt';
        break;
      case VoucherType.contra:
        typeLabel = 'Transfer';
        typeIcon = LucideIcons.arrowLeftRight;
        break;
      case VoucherType.journal:
        typeLabel = 'Journal';
        break;
    }

    // Filter Debits and Credits
    final debits = tx.details.where((d) => d.debit > 0).toList();
    final credits = tx.details.where((d) => d.credit > 0).toList();

    return Opacity(
      opacity: isRemoved ? 0.7 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isRemoved ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isRemoved ? Border.all(color: Colors.grey.shade200) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (MediaQuery.of(context).size.width >= 800) {
                context.read<DashboardProvider>().setView(
                  DashboardView.transactionDetail,
                  args: {'transaction': tx, 'allTransactions': transactions},
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailScreen(
                      transaction: tx,
                      allTransactions: transactions,
                    ),
                  ),
                ).then((_) {
                  if (mounted) {
                    context.read<TransactionProvider>().fetchHistory(
                          currentUser,
                          forceRefresh: true,
                        );
                  }
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ROW 1: [Date] [Voucher ID (dim)] [Status]
                  Row(
                    children: [
                      // Date
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isRemoved
                              ? Colors.grey.shade100
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.calendar,
                              size: 12,
                              color: isRemoved
                                  ? Colors.grey.shade500
                                  : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(tx.date),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isRemoved
                                    ? Colors.grey.shade600
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Voucher ID (Small & Dim)
                      Text(
                        tx.voucherNo,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          decoration:
                              isRemoved ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (tx.isFlagged) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.flag_rounded,
                          size: 12,
                          color: Colors.red.shade400,
                        ),
                      ],
                      if (tx.erpSyncStatus.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildSyncIndicator(tx.erpSyncStatus),
                      ],

                      const Spacer(),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            tx.status,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(
                              tx.status,
                            ).withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          tx.status.toString().split('.').last.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: _getStatusColor(tx.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ROW 2: Debits
                  ...debits.map((d) {
                    String prefix = 'Dr.';
                    switch (tx.type) {
                      case VoucherType.payment:
                        prefix = 'Expense for';
                        break;
                      case VoucherType.receipt:
                        prefix = 'Received in';
                        break;
                      case VoucherType.contra:
                        prefix = 'Transfer to';
                        break;
                      default:
                        prefix = 'Dr.';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            prefix,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              d.account?.name ?? 'Unknown',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                                decoration: isRemoved
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${CurrencyFormatter.getCurrencySymbol(d.currency)} ${CurrencyFormatter.format(d.debit)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isRemoved
                                  ? Colors.grey.shade500
                                  : const Color(0xFF16A34A), // Green
                              decoration:
                                  isRemoved ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // ROW 3: Credits
                  ...credits.map((c) {
                    String prefix = 'Cr.';
                    switch (tx.type) {
                      case VoucherType.payment:
                        prefix = 'Paid from';
                        break;
                      case VoucherType.receipt:
                        prefix = 'Income from';
                        break;
                      case VoucherType.contra:
                        prefix = 'Transfer from';
                        break;
                      default:
                        prefix = 'Cr.';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const SizedBox(width: 24), // Indent for Credit
                          Text(
                            prefix,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              c.account?.name ?? 'Unknown',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                                decoration: isRemoved
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${CurrencyFormatter.getCurrencySymbol(c.currency)} ${CurrencyFormatter.format(c.credit)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isRemoved
                                  ? Colors.grey.shade500
                                  : const Color(0xFFDC2626), // Red
                              decoration:
                                  isRemoved ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),

                  // ROW 4: [Note: (small)] [Main Narration] ... [Type] [Edit]
                  Row(
                    children: [
                      // Note
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                            children: [
                              TextSpan(
                                text: 'Note: ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              TextSpan(
                                text: tx.mainNarration.isNotEmpty
                                    ? tx.mainNarration
                                    : 'None',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              typeIcon,
                              size: 10,
                              color: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              typeLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit Button (if owner/admin) - DISABLED FOR REMOVED
                      if (!isRemoved &&
                          (tx.createdBy.trim().toLowerCase() ==
                                  currentUser.email.trim().toLowerCase() ||
                              currentUser.isAdmin)) ...[
                        const SizedBox(width: 8),
                        Material(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                MaterialPageRoute(
                                  builder: (context) => TransactionEntryScreen(
                                    transaction: tx,
                                  ),
                                ),
                              )
                                  .then((_) {
                                if (mounted) {
                                  context
                                      .read<TransactionProvider>()
                                      .fetchHistory(
                                        currentUser,
                                        forceRefresh: true,
                                      );
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                LucideIcons.edit3,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Modern Date Filter Dialog ---
  Future<void> _showDateFilterDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2563EB).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.calendar,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter by Date',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select a custom time period',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Date Selection Area
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDateTile(
                              'Start Date',
                              _dateRange?.start,
                              () async {
                                final now = DateTime.now();
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate: _dateRange?.start ?? now,
                                  firstDate: DateTime(2000),
                                  lastDate: now,
                                );
                                if (selected != null) {
                                  setDialogState(() {
                                    _dateRange = DateTimeRange(
                                      start: selected,
                                      end: _dateRange?.end ?? selected,
                                    );
                                  });
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: const Icon(
                              LucideIcons.arrowRight,
                              color: Color(0xFF94A3B8),
                              size: 16,
                            ),
                          ),
                          Expanded(
                            child: _buildDateTile(
                              'End Date',
                              _dateRange?.end,
                              _dateRange?.start == null
                                  ? null
                                  : () async {
                                      final selected = await showDatePicker(
                                        context: context,
                                        initialDate: _dateRange?.end ??
                                            _dateRange!.start,
                                        firstDate: _dateRange!.start,
                                        lastDate: DateTime.now(),
                                      );
                                      if (selected != null) {
                                        setDialogState(() {
                                          _dateRange = DateTimeRange(
                                            start: _dateRange!.start,
                                            end: selected,
                                          );
                                        });
                                        setState(() {});
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        if (_dateRange != null)
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setDialogState(() => _dateRange = null);
                                setState(() {});
                                Navigator.pop(dialogContext);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Clear',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Apply Range',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Modern Date Tile Widget ---
  Widget _buildDateTile(String label, DateTime? date, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  date != null ? const Color(0xFF2563EB) : Colors.transparent,
            ),
            color: date != null
                ? const Color(0xFF2563EB).withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: date == null
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: date != null
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date != null ? DateFormat('dd MMM, yy').format(date) : "Select",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: date != null
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.approved:
        return const Color(0xFF16A34A);
      case TransactionStatus.rejected:
        return const Color(0xFFDC2626);
      case TransactionStatus.clarification:
        return const Color(0xFFEA580C);
      case TransactionStatus.correction:
        return const Color(0xFFD97706);
      case TransactionStatus.deleted:
        return const Color(0xFF94A3B8); // Grey
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildSyncIndicator(String status) {
    // Normalize status
    final normalizedStatus = status.trim().toLowerCase();

    IconData icon;
    Color color;
    String tooltip;

    if (normalizedStatus == 'synced') {
      icon = Icons.sync_rounded;
      color = const Color(0xFF2563EB);
      tooltip = 'Synced to ERPNext';
    } else if (normalizedStatus == 'manual') {
      icon = Icons.edit_note_rounded;
      color = const Color(0xFF2563EB);
      tooltip = 'Manually entered in ERPNext';
    } else {
      // Default / 'none'
      icon = Icons.sync_problem_rounded;
      color = Colors.red.shade300;
      tooltip = 'Not synced to ERPNext';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
