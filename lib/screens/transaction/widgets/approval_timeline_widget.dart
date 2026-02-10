import 'package:flutter/material.dart';
import '../../../models/transaction_model.dart';
import 'package:intl/intl.dart';

class ApprovalTimelineWidget extends StatelessWidget {
  final List<ApprovalMessage> logs;

  const ApprovalTimelineWidget({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            "No approval history.",
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    // Reverse the list so newest messages appear first
    final reversedLogs = logs.reversed.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedLogs.length,
      itemBuilder: (context, index) {
        final msg = reversedLogs[index];
        final isApprove = msg.actionType == 'approve';
        final isReject = msg.actionType == 'reject';
        final isClarify = msg.actionType == 'clarify';

        Color statusColor = Colors.grey;
        IconData icon = Icons.comment;

        if (isApprove) {
          statusColor = Colors.green;
          icon = Icons.check_circle;
        } else if (isReject) {
          statusColor = Colors.red;
          icon = Icons.cancel;
        } else if (isClarify) {
          statusColor = Colors.orange;
          icon = Icons.help;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline Connector
              Column(
                children: [
                  Container(
                    width: 2,
                    height: 10,
                    color: index == 0 ? Colors.transparent : Colors.grey[300],
                  ),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    child: Icon(icon, size: 14, color: statusColor),
                  ),
                  Container(
                    width: 2,
                    height: 30, // Dynamic?
                    color: index == reversedLogs.length - 1
                        ? Colors.transparent
                        : Colors.grey[300],
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          msg.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, h:mm a').format(msg.timestamp),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(msg.message, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
