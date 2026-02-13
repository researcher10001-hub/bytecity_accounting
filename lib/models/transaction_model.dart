import 'package:bytecity_accounting/models/account_model.dart';

enum VoucherType { payment, receipt, journal, contra }

enum TransactionStatus {
  pending,
  approved,
  rejected,
  correction,
  clarification,
  underReview,
  deleted,
}

class ApprovalMessage {
  String senderEmail;
  String senderName;
  String senderRole; // 'Admin', 'Management', 'BOA', 'Owner'
  String message;
  DateTime timestamp;
  TransactionStatus resultingStatus;
  String actionType; // 'approve', 'reject', 'clarify', 'comment', 'flag_review'

  ApprovalMessage({
    required this.senderEmail,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.timestamp,
    required this.resultingStatus,
    required this.actionType,
  });

  Map<String, dynamic> toJson() {
    return {
      'sender_email': senderEmail,
      'sender_name': senderName,
      'sender_role': senderRole,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'resulting_status': resultingStatus.toString().split('.').last,
      'action_type': actionType,
    };
  }

  factory ApprovalMessage.fromJson(Map<String, dynamic> json) {
    return ApprovalMessage(
      senderEmail: json['sender_email'] ?? '',
      senderName: json['sender_name'] ?? '',
      senderRole: json['sender_role'] ?? 'User',
      message: json['message'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      resultingStatus: TransactionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['resulting_status'],
        orElse: () => TransactionStatus.pending,
      ),
      actionType: json['action_type'] ?? 'comment',
    );
  }
}

class TransactionDetail {
  Account? account;
  double debit;
  double credit;
  String narration;
  String currency; // Per-line currency: 'BDT', 'AED', 'USD', 'RM'
  double rate; // Exchange rate to BDT (1.0 for BDT)

  // BDT equivalents (for balance checking and ledger)
  double get debitBDT => debit * rate;
  double get creditBDT => credit * rate;

  TransactionDetail({
    this.account,
    this.debit = 0.0,
    this.credit = 0.0,
    this.narration = '',
    this.currency = 'BDT',
    this.rate = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'account_name': account?.name,
      'debit': debit,
      'credit': credit,
      'narration': narration,
      'currency': currency,
      'rate': rate,
      'debit_bdt': debitBDT,
      'credit_bdt': creditBDT,
    };
  }

  // Helper validation
  bool get isValid => account != null && (debit > 0 || credit > 0);
}

class TransactionModel {
  String? id;
  DateTime date;
  VoucherType type;
  String voucherNo;
  String mainNarration;
  List<TransactionDetail> details;
  String createdBy; // User email
  String createdByName; // User name
  String currency;
  double exchangeRate;

  // New Fields for Messaging & Approval
  TransactionStatus status;
  List<ApprovalMessage> approvalLog;

  // New fields for tab assignment and flagging (Phase 2)
  String? lastActionBy;
  bool isFlagged;
  String? flaggedBy;
  DateTime? flaggedAt;
  String? flagReason;

  // New fields for recent activity tracking (Phase 4)
  DateTime? lastActivityAt;
  String? lastActivityType; // 'approve', 'reject', 'respond', 'comment', 'flag'
  String? lastActivityBy;

  TransactionModel({
    this.id,
    required this.date,
    required this.type,
    required this.voucherNo,
    this.mainNarration = '',
    required this.details,
    required this.createdBy,
    this.createdByName = '', // Default to empty, will be populated from API
    this.currency = 'BDT',
    this.exchangeRate = 1.0,
    this.status = TransactionStatus.pending,
    this.approvalLog = const [],
    this.lastActionBy,
    this.isFlagged = false,
    this.flaggedBy,
    this.flaggedAt,
    this.flagReason,
    this.lastActivityAt,
    this.lastActivityType,
    this.lastActivityBy,
  });

  double get totalDebit => details.fold(0, (sum, item) => sum + item.debit);
  double get totalCredit => details.fold(0, (sum, item) => sum + item.credit);
  // BDT equivalents for balance checking
  double get totalDebitBDT =>
      details.fold(0, (sum, item) => sum + item.debitBDT);
  double get totalCreditBDT =>
      details.fold(0, (sum, item) => sum + item.creditBDT);
  bool get isBalanced =>
      (totalDebitBDT - totalCreditBDT).abs() < 0.01; // Floating point tolerance

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'type': type.toString().split('.').last,
      'voucher_no': voucherNo,
      'main_narration': mainNarration,
      'details': details.map((e) => e.toJson()).toList(),
      'created_by': createdBy,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'status': status.toString().split('.').last,
      'approval_log': approvalLog.map((e) => e.toJson()).toList(),
    };
  }
}
