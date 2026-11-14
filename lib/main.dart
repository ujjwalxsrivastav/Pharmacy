import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: PharmaDashApp()));
}

class PharmaDashApp extends ConsumerWidget {
  const PharmaDashApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    final authAsync = ref.watch(authUserProvider);

    return MaterialApp(
      title: 'PharmaDash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: authAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const LoginScreen(),
        data: (user) {
          if (user == null) {
            // Clear location on logout
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(pharmacyLocationProvider.notifier).state = null;
              ref.read(currentPharmacyIdProvider.notifier).state = null;
            });
            return const LoginScreen();
          }

          // User is logged in — resolve city/area if not done yet
          final loc = ref.read(pharmacyLocationProvider);
          if (loc == null) {
            // Trigger lookup asynchronously
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final path = await ref
                  .read(authServiceProvider)
                  .resolvePharmacyPath(user.uid);
              if (path != null) {
                ref.read(pharmacyLocationProvider.notifier).state =
                    PharmacyLocation(
                  uid: user.uid,
                  city: path['city']!,
                  area: path['area']!,
                );
                ref.read(currentPharmacyIdProvider.notifier).state = user.uid;
              }
            });
            // Show loading while resolving
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return const HomeShell();
        },
      ),
    );
  }
}
