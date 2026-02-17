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
}

class DashboardProvider with ChangeNotifier {
  DashboardView _currentView = DashboardView.home;
  final List<DashboardView> _viewStack = [DashboardView.home];

  DashboardView get currentView => _currentView;
  bool get canPop => _viewStack.length > 1;

  void setView(DashboardView view, {bool clearStack = false}) {
    if (clearStack) {
      _viewStack.clear();
      _viewStack.add(DashboardView.home);
    }

    if (_currentView != view) {
      _currentView = view;
      _viewStack.add(view);
      notifyListeners();
    }
  }

  bool popView() {
    if (_viewStack.length > 1) {
      _viewStack.removeLast();
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
    notifyListeners();
  }
}
