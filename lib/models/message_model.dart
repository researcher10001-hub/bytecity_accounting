import 'transaction_model.dart';

/// Represents the status of a message thread
enum MessageStatus { pending, clarify, approved, underReview }

/// Represents a single message in a thread
class MessageItem {
  final String id;
  final String senderEmail;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime timestamp;
  final String actionType;
  final List<String> readBy;

  MessageItem({
    required this.id,
    required this.senderEmail,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.timestamp,
    required this.actionType,
    this.readBy = const [],
  });

  factory MessageItem.fromApprovalMessage(
    ApprovalMessage msg,
    String voucherNo,
  ) {
    return MessageItem(
      id: '${voucherNo}_${msg.timestamp.millisecondsSinceEpoch}',
      senderEmail: msg.senderEmail,
      senderName: msg.senderName,
      senderRole: msg.senderRole,
      message: msg.message,
      timestamp: msg.timestamp,
      actionType: msg.actionType,
      readBy: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_email': senderEmail,
      'sender_name': senderName,
      'sender_role': senderRole,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'action_type': actionType,
      'read_by': readBy,
    };
  }

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] ?? '',
      senderEmail: json['sender_email'] ?? '',
      senderName: json['sender_name'] ?? '',
      senderRole: json['sender_role'] ?? 'User',
      message: json['message'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      actionType: json['action_type'] ?? 'comment',
      readBy: List<String>.from(json['read_by'] ?? []),
    );
  }
}

/// Represents a message thread for a transaction
class MessageThread {
  final String voucherNo;
  final TransactionModel transaction;
  final List<MessageItem> messages;
  final MessageStatus status;
  final bool isUnread;
  final bool isSelfEntry;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime lastMessageTime;

  // New fields for tab assignment and flagging
  final String lastActionBy;
  final bool isFlagged;
  final String? flaggedBy;
  final DateTime? flaggedAt;
  final String? flagReason;

  MessageThread({
    required this.voucherNo,
    required this.transaction,
    required this.messages,
    required this.status,
    this.isUnread = false,
    this.isSelfEntry = false,
    this.approvedBy,
    this.approvedAt,
    DateTime? lastMessageTime,
    required this.lastActionBy,
    this.isFlagged = false,
    this.flaggedBy,
    this.flaggedAt,
    this.flagReason,
  }) : lastMessageTime =
           lastMessageTime ??
           (messages.isNotEmpty ? messages.last.timestamp : DateTime.now());

  /// Get the latest message in the thread
  MessageItem? get latestMessage => messages.isNotEmpty ? messages.last : null;

  /// Get the count of unread messages
  int get unreadCount =>
      messages.where((m) => !m.readBy.contains('current_user')).length;

  /// Check if this is a self-entry (creator is owner)
  static bool checkIsSelfEntry(
    TransactionModel transaction,
    String creatorEmail,
  ) {
    // This will be implemented based on account ownership logic
    // For now, return false
    return false;
  }

  /// Determine message status from transaction status
  static MessageStatus getStatusFromTransaction(TransactionStatus txStatus) {
    switch (txStatus) {
      case TransactionStatus.pending:
        return MessageStatus.pending;
      case TransactionStatus.clarification:
        return MessageStatus.clarify;
      case TransactionStatus.approved:
        return MessageStatus.approved;
      case TransactionStatus.underReview:
        return MessageStatus.underReview;
      default:
        return MessageStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'voucher_no': voucherNo,
      'messages': messages.map((m) => m.toJson()).toList(),
      'status': status.toString().split('.').last,
      'is_unread': isUnread,
      'is_self_entry': isSelfEntry,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'last_message_time': lastMessageTime.toIso8601String(),
      'last_action_by': lastActionBy,
      'is_flagged': isFlagged,
      'flagged_by': flaggedBy,
      'flagged_at': flaggedAt?.toIso8601String(),
      'flag_reason': flagReason,
    };
  }

  /// Create a MessageThread from a TransactionModel
  factory MessageThread.fromTransaction(
    TransactionModel transaction,
    String currentUserEmail,
    Set<String> readVouchers,
  ) {
    final messages = transaction.approvalLog
        .map(
          (msg) => MessageItem.fromApprovalMessage(msg, transaction.voucherNo),
        )
        .toList();

    final status = getStatusFromTransaction(transaction.status);
    final isUnread = !readVouchers.contains(transaction.voucherNo);

    // 2. Identify the last HUMAN actor
    String lastActorEmail =
        transaction.lastActivityBy ??
        transaction.lastActionBy ??
        transaction.createdBy;

    // Search for the last non-system message sender
    for (var msg in transaction.approvalLog.reversed) {
      if (msg.senderEmail.toLowerCase().trim() != 'system' &&
          msg.senderEmail.isNotEmpty) {
        lastActorEmail = msg.senderEmail;
        break;
      }
    }

    // Find approval message if exists
    final approvalMsg = transaction.approvalLog.firstWhere(
      (msg) => msg.actionType == 'approve',
      orElse: () => ApprovalMessage(
        senderEmail: '',
        senderName: '',
        senderRole: '',
        message: '',
        timestamp: DateTime.now(),
        resultingStatus: TransactionStatus.pending,
        actionType: '',
      ),
    );

    return MessageThread(
      voucherNo: transaction.voucherNo,
      transaction: transaction,
      messages: messages,
      status: status,
      isUnread: isUnread,
      isSelfEntry: false, // Will be determined by backend
      approvedBy: approvalMsg.senderEmail.isNotEmpty
          ? (approvalMsg.senderName.isNotEmpty
                ? approvalMsg.senderName
                : approvalMsg.senderEmail)
          : null,
      approvedAt: approvalMsg.senderEmail.isNotEmpty
          ? approvalMsg.timestamp
          : null,
      lastActionBy: lastActorEmail,
      isFlagged: transaction.isFlagged,
      flaggedBy: transaction.flaggedBy,
      flaggedAt: transaction.flaggedAt,
      flagReason: transaction.flagReason,
    );
  }
}
