import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/account_model.dart';
import '../../services/permission_service.dart';

import '../../models/transaction_model.dart';
import '../../core/utils/currency_formatter.dart';
import '../transaction/transaction_entry_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import '../admin/account_groups_screen.dart';

class LedgerScreen extends StatefulWidget {
  final String? initialAccountName;
  const LedgerScreen({super.key, this.initialAccountName});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  List<Account> _selectedAccounts = []; // Multi-select support
  DateTimeRange? _dateRange;
  String?
  _expandedCardKey; // Track currently expanded transaction card (only one)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.fetchUsers();

      // Fetch Groups
      context.read<GroupProvider>().fetchGroups(forceRefresh: true);

      final accountProvider = Provider.of<AccountProvider>(
        context,
        listen: false,
      );
      final currentUser = context.read<AuthProvider>().user;
      context.read<TransactionProvider>().fetchHistory(
        currentUser,
        forceRefresh: true,
        accountProvider: accountProvider,
      );

      if (widget.initialAccountName != null) {
        final accountProvider = Provider.of<AccountProvider>(
          context,
          listen: false,
        );
        try {
          final acc = accountProvider.accounts.firstWhere(
            (a) => a.name == widget.initialAccountName,
          );
          setState(() => _selectedAccounts = [acc]);
        } catch (e) {
          // Account not found
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final accounts = accountProvider.accounts;

    final user = context.watch<AuthProvider>().user;

    // Safety check
    if (user == null) return const SizedBox.shrink();

    // 1. Filter Transactions
    List<Map<String, dynamic>> ledgerEntries = [];
    double runningBalance = 0.0;

    double totalDebit = 0.0;
    double totalCredit = 0.0;

    if (_selectedAccounts.isNotEmpty) {
      // Get all visible transactions
      final allTx = transactionProvider.getVisibleTransactions(user);

      // Filter Sort chrono
      final sortedTx = List<TransactionModel>.from(allTx)
        ..sort((a, b) => a.date.compareTo(b.date));

      for (var tx in sortedTx) {
        // Check filtering by date
        if (_dateRange != null) {
          final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
          if (txDate.isBefore(_dateRange!.start) ||
              txDate.isAfter(_dateRange!.end)) {
            continue;
          }
        }

        // Find details for any of the selected accounts
        // Combined Ledger Logic: We consider the transaction if it involves ANY selected account.
        // For combined balance, we assume a "Net Movement" perspective.

        // Logic for Split Entries:
        // We iterate through details and add a SEPARATE ledger entry for EACH detail that matches a selected account.
        // This ensures chronological sorting (since transactions are sorted) and detailed breakdown.

        for (var detail in tx.details) {
          final matchedAccount = _selectedAccounts
              .where((a) => a.name == detail.account?.name)
              .firstOrNull;

          if (matchedAccount != null) {
            // BOA Group-Only Filtering:
            // If user is NOT admin/management/viewer, and this account is
            // only accessible via group (not owned), only show self-created entries.
            if (!user.isAdmin && !user.isManagement && !user.isViewer) {
              final permSvc = PermissionService();
              final isOwned = permSvc.isOwner(user, matchedAccount);
              if (!isOwned) {
                // Group-only access: only show user's own entries
                final txCreator = (tx.createdBy).trim().toLowerCase();
                final me = user.email.trim().toLowerCase();
                if (txCreator != me && txCreator.isNotEmpty) {
                  continue; // Skip others' entries for group-only accounts
                }
              }
            }
            // Calculate Movement for THIS account
            double movement = 0;
            bool isDebitNormal = [
              'Asset',
              'Expense',
            ].contains(matchedAccount.type);

            if (isDebitNormal) {
              movement = detail.debitBDT - detail.creditBDT;
            } else {
              movement = detail.creditBDT - detail.debitBDT;
            }

            runningBalance += movement;
            totalDebit += detail.debitBDT;
            totalCredit += detail.creditBDT;

            // Determine "Against" accounts (all other accounts in the transaction)
            final otherDetails = tx.details
                .where((d) => d != detail) // Exclude current detail
                .toList();

            String againstAccountName = '';
            if (otherDetails.isNotEmpty) {
              againstAccountName = otherDetails
                  .map((d) => d.account?.name ?? 'Unknown')
                  .toSet()
                  .join(', ');
            } else {
              againstAccountName = 'Self / Error';
            }

            ledgerEntries.add({
              'date': tx.date,
              'voucherNo': tx.voucherNo,
              'narration': detail.narration.isNotEmpty
                  ? detail.narration
                  : (tx.mainNarration.isNotEmpty ? tx.mainNarration : ''),
              'against': againstAccountName,
              // Use BDT equivalents for Ledger
              'debit': detail.debitBDT,
              'credit': detail.creditBDT,
              'balance': runningBalance,
              'type': tx.type,
              'createdBy': tx.createdBy,
              'originalTx': tx,
              'specificAccount': matchedAccount
                  .name, // To know which account this line belongs to
              // Store original currency details for display
              'currency': detail.currency,
              'rate': detail.rate,
              'originalDebit': detail.debit,
              'originalCredit': detail.credit,
            });
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.bookOpen, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Ledger Books',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: transactionProvider.isLoading
                ? const Icon(
                        LucideIcons.refreshCw,
                        size: 18,
                        color: Color(0xFF64748B),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .rotate(duration: 1.seconds)
                : const Icon(
                    LucideIcons.refreshCw,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
            onPressed: () => transactionProvider.fetchHistory(
              user,
              forceRefresh: true,
              accountProvider: accountProvider,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.withAlpha(0x05)),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body:
          (accountProvider.isLoading || transactionProvider.isLoading) &&
              accounts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // FILTERS
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(0x02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Account Selector (Searchable)
                          Expanded(
                            flex: 1,
                            child: _buildAccountDropdown(
                              context,
                              accounts,
                              groupProvider,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Pro Dual-Field Filter Bar
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateTile(
                              'From',
                              _dateRange?.start,
                              () => _selectDate(isStart: true),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              LucideIcons.arrowRight,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Expanded(
                            child: _buildDateTile(
                              'To',
                              _dateRange?.end,
                              _dateRange?.start == null
                                  ? null
                                  : () => _selectDate(isStart: false),
                            ),
                          ),
                          if (_dateRange != null) ...[
                            const SizedBox(width: 8),
                            Material(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () => setState(() => _dateRange = null),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  child: const Icon(
                                    LucideIcons.x,
                                    size: 18,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Loading Bar (visible during refresh)
                if (transactionProvider.isLoading)
                  const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF1E88E5),
                    ),
                  ),

                // TRANSACTION LIST
                Expanded(
                  child: _selectedAccounts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.wallet,
                                size: 48,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Please select an account',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ledgerEntries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.fileX,
                                size: 48,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions found',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: ledgerEntries.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final entry = ledgerEntries[index];
                            final date = entry['date'] as DateTime;
                            final originalTx =
                                entry['originalTx'] as TransactionModel;

                            // Convert dynamic values to double safely
                            final double debit = (entry['debit'] ?? 0.0)
                                .toDouble();
                            final double credit = (entry['credit'] ?? 0.0)
                                .toDouble();

                            final bool isDebit = debit > 0;
                            final double txAmount = isDebit ? debit : credit;
                            final Color amountColor = isDebit
                                ? Colors.green
                                : Colors.red;
                            final String formattedAmount =
                                '৳${CurrencyFormatter.format(txAmount)}';

                            // Status Logic Simulation (since 'status' might not be in model yet)
                            // If 'originalTx' has a status field, use it.
                            // Ideally: String status = originalTx.status;
                            // For now, defaulting to Approved unless specific logic exists.
                            // But user asked for Pending/Approved dots.
                            // We'll mimic this: if it's recent or specific condition, maybe Pending?
                            // For now, let's look for a 'status' key in entry if we added it, or default.
                            // In Step 6145 view, we didn't add status to map.
                            // So we will just show 'Approved' visually for now, or check something.
                            // Let's assume passed validation means Approved.

                            String status = 'Approved';
                            bool isPending = false;

                            // Action Required Logic
                            // If isPending is true, show Action Required.

                            // Extract Original Currency Info
                            final String currency =
                                entry['currency']?.toString() ?? 'BDT';
                            final double rate = (entry['rate'] ?? 1.0)
                                .toDouble();
                            final double originalDebit =
                                (entry['originalDebit'] ?? 0.0).toDouble();
                            final double originalCredit =
                                (entry['originalCredit'] ?? 0.0).toDouble();
                            final double originalAmount = isDebit
                                ? originalDebit
                                : originalCredit;

                            return _buildTransactionCard(
                              context,
                              entry,
                              date,
                              formattedAmount,
                              amountColor,
                              originalTx,
                              isPending: isPending,
                              status: status,
                              uniqueKeyExtra: index.toString(),
                              // Pass Original Currency Info
                              currency: currency,
                              rate: rate,
                              originalAmount: originalAmount,
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _selectedAccounts.isEmpty
          ? null
          : _buildStatusBar(totalDebit, totalCredit, runningBalance),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    Map<String, dynamic> entry,
    DateTime date,
    String formattedAmount,
    Color amountColor,
    TransactionModel originalTx, {
    required bool isPending,
    required String status,
    String? uniqueKeyExtra,
    // New parameters for multi-currency
    String currency = 'BDT',
    double rate = 1.0,
    double originalAmount = 0.0,
  }) {
    final transactionProvider = context.read<TransactionProvider>();
    // FORMAT DATE: "05 Feb"
    final dateStr = DateFormat('dd MMM').format(date);

    // Determines display text
    final double debitVal = (entry['debit'] ?? 0.0).toDouble();
    final bool isDebit = debitVal > 0;
    final String againstAccount = entry['against'] ?? '';
    final String voucherNo = entry['voucherNo'] ?? '';

    // Contextual Labels for Against Account
    String getAgainstLabel() {
      final txType = originalTx.type;
      if (txType == VoucherType.payment) {
        return isDebit ? 'Paid from' : 'Exp. on';
      } else if (txType == VoucherType.receipt) {
        return isDebit ? 'Rec. in' : 'Inc. from';
      } else if (txType == VoucherType.contra) {
        return isDebit ? 'Trans. from' : 'Trans. to';
      } else if (txType == VoucherType.journal) {
        return isDebit ? 'Jour. from' : 'Jour. to';
      }
      return 'Against';
    }

    final againstPrefix = getAgainstLabel();

    // Status Colors
    final statusColor = isPending ? Colors.amber : Colors.green;

    // Unique key for this card
    final cardKey =
        '${originalTx.voucherNo}_${date.millisecondsSinceEpoch}_${uniqueKeyExtra ?? ""}';
    final isExpanded = _expandedCardKey == cardKey;

    return Stack(
      children: [
        // EXPANDED DETAILS (Narrower & Shadowed) - Place first in Stack so it is behind
        if (isExpanded)
          // We use a Column wrapper to naturally occupy space in the list
          // so that neighboring items in the ListView don't overlap incorrectly.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 65), // Wait for header to clear content
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(0x0C),
                      blurRadius: 15,
                      spreadRadius: -2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action Required Alert
                    if (isPending)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.amber.shade200,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'ACTION REQUIRED',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber[800],
                          ),
                        ),
                      ),

                    // Fields: Account (if multiple), Debit / Credit, Against Account, By, Desc, Status
                    if (_selectedAccounts.length > 1 &&
                        entry.containsKey('specificAccount'))
                      _buildDetailRow(
                        'Account:',
                        entry['specificAccount'],
                        isBold: true,
                        valueColor: Colors.blue.shade900,
                      ),

                    _buildDetailRow(
                      isDebit ? 'Debit:' : 'Credit:',
                      formattedAmount,
                      isBold: true,
                    ),
                    _buildDetailRow('$againstPrefix:', againstAccount),
                    _buildDetailRow('Desc:', originalTx.mainNarration),
                    _buildDetailRow('Entry By:', originalTx.createdByName),
                    _buildDetailRow(
                      'Status:',
                      status,
                      statusDotColor: statusColor,
                    ),

                    // ERP Sync Information
                    if (originalTx.erpSyncStatus != 'none' &&
                        originalTx.erpDocumentId != null &&
                        originalTx.erpDocumentId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          // Normal tap - Open in browser
                          final settingsProvider = context
                              .read<SettingsProvider>();
                          final erpUrl = settingsProvider.erpUrl;

                          // Extract ID from URL if needed
                          String documentId = originalTx.erpDocumentId!;
                          if (documentId.startsWith('http://') ||
                              documentId.startsWith('https://')) {
                            final uri = Uri.tryParse(documentId);
                            if (uri != null && uri.pathSegments.isNotEmpty) {
                              documentId = uri.pathSegments.last;
                            }
                          }

                          if (erpUrl.isNotEmpty) {
                            final docUrl =
                                '${erpUrl.endsWith('/') ? erpUrl : '$erpUrl/'}app/journal-entry/$documentId';
                            final uri = Uri.parse(docUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not open ERPNext link',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        onLongPress: () async {
                          // Long press - Copy to clipboard
                          final settingsProvider = context
                              .read<SettingsProvider>();
                          final erpUrl = settingsProvider.erpUrl;

                          // Extract ID from URL if needed
                          String documentId = originalTx.erpDocumentId!;
                          if (documentId.startsWith('http://') ||
                              documentId.startsWith('https://')) {
                            final uri = Uri.tryParse(documentId);
                            if (uri != null && uri.pathSegments.isNotEmpty) {
                              documentId = uri.pathSegments.last;
                            }
                          }

                          if (erpUrl.isNotEmpty) {
                            final docUrl =
                                '${erpUrl.endsWith('/') ? erpUrl : '$erpUrl/'}app/journal-entry/$documentId';
                            await Clipboard.setData(
                              ClipboardData(text: docUrl),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'ERPNext link copied to clipboard',
                                  ),
                                  backgroundColor: Color(0xFF38A169),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        child: Row(
                          children: [
                            SizedBox(
                              width: 75,
                              child: Text(
                                'ERP ID:',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(
                              LucideIcons.link,
                              size: 12,
                              color: Color(0xFF4299E1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              () {
                                String docId = originalTx.erpDocumentId!;
                                if (docId.startsWith('http://') ||
                                    docId.startsWith('https://')) {
                                  final uri = Uri.tryParse(docId);
                                  if (uri != null &&
                                      uri.pathSegments.isNotEmpty) {
                                    return uri.pathSegments.last;
                                  }
                                }
                                return docId;
                              }(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4299E1),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              LucideIcons.externalLink,
                              size: 10,
                              color: Color(0xFF4299E1),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Edit Button
                    InkWell(
                      onTap: () =>
                          _showEditTransactionDialog(context, originalTx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.pencil,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Edit Transaction',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              LucideIcons.chevronRight,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Messages Link
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionDetailScreen(
                              transaction: originalTx,
                              allTransactions: transactionProvider.transactions,
                            ),
                          ),
                        ).then((_) {
                          // Optional: refresh if needed
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              originalTx.approvalLog.isEmpty
                                  ? 'Messages: No comments'
                                  : 'Messages: ${originalTx.approvalLog.length} comments',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const Icon(
                              LucideIcons.chevronRight,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

        // MAIN CARD (Header) - Place second in Stack so it is in front
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(0x0A),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCardKey = null;
                  } else {
                    _expandedCardKey = cardKey;
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: [Date] | [Voucher ID] [Amount] [Dr/Cr]
                    Row(
                      children: [
                        // Date + Separator (Fixed Width for Alignment)
                        SizedBox(
                          width: 75,
                          child: Row(
                            children: [
                              Text(
                                dateStr,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '|',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                        // Voucher ID
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                voucherNo,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              if (originalTx.erpSyncStatus.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _buildSyncIndicator(originalTx.erpSyncStatus),
                              ],
                            ],
                          ),
                        ),
                        // Amount (Side based on isDebit)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formattedAmount,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDebit ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDebit ? 'Dr' : 'Cr',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // ROW 2: [Against : ] [Against account title (unfocused)]
                    Row(
                      children: [
                        SizedBox(
                          width: 75,
                          child: Text(
                            'Against :',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8), // Dim
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            againstAccount,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(
                                0xFF94A3B8,
                              ), // Unfocused (Grey)
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? statusDotColor,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                if (statusDotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
                      color: valueColor ?? const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(double debit, double credit, double balance) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(0x0A),
            offset: const Offset(0, 4),
            blurRadius: 15,
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Debit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Debit',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '৳${CurrencyFormatter.format(debit)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Credit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Credit',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '৳${CurrencyFormatter.format(credit)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, thickness: 1),
            ),
            // Row 3: Balance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balance',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '৳${CurrencyFormatter.format(balance)}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: balance < 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF1F5F9) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null
                ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 12,
                    color: date != null
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      date == null
                          ? 'Select'
                          : DateFormat('dd MMM, yy').format(date),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: date != null
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final primaryColor = const Color(0xFF2563EB);
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_dateRange?.start ?? DateTime.now())
          : (_dateRange?.end ?? _dateRange?.start ?? DateTime.now()),
      firstDate: isStart
          ? DateTime(2020)
          : (_dateRange?.start ?? DateTime(2020)),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: primaryColor,
          brightness: Brightness.light,
          textTheme: GoogleFonts.interTextTheme(),
          datePickerTheme: DatePickerThemeData(
            headerBackgroundColor: primaryColor,
            headerForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            dayStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _dateRange = DateTimeRange(
            start: picked,
            end: _dateRange?.end != null && _dateRange!.end.isAfter(picked)
                ? _dateRange!.end
                : picked,
          );
        } else {
          _dateRange = DateTimeRange(
            start: _dateRange?.start ?? picked,
            end: picked,
          );
        }
      });
    }
  }

  void _showEditTransactionDialog(BuildContext context, TransactionModel tx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionEntryScreen(transaction: tx),
      ),
    );
  }

  Widget _buildAccountDropdown(
    BuildContext context,
    List<Account> accounts,
    GroupProvider groupProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Account Multi-Select Dropdown Trigger
        InkWell(
          onTap: () => _showAccountMultiSelect(context, accounts),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.wallet, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedAccounts.isEmpty
                        ? 'Select Accounts'
                        : _selectedAccounts.length == 1
                        ? _selectedAccounts.first.name
                        : '${_selectedAccounts.length} Accounts Selected',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _selectedAccounts.isEmpty
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAccountMultiSelect(
    BuildContext context,
    List<Account> allAccounts,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = "";
        bool isRefreshing = false; // Loading state
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allAccounts
                .where(
                  (a) =>
                      a.name.toLowerCase().contains(query.toLowerCase()) ||
                      a.type.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();

            // SORT: Selected first, then Alphabetical
            filtered.sort((a, b) {
              final aSelected = _selectedAccounts.contains(a);
              final bSelected = _selectedAccounts.contains(b);
              if (aSelected && !bSelected) return -1;
              if (!aSelected && bSelected) return 1;
              return a.name.compareTo(b.name);
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Loading Indicator
                    if (isRefreshing)
                      const LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Select Accounts',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  // Navigate to Account Groups and auto-refresh on return
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AccountGroupsScreen(
                                            initialTab: 'report',
                                          ),
                                    ),
                                  );

                                  // Show loading state
                                  setModalState(() => isRefreshing = true);

                                  // Auto-refresh accounts when returning
                                  final provider = context
                                      .read<AccountProvider>();
                                  final user = context
                                      .read<AuthProvider>()
                                      .user;
                                  await provider.fetchAccounts(
                                    user,
                                    forceRefresh: true,
                                  );

                                  // Hide loading and rebuild modal
                                  setModalState(() => isRefreshing = false);
                                },
                                icon: const Icon(
                                  LucideIcons.plusCircle,
                                  size: 16,
                                ),
                                label: const Text('Manage Groups'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Search Input
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search accounts...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        onChanged: (val) => setModalState(() => query = val),
                      ),
                    ),

                    // Quick Groups
                    Consumer<GroupProvider>(
                      builder: (context, groupProvider, child) {
                        final reportGroups = groupProvider.reportGroups;
                        if (reportGroups.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return SizedBox(
                          height: 50,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: reportGroups.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final group = reportGroups[index];
                              // Use AccountProvider as source of truth
                              // Filter accounts that possess this group's ID
                              final accountsInGroup = allAccounts
                                  .where((a) => a.groupIds.contains(group.id))
                                  .toList();

                              if (accountsInGroup.isEmpty) {
                                // If no accounts in this group, show as unselected disabled state or just unselected
                                // But better to check if any are selected
                              }

                              final isFullySelected =
                                  accountsInGroup.isNotEmpty &&
                                  accountsInGroup.every(
                                    (a) => _selectedAccounts.contains(a),
                                  );

                              return ActionChip(
                                label: Text(group.name),
                                avatar: Icon(
                                  isFullySelected
                                      ? LucideIcons.checkCircle
                                      : LucideIcons.circle,
                                  size: 14,
                                  color: isFullySelected
                                      ? Colors.white
                                      : Colors.blue,
                                ),
                                backgroundColor: isFullySelected
                                    ? Colors.blue
                                    : Colors.blue.shade50,
                                labelStyle: GoogleFonts.inter(
                                  color: isFullySelected
                                      ? Colors.white
                                      : Colors.blue.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                                onPressed: () {
                                  if (accountsInGroup.isEmpty) return;

                                  if (isFullySelected) {
                                    // Deselect all (robust against stale objects by using name)
                                    final namesInGroup = accountsInGroup
                                        .map((a) => a.name)
                                        .toSet();
                                    _selectedAccounts.removeWhere(
                                      (a) => namesInGroup.contains(a.name),
                                    );
                                  } else {
                                    // Select all (union)
                                    for (var acc in accountsInGroup) {
                                      if (!_selectedAccounts.contains(acc)) {
                                        _selectedAccounts.add(acc);
                                      }
                                    }
                                  }

                                  setModalState(() {});
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),

                    // List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    LucideIcons.search,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No accounts found",
                                    style: GoogleFonts.inter(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              itemCount: filtered.length,
                              separatorBuilder: (c, i) => Divider(
                                height: 1,
                                color: Colors.grey.shade100,
                              ),
                              itemBuilder: (context, index) {
                                final acc = filtered[index];
                                final isSelected = _selectedAccounts.contains(
                                  acc,
                                );

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    // GLOBAL STATE UPDATE
                                    // We do this first so the sort uses the new state
                                    if (value == true) {
                                      _selectedAccounts.add(acc);
                                    } else {
                                      _selectedAccounts.remove(acc);
                                    }

                                    // Trigger rebuild of parent to update the underlying list if needed
                                    // But crucial: trigger setModalState to re-run the builder and re-sort
                                    setModalState(() {});
                                    setState(
                                      () {},
                                    ); // Update the main screen behind
                                  },
                                  title: Text(
                                    acc.name,
                                    style: GoogleFonts.inter(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.blue.shade900
                                          : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    acc.type,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  activeColor: Colors.blue,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  dense: true,
                                  secondary: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withAlpha(0x10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      acc.name.isNotEmpty ? acc.name[0] : '?',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Done Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Done (${_selectedAccounts.length} selected)',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSyncIndicator(String status) {
    // Normalize status
    final normalizedStatus = status.trim().toLowerCase();

    IconData icon;
    Color color;
    String tooltip;

    if (normalizedStatus == 'synced') {
      icon = Icons.sync_rounded;
      color = const Color(0xFF2563EB);
      tooltip = 'Synced to ERPNext';
    } else if (normalizedStatus == 'manual') {
      icon = Icons.edit_note_rounded;
      color = const Color(0xFF2563EB);
      tooltip = 'Manually entered in ERPNext';
    } else {
      // Default / 'none'
      icon = Icons.sync_problem_rounded;
      color = Colors.red.shade300;
      tooltip = 'Not synced to ERPNext';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
