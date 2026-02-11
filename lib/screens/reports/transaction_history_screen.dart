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

import '../transaction/transaction_entry_screen.dart';
import '../transaction/transaction_detail_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      context.read<TransactionProvider>().fetchHistory(user);
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
    final transactions = roleBasedList.where((tx) {
      final txOwner = (tx.createdBy ?? '').trim().toLowerCase();
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

    return Scaffold(
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
            onPressed: () => provider.fetchHistory(user, forceRefresh: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Pro Dual-Field Filter Bar
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
          const Divider(height: 1),

          // List or Empty State
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.history,
                            size: 48,
                            color: Colors.blue.shade300,
                          ),
                        ).animate().scale(
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No transactions found',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      return _buildTransactionCard(
                            tx,
                            transactions,
                            userProvider,
                            user,
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: (index * 50).ms)
                          .slideY(
                            begin: 0.1,
                            end: 0,
                            curve: Curves.easeOutQuad,
                          );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    TransactionModel tx,
    List<TransactionModel> transactions,
    UserProvider userProvider,
    User currentUser,
  ) {
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              context.read<TransactionProvider>().fetchHistory(
                currentUser,
                forceRefresh: true,
              );
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            size: 12,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getModernDate(tx.date),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),

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
                const SizedBox(height: 10),

                // Voucher & Edit Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tx.voucherNo,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        if (tx.isFlagged) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.flag_rounded,
                            size: 14,
                            color: Colors.red.shade600,
                          ),
                        ],
                      ],
                    ),
                    if (tx.createdBy.trim().toLowerCase() ==
                            currentUser.email.trim().toLowerCase() ||
                        currentUser.isAdmin)
                      Material(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TransactionEntryScreen(transaction: tx),
                                  ),
                                )
                                .then((_) {
                                  context
                                      .read<TransactionProvider>()
                                      .fetchHistory(
                                        currentUser,
                                        forceRefresh: true,
                                      );
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
                ),
                const SizedBox(height: 10),

                // Account Lines
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ...[
                        ...tx.details.where((d) => d.debit > 0),
                        ...tx.details.where((d) => d.credit > 0),
                      ].map((detail) {
                        final isDebit = detail.debit > 0;
                        Color accentColor = isDebit
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A);

                        // Prefix Logic
                        String prefix = '';
                        if (isDebit) {
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
                        } else {
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
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (!isDebit) const SizedBox(width: 16),
                                    Container(
                                      width: 2.5,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (prefix.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          prefix,
                                          style: GoogleFonts.inter(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        detail.account?.name ?? 'Unknown',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: isDebit
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isDebit
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFF475569),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                NumberFormat('#,##0.000').format(
                                  isDebit ? detail.debit : detail.credit,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Footer: Narration & User
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DESCRIPTION',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            tx.mainNarration.isNotEmpty
                                ? tx.mainNarration
                                : 'None',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
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
                  ],
                ),
              ],
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

  String _getModernDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return 'Today, ${DateFormat('dd MMM').format(date)}';
    } else if (checkDate == yesterday) {
      return 'Yesterday, ${DateFormat('dd MMM').format(date)}';
    } else {
      return DateFormat('dd MMM, yyyy').format(date);
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
      default:
        return const Color(0xFF64748B);
    }
  }
}
