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

  @override
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

    // 2. Strict Filter for "My History" + Date Filter
    final allTransactions = roleBasedList.where((tx) {
      final txOwner = tx.createdBy.trim().toLowerCase();
      final me = user.email.trim().toLowerCase();
      final isOwner = txOwner == me || txOwner.isEmpty;

      if (!isOwner) return false;

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
      // Note: This relies on fetchHistory being called with AccountProvider
      // to populate 'owners' in the Account objects.
      final isAccountOwner = tx.details.any((d) {
        return d.account?.owners.any((o) => o.trim().toLowerCase() == me) ??
            false;
      });

      // Show if I created it OR I deleted it OR I own an account involved
      bool show = isCreator || isDeleter || isAccountOwner;
      if (show) {
        print(
          "DEBUG: Showing Removed TX: ${tx.voucherNo} (Creator: $isCreator, Deleter: $isDeleter, Owner: $isAccountOwner)",
        );
      }
      return show;
    }).toList();

    print(
      "DEBUG: Active Count: ${activeTransactions.length}, Removed Count: ${removedTransactions.length}",
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Transaction History',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: const Color(0xFF1E293B),
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
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
            indicatorColor: const Color(0xFF2563EB),
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Removed'),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Pro Dual-Field Filter Bar (Shared for both tabs)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDateTile(
                      'From',
                      _dateRange?.start,
                      () => _selectDate(isStart: true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      LucideIcons.arrowRight,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Expanded(
                    child: _buildDateTile(
                      'To',
                      _dateRange?.end,
                      _dateRange?.start == null
                          ? null
                          : () => _selectDate(isStart: false),
                    ),
                  ),
                  if (_dateRange != null) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => setState(() => _dateRange = null),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            LucideIcons.x,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                          decoration: isRemoved
                              ? TextDecoration.lineThrough
                              : null,
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
                              decoration: isRemoved
                                  ? TextDecoration.lineThrough
                                  : null,
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
                              decoration: isRemoved
                                  ? TextDecoration.lineThrough
                                  : null,
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
                                      builder: (context) =>
                                          TransactionEntryScreen(
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

  Widget _buildDateTile(String label, DateTime? date, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF1F5F9) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null
                ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 14,
                    color: date != null
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      date == null
                          ? 'Select'
                          : DateFormat('dd MMM, yy').format(date),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: date != null
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final primaryColor = const Color(0xFF2563EB);
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_dateRange?.start ?? DateTime.now())
          : (_dateRange?.end ?? _dateRange?.start ?? DateTime.now()),
      firstDate: isStart
          ? DateTime(2020)
          : (_dateRange?.start ?? DateTime(2020)),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: primaryColor,
          brightness: Brightness.light,
          textTheme: GoogleFonts.interTextTheme(),
          datePickerTheme: DatePickerThemeData(
            headerBackgroundColor: primaryColor,
            headerForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            dayStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _dateRange = DateTimeRange(
            start: picked,
            end: _dateRange?.end != null && _dateRange!.end.isAfter(picked)
                ? _dateRange!.end
                : picked,
          );
        } else {
          _dateRange = DateTimeRange(
            start: _dateRange?.start ?? picked,
            end: picked,
          );
        }
      });
    }
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
