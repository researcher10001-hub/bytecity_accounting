import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/user_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/account_model.dart';
import '../../core/constants/role_constants.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showDeleted = false;

  @override
  void initState() {
    super.initState();
    // ... existing initState ...
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final accountProvider = Provider.of<AccountProvider>(
        context,
        listen: false,
      );
      userProvider.fetchUsers().then((_) {
        // ... existing logic ...
        final admin = userProvider.users.firstWhere(
          (u) => u.isAdmin,
          orElse: () => User(name: '', email: '', role: '', status: 'Active'),
        );
        if (admin.email.isNotEmpty) {
          accountProvider.fetchAccounts(admin);
        }
      });
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  // ... dispose ...

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context);

    // Filter Users
    final filteredUsers = userProvider.users.where((u) {
      final matchesSearch =
          u.name.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery);

      final matchesStatus = _showDeleted ? true : !u.isDeleted;

      return matchesSearch && matchesStatus;
    }).toList();

    // Group Users
    final admins = filteredUsers.where((u) => u.isAdmin).toList();
    final management = filteredUsers.where((u) => u.isManagement).toList();
    final boas = filteredUsers
        .where((u) => u.isBusinessOperationsAssociate)
        .toList();
    final viewers = filteredUsers.where((u) => u.isViewer).toList(); // Viewers
    final others = filteredUsers
        .where(
          (u) =>
              !u.isAdmin &&
              !u.isManagement &&
              !u.isBusinessOperationsAssociate &&
              !u.isViewer,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Text(
                  'Show Deleted',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _showDeleted,
                    onChanged: (val) {
                      setState(() {
                        _showDeleted = val;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // ...
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Name or Email...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          Expanded(
            child: userProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (admins.isNotEmpty)
                        _buildSection(
                          'Administrators',
                          admins,
                          userProvider,
                          accountProvider,
                        ),
                      if (management.isNotEmpty)
                        _buildSection(
                          'Management',
                          management,
                          userProvider,
                          accountProvider,
                        ),
                      if (boas.isNotEmpty)
                        _buildSection(
                          'Business Operations Associates',
                          boas,
                          userProvider,
                          accountProvider,
                        ),
                      if (viewers.isNotEmpty)
                        _buildSection(
                          'Viewers',
                          viewers,
                          userProvider,
                          accountProvider,
                        ),
                      if (others.isNotEmpty)
                        _buildSection(
                          'Others',
                          others,
                          userProvider,
                          accountProvider,
                        ),

                      if (filteredUsers.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('No users found matching your search.'),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserDialog(context),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<User> users,
    UserProvider provider,
    AccountProvider accountProvider,
  ) {
    // Current user context - ideally get from AuthProvider

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[700],
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...users.map(
          (user) => _buildUserCardNew(context, provider, accountProvider, user),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /*
  Widget _buildUserCard(
    BuildContext context,
    UserProvider provider,
    AccountProvider accountProvider,
    User user,
  ) {
    final bool isDateUnlocked = user.canEditDate;

    String dateUnlockStatus;
    // Admins are always unlocked, check role carefully
    if (user.isAdmin) {
      dateUnlockStatus = 'Always Unlocked (Admin)';
    } else if (isDateUnlocked && user.dateEditPermissionExpiresAt != null) {
      dateUnlockStatus =
          'Unlocked until ${DateFormat('MMM d, h:mm a').format(user.dateEditPermissionExpiresAt!)}';
    } else {
      dateUnlockStatus = 'Date Locked';
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(
                    user.role,
                  ).withValues(alpha: 0.1),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(user.role),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge (Locked/Unlocked) - Only for Non-Admins
                if (!user.isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDateUnlocked
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDateUnlocked
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDateUnlocked ? Icons.lock_open : Icons.lock,
                          size: 12,
                          color: isDateUnlocked
                              ? Colors.green[700]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isDateUnlocked ? 'UNLOCKED' : 'LOCKED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDateUnlocked
                                ? Colors.green[700]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                // View Details Button
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: TextButton.icon(
                    onPressed: () => _showUserDetailsDialog(context, user),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      backgroundColor: Colors.indigo.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Interaction Area - Only if NOT Admin
            if (!user.isAdmin) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),

              // Group Management Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _showGroupDialog(context, user),
                  icon: const Icon(Icons.group_work, size: 16),
                  label: Text('Manage Groups (${user.groupIds.length})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: BorderSide(color: Colors.indigo.shade200),
                  ),
                ),
              ),

              // Ownership Management Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _showOwnershipDialog(context, user),
                  icon: const Icon(Icons.account_balance, size: 16),
                  label: Text(
                    'Manage Ownership (${accountProvider.accounts.where((a) => a.owners.contains(user.email)).length})',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: BorderSide(color: Colors.purple.shade200),
                  ),
                ),
              ),

              // User Status Management
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'User Status',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (_loadingOperations.contains('status_${user.email}'))
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: user.isActive
                            ? Colors.green.shade50
                            : (user.isSuspended
                                  ? Colors.orange.shade50
                                  : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: user.isActive
                              ? Colors.green.shade200
                              : (user.isSuspended
                                    ? Colors.orange.shade200
                                    : Colors.red.shade200),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: user.status,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: user.isActive
                                ? Colors.green.shade700
                                : (user.isSuspended
                                      ? Colors.orange.shade800
                                      : Colors.red.shade700),
                          ),
                          onChanged: (String? val) {
                            if (val != null && val != user.status) {
                              _handleSwitchChange(
                                'status_${user.email}',
                                () async {
                                  await provider.updateUserStatus(
                                    user.email,
                                    val,
                                  );
                                },
                              );
                            }
                          },
                          items: ['Active', 'Suspended', 'Deleted'].map((
                            String status,
                          ) {
                            Color color;
                            if (status == 'Active') {
                              color = Colors.green;
                            } else if (status == 'Suspended')
                              color = Colors.orange;
                            else
                              color = Colors.red;

                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(
                                status,
                                style: TextStyle(color: color),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Foreign Currency Access',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  // Check loading for Currency Access
                  if (_loadingOperations.contains('currency_${user.email}'))
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: user.allowForeignCurrency,
                        onChanged: (val) {
                          _handleSwitchChange(
                            'currency_${user.email}',
                            () async {
                              await provider.toggleCurrencyPermission(
                                user.email,
                                val,
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),

              // Date Permission Button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateUnlockStatus,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDateUnlocked
                                ? Colors.green[700]
                                : Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        provider.grantDatePermission(user.email);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${user.name} access unlocked for 24h.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.timer_outlined, size: 14),
                      label: const Text(
                        'Unlock 24h',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        side: BorderSide(color: Colors.blue.shade200),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _confirmForceLogout(context, provider, user),
                      icon: const Icon(Icons.logout, size: 14),
                      label: const Text(
                        'Force Logout',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[800],
                        side: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Center(
                  child: Text(
                    'Administrator Privileges (Full Access)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  */

  Color _getRoleColor(String role) {
    if (role.toLowerCase() == AppRoles.admin.toLowerCase()) {
      return Colors.orange;
    } else if (role.toLowerCase() == AppRoles.management.toLowerCase()) {
      return Colors.green;
    } else if (role.toLowerCase() ==
        AppRoles.businessOperationsAssociate.toLowerCase()) {
      return Colors.teal;
    } else if (role.toLowerCase() == AppRoles.viewer.toLowerCase()) {
      return Colors.blue;
    }
    return Colors.grey;
  }

  void _showGroupDialog(BuildContext context, User user) {
    // Ensure groups are loaded
    context.read<GroupProvider>().fetchGroups();

    List<String> selectedGroups = List.from(user.groupIds);

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        final scrollController = ScrollController();
        final searchController = TextEditingController();
        String searchQuery = "";

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Assign Groups to ${user.name}'),
            content: Container(
              width: double.maxFinite,
              height: 400, // Increased height for search bar
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Consumer<GroupProvider>(
                builder: (context, groupProvider, child) {
                  if (groupProvider.isLoading && groupProvider.groups.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allGroups = groupProvider.groups;
                  if (allGroups.isEmpty) {
                    return const Center(child: Text("No groups found."));
                  }

                  // Filter logic
                  final groups = allGroups.where((g) {
                    return g.name.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    );
                  }).toList();

                  // Get assigned group names for display
                  final assignedGroupNames = allGroups
                      .where((g) => selectedGroups.contains(g.id))
                      .map((g) => g.name)
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Currently Assigned Header
                      if (assignedGroupNames.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Text(
                            'Assigned (${assignedGroupNames.length}):',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: assignedGroupNames
                                .map(
                                  (name) => Chip(
                                    label: Text(name),
                                    labelStyle: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    backgroundColor: Colors.indigo.shade50,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const Divider(height: 16),
                      ],

                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search groups to assign...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              searchQuery = val;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: groups.isEmpty
                            ? const Center(child: Text("No matching groups"))
                            : Scrollbar(
                                thumbVisibility: true,
                                controller: scrollController,
                                child: ListView.builder(
                                  controller: scrollController,
                                  shrinkWrap: true,
                                  itemCount: groups.length,
                                  itemBuilder: (context, index) {
                                    final g = groups[index];
                                    final isSelected = selectedGroups.contains(
                                      g.id,
                                    );

                                    return CheckboxListTile(
                                      title: Text(g.name),
                                      subtitle: Text(g.description),
                                      value: isSelected,
                                      onChanged: isSaving
                                          ? null
                                          : (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  selectedGroups.add(g.id);
                                                } else {
                                                  selectedGroups.remove(g.id);
                                                }
                                              });
                                            },
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),

            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() {
                          isSaving = true;
                        });

                        final provider = context.read<UserProvider>();

                        // Create updated user object
                        final updatedUser = User(
                          email: user.email,
                          name: user.name,
                          role: user.role,
                          status: user.status,
                          allowForeignCurrency: user.allowForeignCurrency,
                          dateEditPermissionExpiresAt:
                              user.dateEditPermissionExpiresAt,
                          groupIds: selectedGroups,
                        );

                        final success = await provider.updateUser(updatedUser);

                        if (context.mounted) {
                          if (success) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Groups updated')),
                            );
                          } else {
                            setState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Update failed')),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOwnershipDialog(BuildContext context, User user) {
    final accountProvider = context.read<AccountProvider>();
    // Fetch accounts to ensure fresh data
    accountProvider.fetchAccounts(user, forceRefresh: true);

    showDialog(
      context: context,
      builder: (ctx) {
        // Track changes locally: Account -> isOwned
        final Map<String, bool> ownershipChanges = {};
        bool isSaving = false;
        final scrollController = ScrollController();
        final searchController = TextEditingController();
        String searchQuery = "";

        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.wallet,
                            color: Colors.purple.shade400,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Ownership',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Text(
                                'Assign accounts to ${user.name}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            LucideIcons.x,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Expanded(
                    child: Consumer<AccountProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading && provider.accounts.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final allAccounts = provider.accounts;
                        if (allAccounts.isEmpty) {
                          return const Center(
                            child: Text("No accounts found."),
                          );
                        }

                        // Filter logic
                        final accounts = allAccounts.where((a) {
                          return a.name.toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          );
                        }).toList();
                        accounts.sort(
                          (a, b) => a.name.toLowerCase().compareTo(
                            b.name.toLowerCase(),
                          ),
                        );

                        // Get assigned accounts for display
                        final ownedAccountNames = allAccounts
                            .where((a) {
                              final isOriginallyOwned = a.owners.contains(
                                user.email,
                              );
                              final isOwned =
                                  ownershipChanges[a.name] ?? isOriginallyOwned;
                              return isOwned;
                            })
                            .map((a) => a.name)
                            .toList();
                        ownedAccountNames.sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );

                        return Column(
                          children: [
                            // 1. Owned Accounts Summary Section
                            if (ownedAccountNames.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                color: Colors.purple.withOpacity(0.02),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Owned Accounts',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade100,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '${ownedAccountNames.length}',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                              color: Colors.purple.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 120,
                                      ),
                                      child: SingleChildScrollView(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: ownedAccountNames
                                              .map(
                                                (name) => GestureDetector(
                                                  onTap: isSaving
                                                      ? null
                                                      : () {
                                                          setState(() {
                                                            ownershipChanges[name] =
                                                                false;
                                                          });
                                                        },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .purple
                                                            .shade100,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.purple
                                                              .withOpacity(
                                                                0.05,
                                                              ),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          name,
                                                          style:
                                                              GoogleFonts.inter(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: Colors
                                                                    .purple
                                                                    .shade800,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Icon(
                                                          LucideIcons.x,
                                                          size: 10,
                                                          color: Colors
                                                              .purple
                                                              .shade300,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // 2. Search Bar
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: TextField(
                                  controller: searchController,
                                  style: GoogleFonts.inter(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Search accounts by name...',
                                    hintStyle: GoogleFonts.inter(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      LucideIcons.search,
                                      size: 18,
                                      color: Colors.grey.shade400,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      searchQuery = val;
                                    });
                                  },
                                ),
                              ),
                            ),

                            // 3. Selection List
                            Expanded(
                              child: accounts.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            LucideIcons.searchX,
                                            size: 40,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            "No matching accounts",
                                            style: GoogleFonts.inter(
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      controller: scrollController,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      itemCount: accounts.length,
                                      separatorBuilder: (ctx, i) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final account = accounts[index];
                                        final isOriginallyOwned = account.owners
                                            .contains(user.email);
                                        final isOwned =
                                            ownershipChanges[account.name] ??
                                            isOriginallyOwned;

                                        return InkWell(
                                          onTap: isSaving
                                              ? null
                                              : () {
                                                  setState(() {
                                                    ownershipChanges[account
                                                            .name] =
                                                        !isOwned;
                                                  });
                                                },
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: AnimatedContainer(
                                            duration: 200.ms,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isOwned
                                                  ? Colors.indigo.shade50
                                                        .withOpacity(0.5)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isOwned
                                                    ? Colors.indigo.shade200
                                                    : Colors.grey.shade100,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        account.name,
                                                        style: GoogleFonts.inter(
                                                          fontWeight: isOwned
                                                              ? FontWeight.w600
                                                              : FontWeight
                                                                    .normal,
                                                          fontSize: 14,
                                                          color: isOwned
                                                              ? Colors
                                                                    .indigo
                                                                    .shade900
                                                              : Colors
                                                                    .grey
                                                                    .shade800,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${account.type} • ${account.owners.length} Current Owners',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11,
                                                          color: isOwned
                                                              ? Colors
                                                                    .indigo
                                                                    .shade400
                                                              : Colors
                                                                    .grey
                                                                    .shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                AnimatedContainer(
                                                  duration: 200.ms,
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: isOwned
                                                        ? Colors.indigo
                                                        : Colors.transparent,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isOwned
                                                          ? Colors.indigo
                                                          : Colors
                                                                .grey
                                                                .shade300,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: isOwned
                                                      ? const Icon(
                                                          Icons.check,
                                                          size: 14,
                                                          color: Colors.white,
                                                        )
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setState(() => isSaving = true);
                                    // ... existing save logic ...
                                    int successCount = 0;
                                    int failCount = 0;

                                    if (!context.mounted) return;
                                    final authUser = Provider.of<AuthProvider>(
                                      context,
                                      listen: false,
                                    ).user;

                                    if (authUser == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Error: Not authorized",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      setState(() => isSaving = false);
                                      return;
                                    }

                                    final allAccounts =
                                        accountProvider.accounts;
                                    for (var entry
                                        in ownershipChanges.entries) {
                                      final accName = entry.key;
                                      final shouldOwn = entry.value;

                                      final account = allAccounts.firstWhere(
                                        (a) => a.name == accName,
                                        orElse: () => Account(
                                          name: '',
                                          owners: [],
                                          groupIds: [],
                                          type: 'General',
                                        ),
                                      );
                                      if (account.name.isEmpty) continue;

                                      final currentlyOwns = account.owners
                                          .contains(user.email);

                                      if (shouldOwn != currentlyOwns) {
                                        final newOwners = List<String>.from(
                                          account.owners,
                                        );
                                        if (shouldOwn) {
                                          newOwners.add(user.email);
                                        } else {
                                          newOwners.remove(user.email);
                                        }

                                        try {
                                          final success = await accountProvider
                                              .updateAccount(
                                                authUser,
                                                account,
                                                account.name,
                                                account.type,
                                                account.groupIds,
                                                newOwners,
                                                account.defaultCurrency ??
                                                    'BDT',
                                                account.subCategory,
                                              );
                                          if (success) {
                                            successCount++;
                                          } else {
                                            failCount++;
                                          }
                                        } catch (e) {
                                          failCount++;
                                        }
                                      }
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      if (successCount > 0 || failCount > 0) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Updated: $successCount, Failed: $failCount',
                                            ),
                                            backgroundColor: failCount == 0
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String selectedRole = AppRoles.viewer;
    final roles = [
      AppRoles.admin,
      AppRoles.management,
      AppRoles.businessOperationsAssociate,
      AppRoles.viewer,
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add New User'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    items: roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) => setState(() => selectedRole = val!),
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isCreating
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final email = emailController.text.trim();
                        final pass = passwordController.text.trim();
                        final confirmPass = confirmPasswordController.text
                            .trim();

                        if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fill all fields'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (pass != confirmPass) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passwords do not match'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() => isCreating = true);

                        final success = await context
                            .read<UserProvider>()
                            .addUser(name, email, pass, selectedRole);

                        if (context.mounted) {
                          if (success) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User created successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            setState(() => isCreating = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.read<UserProvider>().error ??
                                      'Failed',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create User'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmForceLogout(
    BuildContext context,
    UserProvider provider,
    User user,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force Logout'),
        content: Text(
          'Are you sure you want to force logout "${user.name}"? They will be signed out from all devices, but can log in again with their password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.forceLogout(user.email);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'User logged out successfully'
                          : 'Failed to logout user',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Force Logout',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCardNew(
    BuildContext context,
    UserProvider provider,
    AccountProvider accountProvider,
    User user,
  ) {
    final bool isAdmin = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).isAdmin;

    return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.role).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(user.role),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Name & Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.mail,
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.email,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Badges
                          Row(
                            children: [
                              _buildStatusBadge(user),
                              const SizedBox(width: 8),
                              _buildRoleBadge(user.role),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Admin Actions
                    if (isAdmin)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Reset Password
                            IconButton(
                              icon: const Icon(LucideIcons.key, size: 18),
                              color: Colors.orange,
                              tooltip: 'Reset Password',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                              onPressed: () =>
                                  _showResetPasswordDialog(context, user),
                            ),
                            // Force Logout
                            IconButton(
                              icon: const Icon(LucideIcons.logOut, size: 18),
                              color: Colors.red,
                              tooltip: 'Force Logout',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                              onPressed: () =>
                                  _confirmForceLogout(context, provider, user),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),

                // Manage Buttons (Groups & Ownership)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showGroupDialog(context, user),
                        icon: const Icon(LucideIcons.users, size: 16),
                        label: Text(
                          'Groups (${user.groupIds.length})',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo,
                          side: BorderSide(color: Colors.indigo.shade100),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.indigo.withValues(
                            alpha: 0.02,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showOwnershipDialog(context, user),
                        icon: const Icon(LucideIcons.wallet, size: 16),
                        label: Text(
                          'Ownership (${accountProvider.accounts.where((a) => a.owners.contains(user.email)).length})',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple,
                          side: BorderSide(color: Colors.purple.shade100),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.purple.withValues(
                            alpha: 0.02,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (!user.isAdmin) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _confirmDeleteUser(context, provider, user),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: const Text('Delete User'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade100),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.red.withValues(alpha: 0.02),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Settings Panel (Foreign Currency & Lock) - Show for all, restricted inside
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.shade50),
                  ),
                  child: Column(
                    children: [
                      // Row 1: Foreign Currency
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.globe,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Foreign Currency Access',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 24,
                            child: Switch(
                              value: user.allowForeignCurrency,
                              onChanged: user.isAdmin
                                  ? null
                                  : (val) => provider.toggleCurrencyPermission(
                                      user.email,
                                      val,
                                    ),
                              activeThumbColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      // Row 2: Date Lock
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      (user.canEditDate
                                              ? Colors.green
                                              : Colors.grey)
                                          .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  user.canEditDate
                                      ? LucideIcons.unlock
                                      : LucideIcons.lock,
                                  size: 14,
                                  color: user.canEditDate
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date Entry',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    user.isAdmin
                                        ? 'Always Unlocked'
                                        : (user.canEditDate
                                              ? 'Unlocked (24h)'
                                              : 'Locked to Today'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: user.canEditDate
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!user.isAdmin && !user.canEditDate)
                            TextButton(
                              onPressed: () =>
                                  provider.grantDatePermission(user.email),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.orange.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: Colors.deepOrange,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Unlock 24h',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildStatusBadge(User user) {
    Color color;
    IconData icon;
    String text = user.status;

    if (user.isActive) {
      color = Colors.green;
      icon = LucideIcons.checkCircle;
    } else if (user.isSuspended) {
      color = Colors.orange;
      icon = LucideIcons.alertCircle;
    } else {
      color = Colors.red;
      icon = LucideIcons.xCircle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final color = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, User user) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter new password for ${user.name}:'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.trim().isEmpty) return;

              // Implement change password logic here.
              // We will mock this for now
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Password reset triggered (Mock)"),
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(
    BuildContext context,
    UserProvider provider,
    User user,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to PERMANENTLY delete "${user.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.deleteUser(user.email);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'User deleted successfully'
                          : 'Failed to delete user',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
