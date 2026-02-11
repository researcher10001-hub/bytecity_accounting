import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/message_model.dart';
import '../../models/transaction_model.dart';
import '../transaction/transaction_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Refresh notifications on enter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      final txProvider = context.read<TransactionProvider>();
      if (user != null) {
        context.read<NotificationProvider>().refreshNotifications(
          user,
          txProvider,
          context.read<UserProvider>(),
          accountProvider: context.read<AccountProvider>(),
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    final receivedMessages = notificationProvider.receivedForReview(user.email);
    final sentMessages = notificationProvider.sentForReview(user.email);
    final flaggedMessages = notificationProvider.flaggedMessages;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              final txProvider = context.read<TransactionProvider>();
              context.read<NotificationProvider>().refreshNotifications(
                user,
                txProvider,
                context.read<UserProvider>(),
                accountProvider: context.read<AccountProvider>(),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.blue[700],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[700],
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.inbox),
              text: 'In Review (${receivedMessages.length})',
            ),
            Tab(
              icon: const Icon(Icons.send),
              text: 'Sent Review (${sentMessages.length})',
            ),
            Tab(
              icon: const Icon(Icons.flag),
              text: 'Flagged (${flaggedMessages.length})',
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: notificationProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMessageList(
                        context,
                        receivedMessages,
                        'received',
                        receivedMessages.map((t) => t.transaction).toList(),
                      ),
                      _buildMessageList(
                        context,
                        sentMessages,
                        'sent',
                        sentMessages.map((t) => t.transaction).toList(),
                      ),
                      _buildMessageList(
                        context,
                        flaggedMessages,
                        'flagged',
                        flaggedMessages.map((t) => t.transaction).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    List<MessageThread> threads,
    String tabType,
    List<TransactionModel> allTransactions,
  ) {
    if (threads.isEmpty) {
      IconData emptyIcon;
      String emptyMessage;

      if (tabType == 'received') {
        emptyIcon = Icons.inbox;
        emptyMessage = "No messages waiting for your review";
      } else if (tabType == 'sent') {
        emptyIcon = Icons.send;
        emptyMessage = "No messages waiting for response";
      } else {
        emptyIcon = Icons.flag_outlined;
        emptyMessage = "No flagged items found";
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: threads.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final thread = threads[i];
        return _buildNotificationCard(context, thread, allTransactions);
      },
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    MessageThread thread,
    List<TransactionModel> allTransactions,
  ) {
    IconData icon = Icons.info_outline;
    Color color = Colors.blue;

    // Determine icon and color based on status
    switch (thread.status) {
      case MessageStatus.approved:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case MessageStatus.clarify:
        icon = Icons.help_outline;
        color = Colors.orange;
        break;
      case MessageStatus.underReview:
        icon = Icons.flag_outlined;
        color = Colors.purple;
        break;
      case MessageStatus.pending:
        icon = Icons.info_outline;
        color = Colors.blue;
        break;
    }

    // Get the latest message for display
    final latestMessage = thread.messages.isNotEmpty
        ? thread.messages.last
        : null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(
              transaction: thread.transaction,
              allTransactions: allTransactions,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: thread.isFlagged
                ? Colors.red.shade200
                : Colors.grey.shade200,
            width: thread.isFlagged ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final userProvider = context.read<UserProvider>();
                              final tx = thread.transaction;

                              String actionLabel = 'Sent by';
                              String actorEmail = thread.lastActionBy;

                              if (tx.status == TransactionStatus.approved) {
                                actionLabel = 'Approved by';
                                actorEmail =
                                    thread.approvedBy ?? thread.lastActionBy;
                              } else if (tx.status ==
                                  TransactionStatus.rejected) {
                                actionLabel = 'Rejected by';
                                actorEmail = thread.lastActionBy;
                              }

                              String actorName = actorEmail;
                              try {
                                actorName = userProvider.users
                                    .firstWhere(
                                      (u) =>
                                          u.email.trim().toLowerCase() ==
                                          actorEmail.trim().toLowerCase(),
                                    )
                                    .name;
                              } catch (_) {}

                              return Text(
                                '${thread.voucherNo} - $actionLabel $actorName',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                          if (thread.isFlagged) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.flag, color: Colors.red, size: 16),
                          ],
                        ],
                      ),
                      Text(
                        latestMessage != null
                            ? DateFormat(
                                'h:mm a',
                              ).format(latestMessage.timestamp)
                            : '',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      String displayMsg =
                          (latestMessage?.message ??
                                  thread.transaction.mainNarration)
                              .trim();
                      final tx = thread.transaction;

                      // Show [Amount] - [Description] for automated system/creation messages
                      bool isAutomated =
                          (latestMessage?.actionType ?? '').startsWith(
                            'auto_',
                          ) ||
                          displayMsg.contains('Transaction Created') ||
                          displayMsg.contains('Self-entry');

                      if (isAutomated) {
                        final amountStr = NumberFormat(
                          '#,##0',
                        ).format(tx.totalDebit);
                        displayMsg =
                            '$amountStr ${tx.currency}${tx.mainNarration.isNotEmpty ? ' - ${tx.mainNarration}' : ''}';
                      }
                      return Text(
                        displayMsg,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      );
                    },
                  ),
                  if (thread.isFlagged && thread.flagReason != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              thread.flagReason!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    latestMessage != null
                        ? DateFormat(
                            'MMM d, yyyy',
                          ).format(latestMessage.timestamp)
                        : DateFormat(
                            'MMM d, yyyy',
                          ).format(thread.transaction.date),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
