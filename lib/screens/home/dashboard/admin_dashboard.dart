import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/welcome_header.dart';
import '../widgets/quick_action_card.dart';
import '../../admin/users_screen.dart';
import '../../admin/accounts_screen.dart';

class AdminDashboard extends StatelessWidget {
  final Function(int index) onNavigate;

  const AdminDashboard({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WelcomeHeader(),
          const SizedBox(height: 16),

          // Admin Action Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: QuickActionCard(
                    title: 'Users',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF009688), // Teal
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UsersScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QuickActionCard(
                    title: 'Accounts',
                    icon: Icons.account_balance,
                    color: const Color(0xFF3F51B5), // Indigo
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Ledger & Transactions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: QuickActionCard(
                    title: 'Ledger Book',
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFF673AB7), // Deep Purple
                    onTap: () {
                      // Reports is Index 2. Ledger is part of Reports?
                      // If we want to go to Reports tab: onNavigate(2)
                      onNavigate(2);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QuickActionCard(
                    title: 'All Transactions',
                    icon: Icons.receipt_long,
                    color: const Color(0xFF1E88E5), // Blue
                    onTap: () {
                      // Transactions is Index 1
                      onNavigate(1);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Groups Management
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: QuickActionCard(
                    title: 'Manage Groups',
                    icon: Icons.group_work_rounded,
                    color: const Color(0xFFE91E63), // Pink
                    onTap: () {
                      // Groups is Index 3
                      onNavigate(3);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Spacer(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Admin Summary Panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Admin Summary',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('5', 'Total Users'),
                      _buildDivider(),
                      _buildStatItem('11', 'Total Accts'),
                      _buildDivider(),
                      _buildStatItem('269', 'Total Vouchers', isHigh: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, {bool isHigh = false}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isHigh ? const Color(0xFF1E88E5) : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: Colors.grey[200]);
  }
}
