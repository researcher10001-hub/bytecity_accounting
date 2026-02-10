import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/account_group_provider.dart';
import '../../models/account_group_model.dart';
import '../../providers/account_provider.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({super.key});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountGroupProvider>().fetchGroups();
    });
  }

  void _showAddEditGroupDialog(BuildContext context, {AccountGroup? group}) {
    final TextEditingController nameController = TextEditingController(
      text: group?.name ?? '',
    );
    List<String> selectedAccounts = group?.accountNames.toList() ?? [];
    final accountProvider = context.read<AccountProvider>();
    final allAccounts = accountProvider.accounts;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              group == null ? 'Add New Group' : 'Edit Group',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Accounts',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: allAccounts.length,
                        itemBuilder: (context, index) {
                          final account = allAccounts[index];
                          final isSelected = selectedAccounts.contains(
                            account.name,
                          );
                          return CheckboxListTile(
                            title: Text(account.name),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedAccounts.add(account.name);
                                } else {
                                  selectedAccounts.remove(account.name);
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;

                  final provider = context.read<AccountGroupProvider>();
                  final navigator = Navigator.of(context);

                  final newGroup = AccountGroup(
                    id: group?.id ?? '',
                    name: nameController.text,
                    accountNames: selectedAccounts,
                  );

                  bool success;
                  if (group == null) {
                    success = await provider.addGroup(newGroup);
                  } else {
                    success = await provider.updateGroup(newGroup);
                  }

                  if (success) {
                    navigator.pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Group saved successfully'),
                        ),
                      );
                    }
                  }
                },
                child: Text(group == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<AccountGroupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account Groups',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: groupProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupProvider.groups.length,
              itemBuilder: (context, index) {
                final group = groupProvider.groups[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.folder, color: Colors.blue),
                    ),
                    title: Text(
                      group.name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      '${group.accountNames.length} accounts',
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            LucideIcons.pencil,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              _showAddEditGroupDialog(context, group: group),
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.trash2,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Group'),
                                content: Text(
                                  'Are you sure you want to delete "${group.name}"?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await groupProvider.deleteGroup(group.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditGroupDialog(context),
        backgroundColor: const Color(0xFF1E88E5),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }
}
