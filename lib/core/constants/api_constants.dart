class ApiConstants {
  // TODO: Replace with your deployed Google Apps Script Web App URL
  static const String baseUrl =
      'https://script.google.com/macros/s/AKfycbzS4iQYMEUUdorR4Qd8EFxZzi99ZM7E8MpNOWHyzv1Gxy5iUuZDb6nJhXcArdbUgKhs/exec';

  static const String actionLogin = 'loginUser';
  static const String actionGetAccounts = 'getAccounts';
  static const String actionCreateAccount = 'createAccount';
  static const String actionUpdateAccount = 'updateAccount';
  static const String actionDeleteAccount = 'deleteAccount';

  static const String actionGetEntries = 'getEntries';
  static const String actionCreateEntry = 'createEntry';
  static const String actionDeleteEntry = 'deleteEntry';
  static const String actionEditEntry = 'editEntry';
  static const String actionAddEntryMessage = 'addEntryMessage';

  // Restored Constants
  static const String actionSaveTransaction =
      'saveTransaction'; // Used in TransactionProvider
  static const String actionGetSubCategories =
      'getSubCategories'; // Used in SubCategoryProvider
  static const String actionCreateSubCategory =
      'createSubCategory'; // Used in SubCategoryProvider
  static const String actionUpdateSubCategory =
      'updateSubCategory'; // Used in SubCategoryProvider
  static const String actionDeleteSubCategory =
      'deleteSubCategory'; // Used in SubCategoryProvider

  static const String actionGetUsers = 'getUsers';
  static const String actionCreateUser = 'createUser';
  static const String actionUpdateUser = 'updateUser';
  static const String actionDeleteUser = 'deleteUser';
  static const String actionForceLogout = 'forceLogout';
  static const String actionCheckSession = 'checkSession';
  static const String actionChangePassword = 'changePassword';
  static const String actionResetTestUsers = 'resetTestUsers';

  static const String actionGetGroups = 'getGroups';
  static const String actionCreateGroup = 'createGroup';
  static const String actionUpdateGroup = 'updateGroup';
  static const String actionDeleteGroup = 'deleteGroup';

  static const String actionGetSettings = 'getSettings';
  static const String actionUpdateSettings = 'updateSettings';

  static const String actionFlagForReview = 'flagForReview';
  static const String actionFlagTransaction = 'flagTransaction';
  static const String actionUnflagTransaction = 'unflagTransaction';

  static const String actionGetAdminDashboard = 'getAdminDashboard';
}
