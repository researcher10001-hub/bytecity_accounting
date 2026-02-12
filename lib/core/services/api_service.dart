import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static void Function()? onUnauthorized;

  Future<dynamic> postRequest(String action, Map<String, dynamic> data) async {
    try {
      // Use Uri.https for better Android compatibility
      // Construct URL: script.google.com, /macros/s/ID/exec, {action: action}
      final Uri baseUri = Uri.parse(ApiConstants.baseUrl);
      final finalUrl = Uri.https('script.google.com', baseUri.path, {
        'action': action,
      });

      print('API Request: $finalUrl');
      print('Request Body: ${jsonEncode(data)}');

      // Simple Request with Manual Redirect Handling
      // 1. Initial POST
      final response = await http
          .post(
            finalUrl,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 60));

      print('API Response Code: ${response.statusCode}');

      // 2. Handle 302 Redirect (Apps Script often returns 302 -> GET)
      if (response.statusCode == 302 ||
          response.statusCode == 301 ||
          response.statusCode == 307 ||
          response.statusCode == 308) {
        String? location;
        response.headers.forEach((key, value) {
          if (key.toLowerCase() == 'location') {
            location = value;
          }
        });

        if (location != null) {
          print('Redirecting to: $location');
          // Apps Script 302 Usually points to the result JSON which should be GET
          final newResponse = await http
              .get(Uri.parse(location!))
              .timeout(const Duration(seconds: 60));

          print('Redirect Response Code: ${newResponse.statusCode}');
          print('Redirect Response Body: ${newResponse.body}');
          return _processResponse(newResponse);
        }
      }

      print('API Response Body: ${response.body}');
      return _processResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      print('API Error for action $action: $e');
      throw ApiException('Network Error: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    final bodyString = response.body.trim();

    // Check for HTML error pages (Apps Script 404/403 often return HTML)
    if (bodyString.toLowerCase().startsWith('<!doctype html>') ||
        bodyString.toLowerCase().startsWith('<html')) {
      print(
        'API returned HTML (Code: ${response.statusCode}): ${bodyString.substring(0, bodyString.length > 500 ? 500 : bodyString.length)}',
      );

      if (response.statusCode == 405) {
        throw ApiException(
          'Server Error (405): Method Not Allowed. Please create a NEW deployment in Apps Script with "Anyone" access.',
        );
      }

      throw ApiException(
        'Server Error (${response.statusCode}): Received HTML instead of JSON. This often happens if the Google Script deployment is not set to "Anyone" or requires a login.',
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final body = jsonDecode(bodyString);

        if (body is Map<String, dynamic>) {
          // Check if it follows the success status pattern
          if (body.containsKey('status')) {
            if (body['status'] == 'success') {
              return body['data'];
            } else {
              final message = body['message'] ?? 'Unknown API error';
              if (message.toString().contains('Unauthorized') ||
                  message.toString().contains('Suspended') ||
                  message.toString().contains('Inactive')) {
                onUnauthorized?.call();
              }
              throw ApiException(message);
            }
          }
          // Direct Map response (like old behavior)
          return body;
        }

        // Direct List or other valid JSON
        return body;
      } on ApiException {
        rethrow;
      } catch (e) {
        throw ApiException(
          'Failed to parse response: $e \nBody: ${response.body}',
        );
      }
    } else if (response.statusCode == 405) {
      throw ApiException(
        'Server Error (405): Method Not Allowed. Use a NEW Deployment with "Anyone" access.',
      );
    } else {
      throw ApiException('HTTP Error: ${response.statusCode}');
    }
  }
}
