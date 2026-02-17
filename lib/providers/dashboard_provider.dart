import 'package:flutter/material.dart';

enum DashboardView {
  home,
  transactions,
  search,
  settings,
  ledger,
  pending,
  erpSync,
  ownedAccounts,
  transactionEntry,
  manageUsers,
  chartOfAccounts,
  manageGroups,
  auditDashboard,
  subCategories,
  erpSettings,
  transactionDetail,
  profile,
}

class DashboardProvider with ChangeNotifier {
  DashboardView _currentView = DashboardView.home;
  final List<DashboardView> _viewStack = [DashboardView.home];
  final List<dynamic> _argsStack = [null]; // Keep args in sync with views

  DashboardView get currentView => _currentView;
  dynamic get currentArguments => _argsStack.last;
  bool get canPop => _viewStack.length > 1;

  void setView(DashboardView view, {bool clearStack = false, dynamic args}) {
    if (clearStack) {
      _viewStack.clear();
      _viewStack.add(DashboardView.home);
      _argsStack.clear();
      _argsStack.add(null);
    }

    if (_currentView != view || _argsStack.last != args) {
      _currentView = view;
      _viewStack.add(view);
      _argsStack.add(args);
      notifyListeners();
    }
  }

  bool popView() {
    if (_viewStack.length > 1) {
      _viewStack.removeLast();
      _argsStack.removeLast();
      _currentView = _viewStack.last;
      notifyListeners();
      return true;
    }
    return false;
  }

  void reset() {
    _currentView = DashboardView.home;
    _viewStack.clear();
    _viewStack.add(DashboardView.home);
    _argsStack.clear();
    _argsStack.add(null);
    notifyListeners();
  }
}
