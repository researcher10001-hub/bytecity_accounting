import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../transaction/transaction_entry_screen.dart';
import '../../reports/transaction_history_screen.dart';
import '../../reports/ledger_screen.dart';
import '../../search/search_voucher_screen.dart';
import '../../admin/pending_transactions_screen.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/account_provider.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction_model.dart';

class ActionGrid extends StatelessWidget {
  final String userRole;

  const ActionGrid({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    // Determine which actions to show based on role
    final canCreateTransaction = _canCreateTransaction(userRole);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Row 1: New Transaction + Transaction History
          Row(
            children: [
              if (canCreateTransaction)
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.add_circle_outline,
                    label: 'New Transaction',
                    color: Colors.blue,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TransactionEntryScreen(),
                        ),
                      );
                      if (context.mounted) {
                        final auth = context.read<AuthProvider>();
                        if (auth.user != null) {
                          context.read<AccountProvider>().fetchAccounts(
                            auth.user!,
                          );
                          context.read<TransactionProvider>().fetchHistory(
                            auth.user!,
                            forceRefresh: true,
                          );
                        }
                      }
                    },
                  ),
                ),
              if (canCreateTransaction) const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.history_rounded,
                  label: 'Transaction History',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransactionHistoryScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Ledger + Search Voucher
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Ledger',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LedgerScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.search_rounded,
                  label: 'Search Voucher',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SearchVoucherScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          if (userRole.toLowerCase() == 'admin' ||
              userRole.toLowerCase() == 'management') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Consumer<TransactionProvider>(
                    builder: (context, txProvider, _) {
                      final pendingCount = txProvider.transactions.where((tx) {
                        return tx.status == TransactionStatus.pending ||
                            tx.status == TransactionStatus.clarification ||
                            tx.status == TransactionStatus.underReview;
                      }).length;

                      return _buildActionCard(
                        context,
                        icon: Icons.fact_check_rounded,
                        label: 'Pending for Approval ($pendingCount)',
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PendingTransactionsScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canCreateTransaction(String role) {
    final normalizedRole = role.trim().toLowerCase();
    return normalizedRole == 'admin' ||
        normalizedRole == 'management' ||
        normalizedRole == 'business operations associate';
  }
}
