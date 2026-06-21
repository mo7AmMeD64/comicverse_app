import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(const ComicverseApp());
}

class ComicverseApp extends StatelessWidget {
  const ComicverseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comicverse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const MainShell(),
    );
  }
}
