import 'package:flutter/material.dart';
import 'package:inktoon/screens/library_screen.dart';
import 'package:inktoon/screens/search_screen.dart';
import 'package:inktoon/screens/transfer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _screens = [SearchScreen(), LibraryScreen(), TransferScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Recherche',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Bibliothèque',
          ),
          NavigationDestination(
            icon: Icon(Icons.send_to_mobile_outlined),
            selectedIcon: Icon(Icons.send_to_mobile),
            label: 'Transfert',
          ),
        ],
      ),
    );
  }
}
