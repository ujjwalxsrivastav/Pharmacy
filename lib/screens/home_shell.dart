import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
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

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[selectedTab],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.surfaceLight, width: 0.5))),
        child: BottomNavigationBar(
          currentIndex: selectedTab,
          onTap: (index) => ref.read(selectedTabProvider.notifier).set(index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), activeIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2_rounded), label: 'Inventory'),
            BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_outlined), activeIcon: Icon(Icons.point_of_sale_rounded), label: 'Billing'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics_rounded), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications_rounded), label: 'Alerts'),
          ],
        ),
      ),
    );
  }
}
