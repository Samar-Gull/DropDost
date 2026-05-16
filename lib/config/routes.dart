import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/customer_home_screen.dart';
import '../screens/rider_home_screen.dart';
import '../screens/create_order_screen.dart';
import '../screens/profile_screen.dart';
class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/': (context) => const SplashScreen(),
    '/login': (context) => const LoginScreen(),
    '/signup': (context) => const SignupScreen(),
    '/customer-home': (context) => const CustomerHomeScreen(),
    '/rider-home': (context) => const RiderHomeScreen(),
    '/create-order': (context) => const CreateOrderScreen(),
    '/profile': (context) => const ProfileScreen(),
  };
}
