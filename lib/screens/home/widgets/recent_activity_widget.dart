import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/transaction_model.dart';
import '../../transaction/transaction_detail_screen.dart';
import '../../../providers/dashboard_provider.dart';

class RecentActivityWidget extends StatefulWidget {
  const RecentActivityWidget({super.key});

  @override
  State<RecentActivityWidget> createState() => _RecentActivityWidgetState();
}

class _RecentActivityWidgetState extends State<RecentActivityWidget> {
  int _selectedDays = 1; // Default to Today

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    final txProvider = context.watch<TransactionProvider>();
    final activities = txProvider.getRecentActivity(
      user.email,
      days: _selectedDays,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "RECENT ACTIVITY",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade700,
                  letterSpacing: 1.1,
                ),
              ),
              _buildFilterToggle(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                "No activity found for this period",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length > 5 ? 5 : activities.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final activity = activities[index];
              // Map all activities to their corresponding transactions for context
              final allRelatedTransactions = activities.map((a) {
                final vNo = a['voucher_no']?.toString() ?? '';
                return txProvider.transactions.firstWhere(
                  (t) => t.voucherNo == vNo,
                  orElse: () => txProvider.transactions.first,
                );
              }).toList();

              return _buildActivityItem(
                context,
                activity,
                allRelatedTransactions,
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterButton("Today", 1),
          _buildFilterButton("Yesterday", 2),
          _buildFilterButton("7D", 7),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, int days) {
    final isSelected = _selectedDays == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.blue : Colors.blueGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    Map<String, dynamic> activity,
    List<TransactionModel> allTransactions,
  ) {
    final type = activity['type']?.toString().toLowerCase() ?? 'comment';
    final voucherNo = activity['voucher_no']?.toString() ?? 'Unknown';
    final timestamp =
        DateTime.tryParse(activity['timestamp']?.toString() ?? '') ??
        DateTime.now();
    final description = activity['description']?.toString() ?? '';
    final amount =
        double.tryParse(activity['amount']?.toString() ?? '0') ?? 0.0;
    final currency = activity['currency']?.toString() ?? 'BDT';

    IconData icon;
    Color color;
    String actionText;

    switch (type) {
      case 'approve':
      case 'auto_approve':
        icon = LucideIcons.checkCircle2;
        color = Colors.green;
        actionText = "Approved";
        break;
      case 'reject':
        icon = LucideIcons.xCircle;
        color = Colors.red;
        actionText = "Rejected";
        break;
      case 'flag':
      case 'flagged':
        icon = Icons.flag_rounded;
        color = Colors.orange.shade800;
        actionText = "Flagged for Audit";
        break;
      case 'clarify':
        icon = LucideIcons.helpCircle;
        color = Colors.orange;
        actionText = "Clarification Requested";
        break;
      case 'create':
      case 'created':
        icon = LucideIcons.plusCircle;
        color = Colors.blue;
        actionText = "Created";
        break;
      case 'unflagged':
        icon = Icons.outlined_flag;
        color = Colors.blueGrey;
        actionText = "Flag Resolved";
        break;
      default:
        icon = LucideIcons.messageSquare;
        color = Colors.grey;
        actionText = "Commented";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Find the full transaction object to navigate
            final txProvider = context.read<TransactionProvider>();
            try {
              final tx = txProvider.transactions.firstWhere(
                (t) => t.voucherNo == voucherNo,
              );
              if (MediaQuery.of(context).size.width >= 800) {
                context.read<DashboardProvider>().setView(
                  DashboardView.transactionDetail,
                  args: {'transaction': tx, 'allTransactions': allTransactions},
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailScreen(
                      transaction: tx,
                      allTransactions: allTransactions,
                    ),
                  ),
                );
              }
            } catch (e) {
              // Not found or not visible
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Transaction details not available"),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$actionText - $voucherNo",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            DateFormat('h:mm a').format(timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat('#,##0').format(amount),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    Text(
                      currency,
                      style: GoogleFonts.inter(fontSize: 8, color: Colors.grey),
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
}
