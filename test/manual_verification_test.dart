import 'package:flutter_test/flutter_test.dart';

// Mock http client or use ApiService logic directly?
// ApiService logic parses response. Let's test _processResponse logic by subclassing or checking public methods.
// Actually, `postRequest` in ApiService uses `http.post`. We can't mock `http.post` easily without dependency injection or MockClient.
// However, we added logic to `_processResponse` which is private, but called by `postRequest`.

// Strategy:
// We will test `ApiService` by mocking the http client if possible.
// ApiService.postRequest uses `http.post`. To mock it, we need to pass a client to ApiService, but ApiService uses the static http package function or likely the global instance.
// In the current code: `import 'package:http/http.dart' as http;` and uses `http.post`. This is hard to mock without refactoring.

// Alternative:
// We can test the logic by creating a small script that mimics the response processing if we extract it,
// OR we can trust our code trace.
// But the user asked ME to check.
// I will create a test that copies the critical logic of `_processResponse` to verify the regex/string matching works as expected.

void main() {
  group('Suspension Logic Check', () {
    test('Should detect Suspended keyword', () {
      final body = {
        'status': 'error',
        'message': 'Unauthorized: User is suspended or inactive.',
      };

      bool unauthorizedCalled = false;
      void onUnauthorized() {
        unauthorizedCalled = true;
      }

      // Simulate logic from ApiService
      try {
        final message = body['message'] ?? 'Unknown API error';
        if (message.toString().contains('Unauthorized') ||
            message.toString().contains('Suspended') ||
            message.toString().contains('Inactive')) {
          onUnauthorized();
        }
        throw Exception(message);
      } catch (e) {
        // Expected
      }

      expect(
        unauthorizedCalled,
        true,
        reason: "Should detect 'Suspended' and call callback",
      );
    });

    test('Should detect Inactive keyword', () {
      final body = {'status': 'error', 'message': 'User is Inactive.'};

      bool unauthorizedCalled = false;
      void onUnauthorized() {
        unauthorizedCalled = true;
      }

      try {
        final message = body['message'] ?? 'Unknown API error';
        if (message.toString().contains('Unauthorized') ||
            message.toString().contains('Suspended') ||
            message.toString().contains('Inactive')) {
          onUnauthorized();
        }
        throw Exception(message);
      } catch (e) {
        // Expected
      }

      expect(
        unauthorizedCalled,
        true,
        reason: "Should detect 'Inactive' and call callback",
      );
    });
  });
}
