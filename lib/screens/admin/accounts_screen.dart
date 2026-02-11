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
    final isEditing = account != null;
    final nameController = TextEditingController(text: account?.name ?? '');
    String selectedType = account?.type ?? 'Asset';
    String selectedCurrency = account?.defaultCurrency ?? 'BDT';
    final types = ['Asset', 'Liability', 'Income', 'Expense', 'Equity'];
    final currencies = ['BDT', 'USD', 'RM', 'AED'];
    final Set<String> selectedGroups = account != null
        ? account.groupIds.toSet()
        : {};
    final Set<String> selectedOwners = account != null
        ? account.owners.toSet()
        : {};
    final subCategoryProvider = Provider.of<SubCategoryProvider>(
      context,
      listen: false,
    );
    final Map<String, List<String>> subCategories =
        subCategoryProvider.subCategoriesByType;

    String selectedSubCategory = account?.subCategory ?? '';

    // Auto-initialize for new account or if old value missing from presets
    if (selectedSubCategory.isEmpty &&
        (subCategories[selectedType]?.isNotEmpty ?? false)) {
      selectedSubCategory = subCategories[selectedType]!.first;
    }

    // If subcategory not in list (e.g. from old data), clear or set default
    if (selectedSubCategory.isNotEmpty &&
        !(subCategories[selectedType]?.contains(selectedSubCategory) ??
            false)) {
      // Keep it if it exists but just not in the preset list?
      // For now, let's keep it to avoid data loss, but suggest preset.
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child:
              Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1E88E5,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isEditing
                                        ? LucideIcons.edit3
                                        : LucideIcons.plus,
                                    color: const Color(0xFF1E88E5),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEditing
                                            ? 'Edit Account'
                                            : 'New Account',
                                        style: GoogleFonts.inter(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        isEditing
                                            ? 'Updating ${account.name}'
                                            : 'Create a new financial record',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: const Icon(LucideIcons.x, size: 20),
                                  color: const Color(0xFF94A3B8),
                                  style: IconButton.styleFrom(
                                    hoverColor: Colors.grey[100],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Content
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Account Name
                                  _buildModernLabel('Account Name'),
                                  TextField(
                                    controller: nameController,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: _modernInputDecoration(
                                      'e.g. Cash in Hand',
                                      LucideIcons.type,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Type and Sub-Category Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildModernLabel('Type'),
                                            DropdownButtonFormField<String>(
                                              initialValue:
                                                  types.contains(selectedType)
                                                  ? selectedType
                                                  : 'Asset',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF1E293B),
                                              ),
                                              decoration:
                                                  _modernInputDecoration(
                                                    null,
                                                    LucideIcons.layers,
                                                  ),
                                              isExpanded: true,
                                              items: types
                                                  .map(
                                                    (t) => DropdownMenuItem(
                                                      value: t,
                                                      child: Text(t),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (val) => setState(() {
                                                selectedType = val!;
                                                selectedSubCategory =
                                                    subCategories[val]!.first;
                                              }),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildModernLabel('Sub-Category'),
                                            DropdownButtonFormField<String>(
                                              initialValue:
                                                  (subCategories[selectedType]
                                                          ?.contains(
                                                            selectedSubCategory,
                                                          ) ??
                                                      false)
                                                  ? selectedSubCategory
                                                  : (subCategories[selectedType]
                                                            ?.first ??
                                                        ''),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF1E293B),
                                              ),
                                              decoration:
                                                  _modernInputDecoration(
                                                    null,
                                                    LucideIcons.tag,
                                                  ),
                                              isExpanded: true,
                                              items:
                                                  (subCategories[selectedType] ??
                                                          [])
                                                      .map(
                                                        (s) => DropdownMenuItem(
                                                          value: s,
                                                          child: Text(
                                                            s,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                              onChanged: (val) => setState(
                                                () =>
                                                    selectedSubCategory = val!,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Currency Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildModernLabel('Currency'),
                                            DropdownButtonFormField<String>(
                                              initialValue:
                                                  currencies.contains(
                                                    selectedCurrency,
                                                  )
                                                  ? selectedCurrency
                                                  : 'BDT',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF1E293B),
                                              ),
                                              decoration:
                                                  _modernInputDecoration(
                                                    null,
                                                    LucideIcons.banknote,
                                                  ),
                                              items: currencies
                                                  .map(
                                                    (c) => DropdownMenuItem(
                                                      value: c,
                                                      child: Text(c),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (val) => setState(
                                                () => selectedCurrency = val!,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Access Groups
                                  _buildModernLabel('Access Groups'),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Consumer<GroupProvider>(
                                      builder: (context, groupProvider, child) {
                                        if (groupProvider.groups.isEmpty) {
                                          return Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Center(
                                              child: Text(
                                                "No groups defined.",
                                                style: GoogleFonts.inter(
                                                  color: const Color(
                                                    0xFF94A3B8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return ListView.separated(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount:
                                              groupProvider.groups.length,
                                          separatorBuilder: (context, index) =>
                                              const Divider(
                                                height: 1,
                                                color: Color(0xFFF1F5F9),
                                              ),
                                          itemBuilder: (context, index) {
                                            final g =
                                                groupProvider.groups[index];
                                            final isSelected = selectedGroups
                                                .contains(g.id);
                                            return InkWell(
                                              onTap: () => setState(
                                                () => isSelected
                                                    ? selectedGroups.remove(
                                                        g.id,
                                                      )
                                                    : selectedGroups.add(g.id),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 20,
                                                      height: 20,
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF1E88E5,
                                                              )
                                                            : Colors
                                                                  .transparent,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? const Color(
                                                                  0xFF1E88E5,
                                                                )
                                                              : const Color(
                                                                  0xFFCBD5E1,
                                                                ),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: isSelected
                                                          ? const Icon(
                                                              Icons.check,
                                                              size: 14,
                                                              color:
                                                                  Colors.white,
                                                            )
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      g.name,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight: isSelected
                                                            ? FontWeight.w600
                                                            : FontWeight.w400,
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF1E293B,
                                                              )
                                                            : const Color(
                                                                0xFF475569,
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Assign Owners
                                  if (user.isAdmin) ...[
                                    _buildModernLabel('Assign Owners'),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Consumer<UserProvider>(
                                        builder: (context, userProvider, child) {
                                          return Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: userProvider.users.map((
                                              u,
                                            ) {
                                              final isSelected = selectedOwners
                                                  .contains(u.email);
                                              return AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                child: FilterChip(
                                                  label: Text(u.name),
                                                  selected: isSelected,
                                                  onSelected: (val) => setState(
                                                    () => val
                                                        ? selectedOwners.add(
                                                            u.email,
                                                          )
                                                        : selectedOwners.remove(
                                                            u.email,
                                                          ),
                                                  ),
                                                  selectedColor: const Color(
                                                    0xFF1E88E5,
                                                  ).withValues(alpha: 0.15),
                                                  checkmarkColor: const Color(
                                                    0xFF1E88E5,
                                                  ),
                                                  labelStyle: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF1E88E5,
                                                          )
                                                        : const Color(
                                                            0xFF64748B,
                                                          ),
                                                  ),
                                                  backgroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 2,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    side: BorderSide(
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF1E88E5,
                                                            )
                                                          : const Color(
                                                              0xFFE2E8F0,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Actions
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isEditing)
                                  IconButton(
                                    onPressed: () => _confirmDelete(
                                      ctx,
                                      context,
                                      user,
                                      account,
                                    ),
                                    icon: const Icon(LucideIcons.trash2),
                                    color: Colors.red[400],
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.red[50],
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                if (isEditing) const Spacer(),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) return;
                                    if (selectedOwners.isEmpty) {
                                      selectedOwners.add(user.email);
                                    }

                                    final provider = context
                                        .read<AccountProvider>();
                                    Navigator.pop(ctx);

                                    bool success = isEditing
                                        ? await provider.updateAccount(
                                            user,
                                            account,
                                            name,
                                            selectedType,
                                            selectedGroups.toList(),
                                            selectedOwners.toList(),
                                            selectedCurrency,
                                            selectedSubCategory,
                                          )
                                        : await provider.addAccount(
                                            user,
                                            name,
                                            selectedType,
                                            selectedGroups.toList(),
                                            selectedOwners.toList(),
                                            selectedCurrency,
                                            selectedSubCategory,
                                          );

                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            provider.error ?? 'Action failed',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    isEditing
                                        ? 'Save Changes'
                                        : 'Create Account',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .animate()
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    curve: Curves.easeOutCubic,
                    duration: 500.ms,
                  )
                  .fadeIn(),
        ),
      ),
    );
  }

  Widget _buildModernLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF475569),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  InputDecoration _modernInputDecoration(String? hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF94A3B8),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }

  void _confirmDelete(
    BuildContext dialogContext,
    BuildContext rootContext,
    User user,
    Account account,
  ) {
    showDialog(
      context: rootContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Account?'),
        content: Text("Are you sure you want to delete '${account.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(dialogContext);
              final result = await rootContext
                  .read<AccountProvider>()
                  .deleteAccount(user, account.name);
              if (rootContext.mounted) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['success']
                          ? 'Done'
                          : (result['error'] ?? 'Failed'),
                    ),
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
