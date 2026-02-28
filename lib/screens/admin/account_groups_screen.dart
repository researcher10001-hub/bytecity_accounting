import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/group_provider.dart';
import '../../models/group_model.dart';
import '../../providers/account_provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AccountGroupsScreen extends StatefulWidget {
  final String initialTab;
  const AccountGroupsScreen({super.key, this.initialTab = 'permission'});

  @override
  State<AccountGroupsScreen> createState() => _AccountGroupsScreenState();
}

class _AccountGroupsScreenState extends State<AccountGroupsScreen> {
  late String _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    // Fetch groups on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().fetchGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final accountProvider = context.watch<AccountProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Account Groups',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () {
              groupProvider.fetchGroups(forceRefresh: true);
              final user = context.read<AuthProvider>().user;
              if (user != null) {
                accountProvider.fetchAccounts(user, forceRefresh: true);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<GroupProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E63)),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.alertCircle,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Oops! Something went wrong',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchGroups(forceRefresh: true),
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.layers,
                      color: Color(0xFF94A3B8),
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No groups found',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first category to organize accounts',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }

          // Filter groups by selected tab
          final filteredGroups = _selectedTab == 'permission'
              ? provider.permissionGroups
              : provider.reportGroups;

          return Column(
            children: [
              // Tab Bar
              Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedTab = 'permission'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 'permission'
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 'permission'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.shield,
                                size: 14,
                                color: _selectedTab == 'permission'
                                    ? const Color(0xFFE91E63)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Permission',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTab == 'permission'
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 'report'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 'report'
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 'report'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.barChart2,
                                size: 14,
                                color: _selectedTab == 'report'
                                    ? const Color(0xFFE91E63)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Report',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTab == 'report'
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Group List
              Expanded(
                child: filteredGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedTab == 'permission'
                                  ? LucideIcons.shield
                                  : LucideIcons.barChart2,
                              color: const Color(0xFF94A3B8),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No $_selectedTab groups yet',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        itemCount: filteredGroups.length,
                        itemBuilder: (context, index) {
                          final group = filteredGroups[index];
                          final accountCount = accountProvider.accounts
                              .where((a) => a.groupIds.contains(group.id))
                              .length;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: 0.02,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () => _showLinkedAccounts(context, group),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFE91E63,
                                        ).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(
                                          14,
                                        ),
                                      ),
                                      child: const Icon(
                                        LucideIcons.package,
                                        color: Color(0xFFE91E63),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  group.name,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                    color: const Color(
                                                      0xFF1E293B,
                                                    ),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF1F5F9,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    6,
                                                  ),
                                                ),
                                                child: Text(
                                                  '$accountCount',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(
                                                      0xFF64748B,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (group.description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              group.description,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: const Color(
                                                  0xFF64748B,
                                                ),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _showGroupDialog(
                                              context,
                                              group,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(
                                                8,
                                              ),
                                              child: const Icon(
                                                LucideIcons.edit2,
                                                color: Color(0xFF64748B),
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _confirmDelete(
                                              context,
                                              group,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(
                                                8,
                                              ),
                                              child: const Icon(
                                                LucideIcons.trash2,
                                                color: Color(0xFFF43F5E),
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                              .animate(delay: (index * 50).ms)
                              .fadeIn(duration: 400.ms)
                              .slideX(
                                begin: 0.1,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGroupDialog(context, null),
        backgroundColor: const Color(0xFFE91E63),
        elevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
        label: Text(
          'New Group',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ).animate().scale(
            delay: 400.ms,
            curve: Curves.elasticOut,
            duration: 800.ms,
          ),
    );
  }

  void _showLinkedAccounts(BuildContext context, GroupModel group) {
    final user = context.read<AuthProvider>().user;
    final accountProvider = context.read<AccountProvider>();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        String? removingAccountId;
        final scrollController = ScrollController();

        return StatefulBuilder(
          builder: (context, setState) {
            final linkedAccounts = accountProvider.accounts.where((acc) {
              return acc.groupIds.contains(group.id);
            }).toList();

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 700,
                ),
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
                                  0xFFE91E63,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.link,
                                color: Color(0xFFE91E63),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    'Linked Accounts (${linkedAccounts.length})',
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
                            ),
                          ],
                        ),
                      ),

                      // List of Linked Accounts
                      Flexible(
                        child: linkedAccounts.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 48,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.unlink,
                                        size: 32,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No accounts linked yet',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Scrollbar(
                                controller: scrollController,
                                child: ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(24),
                                  itemCount: linkedAccounts.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final acc = linkedAccounts[index];
                                    final isRemoving =
                                        removingAccountId == acc.name;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(
                                                alpha: 0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              LucideIcons.check,
                                              size: 14,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  acc.name,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: const Color(
                                                      0xFF334155,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  acc.type,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: const Color(
                                                      0xFF94A3B8,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isRemoving)
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFFF43F5E),
                                              ),
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(
                                                LucideIcons.minusCircle,
                                                color: Color(0xFFF43F5E),
                                                size: 20,
                                              ),
                                              onPressed: () async {
                                                if (user == null) return;
                                                setState(
                                                  () => removingAccountId =
                                                      acc.name,
                                                );
                                                try {
                                                  final newGroups =
                                                      List<String>.from(
                                                    acc.groupIds,
                                                  )..remove(group.id);
                                                  await accountProvider
                                                      .updateAccount(
                                                    user,
                                                    acc,
                                                    acc.name,
                                                    acc.type,
                                                    newGroups,
                                                    acc.owners,
                                                    acc.defaultCurrency ??
                                                        'BDT',
                                                    acc.subCategory,
                                                  );
                                                } catch (e) {
                                                  debugPrint(
                                                    'Error removing account: $e',
                                                  );
                                                }
                                                if (context.mounted) {
                                                  setState(
                                                    () => removingAccountId =
                                                        null,
                                                  );
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),

                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // Actions & Adding Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(color: Colors.white),
                        child: Column(
                          children: [
                            Text(
                              "ADD EXISTING ACCOUNT",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                final added = await _showBulkAddDialog(
                                  context,
                                  group,
                                  accountProvider,
                                  user,
                                );
                                if (added == true && context.mounted) {
                                  setState(() {});
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.search,
                                      size: 18,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Search & Select Accounts...",
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(LucideIcons.plus, size: 18),
                                label: const Text("Create New Account"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () async {
                                  if (user == null) return;
                                  final created =
                                      await _showCreateAccountForGroup(
                                    context,
                                    group,
                                    user,
                                  );
                                  if (created == true && context.mounted) {
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Close',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
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
                      duration: 500.ms)
                  .fadeIn(),
            );
          },
        );
      },
    );
  }

  Future<bool?> _showBulkAddDialog(
    BuildContext context,
    GroupModel group,
    AccountProvider provider,
    User? user,
  ) {
    if (user == null) return Future.value(false);

    // Potential candidates: Accounts NOT in this group
    final candidates = provider.accounts
        .where((acc) => !acc.groupIds.contains(group.id))
        .toList();
    List<String> selectedIds = [];

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isAdding = false;
        String searchQuery = ""; // Search state persists here
        final scrollController = ScrollController();
        final searchController = TextEditingController(); // Added controller

        return StatefulBuilder(
          builder: (context, setOuterState) {
            return AlertDialog(
              title: Text("Add Accounts to ${group.name}"),
              content: StatefulBuilder(
                builder: (context, setInnerState) {
                  final filteredCandidates = candidates.where((acc) {
                    final query = searchQuery.toLowerCase();
                    return acc.name.toLowerCase().contains(query) ||
                        acc.type.toLowerCase().contains(query);
                  }).toList();

                  return SizedBox(
                    width: double.maxFinite,
                    height: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: searchController,
                          onChanged: (val) {
                            setInnerState(() => searchQuery = val);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search accounts...',
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              size: 20,
                            ),
                            suffixIcon: searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(LucideIcons.x, size: 16),
                                    onPressed: () {
                                      searchController.clear();
                                      setInnerState(() => searchQuery = "");
                                    },
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filteredCandidates.isEmpty
                              ? const Center(
                                  child: Text("No accounts match your search."),
                                )
                              : Scrollbar(
                                  thumbVisibility: true,
                                  controller: scrollController,
                                  child: ListView.builder(
                                    controller: scrollController,
                                    itemCount: filteredCandidates.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        final allSelected =
                                            filteredCandidates.isNotEmpty &&
                                                filteredCandidates.every(
                                                  (e) => selectedIds
                                                      .contains(e.name),
                                                );
                                        final someSelected =
                                            filteredCandidates.any(
                                          (e) => selectedIds.contains(e.name),
                                        );

                                        return Column(
                                          children: [
                                            CheckboxListTile(
                                              title: const Text(
                                                "Select All",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              subtitle: Text(
                                                "${filteredCandidates.length} accounts matching search",
                                              ),
                                              value: allSelected
                                                  ? true
                                                  : (someSelected
                                                      ? null
                                                      : false),
                                              tristate: true,
                                              onChanged: isAdding
                                                  ? null
                                                  : (val) {
                                                      setOuterState(() {
                                                        if (val == true) {
                                                          for (var acc
                                                              in filteredCandidates) {
                                                            if (!selectedIds
                                                                .contains(
                                                              acc.name,
                                                            )) {
                                                              selectedIds.add(
                                                                acc.name,
                                                              );
                                                            }
                                                          }
                                                        } else {
                                                          for (var acc
                                                              in filteredCandidates) {
                                                            selectedIds.remove(
                                                              acc.name,
                                                            );
                                                          }
                                                        }
                                                      });
                                                    },
                                            ),
                                            const Divider(height: 1),
                                          ],
                                        );
                                      }

                                      final acc = filteredCandidates[index - 1];
                                      final isSelected = selectedIds.contains(
                                        acc.name,
                                      );

                                      return CheckboxListTile(
                                        title: Text(acc.name),
                                        subtitle: Text(acc.type),
                                        value: isSelected,
                                        onChanged: isAdding
                                            ? null
                                            : (val) {
                                                setOuterState(() {
                                                  if (val == true) {
                                                    selectedIds.add(acc.name);
                                                  } else {
                                                    selectedIds.remove(
                                                      acc.name,
                                                    );
                                                  }
                                                });
                                              },
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: isAdding ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          setOuterState(() {
                            isAdding = true;
                          });

                          try {
                            for (var accName in selectedIds) {
                              final acc = candidates.firstWhere(
                                (a) => a.name == accName,
                              );
                              final newGroups = List<String>.from(acc.groupIds)
                                ..add(group.id);
                              await provider.updateAccount(
                                user,
                                acc,
                                acc.name,
                                acc.type,
                                newGroups,
                                acc.owners,
                                acc.defaultCurrency ?? 'BDT',
                                acc.subCategory,
                              );
                            }

                            if (ctx.mounted) {
                              Navigator.pop(ctx, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${selectedIds.length} accounts added.",
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Error adding accounts."),
                                ),
                              );
                              setOuterState(() {
                                isAdding = false;
                              });
                            }
                          }
                        },
                  child: isAdding
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showCreateAccountForGroup(
    BuildContext context,
    GroupModel group,
    User user,
  ) {
    final nameController = TextEditingController();
    String selectedType = 'Asset';
    final types = ['Asset', 'Liability', 'Income', 'Expense', 'Equity'];

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isCreating = false;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Create Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Account Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  items: types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => selectedType = v!,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Will be added to group: ${group.name}",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isCreating ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isCreating
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        setState(() {
                          isCreating = true;
                        });

                        final provider = context.read<AccountProvider>();
                        // Create with Pre-filled Group ID
                        final success = await provider.addAccount(
                          user,
                          name,
                          selectedType,
                          [group.id], // Pre-filled
                          [user.email], // Primary Owner as list
                          'BDT', // Default currency
                          null, // Sub-category
                        );

                        if (ctx.mounted) {
                          if (success) {
                            Navigator.pop(ctx, true);
                          } else {
                            setState(() {
                              isCreating = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(provider.error ?? "Failed"),
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
                    : const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGroupDialog(BuildContext context, GroupModel? group) {
    final isEditing = group != null;
    final nameController = TextEditingController(text: group?.name ?? '');
    final descController = TextEditingController(
      text: group?.description ?? '',
    );
    String selectedType = group?.type ?? _selectedTab;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
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
                              0xFFE91E63,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing ? LucideIcons.edit3 : LucideIcons.layers,
                            color: const Color(0xFFE91E63),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Group' : 'New Group',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                isEditing
                                    ? 'Updating group settings'
                                    : 'Create a new account category',
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
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModernLabel('Group Name'),
                        TextField(
                          controller: nameController,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _modernInputDecoration(
                            'e.g. Fixed Assets',
                            LucideIcons.type,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildModernLabel('Description'),
                        TextField(
                          controller: descController,
                          maxLines: 3,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF475569),
                          ),
                          decoration: _modernInputDecoration(
                            'Describe the purpose of this group...',
                            LucideIcons.alignLeft,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildModernLabel('Group Type'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedType,
                              isExpanded: true,
                              icon: const Icon(
                                LucideIcons.chevronDown,
                                size: 18,
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF334155),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'permission',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.shield,
                                        size: 16,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Permission — Controls entry access',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'report',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.barChart2,
                                        size: 16,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Report — Quick filter in Ledger',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'both',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.layers,
                                        size: 16,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Both — Permission + Report',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => selectedType = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
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
                            backgroundColor: const Color(0xFFE91E63),
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

                            final provider = context.read<GroupProvider>();
                            Navigator.pop(ctx);

                            bool success;
                            if (isEditing) {
                              success = await provider.updateGroup(
                                group.id,
                                name,
                                descController.text.trim(),
                                type: selectedType,
                              );
                            } else {
                              success = await provider.addGroup(
                                name,
                                descController.text.trim(),
                                type: selectedType,
                              );
                            }

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
                            isEditing ? 'Save Changes' : 'Create Group',
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
        borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
      ),
    );
  }

  void _confirmDelete(BuildContext context, GroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<GroupProvider>().deleteGroup(
                    group.id,
                  );
              if (!success && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Delete failed')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
