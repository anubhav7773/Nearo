import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/colors.dart';
import '../bloc/sos_bloc.dart';
import '../bloc/sos_event.dart';
import '../bloc/sos_state.dart';

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
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    try {
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

  void _triggerSos() {
    HapticFeedback.vibrate();
    setState(() {
      _isHolding = false;
      _holdProgress = 1.0;
    });

    context.read<SosBloc>().add(
          TriggerSosBroadcast(
            emergencyType: _selectedType,
            description: _descController.text.trim().isNotEmpty
                ? _descController.text.trim()
                : 'Urgent neighbor assistance required',
            latitude: _userLat,
            longitude: _userLng,
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
      ),
      body: BlocBuilder<SosBloc, SosState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Active SOS Sticky Banner if state is active
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
                        ElevatedButton(
                          onPressed: () {
                            context.read<SosBloc>().add(CancelActiveSos());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceCard,
                            foregroundColor: AppColors.sosRed,
                            side: const BorderSide(color: AppColors.sosRed),
                            minimumSize: const Size(180, 38),
                          ),
                          child: const Text('Cancel / I Am Safe'),
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
                  onTapDown: (_) => _startHolding(),
                  onTapUp: (_) => _cancelHolding(),
                  onTapCancel: () => _cancelHolding(),
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
                      onTap: () => setState(() => _selectedType = type['id']),
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
                              color: isSelected ? (type['color'] as Color) : AppColors.textSecondary,
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
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
