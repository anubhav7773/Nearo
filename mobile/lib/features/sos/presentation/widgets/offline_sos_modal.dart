import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/network/secure_storage.dart';
import '../../utils/offline_sos_helper.dart';

class OfflineSosModal extends StatefulWidget {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OfflineSosModal(
        latitude: latitude,
        longitude: longitude,
        emergencyType: emergencyType,
      ),
    );
  }

  @override
  State<OfflineSosModal> createState() => _OfflineSosModalState();
}

class _OfflineSosModalState extends State<OfflineSosModal> {
  String? _guardianName;
  String? _guardianPhone;

  @override
  void initState() {
    super.initState();
    _loadGuardianContact();
  }

  Future<void> _loadGuardianContact() async {
    final phone = await SecureStorageService.getEmergencyContactPhone();
    final name = await SecureStorageService.getEmergencyContactName();
    if (mounted) {
      setState(() {
        _guardianPhone = phone;
        _guardianName = name;
      });
    }
  }

  Future<void> _onSendSms(BuildContext modalContext) async {
    if (_guardianPhone == null || _guardianPhone!.trim().isEmpty) {
      // Prompt user to enter emergency contact quickly
      final entered = await _showQuickContactDialog(modalContext);
      if (entered != true) return;
    }

    if (modalContext.mounted) {
      Navigator.pop(modalContext);
      OfflineSosHelper.triggerDirectOfflineSms(
        category: widget.emergencyType,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
    }
  }

  Future<bool?> _showQuickContactDialog(BuildContext context) {
    final phoneController = TextEditingController();
    final nameController = TextEditingController(text: 'Guardian');

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.sosRed, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Set Emergency Contact',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your guardian\'s mobile number to auto-fill recipients during emergency SOS.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Relation / Name',
                hintText: 'e.g. Papa, Maa',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                hintText: '10-digit number or +91...',
                prefixText: '+91 ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final raw = phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
              if (raw.length >= 10) {
                final formatted = raw.length == 10 ? '+91$raw' : '+$raw';
                final name = nameController.text.trim().isEmpty ? 'Guardian' : nameController.text.trim();
                await SecureStorageService.saveEmergencyContact(phone: formatted, name: name);
                setState(() {
                  _guardianPhone = formatted;
                  _guardianName = name;
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sosRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Send SMS'),
          ),
        ],
      ),
    );
  }

  void _onDial112(BuildContext context) {
    Navigator.pop(context);
    OfflineSosHelper.dialEmergencyServices(phoneNumber: '112');
  }

  void _onDialCustom(BuildContext context, String number) {
    Navigator.pop(context);
    OfflineSosHelper.dialEmergencyServices(phoneNumber: number);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
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
                        'Offline Emergency Dispatch',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Works without internet using cellular SMS and 112 dialing',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
                  const Icon(Icons.my_location, size: 16, color: AppColors.verifiedGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS Lock: ${widget.latitude.toStringAsFixed(4)}° N, ${widget.longitude.toStringAsFixed(4)}° E',
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
            const SizedBox(height: 16),

            // Action 1: Send Emergency SMS to Guardian
            Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.borderSubtle),
                ),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.sosRedLight,
                  child: Icon(Icons.message, color: AppColors.sosRed),
                ),
                title: Text(
                  _guardianPhone != null && _guardianPhone!.isNotEmpty
                      ? 'Send GPS SMS to ${_guardianName ?? 'Guardian'} ($_guardianPhone)'
                      : 'Send Emergency SMS with GPS Link',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  _guardianPhone != null && _guardianPhone!.isNotEmpty
                      ? 'Opens SMS app directly addressed to $_guardianPhone with Google Maps link'
                      : 'Opens default SMS app with pre-filled coordinates and Google Maps link',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.sosRed),
                onTap: () => _onSendSms(context),
              ),
            ),
            const SizedBox(height: 10),

            // Action 2: Call 112 National Emergency Helpline
            Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.borderSubtle),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.phone_in_talk, color: Color(0xFF1D4ED8)),
                ),
                title: const Text(
                  'Call 112 Emergency Services',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Direct 1-tap call to National Emergency Helpline (Police/Fire/Medical)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF1D4ED8)),
                onTap: () => _onDial112(context),
              ),
            ),
            const SizedBox(height: 16),

            // Secondary Quick Hotlines
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Direct Hotlines',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildEmergencyDialButton(
                    title: '112',
                    subtitle: 'All-in-One',
                    color: AppColors.sosRed,
                    icon: Icons.emergency,
                    onTap: () => _onDial112(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEmergencyDialButton(
                    title: '108',
                    subtitle: 'Ambulance',
                    color: Colors.deepOrange,
                    icon: Icons.local_hospital,
                    onTap: () => _onDialCustom(context, '108'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEmergencyDialButton(
                    title: '100',
                    subtitle: 'Police',
                    color: AppColors.primaryBlue,
                    icon: Icons.local_police,
                    onTap: () => _onDialCustom(context, '100'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
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
