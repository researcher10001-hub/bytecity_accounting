import 'package:flutter/material.dart';

class ApprovalActionWidget extends StatefulWidget {
  final bool isLoading;
  final Function(String message, String action) onAction;
  final bool isOwner; // New parameter to control approval buttons
  final bool isAdmin; // New parameter for Phase 3 Flagging
  final bool isFlagged; // Current flagged status

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DECISION / COMMENT",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Write your reason or comment...",
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Only show Approve/Reject for Owners
                  if (widget.isOwner) ...[
                    _ActionChip(
                      label: "Approve",
                      color: Colors.green,
                      icon: Icons.check_circle_outline,
                      onTap: () => _submit('approve'),
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      label: "Reject",
                      color: Colors.red,
                      icon: Icons.cancel_outlined,
                      onTap: () => _submit('reject'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Everyone can Clarify and Comment
                  _ActionChip(
                    label: "Clarify",
                    color: Colors.orange,
                    icon: Icons.help_outline,
                    onTap: () => _submit('clarify'),
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    label: "Comment",
                    color: Colors.grey,
                    icon: Icons.comment_outlined,
                    onTap: () => _submit('comment'),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 8),
                    _ActionChip(
                      label: widget.isFlagged
                          ? "Resolve Flag"
                          : "Flag for Audit",
                      color: Colors.red.shade700,
                      icon: widget.isFlagged ? Icons.outlined_flag : Icons.flag,
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

    // Approval is allowed without comment. Others require it for audit clarity.
    // Flagging also REQUIRE a comment.
    if (trimmedText.isEmpty && action != 'approve' && action != 'unflag') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Explanation is required for audit.")),
      );
      return;
    }

    final finalMessage = trimmedText.isEmpty ? "Approved" : trimmedText;

    // Confirmation Dialog for Decision
    if (action != 'comment' && action != 'clarify') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Confirm ${action.toUpperCase()}"),
          content: const Text(
            "This action is irreversible and will be logged in the audit trail. Proceed?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'approve'
                    ? Colors.green
                    : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onAction(finalMessage, action);
                _controller.clear();
              },
              child: const Text("Confirm"),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
