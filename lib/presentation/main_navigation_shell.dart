import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/environmental_analysis_screen.dart';
import 'screens/rotation_laboratory_screen.dart';
import 'screens/field_management_screen.dart';
import 'screens/scientific_provenance_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    EnvironmentalAnalysisScreen(),
    RotationLaboratoryScreen(),
    FieldManagementScreen(),
    ScientificProvenanceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
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
