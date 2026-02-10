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

class TransactionEntryScreen extends StatefulWidget {
  final TransactionModel? transaction; // Optional transaction for editing

  const TransactionEntryScreen({super.key, this.transaction});

  @override
  State<TransactionEntryScreen> createState() => _TransactionEntryScreenState();
}

class _TransactionEntryScreenState extends State<TransactionEntryScreen> {
  // UI State for Currency Toggle
  bool _showCurrencyOptions = false;

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
      body: SingleChildScrollView(
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
    );
  }

  Widget _buildActionSelector(TransactionProvider provider) {
    return Column(
      children: [
        Text(
          'SELECT ACTION',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionCard(
              provider,
              VoucherType.payment,
              'Payment',
              Icons.arrow_upward,
              Colors.redAccent,
            ),
            const SizedBox(width: 12),
            _buildActionCard(
              provider,
              VoucherType.receipt,
              'Receipt',
              Icons.arrow_downward,
              Colors.green,
            ),
            const SizedBox(width: 12),
            _buildActionCard(
              provider,
              VoucherType.contra,
              'Transfer Money',
              Icons.swap_horiz,
              Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    TransactionProvider provider,
    VoucherType type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = provider.selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => provider.setVoucherType(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.black87,
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
      return PermissionService().canEnterTransaction(user, acc);
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

        // Currency Toggle
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _showCurrencyOptions = !_showCurrencyOptions;
                if (!_showCurrencyOptions) {
                  provider.setCurrency('BDT'); // Reset if hidden
                }
              });
            },
            icon: const Icon(Icons.public, size: 16),
            label: Text(
              _showCurrencyOptions
                  ? 'Hide Currency Options'
                  : 'Change Currency (BDT)',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),

        // Currency Selection Area (On-Demand)
        if (_showCurrencyOptions || provider.currency != 'BDT')
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: provider.currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(10),
                    ),
                    items: ['BDT', 'USD', 'RM', 'AED']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => provider.setCurrency(val!),
                  ),
                ),
                if (provider.currency != 'BDT') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: provider.exchangeRate.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Exchange Rate',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(10),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (val) =>
                          provider.setExchangeRate(double.tryParse(val) ?? 1.0),
                    ),
                  ),
                ],
              ],
            ),
          ),

        const SizedBox(height: 12),

        if (provider.isSplitMode)
          _buildTwoListSplitForm(
            context,
            provider,
            entryAccounts,
            groupProvider,
          )
        else
          _buildSimpleForm(context, provider, entryAccounts, groupProvider),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: () => provider.toggleSplitMode(!provider.isSplitMode),
            child: Text(
              provider.isSplitMode
                  ? 'Switch to Simple Mode'
                  : 'Split Amount / Advanced',
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

                    TransactionModel? savedTx;
                    if (provider.isEditing) {
                      final success = await provider.editTransaction(user);
                      if (success) {
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

    // Request: Debit Label first, Credit Label second
    // Request: Debit Field first, Credit Field second

    switch (provider.selectedType) {
      case VoucherType.payment:
        // Debit: Expense on, Credit: Paid from
        toLabel = 'Expense on (Debit)';
        fromLabel = 'Paid from (Credit)';
        break;
      case VoucherType.receipt:
        // Debit: Received in, Credit: Income from
        toLabel = 'Received in (Debit)';
        fromLabel = 'Income from (Credit)';
        break;
      case VoucherType.contra:
        // Debit: Transfer to, Credit: Transfer from
        toLabel = 'Transfer to (Debit)';
        fromLabel = 'Transfer from (Credit)';
        break;
      default:
    }

    return Container(
      padding: const EdgeInsets.all(20),
      // ... decoration ...
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Swap: Show Debit (Dest) First
          AccountAutocomplete(
            key: const ValueKey('simple_dest'),
            initialValue: accounts.contains(provider.simpleDestAccount)
                ? provider.simpleDestAccount
                : null,
            label: toLabel,
            options: accounts,
            groupProvider: groupProvider,
            onSelected: (acc) => provider.setSimpleDestAccount(acc),
          ),
          const SizedBox(height: 20),
          // Show Credit (Source) Second
          AccountAutocomplete(
            key: const ValueKey('simple_source'),
            initialValue: accounts.contains(provider.simpleSourceAccount)
                ? provider.simpleSourceAccount
                : null,
            label: fromLabel,
            options: accounts,
            groupProvider: groupProvider,
            onSelected: (acc) => provider.setSimpleSourceAccount(acc),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              TextFormField(
                initialValue: provider.simpleAmount == 0
                    ? ''
                    : provider.simpleAmount.toString(),
                decoration: InputDecoration(
                  labelText: 'Amount (${provider.currency})',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(16),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ], // Numeric Only
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (val) =>
                    provider.setSimpleAmount(double.tryParse(val) ?? 0),
              ),
              if (provider.currency != 'BDT') ...[
                const SizedBox(height: 8),
                Text(
                  'Equivalent: ৳${NumberFormat('#,##0.00').format(provider.equivalentBDT)}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTwoListSplitForm(
    BuildContext context,
    TransactionProvider provider,
    List<Account> accounts,
    GroupProvider groupProvider,
  ) {
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
          color: Colors.blue.shade50,
          total: provider.totalDestAmount,
          currency: provider.currency,
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
          color: Colors.orange.shade50,
          total: provider.totalSourceAmount,
          currency: provider.currency,
        ),
        const SizedBox(height: 16),
        // Balance Check & Conversion Info
        Column(
          children: [
            if (provider.currency != 'BDT')
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Total Equivalent BDT: ৳${NumberFormat('#,##0.00').format(provider.equivalentBDT)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            if (!provider.isBalanced)
              Text(
                'Difference: ${(provider.totalSourceAmount - provider.totalDestAmount).abs()}',
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
    required Color color,
    required double total,
    required String currency,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Total: $total $currency',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, index) {
              final entry = entries[index];
              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: 0,
                      ), // Adjust alignment if needed
                      child: AccountAutocomplete(
                        key: UniqueKey(),
                        initialValue: accounts.contains(entry.account)
                            ? entry.account
                            : null,
                        label: 'Select Account',
                        options: accounts,
                        groupProvider: groupProvider,
                        onSelected: (acc) => onUpdateAccount(index, acc),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      initialValue: entry.amount == 0
                          ? ''
                          : entry.amount.toString(),
                      decoration: const InputDecoration(
                        hintText: 'Amount',
                        isDense: true,
                        contentPadding: EdgeInsets.all(12),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      onChanged: (val) =>
                          onUpdateAmount(index, double.tryParse(val) ?? 0),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.grey,
                    ),
                    onPressed: () => onRemove(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              );
            },
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Line', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
