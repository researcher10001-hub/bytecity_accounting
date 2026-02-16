import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/activity_item.dart';
import '../models/transaction_model.dart';
import '../screens/transaction/transaction_detail_screen.dart';
import '../providers/transaction_provider.dart';
import 'package:provider/provider.dart';

class RecentApprovalsWidget extends StatefulWidget {
  final String userEmail;

  const RecentApprovalsWidget({super.key, required this.userEmail});

  @override
  State<RecentApprovalsWidget> createState() => _RecentApprovalsWidgetState();
}

class _RecentApprovalsWidgetState extends State<RecentApprovalsWidget> {
  bool _isExpanded = false;
  bool _todayOnly = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final approvals = provider.getApprovedActivities(
          widget.userEmail,
          days: _todayOnly ? 1 : 0,
        );

        // TEMPORARY: Show widget even when empty for testing
        // if (approvals.isEmpty) {
        //   return const SizedBox.shrink(); // Hide if no approvals
        // }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildHeader(approvals.length),
              if (_isExpanded) _buildApprovalsList(approvals),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(int count) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Approvals',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'entry' : 'entries'} approved ${_todayOnly ? 'today' : 'in last 24h'}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            _buildToggleButton(),
            const SizedBox(width: 8),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption('24h', !_todayOnly),
          _buildToggleOption('Today', _todayOnly),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _todayOnly = label == 'Today';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalsList(List<Map<String, dynamic>> approvals) {
    // Extract models for all approvals in the list
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final allRelatedTransactions = approvals.map((a) {
      final voucherNo = a['voucherNo'];
      return provider.transactions.firstWhere(
        (t) => t.voucherNo == voucherNo,
        orElse: () => provider.transactions.first,
      );
    }).toList();

    // Empty state
    if (approvals.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No approvals ${_todayOnly ? 'today' : 'in last 24h'}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Backend tracking not yet enabled',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: approvals.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Colors.grey[300],
        ),
        itemBuilder: (context, index) {
          final approvalData = approvals[index];
          final approval = ActivityItem.fromJson(approvalData);
          final tx = allRelatedTransactions[index];
          return _buildApprovalCard(approval, tx, allRelatedTransactions);
        },
      ),
    );
  }

  Widget _buildApprovalCard(
    ActivityItem approval,
    TransactionModel tx,
    List<TransactionModel> transactions,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green[100],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check, color: Colors.green[700], size: 20),
      ),
      title: Text(
        approval.voucherNo,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            approval.description,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '${approval.currency} ${approval.amount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
              Text(
                ' • ${approval.timeAgo}',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey[400],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(
              transaction: tx,
              allTransactions: transactions,
            ),
          ),
        );
      },
    );
  }
}
