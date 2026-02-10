import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../transaction/transaction_entry_screen.dart';
import '../widgets/welcome_header.dart';
import '../widgets/quick_action_card.dart';
import '../../../providers/account_provider.dart';
import '../../reports/ledger_screen.dart';
import '../../reports/transaction_history_screen.dart';
import '../../transaction/search_voucher_screen.dart';
import '../../../services/permission_service.dart';

import '../../../providers/auth_provider.dart';

class AccountantDashboard extends StatelessWidget {
  const AccountantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final accountProvider = context.watch<AccountProvider>();

    if (user == null) return const SizedBox();

    // Filter accounts where user has access
    final myAccounts = accountProvider.accounts.where((account) {
      return PermissionService().canViewAccount(user, account);
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WelcomeHeader(),
          const SizedBox(height: 16),

          // Quick Actions Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: QuickActionCard(
                    title: 'New Transaction',
                    icon: Icons.add,
                    isPrimary: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TransactionEntryScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QuickActionCard(
                    title: 'Transaction History',
                    icon: Icons.history,
                    color: const Color(0xFF455A64), // Blue Grey
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TransactionHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: QuickActionCard(
                    title: 'Ledger',
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFF0288D1), // Light Blue
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LedgerScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QuickActionCard(
                    title: 'Search Voucher',
                    icon: Icons.search,
                    color: const Color(0xFF7B1FA2), // Purple
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchVoucherScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // My Assigned Accounts Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Accounts',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (myAccounts.isNotEmpty)
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E88E5),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (accountProvider.isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (myAccounts.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No accounts assigned yet.',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            )
          else
            _buildAccountList(myAccounts),

          const SizedBox(height: 80), // Space for Bottom Nav
        ],
      ),
    );
  }

  Widget _buildAccountList(List<dynamic> accounts) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: accounts.length > 5 ? 5 : accounts.length, // Limit to 5
      itemBuilder: (context, index) {
        final account = accounts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: account.type == 'Asset'
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  account.type == 'Asset'
                      ? Icons.account_balance_wallet
                      : Icons.analytics,
                  size: 20,
                  color: account.type == 'Asset'
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Type: ${account.type}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        );
      },
    );
  }
}
