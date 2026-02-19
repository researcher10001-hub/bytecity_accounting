import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/user_model.dart';
import '../../models/account_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/sub_category_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/user_provider.dart';
import 'sub_category_management_screen.dart';

class AddEditAccountDialog extends StatefulWidget {
  final User user;
  final Account? account; // Null for new account

  const AddEditAccountDialog({super.key, required this.user, this.account});

  @override
  State<AddEditAccountDialog> createState() => _AddEditAccountDialogState();
}

class _AddEditAccountDialogState extends State<AddEditAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _subCategoryController;

  String _selectedType = 'Asset';
  String _selectedCurrency = 'BDT';
  String _selectedSubCategory = '';

  final Set<String> _selectedGroups = {};
  final Set<String> _selectedOwners = {};

  final List<String> _types = [
    'Asset',
    'Liability',
    'Income',
    'Expense',
    'Equity',
  ];

  final List<String> _currencies = ['BDT', 'USD', 'RM', 'AED'];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers and state
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _selectedType = widget.account?.type ?? 'Asset';
    _selectedCurrency = widget.account?.defaultCurrency ?? 'BDT';

    if (widget.account != null) {
      _selectedGroups.addAll(widget.account!.groupIds);
      _selectedOwners.addAll(widget.account!.owners);
      _selectedSubCategory = widget.account?.subCategory ?? '';
    }

    _subCategoryController = TextEditingController(text: _selectedSubCategory);

    // Fetch latest sub-categories
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubCategoryProvider>().fetchSubCategories();
      // We no longer auto-select a default; user must choose.
    });
  }

  void _onTypeChanged() {
    // When type changes, clear sub-category as old one is likely invalid
    setState(() {
      _selectedSubCategory = '';
      _subCategoryController.text = '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subCategoryController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameController.text.trim().isEmpty) return;

    if (_selectedOwners.isEmpty && widget.user.email != 'admin@test.com') {
      _selectedOwners.add(widget.user.email);
    }

    setState(() => _isSaving = true);

    try {
      final accountProvider = context.read<AccountProvider>();
      bool success;

      final name = _nameController.text.trim();
      final subCat = _subCategoryController.text.trim();

      if (widget.account != null) {
        // Update
        // updateAccount(User user, Account oldAccount, String newName, String newType, List<String> newGroupIds, List<String> newOwners, String newCurrency, String? newSubCategory)
        success = await accountProvider.updateAccount(
          widget.user,
          widget.account!,
          name,
          _selectedType,
          _selectedGroups.toList(),
          _selectedOwners.toList(),
          _selectedCurrency,
          subCat.isEmpty ? null : subCat,
        );
      } else {
        // Create
        // addAccount(User user, String name, String type, List<String> groupIds, List<String> owners, String currency, String? subCategory)
        success = await accountProvider.addAccount(
          widget.user,
          name,
          _selectedType,
          _selectedGroups.toList(),
          _selectedOwners.toList(),
          _selectedCurrency,
          subCat.isEmpty ? null : subCat,
        );
      }

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.account != null ? 'Account updated' : 'Account created',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accountProvider.error ?? 'Operation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _modernInputDecoration(String? hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
      ),
    );
  }

  Widget _buildModernLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
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
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? LucideIcons.edit3 : LucideIcons.plus,
                        color: const Color(0xFF1E88E5),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Account' : 'New Account',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            isEditing
                                ? 'Updating ${widget.account!.name}'
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
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, size: 20),
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Account Name
                        _buildModernLabel('Account Name'),
                        TextFormField(
                          controller: _nameController,
                          validator: (val) => val == null || val.isEmpty
                              ? 'Name required'
                              : null,
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

                        // Type Selection
                        _buildModernLabel('Type'),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B),
                          ),
                          decoration: _modernInputDecoration(
                            null,
                            LucideIcons.layers,
                          ),
                          isExpanded: true,
                          items: _types
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              _selectedType = val;
                              _onTypeChanged();
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // Sub-Category Selection (Moved to new row as requested)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildModernLabel('Sub-Category ($_selectedType)'),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 8,
                                right: 4,
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SubCategoryManagementScreen(),
                                    ),
                                  ).then((_) {
                                    // Refresh on return
                                    context
                                        .read<SubCategoryProvider>()
                                        .fetchSubCategories();
                                  });
                                },
                                child: Text(
                                  'Manage',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF1E88E5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        Consumer<SubCategoryProvider>(
                          builder: (context, provider, child) {
                            if (provider.isLoading) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            if (provider.error != null) {
                              return Text(
                                'Error: ${provider.error}',
                                style: const TextStyle(color: Colors.red),
                              );
                            }

                            final list =
                                provider.subCategoriesByType[_selectedType] ??
                                    [];

                            return TypeAheadField<String>(
                              controller: _subCategoryController,
                              builder: (context, controller, focusNode) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: _modernInputDecoration(
                                    'Select or type...',
                                    LucideIcons.tag,
                                  ),
                                );
                              },
                              suggestionsCallback: (pattern) {
                                return list
                                    .where(
                                      (s) => s.toLowerCase().contains(
                                            pattern.toLowerCase(),
                                          ),
                                    )
                                    .toList();
                              },
                              itemBuilder: (context, suggestion) {
                                return ListTile(title: Text(suggestion));
                              },
                              onSelected: (suggestion) {
                                _subCategoryController.text = suggestion;
                                setState(
                                  () => _selectedSubCategory = suggestion,
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Currency
                        _buildModernLabel('Currency'),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCurrency,
                          items: _currencies
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedCurrency = val!),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B),
                          ),
                          decoration: _modernInputDecoration(
                            null,
                            LucideIcons.banknote,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Access Groups
                        _buildModernLabel('Access Groups'),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Consumer<GroupProvider>(
                            builder: (context, groupProvider, child) {
                              if (groupProvider.groups.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: Text('No groups defined.'),
                                  ),
                                );
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: groupProvider.groups.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFF1F5F9),
                                ),
                                itemBuilder: (context, index) {
                                  final g = groupProvider.groups[index];
                                  final isSelected = _selectedGroups.contains(
                                    g.id,
                                  );
                                  return CheckboxListTile(
                                    title: Text(
                                      g.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedGroups.add(g.id);
                                        } else {
                                          _selectedGroups.remove(g.id);
                                        }
                                      });
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: const Color(0xFF1E88E5),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Owners
                        _buildModernLabel('Owners (Users)'),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Consumer<UserProvider>(
                            builder: (context, userProvider, child) {
                              if (userProvider.users.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(child: Text('No users found.')),
                                );
                              }
                              // Filter checks handled in provider? No, showing all active users usually
                              final activeUsers = userProvider.users
                                  .where((u) => u.isActive)
                                  .toList();

                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: activeUsers.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFF1F5F9),
                                ),
                                itemBuilder: (context, index) {
                                  final u = activeUsers[index];
                                  final isSelected = _selectedOwners.contains(
                                    u.email,
                                  );
                                  return CheckboxListTile(
                                    title: Text(
                                      u.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      u.email,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedOwners.add(u.email);
                                        } else {
                                          _selectedOwners.remove(u.email);
                                        }
                                      });
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: const Color(0xFF1E88E5),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveAccount,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(LucideIcons.check),
                            label: Text(
                              _isSaving
                                  ? 'Processing...'
                                  : (isEditing
                                      ? 'Update Account'
                                      : 'Create Account'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
      ),
    );
  }
}
