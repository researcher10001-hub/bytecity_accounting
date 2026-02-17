import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../core/constants/role_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../services/permission_service.dart';
import '../../providers/dashboard_provider.dart';
import '../main.dart';
import '../screens/profile/profile_screen.dart';

/// Compact user identity widget for AppBar
/// Shows user initials with role badge, minimal space usage
class UserIdentityWidget extends StatelessWidget {
  final User user;
  final VoidCallback? onTap;

  const UserIdentityWidget({super.key, required this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => _showUserBottomSheet(context),
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
            // Name Display
            Text(
              (user.name.trim().isEmpty ? user.email.split('@')[0] : user.name)
                  .split(' ')[0],
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

  /// Get user initials from name or email
  String _getInitials(String name) {
    String displayName = name.trim();

    // Fallback to email if name is empty
    if (displayName.isEmpty) {
      displayName = user.email.split('@')[0];
    }

    if (displayName.isEmpty) return '?';

    final parts = displayName.split(' ');
    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      final part = parts[0];
      return part.isNotEmpty ? part.substring(0, 1).toUpperCase() : '?';
    }

    String firstInitial = parts[0].isNotEmpty ? parts[0].substring(0, 1) : '';
    String lastInitial = parts[parts.length - 1].isNotEmpty
        ? parts[parts.length - 1].substring(0, 1)
        : '';

    // If only one part has an initial, return just that (e.g. "A " -> "A")
    if (lastInitial.isEmpty) return firstInitial.toUpperCase();

    return (firstInitial + lastInitial).toUpperCase();
  }

  /// Get role color
  Color _getRoleColor(String role) {
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole == AppRoles.admin.toLowerCase()) {
      return const Color(0xFF9C27B0); // Purple
    } else if (normalizedRole == AppRoles.management.toLowerCase()) {
      return const Color(0xFF4CAF50); // Green
    } else if (normalizedRole == AppRoles.associate.toLowerCase() ||
        normalizedRole == 'business operations associate') {
      return const Color(0xFF2196F3); // Blue
    } else {
      return const Color(
        0xFF607D8B,
      ); // Blue Grey for Viewer (Distinct from disabled)
    }
  }

  /// Show modern user bottom sheet
  void _showUserBottomSheet(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();
    final ownedCount = accountProvider.accounts
        .where((a) => PermissionService().isOwner(user, a))
        .length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            // Header
            Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getRoleColor(user.role),
                    boxShadow: [
                      BoxShadow(
                        color: _getRoleColor(user.role).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getInitials(user.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ).animate().scale(curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF718096),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _getRoleColor(user.role),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Quick Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEDF2F7)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4299E1).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.briefcase,
                        size: 20,
                        color: Color(0xFF4299E1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accounts Owned',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF718096),
                            ),
                          ),
                          Text(
                            ownedCount.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 32),
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildMenuAction(
                    context,
                    label: 'View Profile',
                    icon: LucideIcons.user,
                    gradient: const [Color(0xFF4299E1), Color(0xFF3182CE)],
                    onTap: () {
                      Navigator.pop(context);
                      if (MediaQuery.of(context).size.width >= 800) {
                        context.read<DashboardProvider>().setView(
                          DashboardView.profile,
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuAction(
                    context,
                    label: 'Logout Account',
                    icon: LucideIcons.logOut,
                    gradient: const [Color(0xFFE53E3E), Color(0xFFC53030)],
                    onTap: () {
                      Navigator.pop(context);
                      _showLogoutConfirmation(context);
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuAction(
    BuildContext context, {
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const Icon(LucideIcons.chevronRight, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Logout',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
