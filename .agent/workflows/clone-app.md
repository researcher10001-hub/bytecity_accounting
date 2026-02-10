---
description: How to create a clone app based on ByteCity Accounting
---

# Clone App Creation Workflow

এই workflow অনুসরণ করে আপনি ByteCity Accounting app-এর structure ব্যবহার করে নতুন একটি clone app তৈরি করতে পারবেন।

---

## Phase 1: Project Setup (প্রজেক্ট সেটআপ)

### Step 1.1: Create New Flutter Project

```bash
# নতুন project directory-তে যান
cd c:\Antigravity\[YourAppName]

# Flutter project তৈরি করুন
flutter create --org com.yourcompany your_app_name
cd your_app_name
```

### Step 1.2: Update pubspec.yaml

নিম্নলিখিত dependencies যোগ করুন:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.5+1          # State management
  http: ^1.6.0                 # API calls
  shared_preferences: ^2.5.4  # Local storage
  google_fonts: ^8.0.0         # Typography
  intl: ^0.20.2                # Date/Number formatting
  flutter_typeahead: ^5.2.0    # Autocomplete features
  flutter_animate: ^4.5.2      # Animations
  lucide_icons: ^0.257.0       # Icon library
```

```bash
flutter pub get
```

---

## Phase 2: Folder Structure (ফোল্ডার স্ট্রাকচার)

### Step 2.1: Create lib/ Directory Structure

```
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   ├── api_constants.dart      # API endpoints
│   │   └── role_constants.dart     # User roles
│   ├── services/
│   │   ├── api_service.dart        # HTTP service
│   │   └── session_manager.dart    # Session handling
│   └── utils/
├── models/
│   ├── user_model.dart
│   └── [other_models].dart
├── providers/
│   ├── auth_provider.dart
│   └── [other_providers].dart
├── screens/
│   ├── auth/
│   │   └── login_screen.dart
│   ├── home/
│   │   ├── home_screen.dart
│   │   └── widgets/
│   └── [other_screens]/
├── services/
│   └── permission_service.dart
└── widgets/
    └── [shared_widgets].dart
```

### Step 2.2: Create Directories

```bash
# PowerShell commands
mkdir lib\core\constants
mkdir lib\core\services
mkdir lib\core\utils
mkdir lib\models
mkdir lib\providers
mkdir lib\screens\auth
mkdir lib\screens\home\widgets
mkdir lib\services
mkdir lib\widgets
```

---

## Phase 3: Core Setup (কোর সেটআপ)

### Step 3.1: API Constants

`lib/core/constants/api_constants.dart` তৈরি করুন:

```dart
class ApiConstants {
  // Google Apps Script Web App URL
  static const String baseUrl = 'YOUR_GOOGLE_APPS_SCRIPT_URL';
  
  // Define your API actions
  static const String actionLogin = 'loginUser';
  static const String actionGetData = 'getData';
  // Add more actions as needed
}
```

### Step 3.2: API Service

`lib/core/services/api_service.dart` তৈরি করুন:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  static Future<Map<String, dynamic>> post(String action, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConstants.baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': action, ...data}),
    );
    return jsonDecode(response.body);
  }
}
```

### Step 3.3: Session Manager

`lib/core/services/session_manager.dart` তৈরি করুন:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyUser = 'user_data';
  
  static Future<void> saveUser(String userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, userData);
  }
  
  static Future<String?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUser);
  }
  
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
```

---

## Phase 4: Models (মডেল)

### Step 4.1: User Model

`lib/models/user_model.dart` তৈরি করুন:

```dart
class User {
  final String id;
  final String name;
  final String email;
  final String role;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
  };
}
```

### Step 4.2: Create Additional Models

আপনার app-এর জন্য প্রয়োজনীয় অন্যান্য models তৈরি করুন (Transaction, Account, etc.)

---

## Phase 5: Providers (প্রোভাইডার)

### Step 5.1: Auth Provider

`lib/providers/auth_provider.dart` তৈরি করুন:

```dart
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../core/services/session_manager.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_constants.dart';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isInitialized = false;
  
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;
  
  Future<void> loadSession() async {
    final userData = await SessionManager.getUser();
    if (userData != null) {
      _user = User.fromJson(jsonDecode(userData));
    }
    _isInitialized = true;
    notifyListeners();
  }
  
  Future<bool> login(String username, String password) async {
    final response = await ApiService.post(
      ApiConstants.actionLogin,
      {'username': username, 'password': password},
    );
    
    if (response['success'] == true) {
      _user = User.fromJson(response['user']);
      await SessionManager.saveUser(jsonEncode(_user!.toJson()));
      notifyListeners();
      return true;
    }
    return false;
  }
  
  Future<void> logout() async {
    _user = null;
    await SessionManager.clearSession();
    notifyListeners();
  }
}
```

### Step 5.2: Create Additional Providers

অন্যান্য providers তৈরি করুন যেমন:
- DataProvider (for your main data)
- SettingsProvider
- NotificationProvider

---

## Phase 6: Screens (স্ক্রিন)

### Step 6.1: Login Screen

`lib/screens/auth/login_screen.dart` তৈরি করুন:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  
  Future<void> _login() async {
    setState(() => _isLoading = true);
    
    final success = await context.read<AuthProvider>().login(
      _usernameController.text,
      _passwordController.text,
    );
    
    setState(() => _isLoading = false);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Build your login UI here
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: _usernameController),
            TextField(controller: _passwordController, obscureText: true),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: Text(_isLoading ? 'Loading...' : 'Login'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 6.2: Home Screen

`lib/screens/home/home_screen.dart` তৈরি করুন

### Step 6.3: Other Screens

প্রয়োজন অনুযায়ী অন্যান্য screens তৈরি করুন।

---

## Phase 7: Main Entry Point (মেইন এন্ট্রি পয়েন্ট)

### Step 7.1: Update main.dart

`lib/main.dart` আপডেট করুন:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
// Import other providers
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadSession()),
        // Add other providers
      ],
      child: MaterialApp(
        title: 'Your App Name',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            primary: const Color(0xFF1E88E5),
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.interTextTheme(),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
```

---

## Phase 8: Backend Setup (ব্যাকএন্ড সেটআপ)

### Step 8.1: Google Apps Script

1. [Google Apps Script](https://script.google.com/) এ যান
2. নতুন project তৈরি করুন
3. `Code.gs` ফাইলে backend logic লিখুন

### Step 8.2: Basic Backend Structure

```javascript
function doPost(e) {
  const data = JSON.parse(e.postData.contents);
  const action = data.action;
  
  switch(action) {
    case 'loginUser':
      return loginUser(data);
    case 'getData':
      return getData(data);
    default:
      return error('Unknown action');
  }
}

function loginUser(data) {
  // Your login logic here
}

function getData(data) {
  // Your data fetching logic here
}

function success(data) {
  return ContentService.createTextOutput(
    JSON.stringify({success: true, ...data})
  ).setMimeType(ContentService.MimeType.JSON);
}

function error(message) {
  return ContentService.createTextOutput(
    JSON.stringify({success: false, error: message})
  ).setMimeType(ContentService.MimeType.JSON);
}
```

### Step 8.3: Deploy Backend

1. Deploy > New deployment
2. Web app হিসেবে deploy করুন
3. URL কপি করে `api_constants.dart` এ paste করুন

---

## Phase 9: Testing & Build (টেস্টিং ও বিল্ড)

### Step 9.1: Run in Debug Mode

```bash
flutter run
```

### Step 9.2: Build APK

```bash
flutter build apk --release
```

### Step 9.3: Build App Bundle (Play Store)

```bash
flutter build appbundle --release
```

---

## Customization Checklist (কাস্টমাইজেশন চেকলিস্ট)

- [ ] App name পরিবর্তন করুন (`pubspec.yaml`, `main.dart`)
- [ ] Package name পরিবর্তন করুন (`android/app/build.gradle`)
- [ ] App icon পরিবর্তন করুন
- [ ] Theme colors পরিবর্তন করুন
- [ ] API URL সেট করুন
- [ ] Models আপনার data structure অনুযায়ী তৈরি করুন
- [ ] Providers আপনার business logic অনুযায়ী তৈরি করুন
- [ ] Screens আপনার UI অনুযায়ী design করুন
- [ ] Backend endpoints implement করুন

---

## Reference Files (রেফারেন্স ফাইল)

ByteCity Accounting app থেকে reference নিতে পারেন:

| Component | Reference File |
|-----------|----------------|
| Main Structure | `lib/main.dart` |
| API Constants | `lib/core/constants/api_constants.dart` |
| API Service | `lib/core/services/api_service.dart` |
| User Model | `lib/models/user_model.dart` |
| Auth Provider | `lib/providers/auth_provider.dart` |
| Login Screen | `lib/screens/auth/login_screen.dart` |
| Home Screen | `lib/screens/home/home_screen.dart` |
| Backend | `backend/code.gs` |

---

## Notes (নোটস)

- প্রতিটি step শেষে `flutter analyze` চালান errors check করতে
- নতুন feature যোগ করার আগে existing code structure বুঝুন
- Provider pattern ব্যবহার করে state management করুন
- API calls সবসময় try-catch block এ wrap করুন
- User authentication সবসময় প্রথমে implement করুন
