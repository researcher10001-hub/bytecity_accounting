import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'side_menu.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../models/transaction_model.dart';
import 'package:provider/provider.dart';

class DesktopScaffold extends StatelessWidget {
  final String role;
  final Function(int) onNavIndexChanged;
  final Widget body;

  const DesktopScaffold({
    super.key,
    required this.role,
    required this.onNavIndexChanged,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Left Sidebar
          SideMenu(role: role, onItemSelected: onNavIndexChanged),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Desktop Header
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (context.watch<DashboardProvider>().canPop) ...[
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                              ),
                              onPressed: () =>
                                  context.read<DashboardProvider>().popView(),
                              tooltip: 'Back',
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _getDynamicPageTitle(context, role),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildHeaderIcon(Icons.notifications_none_rounded),
                          const SizedBox(width: 24),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey[200],
                          ),
                          const SizedBox(width: 24),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                role,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'User Account',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => context
                                .read<DashboardProvider>()
                                .setView(DashboardView.profile),
                            borderRadius: BorderRadius.circular(20),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue[50],
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF1E88E5),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Body Content
                Expanded(
                  child: ClipRect(
                    child: Material(color: Colors.transparent, child: body),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.grey[600], size: 20),
    );
  }

  String _getDynamicPageTitle(BuildContext context, String role) {
    final dp = context.read<DashboardProvider>();
    switch (dp.currentView) {
      case DashboardView.home:
        return 'Dashboard Overview';
      case DashboardView.transactions:
        return 'Transaction History';
      case DashboardView.search:
        return 'Search Voucher';
      case DashboardView.settings:
        return 'System Settings';
      case DashboardView.ledger:
        return 'General Ledger';
      case DashboardView.pending:
        return 'Pending Approvals';
      case DashboardView.erpSync:
        return 'ERP Sync Queue';
      case DashboardView.ownedAccounts:
        return 'Account Balances';
      case DashboardView.transactionEntry:
        return 'New Transaction Entry';
      case DashboardView.manageUsers:
        return 'Manage User Profiles';
      case DashboardView.chartOfAccounts:
        return 'Chart of Accounts';
      case DashboardView.manageGroups:
        return 'Account Groups';
      case DashboardView.auditDashboard:
        return 'Audit & Oversight';
      case DashboardView.subCategories:
        return 'Sub-Category Management';
      case DashboardView.erpSettings:
        return 'ERP Configuration';
      case DashboardView.transactionDetail:
        final args = dp.currentArguments as Map<String, dynamic>?;
        final tx = args?['transaction'] as TransactionModel?;
        return 'Transaction ${tx?.voucherNo ?? ""}';
      case DashboardView.profile:
        return 'User Profile';
    }
  }
}
