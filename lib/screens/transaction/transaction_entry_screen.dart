import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

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
    // Access GroupProvider to resolve names
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null ? 'Edit Transaction' : 'New Entry',
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActionSelector(transactionProvider),
              const SizedBox(height: 24),

              if (transactionProvider.error != null)
                _buildErrorBanner(transactionProvider),

              if (transactionProvider.selectedType == null)
                _buildEmptyStateHint()
              else
                _buildTransactionForm(
                  context,
                  transactionProvider,
                  accountProvider,
                  groupProvider,
                  user,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionSelector(TransactionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildSegmentButton(
                provider,
                VoucherType.payment,
                'Payment',
                Icons.arrow_upward,
                Colors.redAccent,
              ),
              _buildSegmentButton(
                provider,
                VoucherType.receipt,
                'Receipt',
                Icons.arrow_downward,
                Colors.green,
              ),
              _buildSegmentButton(
                provider,
                VoucherType.contra,
                'Transfer',
                Icons.swap_horiz,
                Colors.blue,
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
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
                color: isSelected ? activeColor : Colors.grey.shade500,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? activeColor : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateHint() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Text(
        'Please select an action above to start.',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
      ),
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
        Row(
          children: [
            Expanded(
              child: InkWell(
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
                              colorSchemeSeed: const Color(0xFF2563EB),
                              brightness: Brightness.light,
                              textTheme: GoogleFonts.interTextTheme(),
                              datePickerTheme: DatePickerThemeData(
                                headerBackgroundColor: const Color(0xFF2563EB),
                                headerForegroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                dayStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (date != null) provider.setDate(date);
                      }
                    : null,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    fillColor: canEditDate ? null : Colors.grey.shade100,
                    filled: !canEditDate,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd').format(provider.selectedDate),
                      ),
                      if (canEditDate)
                        const Icon(Icons.calendar_today, size: 18)
                      else
                        const Icon(Icons.lock, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                key: ValueKey(
                  provider.voucherNo,
                ), // Force rebuild on changes mainly for initial value
                initialValue: provider.voucherNo,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Voucher No',
                  border: const OutlineInputBorder(),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  suffixText: provider.voucherNo == 'AUTO'
                      ? 'Prefix: ${DateFormat('yyMM').format(provider.selectedDate)}'
                      : null,
                  suffixStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Per-line currency is now handled inside each form (simple/split)
        const SizedBox(height: 12),

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

        TextFormField(
          maxLines: 2,
          onChanged: provider.setMainNarration,
          decoration: const InputDecoration(
            labelText: 'Note / Remarks',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: provider.isLoading
                ? null
                : () async {
                    if (!provider.isBalanced) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Voucher is not balanced! Debit must equal Credit.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Default Note Logic
                    if (provider.mainNarration.trim().isEmpty) {
                      provider.setMainNarration("No remark.");
                    }

                    TransactionModel? savedTx;
                    if (provider.isEditing) {
                      final success = await provider.editTransaction(user);
                      if (success) {
                        if (!context.mounted) return;
                        // For edit, we don't hold the return object easily yet, but can construct a dummy or just use current state
                        // To Reuse the dialog, let's create a minimal object from provider state
                        // Actually editTransaction updates the history list.
                        // We can just pop.
                        context.read<AccountProvider>().fetchAccounts(user);
                        context.read<TransactionProvider>().fetchHistory(
                          user,
                          forceRefresh: true,
                        );
                        Navigator.pop(context); // Go back to history
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
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    }

                    if (savedTx != null && context.mounted) {
                      // Show Smart Success Dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Success'),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voucher saved successfully!',
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _rowDetail(
                                      'Voucher No',
                                      savedTx!.voucherNo,
                                    ),
                                    const Divider(),
                                    _rowDetail(
                                      'Date',
                                      DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(savedTx.date),
                                    ),
                                    const Divider(),
                                    _rowDetail(
                                      'Amount',
                                      '${provider.currency} ${NumberFormat('#,##0.00').format(savedTx.totalDebit)}',
                                    ),
                                    const Divider(),
                                    _rowDetail(
                                      'Type',
                                      savedTx.type
                                          .toString()
                                          .split('.')
                                          .last
                                          .toUpperCase(),
                                    ),
                                    if (savedTx.mainNarration.isNotEmpty) ...[
                                      const Divider(),
                                      _rowDetail('Note', savedTx.mainNarration),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'What would you like to do next?',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                provider.resetForm();
                                Navigator.pop(ctx);
                                Navigator.pop(context); // Home
                              },
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text(
                                'Go to Home',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                provider.resetForm();
                                Navigator.pop(ctx);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TransactionHistoryScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text(
                                'View History',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                provider.resetForm(keepDate: true); // Reset
                                Navigator.pop(ctx); // Close Dialog
                              },
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text(
                                'Add Another',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: provider.isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    provider.isEditing
                        ? 'UPDATE TRANSACTION'
                        : 'SAVE TRANSACTION',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 50),
      ],
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Debit (Dest) First
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
          const SizedBox(height: 20),
          // Credit (Source) Second
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
          const SizedBox(height: 20),
          FormattedAmountField(
            initialValue: provider.simpleAmount,
            label: 'Amount (BDT)',
            currency: 'BDT',
            isLarge: true,
            onChanged: (val) => provider.setSimpleAmount(val),
          ),
        ],
      ),
    );
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
          total: provider.totalDestAmount,
          currency: provider.currency,
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
          total: provider.totalSourceAmount,
          currency: provider.currency,
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

  Widget _rowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
    final List<String> availableCurrencies = canUseForeignCurrency
        ? ['BDT', 'USD', 'RM', 'AED']
        : ['BDT'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 700;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
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
      contentPadding:
          contentPadding ??
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
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.isLarge ? null : 'Amount',
        border: const OutlineInputBorder(),
        prefixIcon: Container(
          width: widget.isLarge ? 48 : 32,
          alignment: Alignment.center,
          child: Text(
            CurrencyFormatter.getCurrencySymbol(widget.currency),
            style: TextStyle(
              fontSize: widget.isLarge ? 20 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        isDense: true,
        contentPadding: widget.isLarge
            ? const EdgeInsets.all(16)
            : const EdgeInsets.all(12),
        filled: !widget.isLarge,
        fillColor: widget.isLarge ? null : Colors.white,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*,?\d*\.?\d*')),
      ],
      style: widget.isLarge
          ? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          : null,
      onChanged: (val) {
        widget.onChanged(double.tryParse(val.replaceAll(',', '')) ?? 0);
      },
    );
  }
}
