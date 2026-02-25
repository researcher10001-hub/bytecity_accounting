import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/message_model.dart';
import '../../providers/branch_provider.dart';
import '../transaction/transaction_detail_screen.dart';
import '../../core/utils/currency_formatter.dart';

class PendingTransactionsScreen extends StatefulWidget {
  const PendingTransactionsScreen({super.key});

  @override
  State<PendingTransactionsScreen> createState() =>
      _PendingTransactionsScreenState();
}

class _PendingTransactionsScreenState extends State<PendingTransactionsScreen> {
  String? _selectedUserEmail;
  String _selectedBranch = 'All';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending for Approval'),
        centerTitle: true,
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _refreshData(context),
                ),
        ],
      ),
      body: Consumer2<TransactionProvider, NotificationProvider>(
        builder: (context, txProvider, notifProvider, _) {
          final user = context.read<AuthProvider>().user;

          final allPendingTransactions = txProvider.transactions.where((tx) {
            bool matchesStatus = tx.status == TransactionStatus.pending ||
                tx.status == TransactionStatus.clarification ||
                tx.status == TransactionStatus.underReview;

            bool matchesBranch = true;
            if (user != null && (user.isAdmin || user.isManagement)) {
              if (_selectedBranch != 'All') {
                matchesBranch = tx.branch == _selectedBranch;
              }
            }

            return matchesStatus && matchesBranch;
          }).toList();

          // Extract unique users who have pending entries to build filter chips
          final userEmails =
              allPendingTransactions.map((tx) => tx.createdBy).toSet().toList();

          final filteredTransactions = _selectedUserEmail == null
              ? allPendingTransactions
              : allPendingTransactions.where((tx) {
                  return tx.createdBy.trim().toLowerCase() ==
                      _selectedUserEmail!.trim().toLowerCase();
                }).toList();

          if (allPendingTransactions.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              if (user != null && (user.isAdmin || user.isManagement))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business,
                            size: 20, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text('Branch Filter: ',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: Colors.grey.shade700)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBranch,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              items: [
                                'All',
                                ...context.watch<BranchProvider>().branches
                              ]
                                  .map((b) => DropdownMenuItem(
                                      value: b, child: Text(b)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedBranch = val;
                                    _selectedUserEmail =
                                        null; // reset user filter
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // personnel filter chips
              if (userEmails.length > 1) _buildFilterChips(context, userEmails),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = filteredTransactions[index];
                    final thread = notifProvider.messageThreads.firstWhere(
                      (t) => t.voucherNo == tx.voucherNo,
                      orElse: () => MessageThread(
                        voucherNo: tx.voucherNo,
                        transaction: tx,
                        messages: [],
                        status: MessageStatus.pending,
                        isUnread: false,
                        lastActionBy: tx.createdBy,
                      ),
                    );

                    final lastMsg =
                        thread.latestMessage?.message ?? 'No messages yet';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        onTap: () {
                          if (MediaQuery.of(context).size.width >= 800) {
                            context.read<DashboardProvider>().setView(
                              DashboardView.transactionDetail,
                              args: {
                                'transaction': tx,
                                'allTransactions': filteredTransactions,
                              },
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransactionDetailScreen(
                                  transaction: tx,
                                  allTransactions: filteredTransactions,
                                ),
                              ),
                            );
                          }
                        },
                        title: _buildDynamicTitle(context, tx, thread),
                        subtitle: _buildSubtitle(tx, lastMsg),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refreshData(BuildContext context) async {
    setState(() => _isLoading = true);

    try {
      // Add a small delay so the animation is actually visible
      await Future.wait([
        Future.delayed(const Duration(milliseconds: 500)),
        _performRefresh(context),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performRefresh(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final txProvider = context.read<TransactionProvider>();
    final notifProvider = context.read<NotificationProvider>();
    final userProvider = context.read<UserProvider>();
    final accProvider = context.read<AccountProvider>();

    await txProvider.fetchHistory(user, forceRefresh: true);
    if (context.mounted) {
      await notifProvider.refreshNotifications(
        user,
        txProvider,
        userProvider,
        accountProvider: accProvider,
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No pending transactions',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, List<String> emails) {
    final userProvider = context.read<UserProvider>();

    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: _selectedUserEmail == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedUserEmail = null);
                }
              },
            ),
          ),
          ...emails.map((email) {
            String name = email;
            try {
              name = userProvider.users
                  .firstWhere(
                    (u) =>
                        u.email.trim().toLowerCase() ==
                        email.trim().toLowerCase(),
                  )
                  .name;
            } catch (_) {}

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(name),
                selected: _selectedUserEmail == email,
                onSelected: (selected) {
                  setState(() => _selectedUserEmail = selected ? email : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDynamicTitle(
    BuildContext context,
    TransactionModel tx,
    MessageThread thread,
  ) {
    final userProvider = context.read<UserProvider>();
    // Identify the last HUMAN actor by looking at the logical flow
    String lastHumanActorEmail = tx.createdBy;
    bool hasOwnerReplied = false;

    for (var msg in thread.messages.reversed) {
      if (msg.senderEmail.toLowerCase().trim() != 'system' &&
          msg.senderEmail.isNotEmpty) {
        lastHumanActorEmail = msg.senderEmail;
        if (lastHumanActorEmail.trim().toLowerCase() !=
            tx.createdBy.trim().toLowerCase()) {
          hasOwnerReplied = true;
        }
        break;
      }
    }

    // Resolve Actor Name
    String actorName = lastHumanActorEmail;
    try {
      actorName = userProvider.users
          .firstWhere(
            (u) =>
                u.email.trim().toLowerCase() ==
                lastHumanActorEmail.trim().toLowerCase(),
          )
          .name;
    } catch (_) {}

    // Resolve Target Name
    String targetName = 'Owner';
    if (hasOwnerReplied) {
      // Flow is Back to Creator
      try {
        targetName = userProvider.users
            .firstWhere(
              (u) =>
                  u.email.trim().toLowerCase() ==
                  tx.createdBy.trim().toLowerCase(),
            )
            .name;
      } catch (_) {
        targetName = 'Creator';
      }
    } else {
      // Flow is Forward to Owner
      // Find the first Admin or Management user to show a specific name
      try {
        final owner = userProvider.users.firstWhere(
          (u) => u.isAdmin || u.isManagement,
        );
        targetName = owner.name;
      } catch (_) {
        targetName = 'Owner';
      }
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            '${tx.voucherNo} - Sent by $actorName ➔ $targetName',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        if (tx.isFlagged)
          Icon(Icons.flag, color: Colors.red.shade700, size: 16),
      ],
    );
  }

  Widget _buildSubtitle(TransactionModel tx, String lastMsg) {
    String displayMsg = lastMsg.trim();

    if (displayMsg.toLowerCase().contains('transaction created') ||
        displayMsg.toLowerCase().contains('self-entry') ||
        displayMsg == 'No messages yet') {
      final amountStr = CurrencyFormatter.format(tx.totalDebit);
      final narration = tx.mainNarration.trim();
      displayMsg =
          '$amountStr ${tx.currency}${narration.isNotEmpty ? ' - $narration' : ''}';
    }

    return Text(
      displayMsg,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
    );
  }
}
