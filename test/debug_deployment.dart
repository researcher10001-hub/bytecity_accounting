// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String baseUrl =
      'https://script.google.com/macros/s/AKfycbw85rnfscdznTeV3kGXbAFD2r0glMXzN6Awn7_TPx1798Qpvbgylzh8FGvmBXHoYhk2/exec';

  print('Testing Connection to: $baseUrl');

  try {
    // 1. Test Force Logout Action
    // We send a request that SHOULD be handled by the new 'forceLogout' case.
    // Even with a dummy email, it should return "User not found" or "Missing email",
    // NOT "Unknown action".

    final Uri url = Uri.parse('$baseUrl?action=forceLogout');
    final payload = {'email': 'test_debug@example.com'};

    final response = await http.post(
      url,
      body: jsonEncode(payload),
      headers: {'Content-Type': 'text/plain'}, // Apps Script quirk
    );

    print('Response Code: ${response.statusCode}');

    if (response.statusCode == 302) {
      print('Redirect detected (Standard Apps Script behavior). Following...');
      final location = response.headers['location'];
      if (location != null) {
        final newResponse = await http.post(
          Uri.parse(location),
          body: jsonEncode(payload),
          headers: {'Content-Type': 'text/plain'},
        );
        print('Redirect Response Body: ${newResponse.body}');
      }
    } else {
      print('Response Body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
