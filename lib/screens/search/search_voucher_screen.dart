import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/transaction_model.dart';
import '../transaction/transaction_detail_screen.dart';
import '../../core/utils/currency_formatter.dart';

import '../../providers/user_provider.dart';

class SearchVoucherScreen extends StatefulWidget {
  const SearchVoucherScreen({super.key});

  @override
  State<SearchVoucherScreen> createState() => _SearchVoucherScreenState();
}

class _SearchVoucherScreenState extends State<SearchVoucherScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch users to know roles for filtering
      context.read<UserProvider>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = context.watch<TransactionProvider>();

    final userProvider = context.watch<UserProvider>();
    final currentUser = context.read<AuthProvider>().user;

    // Build Email -> Role Map
    final Map<String, String> userRoles = {
      for (var u in userProvider.users) u.email.trim().toLowerCase(): u.role,
    };

    // 1. Get Base List based on Role
    List<TransactionModel> baseList = [];

    if (currentUser == null) {
      baseList = [];
    } else if (currentUser.isAdmin ||
        currentUser.isManagement ||
        currentUser.isViewer) {
      // Admin, Management, Viewer -> See ALL
      baseList = transactionProvider.transactions;
    } else {
      // Associate -> See entries created by ANY Associate
      baseList = transactionProvider.transactions.where((tx) {
        final creatorEmail = tx.createdBy.trim().toLowerCase();

        // 1. Own entries always visible
        if (creatorEmail == currentUser.email.trim().toLowerCase()) return true;

        // 2. Check if creator is also an Associate
        final creatorRole = userRoles[creatorEmail];
        if (creatorRole != null &&
            (creatorRole == 'Associate' ||
                creatorRole == 'Business Operations Associate')) {
          return true;
        }

        return false;
      }).toList();
    }

    // 2. Filter by Search Query
    final List<TransactionModel> filteredTransactions = _searchQuery.isEmpty
        ? []
        : baseList
            .where(
              (tx) =>
                  tx.voucherNo.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                  tx.mainNarration.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
            )
            .toList();

    Widget _highlightText(String text, TextStyle baseStyle) {
      if (_searchQuery.isEmpty) {
        return Text(text,
            style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
      }

      final String lowerText = text.toLowerCase();
      final String lowerQuery = _searchQuery.toLowerCase();
      final int startIndex = lowerText.indexOf(lowerQuery);

      if (startIndex == -1) {
        return Text(text,
            style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
      }

      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: baseStyle,
          children: [
            if (startIndex > 0) TextSpan(text: text.substring(0, startIndex)),
            TextSpan(
              text:
                  text.substring(startIndex, startIndex + _searchQuery.length),
              style: baseStyle.copyWith(
                backgroundColor: Colors.yellow.withValues(alpha: 0.5),
                color: Colors.black,
              ),
            ),
            if (startIndex + _searchQuery.length < text.length)
              TextSpan(text: text.substring(startIndex + _searchQuery.length)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Search Voucher',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by voucher no or comment...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _searchQuery.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter a voucher number or comment to search',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No vouchers found',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = filteredTransactions[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.receipt_rounded,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                              title: _highlightText(
                                tx.voucherNo,
                                GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  _highlightText(
                                    tx.mainNarration,
                                    GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${tx.currency} ${CurrencyFormatter.format(tx.totalDebit)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
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
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
