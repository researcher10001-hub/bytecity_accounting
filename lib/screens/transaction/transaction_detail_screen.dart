import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
import 'transaction_entry_screen.dart'; // Import TransactionEntryScreen
import '../../core/utils/currency_formatter.dart';
import 'package:google_fonts/google_fonts.dart';

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
        title: Text(
          "Transaction ${_currentTransaction.voucherNo}",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF2D3748),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isCreator || user.isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(
                LucideIcons.moreVertical,
                color: Color(0xFF2D3748),
              ),
              onSelected: (value) async {
                if (value == 'edit') {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionEntryScreen(
                        transaction: _currentTransaction,
                      ),
                    ),
                  );
                  // Refresh data after returning from edit
                  if (context.mounted) {
                    // Re-fetch transactions to get updated data
                    // We might need to refresh the specific transaction in the list
                    // For now, let's trigger a rebuild or fetch if the provider updates.
                    // Actually, TransactionEntryScreen refreshes the provider on save.
                    // So we just need to ensure our local _currentTransaction is updated.
                    // We can check the provider for the updated transaction or just re-fetch.
                    // Since _transactions is local, we should probably re-fetch or listen to provider.
                    // But simpler: just setState if we can get the updated obj from provider.

                    final updatedTx = context
                        .read<TransactionProvider>()
                        .transactions
                        .firstWhere(
                          (t) => t.voucherNo == _currentTransaction.voucherNo,
                          orElse: () => _currentTransaction,
                        );

                    setState(() {
                      _currentTransaction = updatedTx;
                      _transactions[_currentIndex] = updatedTx;
                    });
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.edit,
                        size: 16,
                        color: Color(0xFF4A5568),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Entry',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2D3748),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: const Color(0xFFF7FAFC),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              border: Border(
                bottom: BorderSide(color: Colors.red.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.flag,
                    color: Color(0xFFE53E3E),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "FLAGGED FOR AUDIT",
                        style: GoogleFonts.inter(
                          color: const Color(0xFFC53030),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentTransaction.flagReason ?? "No reason given",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF742A2A),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "By ${_currentTransaction.flaggedBy} at ${DateFormat('MMM d, h:mm a').format(_currentTransaction.flaggedAt ?? DateTime.now())}",
                        style: GoogleFonts.inter(
                          color: const Color(0xFFC53030).withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Transaction Summary Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DATE",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF718096),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(_currentTransaction.date),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "TOTAL AMOUNT",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF718096),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${CurrencyFormatter.getCurrencySymbol(_currentTransaction.currency)} ${CurrencyFormatter.format(_currentTransaction.totalDebit)}",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Account Detailed Breakdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7FAFC),
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Color(0xFFEDF2F7)),
                    ),
                  ),
                  child: Column(
                    children: _currentTransaction.details.map((d) {
                      final isDebit = d.debit > 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color:
                                    (isDebit
                                            ? const Color(0xFF38A169)
                                            : const Color(0xFFE53E3E))
                                        .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isDebit
                                    ? LucideIcons.arrowDown
                                    : LucideIcons.arrowUp,
                                size: 12,
                                color: isDebit
                                    ? const Color(0xFF38A169)
                                    : const Color(0xFFE53E3E),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                d.account?.name ?? 'Unknown Account',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4A5568),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${CurrencyFormatter.getCurrencySymbol(d.currency)} ${CurrencyFormatter.format(isDebit ? d.debit : d.credit)}",
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDebit
                                        ? const Color(0xFF2F855A)
                                        : const Color(0xFFC53030),
                                  ),
                                ),
                                Text(
                                  isDebit ? "DEBIT" : "CREDIT",
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        (isDebit
                                                ? const Color(0xFF2F855A)
                                                : const Color(0xFFC53030))
                                            .withValues(alpha: 0.6),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Note and Entry Meta
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.messageSquare,
                            size: 13,
                            color: Color(0xFFA0AEC0),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentTransaction.mainNarration.isNotEmpty
                                  ? _currentTransaction.mainNarration
                                  : "No additional notes",
                              style: GoogleFonts.inter(
                                height: 1.3,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4A5568),
                                fontStyle:
                                    _currentTransaction.mainNarration.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: const Color(
                                  0xFF4299E1,
                                ).withValues(alpha: 0.1),
                                child: Text(
                                  _currentTransaction.createdBy
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF4299E1),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Builder(
                                builder: (context) {
                                  final userProvider = context
                                      .read<UserProvider>();
                                  String creatorName =
                                      _currentTransaction.createdBy;
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
                                    "Entry by $creatorName",
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF718096),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          Builder(
                            builder: (context) {
                              final statusColor = _getStatusColor(
                                _currentTransaction.status,
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _currentTransaction.status
                                      .toString()
                                      .split('.')
                                      .last
                                      .toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.history,
                      size: 14,
                      color: Color(0xFF718096),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "AUDIT TRAIL / MESSAGES",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ApprovalTimelineWidget(
                    logs: _currentTransaction.approvalLog,
                  ),
                ),
              ),
            ],
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
        return const Color(0xFF38A169); // Vibrant Green
      case TransactionStatus.rejected:
        return const Color(0xFFE53E3E); // Vibrant Red
      case TransactionStatus.clarification:
        return const Color(0xFFDD6B20); // Vibrant Orange
      case TransactionStatus.correction:
        return const Color(0xFFD69E2E); // Vibrant Amber
      case TransactionStatus.underReview:
        return const Color(0xFF805AD5); // Vibrant Purple
      case TransactionStatus.pending:
        return const Color(0xFF3182CE); // Vibrant Blue
      case TransactionStatus.deleted:
        return const Color(0xFF718096); // Grey
    }
  }
}
