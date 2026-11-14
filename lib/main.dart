import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'services/auth_service.dart';
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
      title: 'Klinixy Pharmacy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: authAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Auth Error: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(authUserProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const LoginScreen();
          }

          final locAsync = ref.watch(pharmacyLocationFutureProvider);

          return locAsync.when(
            loading: () => const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading pharmacy profile...'),
                  ],
                ),
              ),
            ),
            error: (err, _) => Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.store_mall_directory_outlined,
                          size: 56, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Pharmacy Profile Not Found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'This account (${user.email}) does not have a registered pharmacy profile in Firestore yet.\n\nPlease Register / Sign Up your pharmacy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await ref.read(authServiceProvider).signOut();
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign Out & Register'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () =>
                                ref.invalidate(pharmacyLocationFutureProvider),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (loc) {
              return const HomeShell();
            },
          );
        },
      ),
    );
  }
}
