import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/colors.dart';

class OfflineSosModal extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String emergencyType;

  const OfflineSosModal({
    super.key,
    required this.latitude,
    required this.longitude,
    this.emergencyType = 'security',
  });

  static Future<void> show(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String emergencyType = 'security',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfflineSosModal(
        latitude: latitude,
        longitude: longitude,
        emergencyType: emergencyType,
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmergencySms() async {
    final latStr = latitude.toStringAsFixed(5);
    final lngStr = longitude.toStringAsFixed(5);
    final typeFormatted = emergencyType.toUpperCase();
    final body = Uri.encodeComponent(
      'EMERGENCY ($typeFormatted)! I need immediate help at GPS: $latStr, $lngStr. Nearo SOS Fallback.',
    );
    final uri = Uri.parse('sms:112?body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.sosRedLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off, color: AppColors.sosRed, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Emergency Fallback',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'No internet connectivity detected',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.sosRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GPS Coordinates Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GPS Lock: ${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Direct 1-Tap National Emergency Hotlines
          const Text(
            '1-Tap Direct Emergency Hotlines',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildEmergencyDialButton(
                  title: '112',
                  subtitle: 'All-in-One',
                  color: AppColors.sosRed,
                  icon: Icons.emergency,
                  onTap: () => _makePhoneCall('112'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEmergencyDialButton(
                  title: '108',
                  subtitle: 'Ambulance',
                  color: Colors.deepOrange,
                  icon: Icons.local_hospital,
                  onTap: () => _makePhoneCall('108'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEmergencyDialButton(
                  title: '100',
                  subtitle: 'Police',
                  color: AppColors.primaryBlue,
                  icon: Icons.local_police,
                  onTap: () => _makePhoneCall('100'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pre-filled SMS Trigger Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _sendEmergencySms,
              icon: const Icon(Icons.sms_outlined, color: Colors.white, size: 18),
              label: const Text(
                'Send Pre-filled Emergency SMS to 112',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sosRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmergencyDialButton({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
