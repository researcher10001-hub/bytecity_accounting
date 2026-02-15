import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

            if (queue.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final tx = queue[index];
                return _buildSyncCard(context, tx);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context, TransactionModel tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
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
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tx.voucherNo,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${CurrencyFormatter.format(tx.totalDebit)} ${tx.currency}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tx.mainNarration.isNotEmpty
                      ? tx.mainNarration
                      : "No additional notes",
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'Mark Manual',
                        icon: LucideIcons.edit,
                        color: Colors.grey.shade600,
                        onTap: () => _handleSync(tx, isManual: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        label: 'Push to ERP',
                        icon: LucideIcons.refreshCw,
                        color: const Color(0xFF2563EB),
                        isPrimary: true,
                        onTap: () => _handleSync(tx, isManual: false),
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
    return InkWell(
      onTap: _isProcessing ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isPrimary ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : color,
              ),
            ),
          ],
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
}
