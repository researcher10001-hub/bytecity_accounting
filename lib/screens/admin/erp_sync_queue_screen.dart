import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/transaction_model.dart';
import '../../core/utils/currency_formatter.dart';
import '../transaction/transaction_detail_screen.dart';

class ERPSyncQueueScreen extends StatefulWidget {
  const ERPSyncQueueScreen({super.key});

  @override
  State<ERPSyncQueueScreen> createState() => _ERPSyncQueueScreenState();
}

class _ERPSyncQueueScreenState extends State<ERPSyncQueueScreen> {
  bool _isProcessing = false;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<TransactionModel> _internalQueue = [];

  void _updateItems(List<TransactionModel> newQueue) {
    // 1. Handle removals
    for (int i = _internalQueue.length - 1; i >= 0; i--) {
      final item = _internalQueue[i];
      if (!newQueue.any((newItem) => newItem.voucherNo == item.voucherNo)) {
        final removedItem = _internalQueue.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildRemovedItem(removedItem, animation),
          duration: const Duration(milliseconds: 500),
        );
      }
    }

    // 2. Handle additions
    for (int i = 0; i < newQueue.length; i++) {
      final newItem = newQueue[i];
      if (!_internalQueue.any((item) => item.voucherNo == newItem.voucherNo)) {
        _internalQueue.insert(i, newItem);
        _listKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 500),
        );
      }
    }
  }

  Widget _buildRemovedItem(TransactionModel item, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        child: _buildSyncCard(context, item, isRemoved: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'ERP Sync Queue',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _isProcessing ? null : _refresh,
            tooltip: 'Refresh Queue',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF2563EB),
        child: Consumer<TransactionProvider>(
          builder: (context, txProvider, _) {
            final queue = txProvider.transactions.where((tx) {
              final statusMatch = tx.status == TransactionStatus.approved;
              final syncMatch =
                  tx.erpSyncStatus.trim().toLowerCase() == 'none' ||
                  tx.erpSyncStatus.trim().isEmpty;
              return statusMatch && syncMatch;
            }).toList();

            // Sync internal list with provider list
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateItems(queue);
            });

            if (queue.isEmpty && _internalQueue.isEmpty) {
              return _buildEmptyState();
            }

            return AnimatedList(
              key: _listKey,
              padding: const EdgeInsets.all(16),
              initialItemCount: _internalQueue.length,
              itemBuilder: (context, index, animation) {
                if (index >= _internalQueue.length) return const SizedBox();
                final tx = _internalQueue[index];
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    child: _buildSyncCard(context, tx),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSyncCard(
    BuildContext context,
    TransactionModel tx, {
    bool isRemoved = false,
  }) {
    final debits = tx.details.where((item) => item.debit > 0).toList();
    final credits = tx.details.where((item) => item.credit > 0).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isRemoved
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailScreen(
                        transaction: tx,
                        allTransactions: [tx],
                      ),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER: [Date] [Indicator] ... [Voucher ID (light)]
                // HEADER: [Date] [Indicator] ... [Voucher ID (subtle)]
                Row(
                  children: [
                    // Date (Premium Style)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isRemoved
                            ? Colors.grey.shade100
                            : const Color(0xFFF0F7FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            size: 13,
                            color: isRemoved
                                ? Colors.grey.shade500
                                : const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yyyy').format(tx.date),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isRemoved
                                  ? Colors.grey.shade600
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildSyncIndicator(tx.erpSyncStatus),
                    const Spacer(),
                    // Voucher ID (Right aligned, subtle)
                    Text(
                      tx.voucherNo,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                        decoration: isRemoved
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // DEBITS
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
                                : const Color(0xFF16A34A),
                            decoration: isRemoved
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // CREDITS
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
                        const SizedBox(width: 24),
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
                                : const Color(0xFFDC2626),
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

                // INFO ROW
                Row(
                  children: [
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
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 16),

                // ACTIONS
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'Mark Manual',
                        icon: LucideIcons.edit,
                        color: Colors.grey.shade600,
                        onTap: isRemoved
                            ? () {}
                            : () => _handleSync(tx, isManual: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        label: 'Push to ERP',
                        icon: LucideIcons.refreshCw,
                        color: const Color(0xFF2563EB),
                        isPrimary: true,
                        onTap: isRemoved
                            ? () {}
                            : () => _handleSync(tx, isManual: false),
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isProcessing ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isPrimary ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: isPrimary
                ? null
                : Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isPrimary ? Colors.white : color.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? Colors.white
                      : color.withValues(alpha: 0.8),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    await context.read<TransactionProvider>().fetchHistory(
      user,
      forceRefresh: true,
    );
  }

  Future<void> _handleSync(
    TransactionModel tx, {
    required bool isManual,
  }) async {
    setState(() => _isProcessing = true);
    try {
      final success = await context.read<TransactionProvider>().syncToERPNext(
        voucherNo: tx.voucherNo,
        isManual: isManual,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isManual
                    ? 'Marked as manual in ERPNext'
                    : 'Successfully synced to ERPNext',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Auto-refresh on success
          await _refresh();
        } else {
          final error = context.read<TransactionProvider>().error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync failed: ${error ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.checkCircle,
              size: 64,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sync Queue Clear!',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All approved transactions are synced.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncIndicator(String status) {
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
