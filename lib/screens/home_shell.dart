import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../widgets/profile_bottom_sheet.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'sales_screen.dart';
import 'alerts_screen.dart';
import 'counter_billing_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _screens = <Widget>[
    DashboardScreen(),
    InventoryScreen(),
    CounterBillingScreen(),
    SalesScreen(),
    AlertsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);
    final colors = AppColors.of(context);
    final profileAsync = ref.watch(pharmacyProfileProvider);
    final cartCount = ref.watch(cartTotalUnitsProvider);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[selectedTab],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileAsync.when(
                data: (profile) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: AppColors.primaryGradient),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.local_pharmacy_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        profile?.pharmacyName ?? 'My Pharmacy',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile != null
                            ? '${profile.area}, ${profile.city}'
                            : '',
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.handlerName ?? '',
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.textHint),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: AppColors.primary),
                title: const Text('Edit Profile',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  final profile = profileAsync.valueOrNull;
                  showProfileBottomSheet(context, ref, profile);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded,
                    color: AppColors.error),
                title: const Text('Sign Out',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authServiceProvider).signOut();
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: colors.surfaceLight, width: 0.5))),
        child: BottomNavigationBar(
          currentIndex: selectedTab,
          onTap: (index) =>
              ref.read(selectedTabProvider.notifier).set(index),
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                activeIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2_rounded),
                label: 'Inventory'),
            BottomNavigationBarItem(
                icon: cartCount > 0
                    ? Badge(
                        label: Text('$cartCount'),
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.point_of_sale_outlined),
                      )
                    : const Icon(Icons.point_of_sale_outlined),
                activeIcon: cartCount > 0
                    ? Badge(
                        label: Text('$cartCount'),
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.point_of_sale_rounded),
                      )
                    : const Icon(Icons.point_of_sale_rounded),
                label: 'Billing'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                activeIcon: Icon(Icons.analytics_rounded),
                label: 'Analytics'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined),
                activeIcon: Icon(Icons.notifications_rounded),
                label: 'Alerts'),
          ],
        ),
      ),
    );
  }
}
