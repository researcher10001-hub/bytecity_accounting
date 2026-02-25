import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../reports/ledger_screen.dart';
import '../../search/search_voucher_screen.dart';
import '../../admin/pending_transactions_screen.dart';
import '../../admin/erp_sync_queue_screen.dart';
import '../../reports/branch_entries_screen.dart';
import '../../../providers/transaction_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/dashboard_provider.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction_model.dart';

class ActionGrid extends StatelessWidget {
  final String userRole;

  const ActionGrid({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final bool isAdmin = userRole.trim().toLowerCase() == 'admin';
    final bool isAssociate = user?.isAssociate ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (!isAssociate) ...[
            // Row: Branch Entries (Visible to all EXCEPT Associates)
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.store_mall_directory_rounded,
                    label: 'Branch Entries',
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BranchEntriesScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (isAdmin) ...[
            // Row: Ledger + Search Voucher
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Ledger',
                    color: Colors.green,
                    onTap: () {
                      final dp = context.read<DashboardProvider>();
                      if (MediaQuery.of(context).size.width >= 800) {
                        dp.setView(DashboardView.ledger);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LedgerScreen(),
                          ),
                        );
                      }
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
                      final dp = context.read<DashboardProvider>();
                      if (MediaQuery.of(context).size.width >= 800) {
                        dp.setView(DashboardView.search);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchVoucherScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
          if ((userRole.toLowerCase() == 'admin' ||
                  userRole.toLowerCase() == 'management') &&
              context.watch<AuthProvider>().user?.allowAutoApproval ==
                  true) ...[
            const SizedBox(height: 10),
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
                        onTap: () async {
                          final dp = context.read<DashboardProvider>();
                          if (MediaQuery.of(context).size.width >= 800) {
                            dp.setView(DashboardView.pending);
                          } else {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const PendingTransactionsScreen(),
                              ),
                            );
                            if (context.mounted) {
                              final auth = context.read<AuthProvider>();
                              if (auth.user != null) {
                                context
                                    .read<TransactionProvider>()
                                    .fetchHistory(
                                      auth.user!,
                                      forceRefresh: true,
                                    );
                              }
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Consumer<TransactionProvider>(
                    builder: (context, txProvider, _) {
                      final syncCount = txProvider.transactions.where((tx) {
                        return tx.status == TransactionStatus.approved &&
                            tx.erpSyncStatus == 'none';
                      }).length;

                      return _buildActionCard(
                        context,
                        icon: Icons.sync_rounded,
                        label: 'ERP Sync Queue ($syncCount)',
                        color: Colors.teal,
                        onTap: () async {
                          final dp = context.read<DashboardProvider>();
                          if (MediaQuery.of(context).size.width >= 800) {
                            dp.setView(DashboardView.erpSync);
                          } else {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ERPSyncQueueScreen(),
                              ),
                            );
                            if (context.mounted) {
                              final auth = context.read<AuthProvider>();
                              if (auth.user != null) {
                                context
                                    .read<TransactionProvider>()
                                    .fetchHistory(
                                      auth.user!,
                                      forceRefresh: true,
                                    );
                              }
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
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
    return _ActionCard(icon: icon, label: label, color: color, onTap: onTap);
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: _isHovered
            ? (Matrix4.identity()..translate(0, -4))
            : Matrix4.identity(),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? widget.color.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: _isHovered ? 15 : 8,
                  offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: _isHovered
                    ? widget.color.withOpacity(0.3)
                    : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
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
        ),
      ),
    );
  }
}
