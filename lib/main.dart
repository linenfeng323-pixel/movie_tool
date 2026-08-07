import 'package:flutter/material.dart';
import 'package:movie_tool/services/storage_service.dart';
import 'package:movie_tool/services/app_provider.dart';
import 'package:movie_tool/pages/home_page.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  await storage.loadBuiltInRules();
  runApp(const MovieToolApp());
}

class MovieToolApp extends StatelessWidget {
  const MovieToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..initTheme(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'MovieTool',
            debugShowCheckedModeBanner: false,
            theme: provider.theme,
            darkTheme: provider.darkTheme,
            themeMode: provider.themeMode,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}