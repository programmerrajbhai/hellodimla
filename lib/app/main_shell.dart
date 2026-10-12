import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/02_home/home_screen.dart';
import '../screens/04_menu/menu_screen.dart';
import '../screens/09_shopping_home/shopping_home_screen.dart';
import '../screens/15_business_dashboard/business_dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedIndex = 0;

  late final List<Widget?> pages;

  @override
  void initState() {
    super.initState();

    pages = [
      HomeScreen(
        onOpenStore: () => selectTab(1),
        onOpenMenu: () => selectTab(3),
      ),
      null,
      null,
      null,
    ];
  }

  void selectTab(int index) {
    if (index == selectedIndex) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      pages[index] ??= switch (index) {
        1 => const ShoppingHomeScreen(),
        2 => const BusinessDashboardScreen(),
        3 => const MenuScreen(),
        _ => const SizedBox.shrink(),
      };

      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final largeText =
        MediaQuery.textScalerOf(context).scale(12) > 16;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          for (final page in pages)
            page ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE8EDF5)),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: const Color(0xFFEAF0FF),
            elevation: 0,
            height: largeText ? 92 : 74,
            labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => GoogleFonts.hindSiliguri(
                fontSize: 12,
                height: 1.2,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? const Color(0xFF1959FF)
                    : const Color(0xFF788190),
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                size: 24,
                color: states.contains(WidgetState.selected)
                    ? const Color(0xFF1959FF)
                    : const Color(0xFF788190),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: selectTab,
            animationDuration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 200),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'হোম',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag_rounded),
                label: 'শপিং',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book_rounded),
                label: 'খাতা',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'মেনু',
              ),
            ],
          ),
        ),
      ),
    );
  }
}