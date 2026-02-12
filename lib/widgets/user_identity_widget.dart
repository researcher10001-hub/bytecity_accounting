import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../core/constants/role_constants.dart';
import '../../providers/auth_provider.dart';
import '../main.dart';

/// Compact user identity widget for AppBar
/// Shows user initials with role badge, minimal space usage
class UserIdentityWidget extends StatelessWidget {
  final User user;
  final VoidCallback? onTap;

  const UserIdentityWidget({super.key, required this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => _showUserMenu(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User avatar with initials
            CircleAvatar(
              radius: 14,
              backgroundColor: _getRoleColor(user.role),
              child: Text(
                _getInitials(user.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // First Name
            Text(
              user.name.split(' ')[0],
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  /// Get user initials from name
  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';

    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      final part = parts[0];
      return part.isNotEmpty ? part.substring(0, 1).toUpperCase() : '?';
    }

    String firstInitial = parts[0].isNotEmpty ? parts[0].substring(0, 1) : '';
    String lastInitial = parts[parts.length - 1].isNotEmpty
        ? parts[parts.length - 1].substring(0, 1)
        : '';

    return (firstInitial + lastInitial).toUpperCase();
  }

  /// Get role color
  Color _getRoleColor(String role) {
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole == AppRoles.admin.toLowerCase()) {
      return const Color(0xFF9C27B0); // Purple
    } else if (normalizedRole == AppRoles.management.toLowerCase()) {
      return const Color(0xFF4CAF50); // Green
    } else if (normalizedRole ==
        AppRoles.businessOperationsAssociate.toLowerCase()) {
      return const Color(0xFF2196F3); // Blue
    } else {
      return const Color(0xFF757575); // Gray for Viewer
    }
  }

  /// Show user menu dropdown
  void _showUserMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        // User info header
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(user.role).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.role,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getRoleColor(user.role),
                  ),
                ),
              ),
              const Divider(height: 16),
            ],
          ),
        ),
        // Menu items
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 12),
              Text('Profile', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 12),
              Text('Settings', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleMenuAction(context, value);
      }
    });
  }

  /// Handle menu actions
  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'profile':
        // Navigate to profile screen (to be implemented)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile screen coming soon')),
        );
        break;
      case 'settings':
        // Navigate to settings screen
        Navigator.pushNamed(context, '/settings');
        break;
      case 'logout':
        // Show logout confirmation
        _showLogoutConfirmation(context);
        break;
    }
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: GoogleFonts.inter()),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Perform logout
              context.read<AuthProvider>().logout().then((_) {
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                    (route) => false,
                  );
                }
              });
            },
            child: Text('Logout', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
