import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agro_shift/presentation/providers/agro_providers.dart';

import 'screens/dashboard_screen.dart';
import 'screens/environmental_analysis_screen.dart';
import 'screens/rotation_laboratory_screen.dart';
import 'screens/field_management_screen.dart';
import 'screens/scientific_provenance_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    EnvironmentalAnalysisScreen(),
    RotationLaboratoryScreen(),
    FieldManagementScreen(),
    ScientificProvenanceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationTabIndexProvider);

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(navigationTabIndexProvider.notifier).setTab(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'المناخ',
          ),
          NavigationDestination(
            icon: Icon(Icons.autorenew_outlined),
            selectedIcon: Icon(Icons.autorenew),
            label: 'الدورات',
          ),
          NavigationDestination(
            icon: Icon(Icons.nature_people_outlined),
            selectedIcon: Icon(Icons.nature_people),
            label: 'الحقول',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'المنهجية',
          ),
        ],
      ),
    );
  }
}
