import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/account_provider.dart';
import '../../../models/transaction_model.dart';
import '../../../models/message_model.dart';
import '../../notifications/notifications_screen.dart';
import '../../transaction/transaction_detail_screen.dart';
import '../../../core/utils/currency_formatter.dart';

class MessageCard extends StatefulWidget {
  const MessageCard({super.key});

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, _) {
        final fullReceived = notifProvider.receivedForReview(user.email);
        final fullSent = notifProvider.sentForReview(user.email);
        final fullFlagged = notifProvider.flaggedMessages;

        final bool isAdmin = user.role.trim().toLowerCase() == 'admin';
        final int limit = isAdmin ? 3 : 5;
        final double listHeight = isAdmin ? 210 : 350;

        final receivedMessages = fullReceived.take(limit).toList();
        final sentMessages = fullSent.take(limit).toList();
        final flaggedMessages = fullFlagged.take(limit).toList();

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Messages',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      // When loading, show spinner. Otherwise, show button.
                      child: notifProvider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                notifProvider.refreshNotifications(
                                  user,
                                  context.read<TransactionProvider>(),
                                  context.read<UserProvider>(),
                                  accountProvider: context
                                      .read<AccountProvider>(),
                                  forceRefresh: true,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // Tabs
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                controller: _tabController,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Pending (${fullReceived.length})'),
                        if (fullReceived.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Tab(text: 'Sent Review (${fullSent.length})'),
                  Tab(text: 'Flagged (${fullFlagged.length})'),
                ],
              ),

              // Tab Content
              SizedBox(
                height: listHeight,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMessageList(
                      receivedMessages,
                      notifProvider,
                      fullReceived.map((t) => t.transaction).toList(),
                    ),
                    _buildMessageList(
                      sentMessages,
                      notifProvider,
                      fullSent.map((t) => t.transaction).toList(),
                    ),
                    _buildMessageList(
                      flaggedMessages,
                      notifProvider,
                      fullFlagged.map((t) => t.transaction).toList(),
                    ),
                  ],
                ),
              ),

              // View All Button
              InkWell(
                onTap: () {
                  if (MediaQuery.of(context).size.width >= 800) {
                    context.read<DashboardProvider>().setView(
                      DashboardView.messages,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationScreen(),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList(
    List<MessageThread> threads,
    NotificationProvider provider,
    List<TransactionModel> allTransactions,
  ) {
    if (threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No messages',
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: threads.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final thread = threads[index];
        final latestMessage = thread.latestMessage;

        if (latestMessage == null) return const SizedBox();

        return InkWell(
          onTap: () {
            provider.markThreadAsRead(thread.voucherNo);
            if (MediaQuery.of(context).size.width >= 800) {
              context.read<DashboardProvider>().setView(
                DashboardView.transactionDetail,
                args: {
                  'transaction': thread.transaction,
                  'allTransactions': allTransactions,
                },
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(
                    transaction: thread.transaction,
                    allTransactions: allTransactions,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Unread indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: thread.isUnread ? Colors.blue : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),

                // Role icon
                _buildRoleIcon(latestMessage.senderRole),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final userProvider = context
                                    .watch<UserProvider>();
                                final tx = thread.transaction;
                                final lastMsg = thread.latestMessage;

                                String actionLabel = 'Sent by';
                                String actorEmail = thread.lastActionBy;
                                String actorName =
                                    lastMsg?.senderName ?? actorEmail;

                                if (tx.status == TransactionStatus.approved) {
                                  actionLabel = 'Approved by';
                                  actorName = thread.approvedBy ?? actorName;
                                } else if (tx.status ==
                                    TransactionStatus.rejected) {
                                  actionLabel = 'Rejected by';
                                }

                                // Fallback: If actorName looks like email, try lookup in users list
                                if (actorName.contains('@')) {
                                  try {
                                    actorName = userProvider.users
                                        .firstWhere(
                                          (u) =>
                                              u.email.trim().toLowerCase() ==
                                              actorName.trim().toLowerCase(),
                                        )
                                        .name;
                                  } catch (_) {
                                    // If still email, take the part before @ as last resort or keep as is
                                  }
                                }

                                return Text(
                                  '${thread.voucherNo} - $actionLabel $actorName',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (thread.isFlagged) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.flag, color: Colors.red, size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Builder(
                        builder: (context) {
                          String displayMsg = latestMessage.message.trim();
                          final tx = thread.transaction;

                          // Show [Amount] - [Description] for automated system/creation messages
                          bool isAutomated =
                              latestMessage.actionType.startsWith('auto_') ||
                              displayMsg.contains('Transaction Created') ||
                              displayMsg.contains('Self-entry') ||
                              displayMsg == 'No messages yet';

                          if (isAutomated) {
                            final amountStr = CurrencyFormatter.format(
                              tx.totalDebit,
                            );
                            displayMsg =
                                '$amountStr ${tx.currency}${tx.mainNarration.isNotEmpty ? ' - ${tx.mainNarration}' : ''}';
                          }
                          return Text(
                            displayMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Timestamp
                Text(
                  _formatTime(latestMessage.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleIcon(String role) {
    IconData icon;
    Color color;

    final normalizedRole = role.toLowerCase();
    if (normalizedRole.contains('admin')) {
      icon = Icons.admin_panel_settings;
      color = Colors.orange;
    } else if (normalizedRole.contains('owner') ||
        normalizedRole.contains('management')) {
      icon = Icons.person;
      color = Colors.green;
    } else {
      icon = Icons.work;
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}
