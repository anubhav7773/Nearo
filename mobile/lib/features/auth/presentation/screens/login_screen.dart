import 'package:flutter/material.dart';
import 'otp_login_screen.dart';

class LoginScreen extends StatelessWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  Widget build(BuildContext context) {
    return OtpLoginScreen(onLoginSuccess: onLoginSuccess);
  }
}
