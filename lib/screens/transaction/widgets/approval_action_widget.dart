import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ApprovalActionWidget extends StatefulWidget {
  final bool isLoading;
  final Function(String message, String action) onAction;
  final bool isOwner;
  final bool isAdmin;
  final bool isFlagged;

  const ApprovalActionWidget({
    super.key,
    required this.onAction,
    this.isLoading = false,
    this.isOwner = true,
    this.isAdmin = false,
    this.isFlagged = false,
  });

  @override
  State<ApprovalActionWidget> createState() => _ApprovalActionWidgetState();
}

class _ApprovalActionWidgetState extends State<ApprovalActionWidget> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.edit3,
                  size: 11,
                  color: Color(0xFF718096),
                ),
                const SizedBox(width: 4),
                Text(
                  "DECISION / COMMENT",
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: const Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDF2F7)),
            ),
            child: TextField(
              controller: _controller,
              maxLines: 2,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2D3748),
              ),
              decoration: InputDecoration(
                hintText: "Write your reason or comment...",
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFFA0AEC0),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (widget.isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4299E1),
                strokeWidth: 2,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (widget.isOwner) ...[
                    _ActionChip(
                      label: "Approve",
                      color: const Color(0xFF38A169),
                      icon: LucideIcons.checkCircle,
                      onTap: () => _submit('approve'),
                    ),
                    const SizedBox(width: 6),
                    _ActionChip(
                      label: "Reject",
                      color: const Color(0xFFE53E3E),
                      icon: LucideIcons.xCircle,
                      onTap: () => _submit('reject'),
                    ),
                    const SizedBox(width: 6),
                  ],
                  _ActionChip(
                    label: "Clarify",
                    color: const Color(0xFFD69E2E),
                    icon: LucideIcons.helpCircle,
                    onTap: () => _submit('clarify'),
                  ),
                  const SizedBox(width: 6),
                  _ActionChip(
                    label: "Comment",
                    color: const Color(0xFF718096),
                    icon: LucideIcons.messageSquare,
                    onTap: () => _submit('comment'),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 10),
                    _ActionChip(
                      label: widget.isFlagged
                          ? "Resolve Flag"
                          : "Flag for Audit",
                      color: const Color(0xFFC53030),
                      icon: LucideIcons.flag,
                      onTap: () =>
                          _submit(widget.isFlagged ? 'unflag' : 'flag'),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _submit(String action) {
    final trimmedText = _controller.text.trim();
    if (trimmedText.isEmpty && action != 'approve' && action != 'unflag') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Explanation is required for audit."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final finalMessage = trimmedText.isEmpty ? "Approved" : trimmedText;

    if (action != 'comment' && action != 'clarify') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            "Confirm ${action.toUpperCase()}",
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: Text(
            "This action is irreversible and will be logged in the audit trail. Proceed?",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF4A5568),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(
                  color: const Color(0xFF718096),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'approve'
                    ? const Color(0xFF38A169)
                    : const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onAction(finalMessage, action);
                _controller.clear();
              },
              child: Text(
                "Confirm",
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    } else {
      widget.onAction(finalMessage, action);
      _controller.clear();
    }
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
