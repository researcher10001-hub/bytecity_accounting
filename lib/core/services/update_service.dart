import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/api_service.dart';

class UpdateService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _updateRequired = false;
  String _downloadLink = '';
  String _latestVersion = '';

  bool get isLoading => _isLoading;
  bool get updateRequired => _updateRequired;
  String get downloadLink => _downloadLink;
  String get latestVersion => _latestVersion;

  Future<void> checkForUpdates() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch backend settings
      final response = await _apiService.postRequest('get_app_settings', {});

      if (response != null && response is Map<String, dynamic>) {
        _latestVersion = (response['latest_android_version'] ?? '').toString();

        // Use a more robust boolean check since Apps Script might return 'TRUE' or true
        final forceUpdateRaw = response['force_update_required'];
        final isForceUpdate = forceUpdateRaw == true ||
            forceUpdateRaw?.toString().toUpperCase() == 'TRUE';

        _downloadLink = response['apk_download_link'] ?? '';

        // 2. Get local app version
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        // 3. Compare Version Robustly
        bool needsUpdate = _isVersionLower(currentVersion, _latestVersion);

        if (needsUpdate && isForceUpdate) {
          _updateRequired = true;
        } else {
          _updateRequired = false;
        }
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
      // Fallback to allowing user into the app if update check specifically fails (or choose to block, depending on requirements)
      _updateRequired = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Compares two semantic version strings (e.g., "1.0.0", "3.54", "3.54.0+1").
  /// Returns true if [currentVersion] is STRICTLY LESS THAN [latestVersion].
  bool _isVersionLower(String currentVersion, String latestVersion) {
    try {
      // Clean up versions by removing build numbers (+1, etc.) and non-numeric characters (except dots)
      String cleanCurrent =
          currentVersion.split('+')[0].replaceAll(RegExp(r'[^0-9.]'), '');
      String cleanLatest =
          latestVersion.split('+')[0].replaceAll(RegExp(r'[^0-9.]'), '');

      List<int> currentParts =
          cleanCurrent.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      List<int> latestParts =
          cleanLatest.split('.').map((s) => int.tryParse(s) ?? 0).toList();

      // Pad the shorter list with zeros so we can compare index by index seamlessly
      int maxLength = currentParts.length > latestParts.length
          ? currentParts.length
          : latestParts.length;
      while (currentParts.length < maxLength) currentParts.add(0);
      while (latestParts.length < maxLength) latestParts.add(0);

      for (int i = 0; i < maxLength; i++) {
        if (currentParts[i] < latestParts[i]) {
          return true; // Current is objectively lower
        }
        if (currentParts[i] > latestParts[i]) {
          return false; // Current is actually higher than "latest"
        }
        // If equal, continue to check the next minor/patch segment
      }

      // If we made it through the loop, they are exactly equal
      return false;
    } catch (e) {
      debugPrint("Error parsing versions: $e");
      return false; // Safely default to false if parsing fails
    }
  }
}
