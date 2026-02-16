import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/sub_category_provider.dart';
import '../../models/account_model.dart';
import '../../models/user_model.dart';
import 'add_edit_account_dialog.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  String? _selectedGroupId; // Null = All
  String? _selectedOwnerEmail; // Null = All
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().fetchGroups();
      context.read<UserProvider>().fetchUsers();
      context.read<SubCategoryProvider>().fetchSubCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final accountProvider = context.watch<AccountProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final userProvider = context.watch<UserProvider>();

    if (user == null) return const SizedBox.shrink();

    final filteredAccounts = accountProvider.accounts.where((acc) {
      if (!_showArchived && !acc.active) return false;

      if (_selectedGroupId != null) {
        if (_selectedGroupId == 'UNGROUPED') {
          if (acc.groupIds.isNotEmpty) {
            final validGroupIds = groupProvider.groups.map((g) => g.id).toSet();
            if (acc.groupIds.any((id) => validGroupIds.contains(id))) {
              return false;
            }
          }
        } else {
          if (!acc.groupIds.contains(_selectedGroupId)) return false;
        }
      }

      if (_selectedOwnerEmail != null) {
        if (_selectedOwnerEmail == 'NO_OWNER') {
          final adminEmails = userProvider.users
              .where((u) => u.isAdmin)
              .map((u) => u.email)
              .toSet();
          if (acc.owners.any((owner) => !adminEmails.contains(owner))) {
            return false;
          }
        } else {
          if (!acc.owners.contains(_selectedOwnerEmail)) return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        if (!acc.name.toLowerCase().contains(_searchQuery) &&
            !acc.type.toLowerCase().contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Chart of Accounts',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () =>
                accountProvider.fetchAccounts(user, forceRefresh: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(groupProvider, userProvider, accountProvider),
          Expanded(
            child: accountProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredAccounts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filteredAccounts.length,
                    itemBuilder: (context, index) {
                      final account = filteredAccounts[index];
                      return _AccountCard(
                            account: account,
                            onEdit: () =>
                                _showAccountDialog(context, user, account),
                            groupNames: groupProvider.getGroupNames(
                              account.groupIds,
                            ),
                          )
                          .animate(delay: (index * 50).ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.1, end: 0);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountDialog(context, user, null),
        backgroundColor: const Color(0xFF1E88E5),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text(
          'Add Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ).animate().scale(delay: 400.ms),
    );
  }

  Widget _buildFilterSection(
    GroupProvider groupProvider,
    UserProvider userProvider,
    AccountProvider accountProvider,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or type...',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Row
          Row(
            children: [
              Expanded(
                child: _buildDropDownFilter(
                  value: _selectedGroupId,
                  hint: 'All Groups',
                  icon: LucideIcons.layers,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Groups'),
                    ),
                    const DropdownMenuItem(
                      value: 'UNGROUPED',
                      child: Text('Ungrouped'),
                    ),
                    ...groupProvider.groups.map(
                      (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedGroupId = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropDownFilter(
                  value: _selectedOwnerEmail,
                  hint: 'All Owners',
                  icon: LucideIcons.user,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Owners'),
                    ),
                    const DropdownMenuItem(
                      value: 'NO_OWNER',
                      child: Text('No Owner'),
                    ),
                    ...userProvider.users
                        .where((u) => !u.isAdmin)
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.email,
                            child: Text(u.name),
                          ),
                        ),
                  ],
                  onChanged: (val) => setState(() => _selectedOwnerEmail = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${accountProvider.accounts.where((a) => a.active || _showArchived).length} accounts',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              Row(
                children: [
                  Text(
                    'Archived',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: _showArchived,
                      onChanged: (val) => setState(() => _showArchived = val),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropDownFilter({
    required String? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<String?>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          icon: Icon(icon, size: 16, color: Colors.blueGrey),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.searchX, size: 48, color: Colors.blue[300]),
          ),
          const SizedBox(height: 24),
          Text(
            'No accounts found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search query',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  void _showAccountDialog(BuildContext context, User user, Account? account) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditAccountDialog(user: user, account: account),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback onEdit;
  final String groupNames;

  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.groupNames,
  });

  @override
  Widget build(BuildContext context) {
    final balance = account.totalDebit - account.totalCredit;
    final color = _getTypeColor(account.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TypeBadge(type: account.accountType, color: color),
                          if (account.subCategory != null &&
                              account.subCategory!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                account.subCategory!,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            onPressed: onEdit,
                            icon: const Icon(LucideIcons.edit3, size: 18),
                            color: Colors.grey[400],
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        account.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (groupNames.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          groupNames,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BALANCE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[400],
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                '${account.defaultCurrency ?? 'BDT'} ${NumberFormat("#,##0.000").format(balance.abs())}',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: balance >= 0
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getTypeIcon(account.type),
                              color: color,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'asset':
        return Colors.teal;
      case 'liability':
        return Colors.deepOrange;
      case 'income':
        return Colors.indigo;
      case 'expense':
        return Colors.pink;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'asset':
        return LucideIcons.wallet;
      case 'liability':
        return LucideIcons.creditCard;
      case 'income':
        return LucideIcons.trendingUp;
      case 'expense':
        return LucideIcons.trendingDown;
      default:
        return LucideIcons.box;
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final Color color;

  const _TypeBadge({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

extension on Account {
  String get accountType => type;
}
