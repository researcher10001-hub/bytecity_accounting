import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../models/transaction_model.dart';
import 'package:intl/intl.dart';

class ApprovalTimelineWidget extends StatelessWidget {
  final List<ApprovalMessage> logs;

  const ApprovalTimelineWidget({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.messageSquareDashed,
              size: 24,
              color: Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 12),
            Text(
              "No messages or activity logged yet.",
              style: GoogleFonts.inter(
                color: const Color(0xFFA0AEC0),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Newest messages at bottom for a chat-like feel
    final sortedLogs = logs.toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: sortedLogs.map((msg) {
          final isApprove = msg.actionType == 'approve';
          final isReject = msg.actionType == 'reject';
          final isClarify = msg.actionType == 'clarify';
          final isEdit = msg.actionType == 'edit';
          final isForwardLink = msg.actionType == 'forward_link';
          final isSystem =
              msg.actionType.startsWith('auto_') ||
              msg.message.contains('Created');

          Color statusColor = const Color(0xFF718096);
          IconData icon = LucideIcons.messageSquare;

          if (isApprove) {
            statusColor = const Color(0xFF38A169); // Green
            icon = LucideIcons.checkCircle;
          } else if (isReject) {
            statusColor = const Color(0xFFE53E3E); // Red
            icon = LucideIcons.xCircle;
          } else if (isClarify) {
            statusColor = const Color(0xFFD69E2E); // Amber
            icon = LucideIcons.helpCircle;
          } else if (isEdit) {
            statusColor = const Color(0xFF3182CE); // Blue
            icon = LucideIcons.edit2;
          } else if (isForwardLink) {
            statusColor = const Color(0xFFE53E3E); // Red (Alert)
            icon = LucideIcons.externalLink;
          } else if (isSystem) {
            statusColor = const Color(0xFF3182CE);
            icon = LucideIcons.info;
          }

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender Avatar / Action Icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: statusColor),
                ),
                const SizedBox(width: 8),

                // Message Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            msg.senderName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "• ${DateFormat('h:mm a').format(msg.timestamp)}",
                            style: GoogleFonts.inter(
                              color: const Color(0xFFA0AEC0),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSystem ? Colors.transparent : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          border: isSystem
                              ? null
                              : Border.all(color: const Color(0xFFEDF2F7)),
                        ),
                        child: Text(
                          msg.message,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.3,
                            color: isSystem
                                ? const Color(0xFF718096)
                                : const Color(0xFF4A5568),
                            fontWeight: isSystem
                                ? FontWeight.w500
                                : FontWeight.w400,
                            fontStyle: isSystem
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
