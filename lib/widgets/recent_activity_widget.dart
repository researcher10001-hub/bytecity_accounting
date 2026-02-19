import 'package:flutter/material.dart';
import '../models/activity_item.dart';
import '../models/transaction_model.dart';
import '../screens/transaction/transaction_detail_screen.dart';
import '../providers/transaction_provider.dart';
import '../providers/dashboard_provider.dart';
import 'package:provider/provider.dart';

class RecentActivityWidget extends StatefulWidget {
  final String userEmail;

  const RecentActivityWidget({super.key, required this.userEmail});

  @override
  State<RecentActivityWidget> createState() => _RecentActivityWidgetState();
}

class _RecentActivityWidgetState extends State<RecentActivityWidget> {
  bool _isExpanded = false;
  bool _todayOnly = false; // Toggle state: false = 24h, true = today

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final activities = provider.getRecentActivity(
          widget.userEmail,
          days: _todayOnly ? 1 : 0,
        );
        final stats = provider.getActivityStats(
          widget.userEmail,
          days: _todayOnly ? 1 : 0,
        );

        if (activities.isEmpty) {
          return _buildEmptyState();
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _buildHeader(activities.length, stats),
              if (_isExpanded) _buildActivityList(activities),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(int totalCount, Map<String, int> stats) {
    final approvedCount = stats['approved'] ?? 0;
    final respondedCount = stats['responded'] ?? 0;
    final commentedCount = stats['commented'] ?? 0;

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text('📜', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity ($totalCount)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Toggle button
                _buildToggleButton(),
                const SizedBox(width: 8),
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            if (!_isExpanded && totalCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 28), // Align with text above
                  if (approvedCount > 0) ...[
                    Text(
                      '✅ $approvedCount  ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                  if (respondedCount > 0) ...[
                    Text(
                      '🔄 $respondedCount  ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                  if (commentedCount > 0) ...[
                    Text(
                      '💬 $commentedCount',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList(List<Map<String, dynamic>> activities) {
    // Extract models for all activities in the list
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final allRelatedTransactions = activities.map((a) {
      final voucherNo = a['voucherNo'];
      return provider.transactions.firstWhere(
        (t) => t.voucherNo == voucherNo,
        orElse: () => provider.transactions.first,
      );
    }).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final activityData = activities[index];
        final activity = ActivityItem.fromJson(activityData);
        final tx = allRelatedTransactions[index];
        return _buildActivityCard(activity, tx, allRelatedTransactions);
      },
    );
  }

  Widget _buildActivityCard(
    ActivityItem activity,
    TransactionModel tx,
    List<TransactionModel> transactions,
  ) {
    return ListTile(
      leading: Text(activity.icon, style: const TextStyle(fontSize: 24)),
      title: Text(
        activity.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${activity.voucherNo} • ${activity.timeAgo}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 2),
          Text(
            '${activity.description} - ${activity.currency} ${activity.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
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
          );
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('📜', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text(
              'Recent Activity (0)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            _buildToggleButton(),
            const SizedBox(width: 8),
            Text(
              _todayOnly ? 'No activity today' : 'No activity in 24h',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
