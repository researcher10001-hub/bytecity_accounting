import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';

import 'widgets/approval_timeline_widget.dart';
import 'widgets/approval_action_widget.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;
  final List<TransactionModel>? allTransactions;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.allTransactions,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late TransactionModel _currentTransaction;
  late PageController _pageController;
  late int _currentIndex;
  late List<TransactionModel> _transactions;

  @override
  void initState() {
    super.initState();
    _currentTransaction = widget.transaction;
    _transactions = widget.allTransactions ?? [_currentTransaction];
    _currentIndex = _transactions.indexWhere(
      (tx) => tx.voucherNo == _currentTransaction.voucherNo,
    );
    if (_currentIndex == -1) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final accountProvider = context
        .watch<AccountProvider>(); // For permission check details

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine if User is an OWNER of any account involved in this transaction
    // Or if user is Admin (Can see, but maybe restricted from voting? Protocol says Admin can't approve)
    // Actually Protocol says: "Admin cannot give Financial Approval".
    // So Action Widget is only showing if user is OWNER or CREATOR.

    bool isOwner = false;
    bool isCreator =
        _currentTransaction.createdBy.toLowerCase() == user.email.toLowerCase();

    // Check all accounts in details
    for (var detail in _currentTransaction.details) {
      // We need the Account object to check 'owners' list.
      // The transaction detail has 'account' object but it might be shallow (from history parsing)
      // Let's look it up in AccountProvider for full data (owners list)
      try {
        final realAccount = accountProvider.accounts.firstWhere(
          (a) => a.name == detail.account?.name,
        );
        if (realAccount.owners.any(
          (o) => o.toLowerCase() == user.email.toLowerCase(),
        )) {
          isOwner = true;
          break;
        }
      } catch (e) {
        // Account might be deleted or not found
      }
    }

    // Allow messaging if user is either Owner OR Creator
    bool canSendMessage = isOwner || isCreator;

    return Scaffold(
      appBar: AppBar(
        title: Text("Transaction ${_currentTransaction.voucherNo}"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _transactions.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _currentTransaction = _transactions[index];
              });
            },
            itemBuilder: (context, index) {
              return _buildTransactionContent(
                user,
                accountProvider,
                isOwner,
                canSendMessage,
              );
            },
          ),

          // Left Click Area (Previous)
          if (_currentIndex > 0)
            Positioned(
              left: 0,
              top: 100,
              bottom: 100,
              width: 40,
              child: GestureDetector(
                onTap: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    Icons.chevron_left,
                    color: Colors.black.withValues(alpha: 0.1),
                    size: 40,
                  ),
                ),
              ),
            ),

          // Right Click Area (Next)
          if (_currentIndex < _transactions.length - 1)
            Positioned(
              right: 0,
              top: 100,
              bottom: 100,
              width: 40,
              child: GestureDetector(
                onTap: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.black.withValues(alpha: 0.1),
                    size: 40,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionContent(
    User user,
    AccountProvider accountProvider,
    bool isOwner,
    bool canSendMessage,
  ) {
    // Determine isOwner and isCreator for the local _currentTransaction
    bool localIsOwner = false;
    bool localIsCreator =
        _currentTransaction.createdBy.toLowerCase() == user.email.toLowerCase();

    for (var detail in _currentTransaction.details) {
      try {
        final realAccount = accountProvider.accounts.firstWhere(
          (a) => a.name == detail.account?.name,
        );
        if (realAccount.owners.any(
          (o) => o.toLowerCase() == user.email.toLowerCase(),
        )) {
          localIsOwner = true;
          break;
        }
      } catch (e) {}
    }

    bool localCanSendMessage = localIsOwner || localIsCreator;

    return Column(
      children: [
        // Flag Banner
        if (_currentTransaction.isFlagged)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.flag, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "FLAGGED FOR AUDIT",
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentTransaction.flagReason ?? "No reason given",
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        "By ${_currentTransaction.flaggedBy} at ${DateFormat('MMM d, h:mm a').format(_currentTransaction.flaggedAt ?? DateTime.now())}",
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Header / Summary
        Container(
          color: Colors.blue.shade50,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Date",
                        style: TextStyle(color: Colors.blueGrey, fontSize: 11),
                      ),
                      Text(
                        DateFormat(
                          'dd MMM yyyy',
                        ).format(_currentTransaction.date),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Amount",
                        style: TextStyle(color: Colors.blueGrey, fontSize: 11),
                      ),
                      Text(
                        "${_currentTransaction.currency} ${NumberFormat('#,##0.00').format(_currentTransaction.totalDebit)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Breakdown
              ..._currentTransaction.details.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${d.account?.name}",
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        d.debit > 0 ? "Dr ${d.debit}" : "Cr ${d.credit}",
                        style: TextStyle(
                          fontSize: 12,
                          color: d.debit > 0 ? Colors.black : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  children: [
                    const TextSpan(
                      text: "Description: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: _currentTransaction.mainNarration.isNotEmpty
                          ? _currentTransaction.mainNarration
                          : "No Narration",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              // Status Badge & Entry By
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_currentTransaction.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _currentTransaction.status
                          .toString()
                          .split('.')
                          .last
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final userProvider = context.read<UserProvider>();
                      String creatorName = _currentTransaction.createdBy;
                      try {
                        creatorName = userProvider.users
                            .firstWhere(
                              (u) =>
                                  u.email.trim().toLowerCase() ==
                                  _currentTransaction.createdBy
                                      .trim()
                                      .toLowerCase(),
                            )
                            .name;
                      } catch (_) {}

                      return Text(
                        "Entry by: $creatorName",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AUDIT TRAIL / MESSAGES",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                // Display approval log from local state (updates via setState)
                ApprovalTimelineWidget(logs: _currentTransaction.approvalLog),
              ],
            ),
          ),
        ),

        // Action Area (Allow if Owner OR Creator OR Admin)
        if (localCanSendMessage || user.isAdmin)
          Consumer<TransactionProvider>(
            builder: (ctx, provider, _) => ApprovalActionWidget(
              isLoading: provider.isLoading,
              isOwner: localIsOwner,
              isAdmin: user.isAdmin,
              isFlagged: _currentTransaction.isFlagged,
              onAction: (message, action) async {
                bool success = false;
                if (action == 'flag') {
                  success = await provider.flagTransaction(
                    voucherNo: _currentTransaction.voucherNo,
                    adminEmail: user.email,
                    adminName: user.name,
                    reason: message,
                  );
                } else if (action == 'unflag') {
                  success = await provider.unflagTransaction(
                    voucherNo: _currentTransaction.voucherNo,
                    adminEmail: user.email,
                  );
                } else {
                  success = await provider.addMessage(
                    voucherNo: _currentTransaction.voucherNo,
                    entryId: _currentTransaction.id ?? '',
                    userEmail: user.email,
                    senderName: user.name,
                    message: message,
                    action: action,
                  );
                }

                if (success) {
                  if (ctx.mounted) {
                    // Update local state with new message for real-time display
                    setState(() {
                      // Determine new status based on action
                      TransactionStatus newStatus = _currentTransaction.status;
                      switch (action) {
                        case 'approve':
                          newStatus = TransactionStatus.approved;
                          break;
                        case 'reject':
                          newStatus = TransactionStatus.rejected;
                          break;
                        case 'clarify':
                          newStatus = TransactionStatus.clarification;
                          break;
                        case 'comment':
                        case 'flag':
                        case 'unflag':
                          // Status remains the same
                          break;
                      }

                      // Updated local Flag state if action was flag/unflag
                      bool newIsFlagged = _currentTransaction.isFlagged;
                      String? newFlaggedBy = _currentTransaction.flaggedBy;
                      String? newFlagReason = _currentTransaction.flagReason;
                      DateTime? newFlaggedAt = _currentTransaction.flaggedAt;

                      if (action == 'flag') {
                        newIsFlagged = true;
                        newFlaggedBy = user.email;
                        newFlagReason = message;
                        newFlaggedAt = DateTime.now();
                      } else if (action == 'unflag') {
                        newIsFlagged = false;
                        newFlaggedBy = null;
                        newFlagReason = null;
                        newFlaggedAt = null;
                      }

                      // Create new approval message
                      final newMessage = ApprovalMessage(
                        senderEmail: user.email,
                        senderName: user.name,
                        senderRole: 'User',
                        message: message,
                        timestamp: DateTime.now(),
                        resultingStatus: newStatus,
                        actionType: action,
                      );

                      // Update transaction with new message
                      _currentTransaction = TransactionModel(
                        id: _currentTransaction.id,
                        date: _currentTransaction.date,
                        type: _currentTransaction.type,
                        voucherNo: _currentTransaction.voucherNo,
                        mainNarration: _currentTransaction.mainNarration,
                        details: _currentTransaction.details,
                        createdBy: _currentTransaction.createdBy,
                        currency: _currentTransaction.currency,
                        exchangeRate: _currentTransaction.exchangeRate,
                        status: newStatus,
                        approvalLog: [
                          ..._currentTransaction.approvalLog,
                          newMessage,
                        ],
                        lastActionBy: user.email,
                        isFlagged: newIsFlagged,
                        flaggedBy: newFlaggedBy,
                        flaggedAt: newFlaggedAt,
                        flagReason: newFlagReason,
                      );

                      // Also update the list in case we return to it
                      _transactions[_currentIndex] = _currentTransaction;
                    });

                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text("Message sent successfully!"),
                      ),
                    );
                    // Sync with backend in background
                    provider.fetchHistory(user, forceRefresh: true);
                    // Don't close screen - let user see real-time update
                  }
                }
              },
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.approved:
        return Colors.green;
      case TransactionStatus.rejected:
        return Colors.red;
      case TransactionStatus.clarification:
        return Colors.orange;
      case TransactionStatus.correction:
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }
}
