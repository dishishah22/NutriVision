import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spectrum_flutter/firebase_options.dart';
import 'package:spectrum_flutter/screens/fitness_sync_dashboard.dart';
import 'package:spectrum_flutter/screens/home_screen.dart';
import 'package:spectrum_flutter/screens/login_screen.dart';
import 'package:spectrum_flutter/screens/signup_screen.dart';
import 'package:spectrum_flutter/services/auth_service.dart';
import 'package:spectrum_flutter/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:spectrum_flutter/services/app_config_server.dart';

import 'package:provider/provider.dart';
import 'package:spectrum_flutter/providers/user_nutrition_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Ensure Google Sign In is initialized (required for v7+)
  try {
    await GoogleSignIn.instance.initialize();
  } catch (e) {
    debugPrint("GoogleSignIn init failed: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appConfig = AppConfigServer();

  @override
  void initState() {
    super.initState();
    _appConfig.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserNutritionProvider()),
      ],
      child: MaterialApp(
        title: 'NutriVision',
        debugShowCheckedModeBanner: false,
        themeMode: _appConfig.themeMode,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.accent,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF111827),
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.accent,
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        ),
        locale: _appConfig.locale,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          
          // Sync User ID with Nutrition Provider
          if (user != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
               // Use read to avoid unnecessary rebuilds of AuthWrapper
               // We only want to set the ID if it's different to prevent loops, 
               // but setUserId in provider can handle that check internally if needed.
               // For now, we just set it. provider.setUserId checks usually aren't strict, 
               // let's double check provider logic. 
               // Adding a check here is safer.
               final provider = context.read<UserNutritionProvider>();
               if (provider.userId != user.uid) {
                 provider.setUserId(user.uid);
               }
            });
            return const FitnessSyncDashboard();
          } else {
             // Clear user on logout
             WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<UserNutritionProvider>().clearUser();
             });
             return const LoginScreen();
          }
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
