import 'dart:convert';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bc_math/core/constants/api_constants.dart';

void main() {
  test('Verify Backend Connectivity and Actions', () async {
    const String baseUrl = ApiConstants.baseUrl;
    print('Testing Base URL: $baseUrl');

    // STEP 1: Check Connectivity with a known existing action
    print('\n--- STEP 1: Checking getAccounts (Connectivity) ---');
    try {
      final response1 = await http.post(
        Uri.parse('$baseUrl?action=getAccounts'),
        headers: {'Content-Type': 'text/plain'},
        body: jsonEncode({}),
      );

      print('Status Code: ${response1.statusCode}');
      if (response1.statusCode == 200 || response1.statusCode == 302) {
        // Good sign
        if (response1.statusCode == 200) {
          print(
            'Body check: ${response1.body.substring(0, 100)}...',
          ); // First 100 chars
        }
      } else {
        print('Failed Connectivity. Status: ${response1.statusCode}');
        print('Body: ${response1.body}');
        return; // Stop if basic connect fails
      }
    } catch (e) {
      print('Exception during proper connectivity check: $e');
      return;
    }

    // STEP 2: Check New Action
    print('\n--- STEP 2: Checking forceLogout (New Feature) ---');
    final Uri url = Uri.parse('$baseUrl?action=forceLogout');
    final payload = {'email': 'test_check_deploy@example.com'};

    var response = await http.post(
      url,
      body: jsonEncode(payload),
      headers: {'Content-Type': 'text/plain'},
    );

    // Follow redirect manually if needed (Apps Script standard)
    if (response.statusCode == 302) {
      final location = response.headers['location'];
      if (location != null) {
        print('Following redirect to: $location');
        response = await http.post(
          Uri.parse(location),
          body: jsonEncode(payload),
          headers: {'Content-Type': 'text/plain'},
        );
      }
    }

    print('Final Response Status: ${response.statusCode}');
    print('Final Response Body: ${response.body}');

    try {
      final body = jsonDecode(response.body);
      final message = body['message'];

      if (message == 'Unknown action') {
        print(
          'RESULT: "Unknown action". \nDIAGNOSIS: The deployment is OLD. User needs to create a NEW VERSION.',
        );
      } else if (message == 'User not found' ||
          message == 'User session revoked (Force Logout)') {
        print('RESULT: Success. Feature exists.');
      } else {
        print('RESULT: Other response: $message');
      }
    } catch (e) {
      print('RESULT: Failed to parse JSON. Might be HTML error page.');
    }
  });
}
