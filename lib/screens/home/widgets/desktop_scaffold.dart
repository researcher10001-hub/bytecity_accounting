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
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getPageTitle(currentIndex, role),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: const Icon(Icons.person, color: Colors.grey),
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

  String _getPageTitle(int index, String role) {
    // Simple mapper for title based on index
    // Mirrors SideMenu logic
    if (index == 0) return 'Home';
    if (role == 'Admin') {
      if (index == 1) return 'Transactions';
      if (index == 2) return 'Reports';
    } else {
      if (index == 1) return 'History';
      if (index == 2) return 'Profile';
    }
    return 'Dashboard';
  }
}
