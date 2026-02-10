import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/account_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/user_provider.dart';

import 'providers/group_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/sub_category_provider.dart';

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
        ChangeNotifierProxyProvider<AuthProvider, AccountProvider>(
          create: (_) => AccountProvider(),
          update: (_, auth, previous) => previous!,
        ),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),

        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(
          create: (_) => SubCategoryProvider()..fetchSubCategories(),
        ),
      ],
      child: MaterialApp(
        title: 'ByteCity Accounting',
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
          // Show splash only during initial session check
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
