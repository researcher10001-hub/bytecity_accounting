import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../providers/transaction_provider.dart';
import '../../../../core/constants/role_constants.dart';

class SideMenu extends StatelessWidget {
  final String role;
  final Function(int) onItemSelected;

  const SideMenu({super.key, required this.role, required this.onItemSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF1565C0), // Darker Blue for Sidebar
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: _buildMenuItems(context),
            ),
          ),
          _buildLogoutButton(context),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'BC',
              style: TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'BC\nMath',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final currentView = context.watch<DashboardProvider>().currentView;
    final List<Map<String, dynamic>> items = _getNavItemsForRole(role);

    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final view = item['view'] as DashboardView;
      final isSelected = currentView == view;

      return _SideMenuItem(
        icon: item['icon'] as IconData,
        label: item['label'] as String,
        isSelected: isSelected,
        onTap: () {
          final view = item['view'] as DashboardView;
          if (view == DashboardView.transactions) {
            context.read<TransactionProvider>().resetHistoryFilters();
          }
          context.read<DashboardProvider>().setView(view);
          onItemSelected(index);
        },
      );
    }).toList();
  }

  List<Map<String, dynamic>> _getNavItemsForRole(String role) {
    if (role == AppRoles.admin || role == 'Admin') {
      return [
        {
          'icon': Icons.grid_view_rounded,
          'label': 'Dashboard',
          'view': DashboardView.home,
        },
        {
          'icon': Icons.add_circle_outline_rounded,
          'label': 'New Entry',
          'view': DashboardView.transactionEntry,
        },
        {
          'icon': Icons.history_rounded,
          'label': 'History',
          'view': DashboardView.transactions,
        },
        {
          'icon': Icons.menu_book_rounded,
          'label': 'Ledger',
          'view': DashboardView.ledger,
        },
        {
          'icon': Icons.account_balance_wallet_rounded,
          'label': 'My Accounts',
          'view': DashboardView.ownedAccounts,
        },
        {
          'icon': Icons.search_rounded,
          'label': 'Search',
          'view': DashboardView.search,
        },
        {
          'icon': Icons.settings_rounded,
          'label': 'Settings',
          'view': DashboardView.settings,
        },
      ];
    } else if (role == AppRoles.management || role == 'Management') {
      return [
        {
          'icon': Icons.grid_view_rounded,
          'label': 'Dashboard',
          'view': DashboardView.home,
        },
        {
          'icon': Icons.add_circle_outline_rounded,
          'label': 'New Entry',
          'view': DashboardView.transactionEntry,
        },
        {
          'icon': Icons.history_rounded,
          'label': 'History',
          'view': DashboardView.transactions,
        },
        {
          'icon': Icons.menu_book_rounded,
          'label': 'Ledger',
          'view': DashboardView.ledger,
        },
        {
          'icon': Icons.account_balance_wallet_rounded,
          'label': 'My Accounts',
          'view': DashboardView.ownedAccounts,
        },
        {
          'icon': Icons.search_rounded,
          'label': 'Search Voucher',
          'view': DashboardView.search,
        }, // Placeholder
      ];
    } else {
      return [
        {
          'icon': Icons.grid_view_rounded,
          'label': 'Dashboard',
          'view': DashboardView.home,
        },
        {
          'icon': Icons.add_circle_outline_rounded,
          'label': 'New Entry',
          'view': DashboardView.transactionEntry,
        },
        {
          'icon': Icons.history_rounded,
          'label': 'History',
          'view': DashboardView.transactions,
        },
        {
          'icon': Icons.menu_book_rounded,
          'label': 'Ledger',
          'view': DashboardView.ledger,
        },
        {
          'icon': Icons.account_balance_wallet_rounded,
          'label': 'My Accounts',
          'view': DashboardView.ownedAccounts,
        },
        {
          'icon': Icons.search_rounded,
          'label': 'Search Voucher',
          'view': DashboardView.search,
        },
      ];
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.logout_rounded,
          color: Colors.white70,
          size: 22,
        ),
        title: Text(
          'Logout',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () {
          _showLogoutConfirmation(context);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout Confirmation',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A365D),
          ),
        ),
        content: Text(
          'Are you sure you want to log out from your account?',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        String versionText = 'v... | BC Math';
        if (snapshot.hasData) {
          versionText = 'v${snapshot.data!.version} | BC Math';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            versionText,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
          ),
        );
      },
    );
  }
}

class _SideMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SideMenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SideMenuItem> createState() => _SideMenuItemState();
}

class _SideMenuItemState extends State<_SideMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : _isHovered
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(
            widget.icon,
            color:
                widget.isSelected || _isHovered ? Colors.white : Colors.white70,
            size: 20,
          ),
          title: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: widget.isSelected || _isHovered
                  ? Colors.white
                  : Colors.white70,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          onTap: widget.onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
