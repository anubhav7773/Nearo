import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage.dart';

class EmergencySetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const EmergencySetupScreen({super.key, required this.onComplete});

  @override
  State<EmergencySetupScreen> createState() => _EmergencySetupScreenState();
}

class _EmergencySetupScreenState extends State<EmergencySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final List<String> _quickRelations = [
    'Papa',
    'Maa',
    'Brother',
    'Sister',
    'Spouse',
    'Friend',
  ];

  String? _selectedRelation;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSelectRelation(String relation) {
    setState(() {
      _selectedRelation = relation;
      _nameController.text = relation;
    });
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final name = _nameController.text.trim().isEmpty
        ? (_selectedRelation ?? 'Guardian')
        : _nameController.text.trim();

    String formattedPhone = rawPhone;
    if (rawPhone.length == 10) {
      formattedPhone = '+91$rawPhone';
    } else if (rawPhone.length == 12 && rawPhone.startsWith('91')) {
      formattedPhone = '+$rawPhone';
    } else if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+$formattedPhone';
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // 1. Save to Secure Storage locally for instant offline SOS access
      await SecureStorageService.saveEmergencyContact(
        phone: formattedPhone,
        name: name,
      );

      // 2. Sync to backend user profile asynchronously
      try {
        await ApiClient().dio.patch(
          '/api/v1/users/me',
          data: {
            'emergency_contact_phone': formattedPhone,
            'emergency_contact_name': name,
          },
        );
      } catch (_) {
        // Continue even if network sync fails; local secure storage guarantees offline SOS
      }

      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save contact. Please try again.';
        });
      }
    }
  }

  void _skip() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Top Shield Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.sosRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.sosRed.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.sosRed,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header & Description
                const Center(
                  child: Text(
                    'Set Emergency Guardian',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'In offline crises or 1-tap SOS, your exact GPS coordinates and maps link will be instantly dispatched to this person.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.sosRedLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.sosRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.sosRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Quick Relationship Selection Chips
                const Text(
                  'Relationship / Relation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickRelations.map((relation) {
                    final isSelected = _selectedRelation == relation;
                    return ChoiceChip(
                      label: Text(relation),
                      selected: isSelected,
                      onSelected: (_) => _onSelectRelation(relation),
                      selectedColor: AppColors.primaryBlue,
                      backgroundColor: AppColors.surfaceCard,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.borderSubtle,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Guardian Name Input
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Guardian Name / Custom Relation',
                    hintText: 'e.g., Papa, Maa, Aarav',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a name or select a relation.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Guardian Phone Number Input
                const Text(
                  'Guardian Mobile Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined, size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          const Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 1,
                            height: 22,
                            color: AppColors.borderSubtle,
                          ),
                        ],
                      ),
                    ),
                    hintText: '10-digit mobile number',
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter 10-digit mobile number';
                    }
                    final clean = val.trim();
                    if (clean.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
                      return 'Enter a valid 10-digit Indian mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Save Guardian Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sosRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_person_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Save Guardian & Continue to Nearo',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Skip for Now Option
                Center(
                  child: TextButton(
                    onPressed: _isSaving ? null : _skip,
                    child: const Text(
                      'Skip for now (configure later in Profile)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
