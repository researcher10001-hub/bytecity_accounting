class ActivityItem {
  final String id;
  final String type; // 'approve', 'reject', 'respond', 'comment', 'flag'
  final String voucherNo;
  final String description;
  final double amount;
  final String currency;
  final DateTime timestamp;
  final String transactionId;

  ActivityItem({
    required this.id,
    required this.type,
    required this.voucherNo,
    required this.description,
    required this.amount,
    required this.currency,
    required this.timestamp,
    required this.transactionId,
  });

  String get icon {
    switch (type) {
      case 'approve':
        return '✅';
      case 'reject':
        return '❌';
      case 'respond':
        return '🔄';
      case 'flag':
        return '🚩';
      default:
        return '💬';
    }
  }

  String get label {
    switch (type) {
      case 'approve':
        return 'Approved';
      case 'reject':
        return 'Rejected';
      case 'respond':
        return 'Responded';
      case 'flag':
        return 'Flagged';
      default:
        return 'Commented';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'comment',
      voucherNo: json['voucher_no'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'BDT',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      transactionId: json['transaction_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'voucher_no': voucherNo,
      'description': description,
      'amount': amount,
      'currency': currency,
      'timestamp': timestamp.toIso8601String(),
      'transaction_id': transactionId,
    };
  }
}
