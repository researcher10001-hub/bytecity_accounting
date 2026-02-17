import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../admin/users_screen.dart';
import '../admin/accounts_screen.dart';
import '../admin/account_groups_screen.dart';
import '../admin/audit_dashboard_screen.dart';
import '../admin/sub_category_management_screen.dart';
import '../admin/erp_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAccountsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Center(child: Text('Please login first'));
    }

    // Filter Owned Accounts
    final ownedAccounts = accountProvider.accounts.where((account) {
      return account.owners.any(
        (ownerEmail) => ownerEmail.toLowerCase() == user.email.toLowerCase(),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'My Profile & Settings',
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Section
            _buildProfileHeader(context, user),

            const SizedBox(height: 24),

            // Owned Accounts Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isAccountsExpanded = !_isAccountsExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                LucideIcons.wallet,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Owned Accounts',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '${ownedAccounts.length} accounts owned',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _isAccountsExpanded
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isAccountsExpanded
                        ? Column(
                            children: [
                              const Divider(height: 1),
                              if (ownedAccounts.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      Icon(
                                        LucideIcons.folder,
                                        size: 40,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'You do not own any accounts directly.',
                                        style: GoogleFonts.inter(
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: ownedAccounts.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final account = ownedAccounts[index];
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 4,
                                          ),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          LucideIcons.crown,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(
                                        account.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${account.type} • ${account.defaultCurrency ?? 'BDT'}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: 8),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            const SizedBox(height: 24),

            // Admin Section (Only if Admin)
            if (user.isAdmin) ...[
              _buildSectionHeader('Administration'),
              _buildSettingsTile(
                title: 'Manage Users',
                subtitle: 'Create users, assign roles & permissions',
                icon: LucideIcons.users,
                color: Colors.orange,
                onTap: () {
                  final dp = context.read<DashboardProvider>();
                  if (MediaQuery.of(context).size.width >= 800) {
                    dp.setView(DashboardView.manageUsers);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UsersScreen()),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                title: 'Chart of Accounts',
                subtitle: 'Manage account heads & defaults',
                icon: LucideIcons.wallet,
                color: Colors.purple,
                onTap: () {
                  final dp = context.read<DashboardProvider>();
                  if (MediaQuery.of(context).size.width >= 800) {
                    dp.setView(DashboardView.chartOfAccounts);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountsScreen()),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                title: 'Manage Groups',
                subtitle: 'Define and organize account groups',
                icon: LucideIcons.layers,
                color: Colors.pink,
                onTap: () {
                  final dp = context.read<DashboardProvider>();
                  if (MediaQuery.of(context).size.width >= 800) {
                    dp.setView(DashboardView.manageGroups);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountGroupsScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                title: 'Audit Dashboard',
                subtitle: 'Review flagged transactions for oversight',
                icon: Icons.flag_rounded,
                color: Colors.red.shade700,
                onTap: () {
                  final dp = context.read<DashboardProvider>();
                  if (MediaQuery.of(context).size.width >= 800) {
                    dp.setView(DashboardView.auditDashboard);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AuditDashboardScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                title: 'Account Sub-Categories',
                subtitle: 'Manage dynamic sub-categories for accounts',
                icon: LucideIcons.tag,
                color: Colors.indigo,
                onTap: () {
                  final dp = context.read<DashboardProvider>();
                  if (MediaQuery.of(context).size.width >= 800) {
                    dp.setView(DashboardView.subCategories);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubCategoryManagementScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                title: 'ERPNext Configuration',
                subtitle: 'Setup API credentials & instance URL',
                icon: LucideIcons.settings,
                color: Colors.blueGrey.shade800,
                onTap: () {
                  final dp = context.read<DashboardProvider>();
                  if (MediaQuery.of(context).size.width >= 800) {
                    dp.setView(DashboardView.erpSettings);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ERPSettingsScreen(),
                      ),
                    );
                  }
                },
              ),
            ],

            const SizedBox(height: 40),
            Center(
              child: Text(
                'BC Math v3.23',
                style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey[600],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue.withValues(alpha: 0.1),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(user.role, Colors.blue, LucideIcons.shield),
              _buildChip(
                user.status,
                user.isActive ? Colors.green : Colors.red,
                user.isActive ? LucideIcons.checkCircle : LucideIcons.xCircle,
              ),
              _buildChip(
                'Change Password',
                Colors.blueGrey,
                LucideIcons.lock,
                onTap: () => _showChangePasswordDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    String label,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        trailing: Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: Colors.grey[400],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Change Password',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: currentPassController,
                      label: 'Current Password',
                      icon: LucideIcons.lock,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: newPassController,
                      label: 'New Password',
                      icon: LucideIcons.key,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: confirmPassController,
                      label: 'Confirm Password',
                      icon: LucideIcons.checkCircle,
                      validator: (val) {
                        if (val != newPassController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isLoading = true);
                            FocusScope.of(context).unfocus();

                            final error =
                                await Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                ).changePassword(
                                  currentPassController.text,
                                  newPassController.text,
                                );

                            if (ctx.mounted) {
                              setState(() => isLoading = false);
                              if (error == null) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password changed successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Update',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 14),
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator:
          validator ??
          (val) {
            if (val == null || val.isEmpty) return 'Required';
            if (val.length < 6) return 'Min 6 characters';
            return null;
          },
    );
  }
}
