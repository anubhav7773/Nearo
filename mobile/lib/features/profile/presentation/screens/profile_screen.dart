import 'package:flutter/material.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _aliasName = 'AyodhyaResident_04';
  String _userTier = 'free';
  double _radiusMeters = 1500;
  bool _isUpgrading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final alias = await SecureStorageService.getAliasName();
    final tier = await SecureStorageService.getUserTier();
    if (mounted) {
      setState(() {
        if (alias != null) _aliasName = alias;
        if (tier != null) _userTier = tier;
      });
    }
  }

  Future<void> _upgradeToPro() async {
    setState(() => _isUpgrading = true);
    try {
      final response = await ApiClient().dio.post(
        ApiEndpoints.createSubscriptionOrder,
        data: {
          'tier': 'pro_resident',
          'duration_months': 1,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        await SecureStorageService.updateUserTier('pro_resident');
        setState(() {
          _userTier = 'pro_resident';
          _isUpgrading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Upgraded to Resident Pro! 100% Ad-Free active.'),
              backgroundColor: AppColors.verifiedGreen,
            ),
          );
        }
      }
    } catch (_) {
      // Offline / demo fallback
      await SecureStorageService.updateUserTier('pro_resident');
      setState(() {
        _userTier = 'pro_resident';
        _isUpgrading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Upgraded to Resident Pro! (Demo Mode)'),
            backgroundColor: AppColors.verifiedGreen,
          ),
        );
      }
    }
  }

  Future<void> _syncRadius(double value) async {
    setState(() => _radiusMeters = value);
    try {
      await ApiClient().dio.put(
        ApiEndpoints.syncLocation,
        data: {
          'latitude': 26.7922,
          'longitude': 82.1998,
          'pincode': '224001',
          'preferred_radius_meters': value.toInt(),
        },
      );
    } catch (_) {}
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account & Personal Data?'),
        content: const Text(
          'Under the India DPDP Act, your profile, linked GPS coordinates, and activity will be permanently erased. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiClient().dio.delete(ApiEndpoints.deleteAccount);
              } catch (_) {}
              await SecureStorageService.clearSession();
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
            child: const Text('Purge My Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = _userTier == 'pro_resident' || _userTier == 'business_pro';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Resident Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: () async {
              await SecureStorageService.clearSession();
              widget.onLogout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _aliasName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.verifiedGreenBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                size: 14,
                                color: AppColors.verifiedGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPro ? 'Resident Pro Member' : 'Standard Resident',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isPro ? AppColors.accentBlue : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Pro Tier Upgrade Card
            if (!isPro) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.accentBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'RESIDENT PRO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '₹29 / mo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFeatureBullet('100% Ad-Free Clean Community Feed'),
                    _buildFeatureBullet('Priority Alert Dispatch in 3.0 km Radius'),
                    _buildFeatureBullet('Verified Resident Shield Icon on Profile'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isUpgrading ? null : _upgradeToPro,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryBlue,
                          elevation: 0,
                        ),
                        child: _isUpgrading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Upgrade for ₹29 / Month'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 3. Geofence Radius Slider
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Neighborhood Radius Range',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${(_radiusMeters / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Controls the boundary for community posts and emergency notifications.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Slider(
                    value: _radiusMeters,
                    min: 500,
                    max: 5000,
                    divisions: 9,
                    activeColor: AppColors.primaryBlue,
                    inactiveColor: AppColors.borderSubtle,
                    onChanged: (val) => _syncRadius(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. DPDP 1-Click Data Erasure Button
            Center(
              child: TextButton.icon(
                onPressed: _confirmDeleteAccount,
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.sosRed),
                label: const Text(
                  'Delete Account & Erase All Data',
                  style: TextStyle(color: AppColors.sosRed, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
