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
  bool _hasEmergencyContact = true;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    ApiClient().onUnauthorized = () {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _hasEmergencyContact = true;
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

  void _onLoginSuccess() async {
    final hasContact = await SecureStorageService.hasEmergencyContact();
    if (mounted) {
      setState(() {
        _isAuthenticated = true;
        _hasEmergencyContact = hasContact;
      });
    }
  }

  void _onEmergencySetupComplete() {
    setState(() {
      _hasEmergencyContact = true;
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
        home: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) async {
            if (state is AuthAuthenticated) {
              final hasContact = await SecureStorageService.hasEmergencyContact();
              if (mounted) {
                setState(() {
                  _isAuthenticated = true;
                  _hasEmergencyContact = hasContact;
                  _isCheckingAuth = false;
                });
              }
            } else if (state is AuthUnauthenticated || state is AuthFailure) {
              if (mounted) {
                setState(() {
                  _isAuthenticated = false;
                  _hasEmergencyContact = true;
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
                  ? (!_hasEmergencyContact
                      ? EmergencySetupScreen(onComplete: _onEmergencySetupComplete)
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
