import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_constants.dart';
import 'app_localizations.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'splash_screen.dart';
import 'wrapper_screen.dart';
import 'settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AppLocalizations.init(); // Initialize language preferences
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder rebuilds the app when language changes
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalizations.currentLanguage,
      builder: (context, language, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            scaffoldBackgroundColor: AppColors.background,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          initialRoute: '/splash',
          routes: {
            '/splash': (_) => const SplashScreen(),
            '/wrapper': (_) => const WrapperScreen(),
            '/home': (_) => const HomeScreen(),
            '/login': (_) => const LoginScreen(),
            '/signup': (_) => const SignupScreen(),
            '/forgot-password': (_) => const ForgotPasswordScreen(),
            '/settings': (_) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
