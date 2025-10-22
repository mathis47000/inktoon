import 'package:flutter/material.dart';
import 'package:inktoon/screens/search_screen.dart';
import 'package:inktoon/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inktoon',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const SearchScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
