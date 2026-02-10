import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/account_model.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/welcome_header.dart';
import '../widgets/quick_action_card.dart';

class ViewerDashboard extends StatelessWidget {
  const ViewerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final accountProvider = context.watch<AccountProvider>();
    final myAccounts = (user == null)
        ? <Account>[]
        : accountProvider.accounts.where((a) => a.canView(user)).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WelcomeHeader(),
          const SizedBox(height: 16),

          // Quick Actions (Read Only)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                QuickActionCard(
                  title: 'My Accounts',
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF1E88E5), // Blue
                  isFullWidth: true,
                  onTap: () {
                    // Navigate to Account List or expand below
                  },
                ),
                const SizedBox(height: 12),
                QuickActionCard(
                  title: 'Transactions',
                  icon: Icons.list_alt,
                  color: const Color(0xFF5E35B1), // Deep Purple
                  isFullWidth: true,
                  onTap: () {
                    // Navigate to Transaction History
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // My Accounts List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Accounts',
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
            _buildEmptyState()
          else
            _buildAccountList(myAccounts, user?.email ?? ''),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No accounts assigned yet.',
            style: GoogleFonts.inter(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Contact admin for access.',
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList(List<dynamic> accounts, String userEmail) {
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 20,
                  color: Colors.blue.shade700,
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
                      account.type,
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
