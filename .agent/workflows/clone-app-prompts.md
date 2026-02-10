---
description: Phase-by-phase prompts to create a clone app based on ByteCity Accounting
---

# Clone App Creation - Prompt Guide

নিচের prompts গুলো sequentially ব্যবহার করুন নতুন app তৈরি করতে।

> [!IMPORTANT]
> প্রতিটি phase শেষ হওয়ার পর পরবর্তী phase এর prompt দিন।
> `[YOUR_APP_NAME]` এর জায়গায় আপনার app এর নাম দিন (e.g., `inventory_manager`)

---

## 📋 Phase 1: Project Initialization

```
আমি ByteCity Accounting app এর মতো করে একটি নতুন Flutter app বানাতে চাই।

App Name: [YOUR_APP_NAME]
App Description: [আপনার app এর description]
Company/Org: [com.yourcompany]
Package Name: [your_app_name]

অনুগ্রহ করে:
1. নতুন Flutter project তৈরি করো
2. pubspec.yaml এ প্রয়োজনীয় dependencies যোগ করো (provider, http, shared_preferences, google_fonts, intl, flutter_animate, lucide_icons)
3. flutter pub get চালাও
```

---

## 📁 Phase 2: Folder Structure

```
এখন app এর জন্য proper folder structure তৈরি করো:

lib/
├── core/
│   ├── constants/
│   ├── services/
│   └── utils/
├── models/
├── providers/
├── screens/
│   ├── auth/
│   ├── home/
│   │   └── widgets/
│   └── [other screens]/
├── services/
└── widgets/

সব directories create করো।
```

---

## ⚙️ Phase 3: Core Constants & Services

```
এখন core files তৈরি করো:

1. lib/core/constants/api_constants.dart - API endpoints define করো
   - baseUrl (Google Apps Script URL placeholder)
   - Action constants for API calls

2. lib/core/constants/role_constants.dart - User roles define করো
   - Admin, User, etc.

3. lib/core/services/api_service.dart - HTTP service class
   - POST method for API calls
   - Error handling

4. lib/core/services/session_manager.dart - Session handling
   - Save/Load/Clear user session using SharedPreferences

ByteCity Accounting এর pattern follow করো।
```

---

## 📦 Phase 4: Models

```
এখন data models তৈরি করো:

1. lib/models/user_model.dart
   - id, name, email, role fields
   - fromJson/toJson methods

2. [যদি আপনার app এ অন্য models দরকার হয়, specify করুন]:
   - lib/models/[model_name].dart

ByteCity Accounting এর model pattern follow করো (factory constructors, null safety, etc.)
```

---

## 🔄 Phase 5: Auth Provider

```
এখন authentication provider তৈরি করো:

lib/providers/auth_provider.dart

Features:
- User state management
- isInitialized, isAuthenticated getters
- loadSession() - load saved session
- login(username, password) - API call করে login
- logout() - clear session

ByteCity Accounting এর auth_provider.dart pattern follow করো।
```

---

## 🔄 Phase 6: Additional Providers

```
এখন অন্যান্য providers তৈরি করো:

[আপনার app এর জন্য যে providers দরকার সেগুলো specify করুন]

Example:
1. lib/providers/data_provider.dart - main data management
2. lib/providers/settings_provider.dart - app settings

প্রতিটি provider এ:
- ChangeNotifier extend করো
- State variables
- API integration methods
- notifyListeners() calls

ByteCity Accounting pattern follow করো।
```

---

## 🔐 Phase 7: Login Screen

```
এখন login screen তৈরি করো:

lib/screens/auth/login_screen.dart

Features:
- Username/Password text fields
- Login button with loading state
- Error handling with SnackBar
- Form validation
- Beautiful UI with gradients/animations

ByteCity Accounting এর login_screen.dart reference করো কিন্তু unique design দাও।
```

---

## 🏠 Phase 8: Home Screen

```
এখন home screen তৈরি করো:

lib/screens/home/home_screen.dart

Features:
- AppBar with user info
- Navigation/Menu options
- Main content area
- Logout functionality

[আপনার app এর home screen এ কি কি features চান specify করুন]

Widgets folder এ reusable widgets রাখো।
```

---

## 📱 Phase 9: Additional Screens

```
এখন বাকি screens তৈরি করো:

[আপনার app এ যে screens দরকার list করুন]

Example:
1. lib/screens/[feature]/[feature]_screen.dart
2. lib/screens/profile/profile_screen.dart
3. lib/screens/settings/settings_screen.dart

প্রতিটি screen এ:
- Proper Provider integration
- Loading/Error states
- Beautiful responsive UI
```

---

## 🚀 Phase 10: Main Entry Point

```
এখন main.dart update করো:

lib/main.dart

Features:
- MultiProvider setup with all providers
- MaterialApp configuration
- Theme setup (colors, fonts using Google Fonts)
- AuthWrapper widget for auth state handling
- Home/Login screen routing

ByteCity Accounting এর main.dart pattern follow করো।
```

---

## 🖥️ Phase 11: Backend Setup

```
এখন Google Apps Script backend তৈরি করো:

backend/code.gs

Features:
- doPost(e) function for API handling
- Action-based routing (switch/case)
- [আপনার API functions specify করুন]:
  - loginUser
  - getData
  - saveData
  - etc.
- Google Sheets integration (if needed)
- Success/Error response helpers

ByteCity Accounting এর backend/code.gs reference করো।
```

---

## ✅ Phase 12: Testing & Finalization

```
এখন app test করো এবং finalize করো:

1. flutter analyze চালাও - কোনো error/warning থাকলে fix করো
2. flutter run দিয়ে debug mode এ test করো
3. সব features ঠিকমতো কাজ করছে কিনা check করো
4. UI/UX improvements দরকার থাকলে করো
5. flutter build apk --release দিয়ে APK build করো

কোনো issue থাকলে জানাও।
```

---

## 🎨 Bonus: Customization

```
App customize করতে:

1. Theme colors পরিবর্তন করো - primary color: [YOUR_COLOR]
2. App icon update করো
3. Splash screen add করো
4. [অন্যান্য customization যা চান]
```

---

## 📝 Usage Notes

| Phase | Estimated Time | Dependencies |
|-------|---------------|--------------|
| 1 | 5 min | None |
| 2 | 2 min | Phase 1 |
| 3 | 10 min | Phase 2 |
| 4 | 10 min | Phase 3 |
| 5 | 15 min | Phase 3, 4 |
| 6 | 15 min | Phase 5 |
| 7 | 20 min | Phase 5 |
| 8 | 25 min | Phase 5, 6 |
| 9 | 30+ min | Phase 8 |
| 10 | 10 min | Phase 5-9 |
| 11 | 30+ min | Phase 3 |
| 12 | 15 min | All |

---

## 💡 Tips

- প্রতিটি phase এ specific details দিলে better result পাবেন
- Error হলে error message সহ পরবর্তী prompt দিন
- একসাথে অনেক কিছু না চেয়ে step by step আগান
- UI design এর জন্য reference images দিতে পারেন
