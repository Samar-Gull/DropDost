import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart'; // ADD THIS
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/order_provider.dart';
import 'providers/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // ADD THIS
    );
    runApp(const DropDostApp());
  } catch (e) {
    debugPrint('Firebase initialization error: $e'); // Better logging
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Firebase Error:\n$e'))),
      ),
    );
  }
}

class DropDostApp extends StatelessWidget {
  const DropDostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
      ],
      child: MaterialApp(
        title: 'DropDost',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: AppRoutes.routes,
      ),
    );
  }
}
