import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/network/secure_storage.dart';
import '../../../auth/presentation/screens/phone_verification_screen.dart';
import '../bloc/sos_bloc.dart';
import '../bloc/sos_event.dart';
import '../bloc/sos_state.dart';
import '../widgets/offline_sos_modal.dart';
import 'active_sos_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  String _selectedType = 'security';
  final TextEditingController _descController = TextEditingController();

  double _userLat = 26.7922;
  double _userLng = 82.1998;
  String _locationStatus = 'Locking GPS coordinates...';

  // Long press animation state (1.5 seconds)
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  bool _isHolding = false;

  final List<Map<String, dynamic>> _emergencyTypes = [
    {
      'id': 'security',
      'label': 'Suspicious Activity / Scam',
      'icon': Icons.warning_amber_rounded,
      'color': AppColors.warningOrange,
    },
    {
      'id': 'medical',
      'label': 'Medical Emergency',
      'icon': Icons.local_hospital_outlined,
      'color': AppColors.sosRed,
    },
    {
      'id': 'fire',
      'label': 'Fire / Electrical Hazard',
      'icon': Icons.local_fire_department_outlined,
      'color': Colors.deepOrange,
    },
    {
      'id': 'harassment',
      'label': 'Security / Harassment',
      'icon': Icons.shield_outlined,
      'color': AppColors.primaryBlue,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchGpsLocation();
    // Check if user has an existing active emergency
    context.read<SosBloc>().add(CheckActiveSos());
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        if (mounted) {
          setState(() {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
            _locationStatus =
                '${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E (GPS Lock ±${pos.accuracy.toInt()}m)';
          });
        }
      } else {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null && mounted) {
          setState(() {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
            _locationStatus =
                '${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E (Last Known GPS)';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationStatus = '26.7922° N, 82.1998° E (Ayodhya Central · ±8m)';
        });
      }
    }
  }

  void _startHolding() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    const int totalSteps = 150; // 1500ms / 10ms
    int currentStep = 0;

    _holdTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      currentStep++;
      if (mounted) {
        setState(() {
          _holdProgress = currentStep / totalSteps;
        });
      }

      if (currentStep % 30 == 0) {
        HapticFeedback.heavyImpact();
      }

      if (currentStep >= totalSteps) {
        timer.cancel();
        _triggerSos();
      }
    });
  }

  void _cancelHolding() {
    _holdTimer?.cancel();
    if (_isHolding) {
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
    }
  }

  Future<void> _triggerSos() async {
    final hasPhone = await SecureStorageService.hasUserPhone();
    if (!hasPhone) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please register your mobile number before broadcasting SOS alerts.'),
          backgroundColor: AppColors.sosRed,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhoneVerificationScreen(
            onVerificationComplete: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = false;
      _holdProgress = 1.0;
    });

    context.read<SosBloc>().add(
          TriggerSosRequested(
            category: _selectedType,
            description: _descController.text.trim().isNotEmpty
                ? _descController.text.trim()
                : 'Urgent neighbor assistance required',
            latitude: _userLat,
            longitude: _userLng,
          ),
        );
  }

  void _openOfflineModal() {
    OfflineSosModal.show(
      context,
      latitude: _userLat,
      longitude: _userLng,
      emergencyType: _selectedType,
    );
  }

  void _showFailureDialog(SosDispatchFailure failure) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.sosRed, size: 24),
            SizedBox(width: 8),
            Text('Dispatch Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(failure.errorMessage),
            const SizedBox(height: 12),
            const Text(
              'You can immediately switch to Offline Emergency Mode to send instant SMS alerts with GPS coordinates to police (112) and trusted emergency contacts without internet connectivity.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _triggerSos();
            },
            child: const Text('Retry Dispatch'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sosRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _openOfflineModal();
            },
            icon: const Icon(Icons.offline_bolt, size: 18),
            label: const Text('Offline Mode (112/SMS)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Civic SOS Dispatch',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Offline Emergency Dialer & SMS',
            icon: const Icon(Icons.offline_bolt_outlined, color: AppColors.sosRed),
            onPressed: _openOfflineModal,
          ),
        ],
      ),
      body: BlocConsumer<SosBloc, SosState>(
        listener: (context, state) {
          if (state is SosDispatchedSuccess) {
            HapticFeedback.heavyImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActiveSosScreen(sosEvent: state.sosEvent),
              ),
            );
          } else if (state is SosOfflineFailureState) {
            HapticFeedback.heavyImpact();
            OfflineSosModal.show(
              context,
              latitude: state.latitude,
              longitude: state.longitude,
              emergencyType: state.emergencyType,
            );
          } else if (state is SosDispatchFailure) {
            HapticFeedback.heavyImpact();
            _showFailureDialog(state);
          }
        },
        builder: (context, state) {
          final isDispatching = state is SosDispatchingState;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Active SOS Sticky Banner if an active emergency exists
                    if (state is SosActiveState) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.sosRedLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.sosRed, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield, color: AppColors.sosRed, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'EMERGENCY ALERT ACTIVE',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.sosRed,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dispatched to ${state.dispatchedCount} verified neighbors within ${state.broadcastRadiusMeters} meters.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ActiveSosScreen(sosEvent: state.sosEvent),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.track_changes, size: 18),
                                  label: const Text('Open Tracking View'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.sosRed,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(150, 40),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Instructional Subheading
                    const Text(
                      'CIVIC SOS EMERGENCY BROADCAST',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sosRed,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap and hold the red button for 1.5 seconds to instantly broadcast high-priority alerts to nearby verified residents.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 1.5-Second Hold Animated SOS Button
                    GestureDetector(
                      onTapDown: isDispatching ? null : (_) => _startHolding(),
                      onTapUp: isDispatching ? null : (_) => _cancelHolding(),
                      onTapCancel: isDispatching ? null : () => _cancelHolding(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Pulse Ring
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _isHolding ? 200 : 180,
                            height: _isHolding ? 200 : 180,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.sosRedPulse,
                            ),
                          ),
                          // Progress Ring
                          SizedBox(
                            width: 170,
                            height: 170,
                            child: CircularProgressIndicator(
                              value: _holdProgress,
                              strokeWidth: 6,
                              backgroundColor: Colors.transparent,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          // Main Core Circular Red Button
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.sosRed,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.sosRed.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.touch_app, size: 36, color: Colors.white),
                                const SizedBox(height: 4),
                                const Text(
                                  'SOS',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  _isHolding ? 'HOLDING...' : 'HOLD 1.5s',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Emergency Type Selector
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Emergency Category',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: _emergencyTypes.map((type) {
                        final isSelected = _selectedType == type['id'];
                        return InkWell(
                          onTap: isDispatching
                              ? null
                              : () => setState(() => _selectedType = type['id']),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (type['color'] as Color).withValues(alpha: 0.06)
                                  : AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? (type['color'] as Color)
                                    : AppColors.borderSubtle,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  type['icon'] as IconData,
                                  color: type['color'] as Color,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    type['label'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected
                                      ? (type['color'] as Color)
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // GPS Location Accuracy Lock Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed, size: 16, color: AppColors.verifiedGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationStatus,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Offline Emergency Fallback Button Card
                    InkWell(
                      onTap: _openOfflineModal,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.sosRed.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.offline_bolt, size: 18, color: AppColors.sosRed),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Offline Emergency Mode: 1-Tap 112 Dial & Direct SMS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.sosRed,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 18, color: AppColors.sosRed),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Fullscreen High-Priority Dispatching HUD
              if (isDispatching)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.sosRed,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Broadcasting Emergency Alert',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Locking high-accuracy GPS coordinates and notifying nearby residents & emergency services...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
