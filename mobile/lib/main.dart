import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/constants/colors.dart';
import 'core/network/api_client.dart';
import 'core/network/secure_storage.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/emergency_setup_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/phone_verification_screen.dart';
import 'features/feed/presentation/bloc/feed_bloc.dart';
import 'features/feed/presentation/screens/directory_screen.dart';
import 'features/feed/presentation/screens/feed_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/sos/presentation/bloc/sos_bloc.dart';
import 'features/sos/presentation/screens/sos_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await FCMNotificationService().initialize();
  } catch (_) {}
  runApp(const NearoApp());
}

class NearoApp extends StatefulWidget {
  const NearoApp({super.key});

  @override
  State<NearoApp> createState() => _NearoAppState();
}

class _NearoAppState extends State<NearoApp> {
  final AuthBloc _authBloc = AuthBloc();

  bool _isAuthenticated = false;
  bool _hasUserPhone = true;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    ApiClient().onUnauthorized = () {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _hasUserPhone = true;
        });
      }
    };
    _authBloc.add(CheckAuthStatus());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  Future<void> _checkPhoneStatus() async {
    bool hasPhone = await SecureStorageService.hasUserPhone();
    if (!hasPhone) {
      try {
        final response = await ApiClient().dio.get('/api/v1/users/me');
        if (response.statusCode == 200 && response.data != null) {
          final phone = response.data['phone_number'] ?? response.data['phone'];
          if (phone != null && phone.toString().trim().isNotEmpty) {
            await SecureStorageService.saveUserPhone(phone.toString().trim());
            hasPhone = true;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _hasUserPhone = hasPhone;
      });
    }
  }

  void _onLoginSuccess() async {
    await _checkPhoneStatus();
    if (mounted) {
      setState(() {
        _isAuthenticated = true;
      });
    }
  }

  void _onPhoneVerificationComplete() {
    setState(() {
      _hasUserPhone = true;
    });
  }

  void _onLogout() {
    _authBloc.add(SignOutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
        BlocProvider<FeedBloc>(create: (_) => FeedBloc()),
        BlocProvider<SosBloc>(create: (_) => SosBloc()),
      ],
      child: MaterialApp(
        title: 'Nearo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routes: {
          '/emergency-number-setup': (context) => const EmergencySetupScreen(),
          '/emergency-setup': (context) => const EmergencySetupScreen(),
          '/phone-verification': (context) => PhoneVerificationScreen(
                onVerificationComplete: () => Navigator.of(context).pop(),
              ),
        },
        home: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) async {
            if (state is AuthAuthenticated) {
              await _checkPhoneStatus();
              if (mounted) {
                setState(() {
                  _isAuthenticated = true;
                  _isCheckingAuth = false;
                });
              }
            } else if (state is AuthUnauthenticated || state is AuthFailure) {
              if (mounted) {
                setState(() {
                  _isAuthenticated = false;
                  _hasUserPhone = true;
                  _isCheckingAuth = false;
                });
              }
            }
          },
          child: _isCheckingAuth
              ? const Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryBlue),
                  ),
                )
              : _isAuthenticated
                  ? (!_hasUserPhone
                      ? PhoneVerificationScreen(
                          onVerificationComplete: _onPhoneVerificationComplete,
                        )
                      : MainNavigationScreen(onLogout: _onLogout))
                  : LoginScreen(onLoginSuccess: _onLoginSuccess),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MainNavigationScreen({super.key, required this.onLogout});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const FeedScreen(),
      const DirectoryScreen(),
      const SosScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Radius Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Directory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            activeIcon: Icon(Icons.shield, color: AppColors.sosRed),
            label: 'Civic SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
