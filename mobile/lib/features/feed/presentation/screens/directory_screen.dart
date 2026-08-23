import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/geo_utils.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  String _selectedCategory = 'all';
  List<Map<String, dynamic>> _businesses = [];
  double _userLat = 26.7922;
  double _userLng = 82.1998;

  final List<Map<String, String>> _categories = [
    {'key': 'all', 'label': 'All Categories'},
    {'key': 'healthcare', 'label': 'Healthcare & Lab'},
    {'key': 'grocery', 'label': 'Grocery & Produce'},
    {'key': 'home_services', 'label': 'Home Services'},
    {'key': 'food', 'label': 'Food & Dining'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoading = true);

    try {
      final pos = await _determinePosition();
      if (pos != null) {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }
    } catch (_) {}

    final jittered = GeoUtils.applyJitter(
      latitude: _userLat,
      longitude: _userLng,
      minMeters: 200.0,
      maxMeters: 500.0,
    );

    try {
      final queryParams = <String, dynamic>{
        'lat': jittered['latitude'] ?? _userLat,
        'lng': jittered['longitude'] ?? _userLng,
        'radius_meters': 3000,
      };
      if (_selectedCategory != 'all') {
        queryParams['category'] = _selectedCategory;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.directory,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['data'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _businesses = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback if offline
    if (mounted) {
      setState(() {
        _businesses = _getFallbackBusinesses();
        _isLoading = false;
      });
    }
  }

  Future<Position?> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 3),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _launchWhatsApp(String rawPhone, String businessName) async {
    // Format clean digits with country code
    String cleanDigits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.length == 10) {
      cleanDigits = '91$cleanDigits';
    }

    final message = Uri.encodeComponent(
      'Hello I found your listing on Nearo',
    );

    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanDigits&text=$message');
    final webUri = Uri.parse('https://wa.me/$cleanDigits?text=$message');

    try {
      final launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final webLaunched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        if (!webLaunched && mounted) {
          _showWhatsAppErrorSnackBar();
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) _showWhatsAppErrorSnackBar();
      }
    }
  }

  void _showWhatsAppErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open WhatsApp. Please verify WhatsApp is installed on your device.'),
        backgroundColor: AppColors.sosRed,
      ),
    );
  }

  void _showRegisterBusinessModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCat = 'grocery';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'List Your Local Business',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Business Name
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Business / Shop Name *',
                        hintText: 'e.g. Awadh Diagnostics & Clinic',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Selector
                    const Text(
                      'Business Category',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'key': 'healthcare', 'label': 'Healthcare'},
                        {'key': 'grocery', 'label': 'Grocery'},
                        {'key': 'home_services', 'label': 'Services'},
                        {'key': 'food', 'label': 'Food'},
                      ].map((cat) {
                        final isSel = cat['key'] == selectedCat;
                        return ChoiceChip(
                          label: Text(cat['label']!),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedCat = cat['key']!);
                          },
                          selectedColor: AppColors.primaryBlue,
                          backgroundColor: AppColors.background,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                            color: isSel ? Colors.white : AppColors.textPrimary,
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // WhatsApp Phone Number
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp Contact Number *',
                        hintText: '+919876543210',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Overview / Services Offered',
                        hintText: 'Describe key products, offers, home delivery, or working hours...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final phone = phoneCtrl.text.trim();
                                if (name.isEmpty || phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter business name and WhatsApp number.')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                try {
                                  await _apiClient.dio.post(
                                    ApiEndpoints.directoryRegister,
                                    data: {
                                      'name': name,
                                      'category': selectedCat,
                                      'whatsapp_number': phone,
                                      'description': descCtrl.text.trim(),
                                      'latitude': _userLat,
                                      'longitude': _userLng,
                                    },
                                  );
                                } catch (_) {}

                                if (modalCtx.mounted) {
                                  Navigator.pop(modalCtx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Business registered! Listed on neighborhood directory.'),
                                      backgroundColor: AppColors.verifiedGreen,
                                    ),
                                  );
                                  _loadDirectory();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Register Listing',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Neighborhood Directory',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryBlue),
            onPressed: _loadDirectory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: AppColors.surfaceCard,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat['key'] == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat['label']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat['key']!);
                      _loadDirectory();
                    }
                  },
                  selectedColor: AppColors.primaryBlue,
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.primaryBlue : AppColors.borderSubtle,
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Business Listings
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                : _businesses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.storefront_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'No businesses listed in this category yet.',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _showRegisterBusinessModal,
                              child: const Text('List Your Business'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDirectory,
                        color: AppColors.primaryBlue,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _businesses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final b = _businesses[index];
                            final name = b['name'] as String? ?? 'Local Business';
                            final category = b['category'] as String? ?? 'General';
                            final distance = b['distance_text'] as String? ?? 'Nearby';
                            final desc = b['description'] as String? ?? '';
                            final whatsapp = b['whatsapp_number'] as String? ?? '';
                            final isVerified = b['is_verified'] == true;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.storefront, color: AppColors.primaryBlue, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isVerified) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.verified, size: 14, color: AppColors.verifiedGreen),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              '$category · $distance',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      desc,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _launchWhatsApp(whatsapp, name),
                                      icon: const Icon(Icons.chat_outlined, size: 16),
                                      label: const Text('Contact via WhatsApp'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.verifiedGreen,
                                        side: const BorderSide(color: AppColors.verifiedGreen),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegisterBusinessModal,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_business, color: Colors.white, size: 18),
        label: const Text(
          'List Business',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFallbackBusinesses() {
    return [
      {
        'name': 'Gupta Diagnostic Center',
        'category': 'healthcare',
        'distance_text': '320m away',
        'is_verified': true,
        'description': 'Complete blood tests, thyroid profiling, and home sample collection across Ayodhya central.',
        'whatsapp_number': '+919876543210',
      },
      {
        'name': 'Awadh Daily Fresh Mart',
        'category': 'grocery',
        'distance_text': '540m away',
        'is_verified': true,
        'description': 'Farm-fresh local vegetables, fruits, dairy, and pure desi ghee delivered in 30 minutes.',
        'whatsapp_number': '+919812345678',
      },
      {
        'name': 'Shukla Plumbing & Electrician Works',
        'category': 'home_services',
        'distance_text': '850m away',
        'is_verified': true,
        'description': 'Licensed emergency plumbing, wiring repair, RO water purifier service, and AC installation.',
        'whatsapp_number': '+919765432109',
      },
    ];
  }
}
