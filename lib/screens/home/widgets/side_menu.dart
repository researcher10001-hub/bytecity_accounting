import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/constants/role_constants.dart';

class SideMenu extends StatelessWidget {
  final String role;
  final int currentIndex;
  final Function(int) onItemSelected;

  const SideMenu({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onItemSelected,
  });

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
              children: _buildMenuItems(),
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
      padding: const EdgeInsets.all(24),
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
              'ByteCityBD\nAccounting',
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

  List<Widget> _buildMenuItems() {
    final List<Map<String, dynamic>> items = _getNavItemsForRole(role);

    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isSelected = index == currentIndex;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            item['icon'] as IconData,
            color: Colors.white,
            size: 22,
          ),
          title: Text(
            item['label'] as String,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          onTap: () => onItemSelected(index),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _getNavItemsForRole(String role) {
    // Mapping matches HomeScreen _buildBottomNav indexing logic generally
    // But we can add more items here if we implement them.
    // For now, let's keep it strictly mapped to what HomeScreen expects to avoid IndexOutOfBounds.
    // HomeScreen expects:
    // Admin: 0:Home, 1:Trans, 2:Reports
    // Others: 0:Home, 1:History, 2:Profile

    // However, Reference Image shows more.
    // We will stick to the functional ones for now to prevent breaking the build with unimplemented screens.

    if (role == AppRoles.admin || role == 'Admin') {
      return [
        {'icon': Icons.home_rounded, 'label': 'Home'},
        {'icon': Icons.swap_horiz_rounded, 'label': 'Transactions'},
        {'icon': Icons.analytics_rounded, 'label': 'Reports'},
        {'icon': Icons.group_work_rounded, 'label': 'Groups'},
        {'icon': Icons.settings_rounded, 'label': 'Settings'},
      ];
    } else if (role == AppRoles.management || role == 'Management') {
      return [
        {'icon': Icons.home_rounded, 'label': 'Home'},
        {'icon': Icons.history_rounded, 'label': 'History'},
        {'icon': Icons.analytics_rounded, 'label': 'Reports'},
        {'icon': Icons.settings_rounded, 'label': 'Settings'},
      ];
    } else {
      // BOA / Viewer
      return [
        {'icon': Icons.home_rounded, 'label': 'Home'},
        {'icon': Icons.history_rounded, 'label': 'History'},
        {'icon': Icons.settings_rounded, 'label': 'Settings'},
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
          Provider.of<AuthProvider>(context, listen: false).logout();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Text(
        'v1.0.0 | ByteCityBD',
        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
