import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sub_category_provider.dart';

class SubCategoryManagementScreen extends StatefulWidget {
  const SubCategoryManagementScreen({super.key});

  @override
  State<SubCategoryManagementScreen> createState() =>
      _SubCategoryManagementScreenState();
}

class _SubCategoryManagementScreenState
    extends State<SubCategoryManagementScreen> {
  final Map<String, IconData> typeIcons = {
    'Asset': LucideIcons.wallet,
    'Liability': LucideIcons.creditCard,
    'Income': LucideIcons.trendingUp,
    'Expense': LucideIcons.trendingDown,
    'Equity': LucideIcons.pieChart,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SubCategoryProvider>(
        context,
        listen: false,
      ).fetchSubCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subCategoryProvider = context.watch<SubCategoryProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user == null || !user.isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    final grouped = subCategoryProvider.subCategoriesByType;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Manage Sub-Categories',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCcw, size: 20),
            onPressed: () => subCategoryProvider.fetchSubCategories(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: subCategoryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : subCategoryProvider.error != null && grouped.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading sub-categories',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subCategoryProvider.error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => subCategoryProvider.fetchSubCategories(),
                      icon: const Icon(LucideIcons.refreshCcw, size: 16),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: typeIcons.keys.length,
              itemBuilder: (context, index) {
                final type = typeIcons.keys.elementAt(index);
                final subs = grouped[type] ?? [];
                final icon = typeIcons[type]!;

                return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, color: Colors.blue, size: 20),
                            ),
                            title: Text(
                              type,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                LucideIcons.plusCircle,
                                color: Colors.blue,
                              ),
                              onPressed: () => _showAddDialog(context, type),
                            ),
                          ),
                          const Divider(height: 1),
                          if (subs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No sub-categories defined',
                                style: GoogleFonts.inter(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: subs.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 56),
                              itemBuilder: (context, index) {
                                final name = subs[index];
                                return ListTile(
                                      contentPadding: const EdgeInsets.only(
                                        left: 56,
                                        right: 8,
                                      ),
                                      title: Text(
                                        name,
                                        style: GoogleFonts.inter(fontSize: 14),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              LucideIcons.edit2,
                                              size: 16,
                                              color: Colors.blueGrey,
                                            ),
                                            onPressed: () => _showEditDialog(
                                              context,
                                              type,
                                              name,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              LucideIcons.trash2,
                                              size: 18,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () => _confirmDelete(
                                              user,
                                              type,
                                              name,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 400.ms)
                                    .slideX(
                                      begin: 0.1,
                                      end: 0,
                                      curve: Curves.easeOutCubic,
                                    )
                                    .scale(
                                      begin: const Offset(0.95, 0.95),
                                      end: const Offset(1, 1),
                                    )
                                    .shimmer(
                                      duration: 1000.ms,
                                      color: Colors.blue.withValues(
                                        alpha: 0.05,
                                      ),
                                    );
                              },
                            ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: (index * 80).ms, duration: 500.ms)
                    .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context, String type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'New $type Sub-Category',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. Digital Assets',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final provider = Provider.of<SubCategoryProvider>(
                context,
                listen: false,
              );
              final user = Provider.of<AuthProvider>(
                context,
                listen: false,
              ).user!;
              final success = await provider.addSubCategory(
                user,
                type,
                controller.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.actionError ?? 'Failed to add',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            child: Consumer<SubCategoryProvider>(
              builder: (context, provider, child) {
                return provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add');
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(dynamic user, String type, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sub-Category?'),
        content: Text('Are you sure you want to remove "$name" from $type?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = Provider.of<SubCategoryProvider>(
                context,
                listen: false,
              );
              final success = await provider.deleteSubCategory(
                user,
                type,
                name,
              );
              if (mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.actionError ?? 'Failed to delete',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            child: Consumer<SubCategoryProvider>(
              builder: (context, provider, child) {
                return provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : const Text('Delete', style: TextStyle(color: Colors.red));
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String type, String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rename Sub-Category',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: $type',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'New Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Important: This will update all accounts using this sub-category.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.orange.shade700,
                fontStyle: FontStyle.italic,
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
              if (controller.text.trim().isEmpty ||
                  controller.text.trim() == oldName) {
                Navigator.pop(ctx);
                return;
              }
              final provider = Provider.of<SubCategoryProvider>(
                context,
                listen: false,
              );
              final user = Provider.of<AuthProvider>(
                context,
                listen: false,
              ).user!;
              final success = await provider.updateSubCategory(
                user,
                type,
                oldName,
                controller.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.actionError ?? 'Failed to update',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Sub-category renamed successfully',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            child: Consumer<SubCategoryProvider>(
              builder: (context, provider, child) {
                return provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update');
              },
            ),
          ),
        ],
      ),
    );
  }
}
