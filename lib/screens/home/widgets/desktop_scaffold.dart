import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'side_menu.dart';

class DesktopScaffold extends StatelessWidget {
  final String role;
  final int currentIndex;
  final Function(int) onNavIndexChanged;
  final Widget body;

  const DesktopScaffold({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onNavIndexChanged,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    // final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Left Sidebar
          SideMenu(
            role: role,
            currentIndex: currentIndex,
            onItemSelected: onNavIndexChanged,
          ),

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
                      Text(
                        _getPageTitle(currentIndex, role),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          _buildHeaderIcon(Icons.search_rounded),
                          const SizedBox(width: 16),
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
                                'User Account', // Update this if real name available
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blue[50],
                            child: const Icon(
                              Icons.person,
                              color: Color(0xFF1E88E5),
                              size: 20,
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
                    child: body, // Provide the dashboard body here
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

  String _getPageTitle(int index, String role) {
    // Simple mapper for title based on index
    // Mirrors SideMenu logic
    if (index == 0) return 'Dashboard Overview';
    final bool isAdmin = role.trim().toLowerCase() == 'admin';

    if (isAdmin) {
      if (index == 1) return 'Transactions History';
      if (index == 2) return 'Financial Reports';
      if (index == 3) return 'User Groups';
      if (index == 4) return 'System Settings';
    } else {
      if (index == 1) return 'Transaction History';
      if (index == 2) return 'Profile & Accounts';
      if (index == 3) return 'General Settings';
    }
    return 'Management Console';
  }
}
