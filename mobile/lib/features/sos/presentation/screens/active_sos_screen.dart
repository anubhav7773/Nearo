import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/sos_event_model.dart';
import '../bloc/sos_bloc.dart';
import '../bloc/sos_event.dart';
import '../bloc/sos_state.dart';
import '../widgets/offline_sos_modal.dart';

class ActiveSosScreen extends StatefulWidget {
  final SosEventModel sosEvent;

  const ActiveSosScreen({
    super.key,
    required this.sosEvent,
  });

  @override
  State<ActiveSosScreen> createState() => _ActiveSosScreenState();
}

class _ActiveSosScreenState extends State<ActiveSosScreen>
    with SingleTickerProviderStateMixin {
  late SosEventModel _currentEvent;
  Timer? _pollingTimer;
  Timer? _tickerTimer;
  Duration _elapsed = Duration.zero;
  bool _isCancelling = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.sosEvent;
    _elapsed = DateTime.now().difference(_currentEvent.createdAt);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Update elapsed timer every second
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_currentEvent.createdAt);
        });
      }
    });

    // Real-time polling every 8 seconds to track responder count updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_isCancelling) {
        context.read<SosBloc>().add(FetchActiveSosDetails(sosId: _currentEvent.id));
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _pollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _onCancelSos() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm Resolution'),
        content: const Text(
          'Are you safe and would you like to cancel this emergency broadcast? Your nearby neighbors will be notified that the situation is resolved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verifiedGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              setState(() => _isCancelling = true);
              context.read<SosBloc>().add(CancelActiveSos(eventId: _currentEvent.id));
            },
            child: const Text('I Am Safe / Cancel SOS'),
          ),
        ],
      ),
    );
  }

  void _openOfflineModal() {
    OfflineSosModal.show(
      context,
      latitude: _currentEvent.latitude,
      longitude: _currentEvent.longitude,
      emergencyType: _currentEvent.category,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SosBloc, SosState>(
      listener: (context, state) {
        if (state is SosDispatchedSuccess) {
          setState(() {
            _currentEvent = state.sosEvent;
          });
        } else if (state is SosCancelledSuccess || state is SosIdle) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Emergency broadcast successfully resolved. You are marked safe.'),
                backgroundColor: AppColors.verifiedGreen,
              ),
            );
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      builder: (context, state) {
        final timeFormatter = DateFormat('hh:mm:ss a · dd MMM yyyy');

        return WillPopScope(
          onWillPop: () async {
            // Prevent accidental back navigation while SOS is active without confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Emergency broadcast is active. Tap "Cancel / I Am Safe" to resolve.'),
                duration: Duration(seconds: 2),
              ),
            );
            return false;
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.sosRedLight,
              title: const Row(
                children: [
                  Icon(Icons.shield, color: AppColors.sosRed, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'LIVE CIVIC SOS ACTIVE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sosRed,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Offline 112 / SMS',
                  icon: const Icon(Icons.offline_bolt_outlined, color: AppColors.sosRed),
                  onPressed: _openOfflineModal,
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Pulsing High Priority Beacon
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sosRed,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.sosRed.withValues(alpha: 0.4),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.emergency,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Elapsed Active Timer
                  Text(
                    'BROADCAST ACTIVE: ${_formatDuration(_elapsed)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.sosRed,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Initiated: ${timeFormatter.format(_currentEvent.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category & Description Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.sosRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                _currentEvent.categoryDisplayName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.sosRed,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.circle, color: AppColors.sosRed, size: 10),
                            const SizedBox(width: 6),
                            const Text(
                              'Live on Network',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.sosRed,
                              ),
                            ),
                          ],
                        ),
                        if (_currentEvent.description != null &&
                            _currentEvent.description!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _currentEvent.description!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Real Broadcast Dispatch Metrics
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.people_alt_outlined, color: AppColors.primaryBlue, size: 28),
                              const SizedBox(height: 6),
                              Text(
                                '${_currentEvent.neighborsAlerted}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'Neighbors Alerted',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.radar_outlined, color: AppColors.warningOrange, size: 28),
                              const SizedBox(height: 6),
                              Text(
                                '${_currentEvent.broadcastRadiusMeters}m',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'Broadcast Radius',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // GPS Coordinates Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gps_fixed, color: AppColors.verifiedGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Exact GPS Lock Broadcasted',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Exact GPS Lock: ${_currentEvent.latitude.toStringAsFixed(4)}° N, ${_currentEvent.longitude.toStringAsFixed(4)}° E',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Primary Action: Cancel / I Am Safe Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isCancelling ? null : _onCancelSos,
                      icon: _isCancelling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle, size: 22),
                      label: Text(
                        _isCancelling ? 'RESOLVING ALERT...' : 'CANCEL / I AM SAFE',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.verifiedGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Secondary Action: Offline Emergency Dialer
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _openOfflineModal,
                      icon: const Icon(Icons.phone_in_talk, size: 20),
                      label: const Text(
                        'Offline Emergency (Dial 112 / SMS)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.sosRed,
                        side: const BorderSide(color: AppColors.sosRed, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
