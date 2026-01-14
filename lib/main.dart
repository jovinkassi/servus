// main.dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const ServusApp());
}

class ServusApp extends StatelessWidget {
  const ServusApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Servus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const HomePage(),
    );
  }
}