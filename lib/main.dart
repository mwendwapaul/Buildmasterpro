import 'package:build_masterpro/features/auth/screens/forgot_password_screen.dart';
import 'package:build_masterpro/features/auth/screens/register_screen.dart';
import 'package:build_masterpro/features/projects/screens/about_my_app_screen.dart';
import 'package:build_masterpro/features/projects/screens/capture_photos_screen.dart';
import 'package:build_masterpro/features/projects/screens/checklists_screen.dart';
import 'package:build_masterpro/features/projects/screens/daily_logs_screen.dart';
import 'package:build_masterpro/features/projects/screens/profile_screen.dart';
import 'package:build_masterpro/features/projects/screens/submit_reports_screen.dart';
import 'package:build_masterpro/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/projects/screens/home_screen.dart';
import 'features/projects/screens/project_management_screen.dart';
import 'features/projects/screens/document_management_screen.dart';
import 'features/projects/screens/communication_tools_screen.dart';
import 'features/projects/screens/field_reporting_screen.dart';
import 'features/projects/screens/resource_management_screen.dart';
import 'features/projects/screens/financial_management_screen.dart';
import 'features/projects/screens/time_tracking_screen.dart';
import 'features/projects/screens/safety_management_screen.dart';
import 'features/projects/screens/user_management_screen.dart';
import 'features/projects/screens/analytics_reporting_screen.dart';
import 'core/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, 
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'BuildMasterPro',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF006D77),
            primary: const Color(0xFF006D77),
            secondary: const Color(0xFF83C5BE),
          ),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          '/project_management': (context) => const ProjectManagementScreen(),
          '/document_management': (context) => const DocumentManagementScreen(),
          '/communication_tools': (context) => const CommunicationToolsScreen(),
          '/field_reporting': (context) => const FieldReportingScreen(),
          '/resource_management': (context) => const ResourceManagementScreen(),
          '/financial_management': (context) => const FinancialManagementScreen(),
          '/time_tracking': (context) => const TimeTrackingScreen(),
          '/safety_management': (context) => const SafetyManagementScreen(),
          '/user_management': (context) => const UserManagementScreen(),
          '/analytics_reporting': (context) => const AnalyticsReportingScreen(),
          '/profile': (context) => ProfileScreen(
          username: 'User123',
          email: 'user@example.com',
          onLogout: () {
          },
        ),
        '/fieldReport': (context) => const FieldReportingScreen(),
        '/dailyLogs': (context) => const DailyLogsScreen(),
        '/capturePhotos': (context) => const CapturePhotosScreen(),
        '/checklists': (context) => const ChecklistsScreen(),
        '/submitReports': (context) => const SubmitReportScreen(userId: '',),
        '/about_app': (context) => const AboutMyAppScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return StreamBuilder<User?>(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              final User? user = snapshot.data;
              if (user == null) {
                return const LoginScreen();
              }
              return const HomeScreen();
            }
            
            // Show loading indicator while checking auth state
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        );
      },
    );
  }
}