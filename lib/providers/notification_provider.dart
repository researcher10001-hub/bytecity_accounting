import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';
import 'transaction_provider.dart';
import 'account_provider.dart';

class NotificationProvider with ChangeNotifier {
  List<MessageThread> _messageThreads = [];
  bool _isLoading = false;
  Set<String> _readVouchers = {};

  List<MessageThread> get messageThreads => _messageThreads;
  bool get isLoading => _isLoading;

  // Status-based getters
  List<MessageThread> get pendingMessages =>
      _messageThreads.where((t) => t.status == MessageStatus.pending).toList();

  List<MessageThread> get clarifyMessages =>
      _messageThreads.where((t) => t.status == MessageStatus.clarify).toList();

  List<MessageThread> get approvedMessages =>
      _messageThreads.where((t) => t.status == MessageStatus.approved).toList();

  List<MessageThread> get underReviewMessages => _messageThreads
      .where((t) => t.status == MessageStatus.underReview)
      .toList();

  // New getters for Received/Sent for Review tabs (Phase 3)
  // Note: These require currentUserEmail to be passed in, so we'll create methods instead
  List<MessageThread> receivedForReview(String currentUserEmail) {
    return _messageThreads.where((t) {
      // Exclude approved/rejected
      if (t.status == MessageStatus.approved ||
          t.status == MessageStatus.rejected) {
        return false;
      }

      // Received = last action was NOT by me (waiting on me to respond)
      return t.lastActionBy.toLowerCase() != currentUserEmail.toLowerCase();
    }).toList();
  }

  List<MessageThread> sentForReview(String currentUserEmail) {
    return _messageThreads.where((t) {
      // Exclude approved/rejected
      if (t.status == MessageStatus.approved ||
          t.status == MessageStatus.rejected) {
        return false;
      }

      // Sent = last action WAS by me (waiting on them to respond)
      return t.lastActionBy.toLowerCase() == currentUserEmail.toLowerCase();
    }).toList();
  }

  List<MessageThread> get flaggedMessages =>
      _messageThreads.where((t) => t.isFlagged).toList();

  // Count getters
  int get pendingCount => pendingMessages.length;
  int get clarifyCount => clarifyMessages.length;
  int get approvedCount => approvedMessages.length;
  int get underReviewCount => underReviewMessages.length;
  int get flaggedCount => flaggedMessages.length;

  int receivedForReviewCount(String currentUserEmail) =>
      receivedForReview(currentUserEmail).length;

  int sentForReviewCount(String currentUserEmail) =>
      sentForReview(currentUserEmail).length;

  int get unreadCount => _messageThreads.where((t) => t.isUnread).length;

  int get selfEntryCount => approvedMessages.where((t) => t.isSelfEntry).length;

  NotificationProvider() {
    _loadReadStatus();
  }

  Future<void> _loadReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readVouchers = prefs.getStringList('read_vouchers') ?? [];
      _readVouchers = Set.from(readVouchers);
    } catch (e) {
      debugPrint('Error loading read status: $e');
    }
  }

  Future<void> markThreadAsRead(String voucherNo) async {
    _readVouchers.add(voucherNo);

    // Update the thread
    final index = _messageThreads.indexWhere((t) => t.voucherNo == voucherNo);
    if (index != -1) {
      final thread = _messageThreads[index];
      _messageThreads[index] = MessageThread(
        voucherNo: thread.voucherNo,
        transaction: thread.transaction,
        messages: thread.messages,
        status: thread.status,
        isUnread: false,
        isSelfEntry: thread.isSelfEntry,
        approvedBy: thread.approvedBy,
        approvedAt: thread.approvedAt,
        lastActionBy: thread.lastActionBy,
        isFlagged: thread.isFlagged,
        flaggedBy: thread.flaggedBy,
        flaggedAt: thread.flaggedAt,
        flagReason: thread.flagReason,
      );
    }

    // Persist to storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_vouchers', _readVouchers.toList());
    } catch (e) {
      debugPrint('Error saving read status: $e');
    }

    notifyListeners();
  }

  /// Refresh notifications from transaction provider
  Future<void> refreshNotifications(
    User user,
    TransactionProvider transactionProvider,
    dynamic userProvider, {
    required AccountProvider accountProvider,
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // 1. Ensure we have accounts for ownership filtering
      if (accountProvider.accounts.isEmpty || forceRefresh) {
        await accountProvider.fetchAccounts(user);
      }

      // 2. Ensure we have the latest transactions
      if (silent && !forceRefresh) {
        await transactionProvider.syncHistory(
          user,
          accountProvider: accountProvider,
        );
      } else {
        await transactionProvider.fetchHistory(
          user,
          accountProvider: accountProvider,
          forceRefresh: forceRefresh,
        );
      }
      final allTransactions = transactionProvider.transactions;

      _messageThreads = [];

      for (var tx in allTransactions) {
        // Skip deleted and rejected transactions for Message Card / Notifications
        if (tx.status == TransactionStatus.deleted ||
            tx.status == TransactionStatus.rejected) {
          continue;
        }

        bool isMyCreation = tx.createdBy.trim().toLowerCase() ==
            user.email.trim().toLowerCase();

        // Check if there are messages
        if (tx.approvalLog.isEmpty) continue;

        // Determine if this is relevant to the user for the Message Card / Notifications screen
        bool isRelevant = false;

        // 1. My Creation is always relevant
        if (isMyCreation) {
          isRelevant = true;
        } else {
          // 2. Ownership-based relevance
          // Any user who is an owner of ANY account involved in this transaction should see the notification
          final myEmail = user.email.toLowerCase().trim();
          final myOwnedAccountNames = accountProvider.accounts
              .where(
                (a) => a.owners.any((o) => o.toLowerCase().trim() == myEmail),
              )
              .map((a) => a.name.toLowerCase().trim())
              .toSet();

          if (myOwnedAccountNames.isNotEmpty) {
            final txAccountNames = tx.details
                .map((d) => d.account?.name.toLowerCase().trim())
                .where((name) => name != null)
                .cast<String>()
                .toSet();

            bool isOwnerInvolved = txAccountNames.any(
              (accName) => myOwnedAccountNames.contains(accName),
            );

            if (isOwnerInvolved) {
              isRelevant = true;
            }
          }
        }

        if (!isRelevant) {
          // Silent debug for developer (optional)
          // print('[NotificationProvider] Filtering out ${tx.voucherNo} for ${user.email} - Not My Creation and Not an Owner of involved accounts');
          continue;
        }

        // For approved transactions, only show to admin in approved tab
        if (tx.status == TransactionStatus.approved) {
          if (!user.isAdmin) continue; // Only admin sees approved
        }

        // Create message thread
        final thread = MessageThread.fromTransaction(
          tx,
          user.email,
          _readVouchers,
        );

        // Check if self-entry (will be enhanced with backend data)
        // For now, simple check: creator owns all accounts
        bool isSelfEntry = false;
        if (tx.status == TransactionStatus.approved && isMyCreation) {
          // This is a simplified check - backend will provide accurate data
          isSelfEntry = true;
        }

        _messageThreads.add(
          MessageThread(
            voucherNo: thread.voucherNo,
            transaction: thread.transaction,
            messages: thread.messages,
            status: thread.status,
            isUnread: thread.isUnread,
            isSelfEntry: isSelfEntry,
            approvedBy: thread.approvedBy,
            approvedAt: thread.approvedAt,
            lastActionBy: thread.lastActionBy,
            isFlagged: thread.isFlagged,
            flaggedBy: thread.flaggedBy,
            flaggedAt: thread.flaggedAt,
            flagReason: thread.flagReason,
          ),
        );
      }

      // Sort by latest message time
      _messageThreads.sort(
        (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
      );
    } catch (e) {
      debugPrint("Error processing notifications: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Flag a transaction for review (Admin only)
  Future<bool> flagForReview(
    String voucherNo,
    String adminEmail,
    String reason,
    String newStatus,
  ) async {
    try {
      final apiService = ApiService();
      final response =
          await apiService.postRequest(ApiConstants.actionFlagForReview, {
        'voucher_no': voucherNo,
        'admin_email': adminEmail,
        'reason': reason,
        'new_status': newStatus,
      });

      if (response != null) {
        // Move thread from approved to clarify/underReview
        final index = _messageThreads.indexWhere(
          (t) => t.voucherNo == voucherNo,
        );
        if (index != -1) {
          final thread = _messageThreads[index];
          final newStatusEnum = newStatus == 'Clarify'
              ? MessageStatus.clarify
              : MessageStatus.underReview;

          _messageThreads[index] = MessageThread(
            voucherNo: thread.voucherNo,
            transaction: thread.transaction,
            messages: thread.messages,
            status: newStatusEnum,
            isUnread: true, // Mark as unread for recipients
            isSelfEntry: thread.isSelfEntry,
            approvedBy: thread.approvedBy,
            approvedAt: thread.approvedAt,
            lastActionBy: thread.lastActionBy,
            isFlagged: thread.isFlagged,
            flaggedBy: thread.flaggedBy,
            flaggedAt: thread.flaggedAt,
            flagReason: thread.flagReason,
          );
        }

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error flagging for review: $e');
      return false;
    }
  }

  /// Get approved messages from last 7 days (Admin only)
  List<MessageThread> getRecentApprovedMessages() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return approvedMessages.where((thread) {
      if (thread.approvedAt == null) return false;
      return thread.approvedAt!.isAfter(sevenDaysAgo);
    }).toList();
  }
}
