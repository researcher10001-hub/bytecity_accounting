import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Added for JSON decoding
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/user_model.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';
import '../services/permission_service.dart';
import 'account_provider.dart';

// Helper class for UI modification before saving to main model
class SplitEntry {
  final String id; // Stable ID for UI keys
  Account? account;
  double amount;
  String currency; // Per-line currency: 'BDT', 'AED', 'USD', 'RM'
  double rate; // Exchange rate to BDT (1.0 for BDT)

  double get bdtAmount => amount * rate;

  SplitEntry({
    String? id,
    this.account,
    this.amount = 0.0,
    this.currency = 'BDT',
    this.rate = 1.0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

class TransactionProvider with ChangeNotifier {
  // Form State
  DateTime _selectedDate = DateTime.now();
  VoucherType? _selectedType;
  String _voucherNo = '';
  String _mainNarration = '';

  // Currency State (voucher-level kept for backward compat, but per-line is primary)
  String _currency = 'BDT';
  double _exchangeRate = 1.0;

  // Logic: We maintain two temporary lists for the UI
  List<SplitEntry> _sources = [];
  List<SplitEntry> _destinations = [];

  // Transaction History
  List<TransactionModel> _transactions = [];
  final ApiService _apiService = ApiService();

  // Simple Mode State
  bool _isSplitMode = false;

  // Edit Mode State
  bool _isEditing = false;
  String? _editingOldVoucherNo;

  // Loading State
  bool _isLoading = false;
  String? _error;

  // Getters
  DateTime get selectedDate => _selectedDate;
  VoucherType? get selectedType => _selectedType;
  String get voucherNo => _voucherNo;
  String get mainNarration => _mainNarration;
  String get currency => _currency;
  double get exchangeRate => _exchangeRate;

  List<SplitEntry> get sources => _sources;
  List<SplitEntry> get destinations => _destinations;

  TransactionProvider() {
    _loadFromCache();
    resetForm();
  }

  // --- Caching Logic ---
  static const String _cacheKey = 'cached_transactions';

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_cacheKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> data = jsonDecode(jsonString);
        _processResponseData(data); // Re-use parsing logic (refactoring needed)
        notifyListeners();
        print("DEBUG: Loaded ${data.length} transactions from cache.");
      }
    } catch (e) {
      print("Cache Load Error: $e");
    }
  }

  Future<void> _saveToCache(List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      print("Cache Save Error: $e");
    }
  }

  List<TransactionModel> get transactions => _transactions;

  bool get isSplitMode => _isSplitMode;
  bool get isEditing => _isEditing;

  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalSourceAmount =>
      _sources.fold(0, (sum, item) => sum + item.amount);
  double get totalDestAmount =>
      _destinations.fold(0, (sum, item) => sum + item.amount);

  // BDT equivalent totals (for balance checking across currencies)
  double get totalSourceBDT =>
      _sources.fold(0, (sum, item) => sum + item.bdtAmount);
  double get totalDestBDT =>
      _destinations.fold(0, (sum, item) => sum + item.bdtAmount);

  double get equivalentBDT => totalSourceBDT;

  bool get isBalanced => (totalSourceBDT - totalDestBDT).abs() < 0.01;

  void resetForm({bool keepDate = false}) {
    // Standardize to Midnight (00:00:00)
    final now = DateTime.now();

    if (!keepDate) {
      _selectedDate = DateTime(now.year, now.month, now.day);
    } else {
      // If we keep date, we still want to ensure it has valid time if null?
      // No, it's non-nullable.
    }

    _selectedType = null;
    _voucherNo = 'AUTO'; // Server will assign based on YYMM sequence
    _mainNarration = '';
    _currency = 'BDT';
    _exchangeRate = 1.0;
    _sources = [];
    _destinations = [];
    _destinations = [];
    _isSplitMode = false;
    _isEditing = false;
    _editingOldVoucherNo = null;
    _error = null;
    notifyListeners();
  }

  // --- Actions ---

  void setDate(DateTime date) {
    // Normalize to Midnight just in case
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void setCurrency(String currency) {
    _currency = currency;
    if (currency == 'BDT') {
      _exchangeRate = 1.0;
    }
    notifyListeners();
  }

  void setExchangeRate(double rate) {
    _exchangeRate = rate;
    notifyListeners();
  }

  void setVoucherType(VoucherType? type) {
    _selectedType = type;

    // Always initialize with 1 empty row each for Simple Mode compatibility
    if (_sources.isEmpty) _sources = [SplitEntry()];
    if (_destinations.isEmpty) _destinations = [SplitEntry()];

    notifyListeners();
  }

  void setVoucherNo(String no) {
    _voucherNo = no;
    notifyListeners();
  }

  void setMainNarration(String text) {
    _mainNarration = text;
    notifyListeners();
  }

  void toggleSplitMode(bool enable) {
    _isSplitMode = enable;
    if (!enable) {
      // Simple mode = BDT only; reset currencies
      if (_sources.length > 1) _sources = [_sources.first];
      if (_destinations.length > 1) _destinations = [_destinations.first];
      for (var s in _sources) {
        s.currency = 'BDT';
        s.rate = 1.0;
      }
      for (var d in _destinations) {
        d.currency = 'BDT';
        d.rate = 1.0;
      }
    }
    notifyListeners();
  }

  // --- Edit Mode Helper ---
  void setTransactionForEdit(TransactionModel tx) {
    resetForm(keepDate: true); // Reset UI but we will overwrite

    _isEditing = true;
    _editingOldVoucherNo = tx.voucherNo;

    _selectedDate = tx.date;
    _selectedType = tx.type;
    _voucherNo = tx.voucherNo;
    _mainNarration = tx.mainNarration;
    _currency = tx.currency;
    _exchangeRate = tx.exchangeRate;

    // Populate Sources and Destinations with per-line currency/rate
    _sources = [];
    _destinations = [];

    for (var detail in tx.details) {
      if (detail.debit > 0) {
        // Destination (Debit) — use original amount and per-line currency/rate
        _destinations.add(
          SplitEntry(
            account: detail.account,
            amount: detail.debit,
            currency: detail.currency,
            rate: detail.rate,
          ),
        );
      } else {
        // Source (Credit) — use original amount and per-line currency/rate
        _sources.add(
          SplitEntry(
            account: detail.account,
            amount: detail.credit,
            currency: detail.currency,
            rate: detail.rate,
          ),
        );
      }
    }

    // Ensure at least one empty row if empty (safety)
    // Also set Split Mode if multiple rows
    if (_sources.length > 1 || _destinations.length > 1) {
      _isSplitMode = true;
    }
    if (_sources.isEmpty) _sources.add(SplitEntry());
    if (_destinations.isEmpty) _destinations.add(SplitEntry());

    notifyListeners();
  }

  // --- Per-line currency helpers ---
  void updateSourceCurrency(int index, String currency) {
    _sources[index].currency = currency;
    if (currency == 'BDT') _sources[index].rate = 1.0;
    notifyListeners();
  }

  void updateSourceRate(int index, double rate) {
    _sources[index].rate = rate;
    notifyListeners();
  }

  void updateDestCurrency(int index, String currency) {
    _destinations[index].currency = currency;
    if (currency == 'BDT') _destinations[index].rate = 1.0;
    notifyListeners();
  }

  void updateDestRate(int index, double rate) {
    _destinations[index].rate = rate;
    notifyListeners();
  }

  // --- Simple Mode Helpers ---

  Account? get simpleSourceAccount =>
      _sources.isNotEmpty ? _sources[0].account : null;
  Account? get simpleDestAccount =>
      _destinations.isNotEmpty ? _destinations[0].account : null;
  double get simpleAmount => _sources.isNotEmpty ? _sources[0].amount : 0.0;

  void setSimpleSourceAccount(Account? account) {
    if (_sources.isNotEmpty) {
      _sources[0].account = account;
      // Auto-detect currency from account's defaultCurrency
      if (account?.defaultCurrency != null &&
          account!.defaultCurrency!.isNotEmpty) {
        _sources[0].currency = account.defaultCurrency!;
        if (account.defaultCurrency == 'BDT') _sources[0].rate = 1.0;
      }
      notifyListeners();
    }
  }

  void setSimpleDestAccount(Account? account) {
    if (_destinations.isNotEmpty) {
      _destinations[0].account = account;
      // Auto-detect currency from account's defaultCurrency
      if (account?.defaultCurrency != null &&
          account!.defaultCurrency!.isNotEmpty) {
        _destinations[0].currency = account.defaultCurrency!;
        if (account.defaultCurrency == 'BDT') _destinations[0].rate = 1.0;
      }
      notifyListeners();
    }
  }

  void setSimpleAmount(double amount) {
    // Sync both sides for simple mode
    if (_sources.isNotEmpty) _sources[0].amount = amount;
    if (_destinations.isNotEmpty) _destinations[0].amount = amount;
    notifyListeners();
  }

  // --- Split Mode List Actions ---

  void addSource() {
    _sources.add(SplitEntry());
    notifyListeners();
  }

  void removeSource(int index) {
    if (_sources.length > 1) {
      _sources.removeAt(index);
      notifyListeners();
    }
  }

  void updateSourceAccount(int index, Account? account) {
    _sources[index].account = account;
    // Auto-detect currency from account
    if (account?.defaultCurrency != null &&
        account!.defaultCurrency!.isNotEmpty) {
      _sources[index].currency = account.defaultCurrency!;
      if (account.defaultCurrency == 'BDT') _sources[index].rate = 1.0;
    }
    notifyListeners();
  }

  void updateSourceAmount(int index, double amount) {
    _sources[index].amount = amount;
    notifyListeners();
  }

  void addDestination() {
    _destinations.add(SplitEntry());
    notifyListeners();
  }

  void removeDestination(int index) {
    if (_destinations.length > 1) {
      _destinations.removeAt(index);
      notifyListeners();
    }
  }

  void updateDestAccount(int index, Account? account) {
    _destinations[index].account = account;
    // Auto-detect currency from account
    if (account?.defaultCurrency != null &&
        account!.defaultCurrency!.isNotEmpty) {
      _destinations[index].currency = account.defaultCurrency!;
      if (account.defaultCurrency == 'BDT') _destinations[index].rate = 1.0;
    }
    notifyListeners();
  }

  void updateDestAmount(int index, double amount) {
    _destinations[index].amount = amount;
    notifyListeners();
  }

  // --- Validation & Save ---

  bool validate() {
    if (_selectedType == null) {
      _error = 'Please select a Transaction Action.';
      notifyListeners();
      return false;
    }

    // Check Sources
    for (var s in _sources) {
      if (s.account == null) {
        _error = 'Please select all Source Accounts.';
        notifyListeners();
        return false;
      }
      if (s.amount <= 0) {
        _error = 'Please enter valid amounts for Sources.';
        notifyListeners();
        return false;
      }
    }

    // Check Destinations
    for (var d in _destinations) {
      if (d.account == null) {
        _error = 'Please select all Destination Accounts.';
        notifyListeners();
        return false;
      }
      if (d.amount <= 0) {
        _error = 'Please enter valid amounts for Destinations.';
        notifyListeners();
        return false;
      }
    }

    if (!isBalanced) {
      _error =
          'BDT Equivalent mismatch: Source BDT(${totalSourceBDT.toStringAsFixed(2)}) ≠ Dest BDT(${totalDestBDT.toStringAsFixed(2)})';
      notifyListeners();
      return false;
    }

    _error = null;
    return true;
  }

  Future<TransactionModel?> saveTransaction(User user) async {
    if (!validate()) return null;

    // Permission Check Logic (Safe-guard, though UI will also block)
    if (!user.canEditDate &&
        _selectedDate.difference(DateTime.now()).inDays.abs() > 0 &&
        !_isSameDay(_selectedDate, DateTime.now())) {
      _selectedDate = DateTime.now();
    }

    _isLoading = true;
    notifyListeners();

    try {
      // CONVERT Sources/Destinations to TransactionDetail list with per-line currency/rate
      List<TransactionDetail> finalDetails = [];

      // Add Destinations (Debit) FIRST — original amount, per-line currency/rate
      for (var d in _destinations) {
        finalDetails.add(
          TransactionDetail(
            account: d.account,
            credit: 0,
            debit: d.amount, // Original amount (NOT multiplied by rate)
            narration: 'Destination',
            currency: d.currency,
            rate: d.rate,
          ),
        );
      }

      // Add Sources (Credit) SECOND — original amount, per-line currency/rate
      for (var s in _sources) {
        finalDetails.add(
          TransactionDetail(
            account: s.account,
            credit: s.amount, // Original amount (NOT multiplied by rate)
            debit: 0,
            narration: 'Source',
            currency: s.currency,
            rate: s.rate,
          ),
        );
      }

      // Build API Payload with per-line currency/rate
      final Map<String, dynamic> apiPayload = {
        'user_email': user.email,
        'session_token': user.sessionToken,
        'entry': {
          'date':
              "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
          'type': _selectedType.toString().split('.').last,
          'voucher_no': _voucherNo,
          'description': _mainNarration,
          'currency': _currency, // Voucher-level (backward compat)
          'rate': _exchangeRate, // Voucher-level (backward compat)
          'lines': finalDetails.map((d) {
            return {
              'account': d.account?.name ?? 'Unknown',
              'debit': d.debit,
              'credit': d.credit,
              'currency': d.currency,
              'rate': d.rate,
            };
          }).toList(),
        },
      };

      // API Call
      final response = await _apiService.postRequest(
        ApiConstants.actionCreateEntry,
        apiPayload,
      );

      // Update with Server-Assigned Voucher No
      if (response is Map && response['voucher_no'] != null) {
        final serverVoucherNo = response['voucher_no'].toString();
        _voucherNo = serverVoucherNo;

        final updatedTransaction = TransactionModel(
          date: _selectedDate,
          type: _selectedType!,
          voucherNo: serverVoucherNo,
          mainNarration: _mainNarration,
          details: finalDetails,
          createdBy: user.email,
          createdByName: user.name,
          currency: _currency,
          exchangeRate: _exchangeRate,
        );

        print('Saved Transaction: ${updatedTransaction.toJson()}');
        _transactions.insert(0, updatedTransaction);

        return updatedTransaction;
      }

      // Fallback
      final transaction = TransactionModel(
        date: _selectedDate,
        type: _selectedType!,
        voucherNo: _voucherNo,
        mainNarration: _mainNarration,
        details: finalDetails,
        createdBy: user.email,
        currency: _currency,
        exchangeRate: _exchangeRate,
      );
      print('Saved Transaction (Fallback): ${transaction.toJson()}');
      _transactions.insert(0, transaction);

      _isLoading = false;
      return transaction;
    } catch (e) {
      print('Error in saveTransaction: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> editTransaction(User user) async {
    if (!_isEditing || _editingOldVoucherNo == null) return false;
    if (!validate()) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // Build TransactionDetails with per-line currency/rate
      List<TransactionDetail> finalDetails = [];
      for (var d in _destinations) {
        finalDetails.add(
          TransactionDetail(
            account: d.account,
            debit: d.amount, // Original amount
            credit: 0,
            narration: 'Destination',
            currency: d.currency,
            rate: d.rate,
          ),
        );
      }
      for (var s in _sources) {
        finalDetails.add(
          TransactionDetail(
            account: s.account,
            debit: 0,
            credit: s.amount, // Original amount
            narration: 'Source',
            currency: s.currency,
            rate: s.rate,
          ),
        );
      }

      final Map<String, dynamic> apiPayload = {
        'action': 'editEntry',
        'user_email': user.email,
        'old_voucher_no': _editingOldVoucherNo,
        'entry': {
          'date':
              "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
          'type': _selectedType.toString().split('.').last,
          'voucher_no': _voucherNo,
          'description': _mainNarration,
          'currency': _currency,
          'rate': _exchangeRate,
          'lines': finalDetails.map((d) {
            return {
              'account': d.account?.name ?? 'Unknown',
              'debit': d.debit,
              'credit': d.credit,
              'currency': d.currency,
              'rate': d.rate,
            };
          }).toList(),
        },
      };

      await _apiService.postRequest('editEntry', apiPayload);

      // Update Local State
      _transactions.removeWhere((tx) => tx.voucherNo == _editingOldVoucherNo);

      final updatedTransaction = TransactionModel(
        date: _selectedDate,
        type: _selectedType!,
        voucherNo: _voucherNo,
        mainNarration: _mainNarration,
        details: finalDetails,
        createdBy: user.email,
        createdByName: user.name,
        currency: _currency,
        exchangeRate: _exchangeRate,
      );

      _transactions.insert(0, updatedTransaction);
      _transactions.sort((a, b) => b.date.compareTo(a.date));

      _isLoading = false;
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- APPROVAL SYSTEM ---
  Future<bool> addMessage({
    required String voucherNo,
    required String userEmail,
    required String message,
    required String action,
    String? senderName,
    required String entryId, // Add this if available or rely on voucher
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postRequest('addEntryMessage', {
        'voucher_no': voucherNo,
        'entry_id': entryId,
        'user_email': userEmail,
        'sender_name': senderName,
        'message': message,
        'action': action,
      });

      // ApiService returns the 'data' object directly on success, not the full response
      // So if response is not null, it means the API call was successful
      if (response != null) {
        // Optimistically update local state for real-time UI update
        _updateLocalTransactionMessage(
          voucherNo: voucherNo,
          userEmail: userEmail,
          senderName: senderName ?? userEmail,
          message: message,
          action: action,
        );

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to send message';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- FLAGGING SYSTEM (PHASE 3) ---
  Future<bool> flagTransaction({
    required String voucherNo,
    required String adminEmail,
    required String adminName,
    required String reason,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postRequest('flagTransaction', {
        'voucher_no': voucherNo,
        'admin_email': adminEmail,
        'admin_name': adminName,
        'reason': reason,
      });

      if (response != null) {
        _updateLocalFlagStatus(
          voucherNo: voucherNo,
          isFlagged: true,
          flaggedBy: adminEmail,
          flagReason: reason,
          senderName: adminName,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> unflagTransaction({
    required String voucherNo,
    required String adminEmail,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postRequest('unflagTransaction', {
        'voucher_no': voucherNo,
        'admin_email': adminEmail,
      });

      if (response != null) {
        _updateLocalFlagStatus(
          voucherNo: voucherNo,
          isFlagged: false,
          flaggedBy: null,
          flagReason: null,
          senderName: adminEmail,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- ERPNEXT SYNC SYSTEM (PHASE 5) ---
  Future<bool> syncToERPNext({
    required String voucherNo,
    bool isManual = false,
    String? erpDocumentId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postRequest('syncToERPNext', {
        'voucher_no': voucherNo,
        'is_manual': isManual,
        'erp_document_id': erpDocumentId,
      });

      if (response != null) {
        // Extract ERP document ID from response if available
        final erpDocId = response['erp_document_id'] as String?;

        _updateLocalSyncStatus(
          voucherNo: voucherNo,
          status: isManual ? 'manual' : 'synced',
          erpDocumentId: erpDocId,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _updateLocalSyncStatus({
    required String voucherNo,
    required String status,
    String? erpDocumentId,
  }) {
    final index = _transactions.indexWhere((t) => t.voucherNo == voucherNo);
    if (index != -1) {
      final transaction = _transactions[index];
      _transactions[index] = TransactionModel(
        id: transaction.id,
        date: transaction.date,
        type: transaction.type,
        voucherNo: transaction.voucherNo,
        mainNarration: transaction.mainNarration,
        details: transaction.details,
        createdBy: transaction.createdBy,
        createdByName: transaction.createdByName,
        currency: transaction.currency,
        exchangeRate: transaction.exchangeRate,
        status: transaction.status,
        approvalLog: transaction.approvalLog,
        lastActionBy: transaction.lastActionBy,
        isFlagged: transaction.isFlagged,
        flaggedBy: transaction.flaggedBy,
        flaggedAt: transaction.flaggedAt,
        flagReason: transaction.flagReason,
        lastActivityAt: transaction.lastActivityAt,
        lastActivityType: transaction.lastActivityType,
        lastActivityBy: transaction.lastActivityBy,
        erpSyncStatus: status,
        erpDocumentId: erpDocumentId ?? transaction.erpDocumentId,
      );
    }
  }

  void _updateLocalFlagStatus({
    required String voucherNo,
    required bool isFlagged,
    String? flaggedBy,
    String? flagReason,
    required String senderName,
  }) {
    final index = _transactions.indexWhere((t) => t.voucherNo == voucherNo);
    if (index != -1) {
      final transaction = _transactions[index];

      // Add to log as well
      final newLogEntry = ApprovalMessage(
        senderEmail: flaggedBy ?? senderName,
        senderName: senderName,
        senderRole: 'Admin',
        message: isFlagged ? 'FLAGGED: $flagReason' : 'FLAG REMOVED (Resolved)',
        timestamp: DateTime.now(),
        resultingStatus: transaction.status,
        actionType: isFlagged ? 'flag' : 'unflag',
      );

      _transactions[index] = TransactionModel(
        id: transaction.id,
        date: transaction.date,
        type: transaction.type,
        voucherNo: transaction.voucherNo,
        mainNarration: transaction.mainNarration,
        details: transaction.details,
        createdBy: transaction.createdBy,
        currency: transaction.currency,
        exchangeRate: transaction.exchangeRate,
        status: transaction.status,
        approvalLog: [...transaction.approvalLog, newLogEntry],
        lastActionBy: senderName,
        isFlagged: isFlagged,
        flaggedBy: flaggedBy,
        flaggedAt: isFlagged ? DateTime.now() : null,
        flagReason: flagReason,
        lastActivityAt: DateTime.now(),
        lastActivityType: isFlagged ? 'flagged' : 'unflagged',
        lastActivityBy: flaggedBy ?? senderName,
      );
    }
  }

  // Helper method to update local transaction state
  void _updateLocalTransactionMessage({
    required String voucherNo,
    required String userEmail,
    required String senderName,
    required String message,
    required String action,
  }) {
    // Find the transaction in local list
    final index = _transactions.indexWhere((t) => t.voucherNo == voucherNo);

    if (index != -1) {
      final transaction = _transactions[index];

      // OPTIMIZATION: Removed client-side balance calculation
      // accountProvider?.updateBalancesFromTransactions(_transactions);
      // Determine new status based on action
      TransactionStatus newStatus = transaction.status;
      switch (action) {
        case 'approve':
          newStatus = TransactionStatus.approved;
          break;
        case 'reject':
          newStatus = TransactionStatus.rejected;
          break;
        case 'clarify':
          newStatus = TransactionStatus.clarification;
          break;
        case 'comment':
          // Status remains the same for comments
          break;
      }

      // Create new approval log entry
      final newLogEntry = ApprovalMessage(
        senderEmail: userEmail,
        senderName: senderName,
        senderRole: 'User', // Could be enhanced to pass actual role
        message: message,
        timestamp: DateTime.now(),
        resultingStatus: newStatus,
        actionType: action,
      );

      // Create updated transaction with new log entry
      final updatedTransaction = TransactionModel(
        id: transaction.id,
        date: transaction.date,
        type: transaction.type,
        voucherNo: transaction.voucherNo,
        mainNarration: transaction.mainNarration,
        details: transaction.details,
        createdBy: transaction.createdBy,
        currency: transaction.currency,
        exchangeRate: transaction.exchangeRate,
        status: newStatus,
        approvalLog: [...transaction.approvalLog, newLogEntry],
        lastActionBy: userEmail,
        isFlagged: transaction.isFlagged,
        flaggedBy: transaction.flaggedBy,
        flaggedAt: transaction.flaggedAt,
        flagReason: transaction.flagReason,
        lastActivityAt: DateTime.now(),
        lastActivityType: action,
        lastActivityBy: userEmail,
      );

      // Replace in list
      _transactions[index] = updatedTransaction;
    }
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> fetchHistory(
    User? user, {
    bool forceRefresh = false,
    bool skipLoading = false,
    AccountProvider? accountProvider,
  }) async {
    if (user == null) return;

    // Cache Check
    if (!forceRefresh && _transactions.isNotEmpty) return;

    if (!skipLoading) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      // For MVP, we fetch ALL entries.
      // Google Script `getEntries` returns flat rows.
      final response = await _apiService.postRequest('getEntries', {
        'user_email': user.email,
        'limit': 300, // OPTIMIZATION: Fetch only recent 300
      });

      if (response is List) {
        // Cache Success Response
        _saveToCache(response);

        // Process
        _processResponseData(response, accountProvider: accountProvider);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print("Fetch Error: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  // Define _processResponseData
  void _processResponseData(
    List<dynamic> data, {
    AccountProvider? accountProvider,
  }) {
    // Grouping Logic: Use Entry ID (or Voucher No as fallback)
    Map<String, TransactionModel> entryMap = {};

    print("DEBUG: Processing ${data.length} rows.");

    for (var item in data) {
      try {
        String vch = item['voucher_no']?.toString() ?? '';
        String entryId = item['id']?.toString() ?? '';
        String key = entryId.isNotEmpty ? entryId : vch;
        String status = item['approval_status']?.toString() ?? 'pending';

        if (status.toLowerCase() == 'deleted') {
          continue;
        }

        if (!entryMap.containsKey(key)) {
          entryMap[key] = TransactionModel(
            id: entryId,
            voucherNo: vch,
            date: DateTime.parse(item['date']),
            mainNarration: item['description']?.toString() ?? '',
            type: VoucherType.values.firstWhere(
              (e) =>
                  e.toString().split('.').last.toLowerCase() ==
                  (item['type'] ?? 'journal').toString().toLowerCase(),
              orElse: () => VoucherType.journal,
            ),
            currency: item['currency']?.toString() ?? 'BDT',
            exchangeRate: _parseSafeDouble(item['rate'], defaultValue: 1.0),
            createdBy: item['created_by']?.toString() ?? '',
            createdByName: item['created_by_name']?.toString() ??
                item['created_by']?.toString() ??
                '',
            status: TransactionStatus.values.firstWhere(
              (e) =>
                  e.toString().split('.').last ==
                  (item['approval_status'] ?? 'pending')
                      .toString()
                      .toLowerCase(),
              orElse: () => TransactionStatus.pending,
            ),
            approvalLog: (item['approval_log'] != null &&
                    item['approval_log'].toString().isNotEmpty)
                ? (jsonDecode(item['approval_log'].toString()) as List)
                    .map((e) => ApprovalMessage.fromJson(e))
                    .toList()
                : [],
            lastActionBy: item['last_action_by']?.toString(),
            isFlagged:
                item['is_flagged'] == true || item['is_flagged'] == 'true',
            flaggedBy: item['flagged_by']?.toString(),
            flaggedAt: item['flagged_at'] != null &&
                    item['flagged_at'].toString().isNotEmpty
                ? DateTime.tryParse(item['flagged_at'].toString())
                : null,
            flagReason: item['flag_reason']?.toString(),
            lastActivityAt: item['last_activity_at'] != null &&
                    item['last_activity_at'].toString().isNotEmpty
                ? DateTime.tryParse(item['last_activity_at'].toString())
                : null,
            lastActivityType: item['last_activity_type']?.toString(),
            lastActivityBy: item['last_activity_by']?.toString(),
            erpSyncStatus:
                (item['erp_sync_status']?.toString().trim().isEmpty ?? true)
                    ? 'none'
                    : item['erp_sync_status'].toString().trim().toLowerCase(),
            erpDocumentId: item['erp_document_id']?.toString(),
            details: [],
          );
        }

        // Add Detail
        // Look up real account to get permissions
        Account? realAccount;
        if (accountProvider != null) {
          try {
            realAccount = accountProvider.getAccountByName(
              item['account']?.toString() ?? '',
            );
          } catch (e) {}
        }

        entryMap[key]!.details.add(
              TransactionDetail(
                account: realAccount ??
                    Account(
                      name: item['account']?.toString() ?? 'Unknown',
                      owners: [],
                      groupIds: [],
                      type: 'General',
                    ),
                debit: _parseSafeDouble(item['debit']),
                credit: _parseSafeDouble(item['credit']),
                narration: '',
                currency: item['currency']?.toString() ?? 'BDT',
                rate: _parseSafeDouble(item['rate'], defaultValue: 1.0),
              ),
            );
      } catch (e) {
        print("Skipping invalid row: $e");
      }
    }

    _transactions = entryMap.values.toList();
    _transactions.sort((a, b) => b.date.compareTo(a.date));
  }

  /// Alias for silent sync used in periodic timers
  Future<void> syncHistory(User? user, {AccountProvider? accountProvider}) =>
      fetchHistory(
        user,
        forceRefresh: true,
        skipLoading: true,
        accountProvider: accountProvider,
      );

  double _parseSafeDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return defaultValue;
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  // --- Hybrid Permission Logic ---
  List<TransactionModel> getVisibleTransactions(User user) {
    return _transactions.where((tx) {
      // Apply primary permission rules (Admin, Mgmt, Viewer, Creator, Owner)
      if (PermissionService().canViewTransaction(user, tx)) return true;

      // Fallback: Allow "Legacy" transactions that have no creator recorded
      final txOwner = tx.createdBy.trim().toLowerCase();
      return txOwner.isEmpty;
    }).toList();
  }

  // --- Recent Activity (Phase 4) ---
  // Get activities from last 24 hours OR today only for current user
  List<Map<String, dynamic>> getRecentActivity(
    String userEmail, {
    int days = 0, // 0: Last 24h, 1: Today, 2: Yesterday, 7: Last 7 Days
  }) {
    final now = DateTime.now();
    DateTime cutoffStart;
    DateTime? cutoffEnd;

    if (days == 1) {
      // Today (Midnight to now)
      cutoffStart = DateTime(now.year, now.month, now.day);
    } else if (days == 2) {
      // Yesterday (Midnight yesterday to midnight today)
      final yesterday = now.subtract(const Duration(days: 1));
      cutoffStart = DateTime(yesterday.year, yesterday.month, yesterday.day);
      cutoffEnd = DateTime(now.year, now.month, now.day);
    } else if (days == 7) {
      // Last 7 Days
      cutoffStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 7));
    } else {
      // Last 24 hours (Rolling window)
      cutoffStart = now.subtract(const Duration(hours: 24));
    }

    return _transactions
        .where(
          (tx) =>
              tx.lastActivityAt != null &&
              tx.lastActivityAt!.isAfter(cutoffStart) &&
              (cutoffEnd == null || tx.lastActivityAt!.isBefore(cutoffEnd)) &&
              // Show activities where:
              // 1. I am the one who performed the activity
              // 2. I am the creator of the transaction (someone else commented/approved)
              // 3. I am an owner of one of the accounts in the transaction
              (tx.lastActivityBy?.toLowerCase() == userEmail.toLowerCase() ||
                  tx.createdBy.toLowerCase() == userEmail.toLowerCase() ||
                  tx.details.any(
                    (d) =>
                        d.account?.owners.any(
                          (o) => o.toLowerCase() == userEmail.toLowerCase(),
                        ) ??
                        false,
                  )),
        )
        .map(
          (tx) => {
            'id': tx.id ?? tx.voucherNo,
            'type': tx.lastActivityType ?? 'comment',
            'voucher_no': tx.voucherNo,
            'description': tx.mainNarration,
            'amount': tx.totalDebit,
            'currency': tx.currency,
            'timestamp': tx.lastActivityAt!.toIso8601String(),
            'transaction_id': tx.id ?? tx.voucherNo,
          },
        )
        .toList()
      ..sort((a, b) {
        final aTime = DateTime.parse(a['timestamp'].toString());
        final bTime = DateTime.parse(b['timestamp'].toString());
        return bTime.compareTo(aTime); // Newest first
      });
  }

  Map<String, int> getActivityStats(String userEmail, {int days = 0}) {
    final activities = getRecentActivity(userEmail, days: days);
    return {
      'approved': activities.where((a) => a['type'] == 'approve').length,
      'rejected': activities.where((a) => a['type'] == 'reject').length,
      'responded': activities.where((a) => a['type'] == 'respond').length,
      'commented': activities.where((a) => a['type'] == 'comment').length,
      'flagged': activities.where((a) => a['type'] == 'flag').length,
    };
  }

  List<Map<String, dynamic>> getApprovedActivities(
    String userEmail, {
    int days = 0,
  }) {
    final now = DateTime.now();
    DateTime cutoffTime;

    if (days == 1) {
      cutoffTime = DateTime(now.year, now.month, now.day);
    } else if (days == 2) {
      // Just for approval logic if needed
      final yesterday = now.subtract(const Duration(days: 1));
      cutoffTime = DateTime(yesterday.year, yesterday.month, yesterday.day);
    } else {
      cutoffTime = now.subtract(const Duration(hours: 24));
    }

    return _transactions
        .where(
          (tx) =>
              tx.lastActivityAt != null &&
              tx.lastActivityAt!.isAfter(cutoffTime) &&
              tx.lastActivityBy?.toLowerCase() == userEmail.toLowerCase() &&
              tx.lastActivityType == 'approve' && // Only approved
              tx.status == TransactionStatus.approved, // Double check status
        )
        .map(
          (tx) => {
            'id': tx.id ?? tx.voucherNo,
            'type': 'approve',
            'voucher_no': tx.voucherNo,
            'description': tx.mainNarration,
            'amount': tx.totalDebit,
            'currency': tx.currency,
            'timestamp': tx.lastActivityAt!.toIso8601String(),
            'transaction_id': tx.id ?? tx.voucherNo,
          },
        )
        .toList()
      ..sort((a, b) {
        final aTime = DateTime.parse(a['timestamp'].toString());
        final bTime = DateTime.parse(b['timestamp'].toString());
        return bTime.compareTo(aTime); // Newest first
      });
  }
}
