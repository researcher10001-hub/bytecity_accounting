import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../main.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/account_model.dart';
import '../../services/permission_service.dart';
import 'widgets/account_autocomplete.dart';
import '../reports/transaction_history_screen.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/dashboard_provider.dart';

class TransactionEntryScreen extends StatefulWidget {
  final TransactionModel? transaction; // Optional transaction for editing

  const TransactionEntryScreen({super.key, this.transaction});

  @override
  State<TransactionEntryScreen> createState() => _TransactionEntryScreenState();
}

class _TransactionEntryScreenState extends State<TransactionEntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final txProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      txProvider.resetForm(); // Clear stale state

      // If editing, set transaction
      if (widget.transaction != null) {
        txProvider.setTransactionForEdit(widget.transaction!);
      }

      Provider.of<AccountProvider>(context, listen: false).fetchAccounts(user);
      groupProvider.fetchGroups(); // Fetch groups to resolve names
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final groupProvider = Provider.of<GroupProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String title =
        widget.transaction != null ? 'Edit Transaction' : 'New Entry';

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return Material(
            color: _getBackgroundColor(transactionProvider.selectedType),
            child: Column(
              children: [
                // Form Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: _buildFormBody(
                          transactionProvider,
                          accountProvider,
                          groupProvider,
                          user,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Layout
        return Scaffold(
          backgroundColor:
              _getBackgroundColor(transactionProvider.selectedType),
          appBar: AppBar(
            title: Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D3748),
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            leading: IconButton(
              icon: const Icon(
                LucideIcons.chevronLeft,
                color: Color(0xFF2D3748),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _buildFormBody(
              transactionProvider,
              accountProvider,
              groupProvider,
              user,
            ),
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(VoucherType? type) {
    return const Color(0xFFF7FAFC);
  }

  Widget _buildFormBody(
    TransactionProvider tp,
    AccountProvider ap,
    GroupProvider gp,
    dynamic user,
  ) {
    if (tp.selectedType == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEmptyStateHint(),
            const SizedBox(height: 40),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _buildActionSelector(tp),
            ),
          ],
        ),
      ).animate().fade(duration: 150.ms);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionSelector(tp),
          const SizedBox(height: 16),
          if (tp.error != null) _buildErrorBanner(tp),
          _buildTransactionForm(context, tp, ap, gp, user),
        ],
      ),
    );
  }

  Widget _buildActionSelector(TransactionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(
                0xFFE2E8F0), // Slightly darker base for better contrast
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _buildSegmentButton(
                provider,
                VoucherType.payment,
                'Payment',
                LucideIcons.arrowUp,
                const Color(0xFFF43F5E), // Muted Rose (Eye-friendly)
              ),
              _buildSegmentButton(
                provider,
                VoucherType.receipt,
                'Receipt',
                LucideIcons.arrowDown,
                const Color(0xFF10B981), // Muted Emerald
              ),
              _buildSegmentButton(
                provider,
                VoucherType.contra,
                'Transfer',
                LucideIcons.repeat,
                const Color(0xFF3B82F6), // Muted Blue
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentButton(
    TransactionProvider provider,
    VoucherType type,
    String label,
    IconData icon,
    Color activeColor,
  ) {
    final isSelected = provider.selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setVoucherType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateHint() {
    return Column(
      children: [
        Icon(
          LucideIcons.layoutGrid,
          size: 64,
          color: const Color(0xFF4299E1).withValues(alpha: 0.2),
        ),
        const SizedBox(height: 24),
        Text(
          'Select Transaction Type',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how you want to record\nyour entry to get started',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF718096),
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(TransactionProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: provider.clearError,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionForm(
    BuildContext context,
    TransactionProvider provider,
    AccountProvider accountProvider,
    GroupProvider groupProvider,
    dynamic user,
  ) {
    final canEditDate = user.canEditDate;

    // Filter Accounts for Entry
    final entryAccounts = accountProvider.accounts.where((acc) {
      if (!PermissionService().canEnterTransaction(user, acc)) return false;

      // If user lacks Foreign Currency permission (and is not Admin), hide non-BDT accounts
      if (!user.allowForeignCurrency && !user.isAdmin) {
        if (acc.defaultCurrency != null &&
            acc.defaultCurrency!.isNotEmpty &&
            acc.defaultCurrency != 'BDT') {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          context: context,
          title: 'General Details',
          icon: LucideIcons.fileText,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(context, provider, canEditDate),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildReadOnlyField(
                      label: 'Voucher No',
                      value: provider.voucherNo,
                      suffix: provider.voucherNo == 'AUTO'
                          ? 'Prefix: ${DateFormat('yyMM').format(provider.selectedDate)}'
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fade(duration: 150.ms),

        // Per-line currency is now handled inside each form (simple/split)
        const SizedBox(height: 8),

        if (provider.isSplitMode)
          _buildTwoListSplitForm(
            context,
            provider,
            entryAccounts,
            groupProvider,
            canUseForeignCurrency: user.allowForeignCurrency || user.isAdmin,
          )
        else
          _buildSimpleForm(context, provider, entryAccounts, groupProvider),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: () => provider.toggleSplitMode(!provider.isSplitMode),
            child: Text(
              provider.isSplitMode
                  ? 'Switch to Simple Mode (BDT Only)'
                  : 'Split / Multi-Currency Mode',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 24),

        _buildSectionCard(
          context: context,
          title: 'Observations',
          icon: LucideIcons.messageSquare,
          child: TextFormField(
            key: ValueKey('narration_${provider.formSessionId}'),
            minLines: 2,
            maxLines: null,
            onChanged: provider.setMainNarration,
            initialValue: provider.mainNarration,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2D3748),
            ),
            decoration: InputDecoration(
              hintText: 'Add some notes or details here...',
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFA0AEC0),
              ),
              filled: true,
              fillColor: const Color(0xFFF7FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ).animate().fade(duration: 150.ms, delay: 50.ms),

        const SizedBox(height: 24),

        _buildGradientSaveButton(provider, user),

        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    TransactionProvider provider,
    bool canEditDate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF718096),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: canEditDate
              ? () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: provider.selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (context, child) => Theme(
                      data: ThemeData(
                        useMaterial3: true,
                        colorSchemeSeed: const Color(0xFF4299E1),
                        brightness: Brightness.light,
                        textTheme: GoogleFonts.interTextTheme(),
                      ),
                      child: child!,
                    ),
                  );
                  if (date != null) provider.setDate(date);
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    canEditDate ? const Color(0xFFE2E8F0) : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd').format(provider.selectedDate),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                Icon(
                  canEditDate ? LucideIcons.calendar : LucideIcons.lock,
                  size: 16,
                  color: const Color(0xFF718096),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF718096),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF2F7).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4A5568),
                ),
              ),
              if (suffix != null) ...[
                const Spacer(),
                Text(
                  suffix,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF718096),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    Color bgColor =
        Colors.white; // Keep cards clean white so it doesn't hurt eyes

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2E8F0), // Neutral border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4299E1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF4299E1)),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildGradientSaveButton(TransactionProvider provider, dynamic user) {
    return InkWell(
      onTap: provider.isLoading
          ? null
          : () async {
              // ... keep existing validation/logic from button below
              if (!provider.isBalanced) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voucher is not balanced!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              _showPreviewDialog(context, provider, user);
            },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: provider.isEditing
                ? [const Color(0xFF3182CE), const Color(0xFF2B6CB0)]
                : provider.selectedType == VoucherType.payment
                    ? [
                        const Color(0xFFF43F5E),
                        const Color(0xFFE11D48)
                      ] // Rose for Payment
                    : provider.selectedType == VoucherType.receipt
                        ? [
                            const Color(0xFF10B981),
                            const Color(0xFF059669)
                          ] // Green for Receipt
                        : provider.selectedType == VoucherType.contra
                            ? [
                                const Color(0xFF3B82F6),
                                const Color(0xFF2563EB)
                              ] // Blue for Transfer
                            : [
                                const Color(0xFF38A169),
                                const Color(0xFF2F855A)
                              ], // Default Green
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (provider.selectedType == VoucherType.payment
                      ? const Color(0xFFF43F5E)
                      : provider.selectedType == VoucherType.receipt
                          ? const Color(0xFF10B981)
                          : provider.selectedType == VoucherType.contra
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF38A169))
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: provider.isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    provider.isEditing ? LucideIcons.save : LucideIcons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    provider.isEditing
                        ? 'UPDATE TRANSACTION'
                        : 'SAVE TRANSACTION',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  void _submitForm(TransactionProvider provider, dynamic user) async {
    // Moved the logic from the old button here for clarity
    if (provider.mainNarration.trim().isEmpty) {
      provider.setMainNarration("No additional notes");
    }

    TransactionModel? savedTx;
    if (provider.isEditing) {
      final success = await provider.editTransaction(user);
      if (success) {
        if (!context.mounted) return;
        context.read<AccountProvider>().fetchAccounts(user);
        context.read<TransactionProvider>().fetchHistory(
              user,
              forceRefresh: true,
            );
        if (MediaQuery.of(context).size.width >= 800) {
          context.read<DashboardProvider>().popView();
        } else {
          Navigator.pop(context);
        }
        return;
      }
    } else {
      try {
        savedTx = await provider.saveTransaction(user);
        if (savedTx != null && context.mounted) {
          context.read<AccountProvider>().fetchAccounts(user);
          context.read<TransactionProvider>().fetchHistory(
                user,
                forceRefresh: true,
              );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    if (savedTx != null && context.mounted) {
      _showSuccessDialog(context, savedTx, provider);
    }
  }

  void _showPreviewDialog(
    BuildContext context,
    TransactionProvider provider,
    dynamic user,
  ) {
    if (provider.mainNarration.trim().isEmpty) {
      provider.setMainNarration("No additional notes");
    }

    final isPayment = provider.selectedType == VoucherType.payment;
    final isReceipt = provider.selectedType == VoucherType.receipt;
    final isTransfer = provider.selectedType == VoucherType.contra;

    String typeStr = "Transaction";
    Color typeColor = Colors.blue;
    String fromTitle = 'Credits';
    String fromSubtitle = ' (From / Paid By)';
    String toTitle = 'Debits';
    String toSubtitle = ' (To / Received / Transferred To)';

    if (isPayment) {
      typeStr = "Payment";
      typeColor = const Color(0xFFF43F5E);
      toTitle = 'Expense on';
      toSubtitle = ' (Debit)';
      fromTitle = 'Paid from';
      fromSubtitle = ' (Credit)';
    } else if (isReceipt) {
      typeStr = "Receipt";
      typeColor = const Color(0xFF10B981);
      toTitle = 'Received in';
      toSubtitle = ' (Debit)';
      fromTitle = 'Income from';
      fromSubtitle = ' (Credit)';
    } else if (isTransfer) {
      typeStr = "Transfer";
      typeColor = const Color(0xFF3B82F6);
      toTitle = 'Transfer to';
      toSubtitle = ' (Debit)';
      fromTitle = 'Transfer from';
      fromSubtitle = ' (Credit)';
    }

    Widget buildHeader(String title, String subtitle) {
      return RichText(
        text: TextSpan(
          text: title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
          children: [
            TextSpan(
              text: subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400, // Dimmed
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(LucideIcons.eye, color: typeColor),
            const SizedBox(width: 12),
            Text(
              'Preview $typeStr',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please review before ${provider.isEditing ? 'updating' : 'saving'}:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEDF2F7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _rowDetail('Date',
                        DateFormat('yyyy-MM-dd').format(provider.selectedDate)),
                    if (provider.selectedType != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Type',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  typeStr,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    _rowDetail(
                      'Total Amount',
                      '৳ ${NumberFormat('#,##0.00').format(provider.totalDestBDT)}',
                    ),
                    const Divider(height: 16),
                    buildHeader(toTitle, toSubtitle),
                    const SizedBox(height: 4),
                    ...provider.destinations.map(
                      (d) => _rowDetail(
                        d.account?.name ?? 'Unknown',
                        '${d.currency} ${NumberFormat('#,##0.00').format(d.amount)}',
                        icon: LucideIcons.arrowDown,
                        iconColor: const Color(0xFF38A169),
                      ),
                    ),
                    const Divider(height: 16),
                    buildHeader(fromTitle, fromSubtitle),
                    const SizedBox(height: 4),
                    ...provider.sources.map(
                      (s) => _rowDetail(
                        s.account?.name ?? 'Unknown',
                        '${s.currency} ${NumberFormat('#,##0.00').format(s.amount)}',
                        icon: LucideIcons.arrowUp,
                        iconColor: const Color(0xFFD69E2E),
                      ),
                    ),
                    const Divider(height: 16),
                    Text(
                      'Narration',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.mainNarration,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'EDIT',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close preview
              _submitForm(provider, user); // Actually submit
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: typeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              provider.isEditing ? 'CONFIRM UPDATE' : 'CONFIRM SAVE',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(
    BuildContext context,
    TransactionModel tx,
    TransactionProvider provider,
  ) {
    final debits = tx.details.where((d) => d.debit > 0).toList();
    final credits = tx.details.where((d) => d.credit > 0).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(LucideIcons.checkCircle, color: Color(0xFF38A169)),
            const SizedBox(width: 12),
            Text(
              'Success!',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voucher saved successfully!',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF38A169),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDF2F7)),
              ),
              child: Column(
                children: [
                  // Debits
                  ...debits.map(
                    (d) => _rowDetail(
                      'Debit: ${d.account?.name ?? 'Unknown'}',
                      '${d.currency} ${NumberFormat('#,##0.00').format(d.debit)}',
                      icon: LucideIcons.arrowDown,
                      iconColor: const Color(0xFF38A169), // Green
                    ),
                  ),
                  const Divider(height: 16),
                  // Credits
                  ...credits.map(
                    (c) => _rowDetail(
                      'Credit: ${c.account?.name ?? 'Unknown'}',
                      '${c.currency} ${NumberFormat('#,##0.00').format(c.credit)}',
                      icon: LucideIcons.arrowUp,
                      iconColor: const Color(0xFFD69E2E), // Orange/Gold
                    ),
                  ),
                  const Divider(height: 16),
                  _rowDetail('Voucher No', tx.voucherNo),
                  _rowDetail('Date', DateFormat('yyyy-MM-dd').format(tx.date)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  provider.resetForm();
                  Navigator.pop(ctx); // Pop Dialog
                  if (MediaQuery.of(context).size.width >= 800) {
                    context.read<DashboardProvider>().setView(
                          DashboardView.transactions,
                        );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransactionHistoryScreen(),
                      ),
                    );
                  }
                },
                child: Text(
                  'HISTORY',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4299E1),
                    fontSize: 12,
                  ),
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      provider.resetForm();
                      Navigator.pop(ctx);
                      if (MediaQuery.of(context).size.width >= 800) {
                        context.read<DashboardProvider>().popView();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      'HOME',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF718096),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      provider.resetForm(keepDate: true);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38A169),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'ADD NEW',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Widget _buildSimpleForm(
    BuildContext context,
    TransactionProvider provider,
    List<Account> accounts,
    GroupProvider groupProvider,
  ) {
    String fromLabel = 'From (Credit)';
    String toLabel = 'To (Debit)';

    switch (provider.selectedType) {
      case VoucherType.payment:
        toLabel = 'Expense on (Debit)';
        fromLabel = 'Paid from (Credit)';
        break;
      case VoucherType.receipt:
        toLabel = 'Received in (Debit)';
        fromLabel = 'Income from (Credit)';
        break;
      case VoucherType.contra:
        toLabel = 'Transfer to (Debit)';
        fromLabel = 'Transfer from (Credit)';
        break;
      default:
    }

    // Filter for BDT accounts only
    final simpleModeAccounts = accounts
        .where(
          (acc) =>
              acc.defaultCurrency != null &&
              acc.defaultCurrency!.toUpperCase() == 'BDT',
        )
        .toList();

    return _buildSectionCard(
      context: context,
      title: 'Transaction Details',
      icon: LucideIcons.layers,
      child: Column(
        children: [
          AccountAutocomplete(
            key: const ValueKey('simple_dest'),
            initialValue:
                simpleModeAccounts.contains(provider.simpleDestAccount)
                    ? provider.simpleDestAccount
                    : null,
            label: toLabel,
            options: simpleModeAccounts,
            groupProvider: groupProvider,
            onSelected: (acc) => provider.setSimpleDestAccount(acc),
          ),
          const SizedBox(height: 16),
          AccountAutocomplete(
            key: const ValueKey('simple_source'),
            initialValue:
                simpleModeAccounts.contains(provider.simpleSourceAccount)
                    ? provider.simpleSourceAccount
                    : null,
            label: fromLabel,
            options: simpleModeAccounts,
            groupProvider: groupProvider,
            onSelected: (acc) => provider.setSimpleSourceAccount(acc),
          ),
          const SizedBox(height: 16),
          FormattedAmountField(
            initialValue: provider.simpleAmount,
            label: 'Amount (BDT)',
            currency: 'BDT',
            isLarge: true,
            onChanged: (val) => provider.setSimpleAmount(val),
          ),
        ],
      ),
    ).animate().fade(duration: 150.ms);
  }

  Widget _buildTwoListSplitForm(
    BuildContext context,
    TransactionProvider provider,
    List<Account> accounts,
    GroupProvider groupProvider, {
    bool canUseForeignCurrency = false,
  }) {
    String sourceTitle = 'Sources (Credit)';
    String destTitle = 'Destinations (Debit)';

    switch (provider.selectedType) {
      case VoucherType.payment:
        // Debit: Expense on, Credit: Paid from
        destTitle = 'Expense on (Debit)';
        sourceTitle = 'Paid from (Credit)';
        break;
      case VoucherType.receipt:
        // Debit: Received in, Credit: Income from
        destTitle = 'Received in (Debit)';
        sourceTitle = 'Income from (Credit)';
        break;
      case VoucherType.contra:
        // Debit: Transfer to, Credit: Transfer from
        destTitle = 'Transfer to (Debit)';
        sourceTitle = 'Transfer from (Credit)';
        break;
      default:
    }

    return Column(
      children: [
        // Swap: Show Debit (Dest) First
        _buildSplitListComponent(
          title: destTitle,
          entries: provider.destinations,
          accounts: accounts,
          groupProvider: groupProvider,
          onAdd: provider.addDestination,
          onRemove: provider.removeDestination,
          onUpdateAccount: provider.updateDestAccount,
          onUpdateAmount: provider.updateDestAmount,
          onUpdateCurrency: provider.updateDestCurrency,
          onUpdateRate: provider.updateDestRate,
          color: Colors.blue,
          total: provider.totalDestBDT,
          currency: 'BDT',
          canUseForeignCurrency: canUseForeignCurrency,
        ),
        const SizedBox(height: 24),
        // Show Credit (Source) Second
        _buildSplitListComponent(
          title: sourceTitle,
          entries: provider.sources,
          accounts: accounts,
          groupProvider: groupProvider,
          onAdd: provider.addSource,
          onRemove: provider.removeSource,
          onUpdateAccount: provider.updateSourceAccount,
          onUpdateAmount: provider.updateSourceAmount,
          onUpdateCurrency: provider.updateSourceCurrency,
          onUpdateRate: provider.updateSourceRate,
          color: Colors.orange,
          total: provider.totalSourceBDT,
          currency: 'BDT',
          canUseForeignCurrency: canUseForeignCurrency,
        ),
        const SizedBox(height: 16),
        // Balance Check & Conversion Info
        Column(
          children: [
            // Show BDT equivalent breakdown if any line has foreign currency
            if (provider.destinations.any((d) => d.currency != 'BDT') ||
                provider.sources.any((s) => s.currency != 'BDT'))
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  children: [
                    Text(
                      'Debit BDT: ৳ ${CurrencyFormatter.format(provider.totalDestBDT)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Credit BDT: ৳ ${CurrencyFormatter.format(provider.totalSourceBDT)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            if (!provider.isBalanced)
              Text(
                'BDT Difference: ${CurrencyFormatter.format((provider.totalSourceBDT - provider.totalDestBDT).abs())}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Balanced',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _rowDetail(
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? Colors.grey),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitListComponent({
    required String title,
    required List<SplitEntry> entries,
    required List<Account> accounts,
    required GroupProvider groupProvider,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required Function(int, Account?) onUpdateAccount,
    required Function(int, double) onUpdateAmount,
    required Function(int, String) onUpdateCurrency,
    required Function(int, double) onUpdateRate,
    required Color color,
    required double total,
    required String currency,
    bool canUseForeignCurrency = false,
  }) {
    final List<String> availableCurrencies =
        canUseForeignCurrency ? ['BDT', 'USD', 'RM', 'AED'] : ['BDT'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 700;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 6, color: color),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        _buildTotalBadge(total, currency, color),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (entries.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No entries added yet.',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      )
                    else if (isDesktop)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'ACCOUNT',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _headerText('CURRENCY', 1),
                                const SizedBox(width: 12),
                                _headerText('RATE', 1),
                                const SizedBox(width: 12),
                                _headerText('AMOUNT', 2),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: entries.length,
                            itemBuilder: (ctx, index) {
                              final entry = entries[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 48, // Match input height roughly
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: AccountAutocomplete(
                                        key: ValueKey(entry.id),
                                        initialValue:
                                            accounts.contains(entry.account)
                                                ? entry.account
                                                : null,
                                        label: 'Account',
                                        options: accounts,
                                        groupProvider: groupProvider,
                                        onSelected: (acc) =>
                                            onUpdateAccount(index, acc),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 1,
                                      child: _buildCurrencyDropdown(
                                        index,
                                        entry.currency,
                                        availableCurrencies,
                                        onUpdateCurrency,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 1,
                                      child: _buildRateField(
                                        index,
                                        entry,
                                        onUpdateRate,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: FormattedAmountField(
                                        key: ValueKey('amount_${entry.id}'),
                                        initialValue: entry.amount,
                                        label: 'Amount',
                                        currency: entry.currency,
                                        onChanged: (val) =>
                                            onUpdateAmount(index, val),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.grey.shade400,
                                      ),
                                      onPressed: () => onRemove(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entries.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, index) {
                          final entry = entries[index];
                          final isForeign = entry.currency != 'BDT';
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 4,
                                    color: color.withValues(alpha: 0.6),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    12,
                                    12,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: AccountAutocomplete(
                                              key: ValueKey(entry.id),
                                              initialValue: accounts.contains(
                                                entry.account,
                                              )
                                                  ? entry.account
                                                  : null,
                                              label: 'Account',
                                              options: accounts,
                                              groupProvider: groupProvider,
                                              onSelected: (acc) =>
                                                  onUpdateAccount(index, acc),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                            onPressed: () => onRemove(index),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (isForeign)
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: _buildCurrencyDropdown(
                                                index,
                                                entry.currency,
                                                availableCurrencies,
                                                onUpdateCurrency,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 3,
                                              child: _buildRateField(
                                                index,
                                                entry,
                                                onUpdateRate,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        const SizedBox.shrink(),
                                      if (isForeign) const SizedBox(height: 8),
                                      FormattedAmountField(
                                        initialValue: entry.amount,
                                        label: 'Amount (${entry.currency})',
                                        currency: entry.currency,
                                        onChanged: (val) =>
                                            onUpdateAmount(index, val),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        'Add Line',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerText(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown(
    int index,
    String current,
    List<String> options,
    Function(int, String) onUpdate,
  ) {
    return InputDecorator(
      decoration: _buildInputDecoration(
        labelText: 'Curr',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(current) ? current : 'BDT',
          isDense: true,
          isExpanded: true,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          items: options
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (val) => onUpdate(index, val!),
        ),
      ),
    );
  }

  Widget _buildRateField(
    int index,
    SplitEntry entry,
    Function(int, double) onUpdate,
  ) {
    return TextFormField(
      initialValue: entry.rate.toString(),
      enabled: entry.currency != 'BDT',
      decoration: _buildInputDecoration(
        labelText: 'Rate',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.inter(fontSize: 13),
      onChanged: (val) => onUpdate(index, double.tryParse(val) ?? 1.0),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    IconData? icon,
    bool enabled = true,
    Color? fillColor,
    bool isDense = false,
    double? startPadding,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.grey.shade500, size: 20)
          : null,
      filled: true,
      fillColor:
          fillColor ?? (enabled ? Colors.grey.shade50 : Colors.grey.shade100),
      enabled: enabled,
      isDense: isDense,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: contentPadding ??
          (isDense
              ? EdgeInsets.fromLTRB(startPadding ?? 12, 12, 12, 12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: GoogleFonts.inter(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
        fontSize: isDense ? 13 : 14,
      ),
    );
  }

  Widget _buildTotalBadge(double total, String currency, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        'Total: ${CurrencyFormatter.format(total)} $currency',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: color.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class FormattedAmountField extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onChanged;
  final String label;
  final String currency;
  final bool isLarge;

  const FormattedAmountField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.label,
    this.currency = 'BDT',
    this.isLarge = false,
  });

  @override
  State<FormattedAmountField> createState() => _FormattedAmountFieldState();
}

class _FormattedAmountFieldState extends State<FormattedAmountField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(
      text: widget.initialValue == 0
          ? ''
          : CurrencyFormatter.format(widget.initialValue),
    );

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _formatValue();
      }
    });
  }

  @override
  void didUpdateWidget(FormattedAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the external value changed significantly (and we don't have focus), update controller
    if (!_focusNode.hasFocus && widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue == 0
          ? ''
          : CurrencyFormatter.format(widget.initialValue);
    }
  }

  void _formatValue() {
    final text = _controller.text.replaceAll(',', '');
    double val = double.tryParse(text) ?? 0;
    _controller.text = val == 0 ? '' : CurrencyFormatter.format(val);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      style: GoogleFonts.inter(
        fontSize: widget.isLarge ? 18 : 14,
        fontWeight: widget.isLarge ? FontWeight.w800 : FontWeight.w600,
        color: const Color(0xFF2D3748),
      ),
      decoration: InputDecoration(
        labelText: widget.label.toUpperCase(),
        labelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF718096),
          letterSpacing: 0.5,
        ),
        hintText: widget.isLarge ? null : 'Amount',
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFFA0AEC0),
          fontSize: 13,
        ),
        filled: true,
        fillColor: const Color(0xFFF7FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4299E1), width: 1.5),
        ),
        prefixIcon: Container(
          width: widget.isLarge ? 48 : 32,
          alignment: Alignment.center,
          child: Text(
            CurrencyFormatter.getCurrencySymbol(widget.currency),
            style: GoogleFonts.inter(
              fontSize: widget.isLarge ? 18 : 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4299E1),
            ),
          ),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.all(16),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*,?\d*\.?\d*')),
      ],
      onChanged: (val) {
        widget.onChanged(double.tryParse(val.replaceAll(',', '')) ?? 0);
      },
    );
  }
}
