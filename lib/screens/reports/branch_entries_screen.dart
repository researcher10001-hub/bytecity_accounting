import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';

import '../transaction/transaction_detail_screen.dart';

class BranchEntriesScreen extends StatefulWidget {
  const BranchEntriesScreen({super.key});

  @override
  State<BranchEntriesScreen> createState() => _BranchEntriesScreenState();
}

class _BranchEntriesScreenState extends State<BranchEntriesScreen> {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String myBranch = user.branch;

    // Get ALL transactions that the user is ALLOWED to see based on backend strict rules
    final allTxs = context.watch<TransactionProvider>().transactions;

    // Filter to ONLY show transactions from my branch, EXCLUDING my own
    // The strict rule (backend dropping admin/mgmt rows for general users) is already applied
    final branchTxs = allTxs.where((tx) {
      return tx.branch == myBranch && tx.createdBy != user.email;
    }).toList();

    // Sort by date descending
    branchTxs.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '$myBranch Branch Entries',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: branchTxs.isEmpty
          ? Center(
              child: Text(
                'No peer entries found for $myBranch.',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 15,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: branchTxs.length,
              itemBuilder: (context, index) {
                final tx = branchTxs[index];
                return _buildTransactionCard(context, tx, branchTxs);
              },
            ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, TransactionModel tx,
      List<TransactionModel> allTxs) {
    // A simplified card tailored for viewing peer entries.
    // Tapping it opens the detailed view.
    final String typeString = tx.type.toString().split('.').last.toLowerCase();
    final bool isCredit = typeString == 'credit' || typeString == 'receipt';
    final Color typeColor = isCredit ? Colors.green : Colors.red;

    // Calculate total amount from details
    final double totalAmount = tx.details.fold(
            0.0, (sum, detail) => sum + detail.debitBDT + detail.creditBDT) /
        2;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(
                transaction: tx,
                allTransactions: allTxs,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tx.mainNarration,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '৳${totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: typeColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'By: ${tx.createdByName.isEmpty ? tx.createdBy : tx.createdByName}',
                    style: GoogleFonts.inter(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    tx.status.toString().split('.').last.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: _getStatusColor(tx.status),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.approved:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.rejected:
        return Colors.red;
      case TransactionStatus.clarification:
        return Colors.blue;
      case TransactionStatus.underReview:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
