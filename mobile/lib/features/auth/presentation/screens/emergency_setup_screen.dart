import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage.dart';

class EmergencySetupScreen extends StatefulWidget {
  final VoidCallback? onSetupComplete;

  const EmergencySetupScreen({
    super.key,
    this.onSetupComplete,
  });

  @override
  State<EmergencySetupScreen> createState() => _EmergencySetupScreenState();
}

class _EmergencySetupScreenState extends State<EmergencySetupScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingContact();
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadExistingContact() async {
    final existingPhone = await SecureStorageService.getEmergencyContactPhone();
    final existingName = await SecureStorageService.getEmergencyContactName();
    if (existingPhone != null && existingPhone.isNotEmpty) {
      String clean = existingPhone.replaceAll('+91', '').replaceAll(RegExp(r'\D'), '');
      if (clean.length > 10) clean = clean.substring(clean.length - 10);
      _phoneController.text = clean;
    }
    if (existingName != null && existingName.isNotEmpty) {
      _nameController.text = existingName;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _isValidPhone {
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^[6-9]\d{9}$').hasMatch(raw);
  }

  Future<void> _submitEmergencyContact() async {
    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Primary Emergency Contact';

    if (!_isValidPhone || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final formattedPhone = '+91$rawPhone';

    // 1. Instant local persistence in secure storage
    await SecureStorageService.saveEmergencyContactPhone(formattedPhone);
    await SecureStorageService.saveEmergencyContactName(name);

    // 2. Asynchronous backend synchronization
    try {
      await _apiClient.dio.patch(
        '/api/v1/users/me',
        data: {
          'emergency_contact_phone': formattedPhone,
          'emergency_contact_name': name,
          'phone_number': formattedPhone,
        },
      );
    } catch (e) {
      debugPrint('Backend emergency contact sync deferred / offline: $e');
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (widget.onSetupComplete != null) {
        widget.onSetupComplete!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final charCount = rawPhone.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Emergency Contact Setup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Emergency Icon Badge
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.sosRedLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.contact_phone_rounded,
                      size: 50,
                      color: AppColors.sosRed,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Set Your Primary Emergency Contact',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text(
                    'In offline crises or 1-tap SOS, your exact GPS coordinates will be instantly dispatched to this person via auto-targeted SMS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Form Container
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name / Relation Field
                        const Text(
                          'Contact Name / Relation',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                            hintText: 'e.g. Spouse, Father, Brother, Trusted Neighbor',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryBlue,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Phone Number Field
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Emergency Mobile Number',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'India (+91)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              margin: const EdgeInsets.only(right: 10),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: AppColors.borderSubtle,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 6),
                                  Text(
                                    '+91',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            hintText: '9876543210',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryBlue,
                                width: 1.8,
                              ),
                            ),
                            suffixIcon: charCount == 10
                                ? Icon(
                                    _isValidPhone
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    color: _isValidPhone
                                        ? AppColors.verifiedGreen
                                        : AppColors.sosRed,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              charCount > 0 && !_isValidPhone && charCount == 10
                                  ? 'Indian numbers must start with 6, 7, 8, or 9'
                                  : (charCount > 0 && charCount < 10
                                      ? 'Enter 10-digit number'
                                      : ''),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.sosRed,
                              ),
                            ),
                            Text(
                              '$charCount/10',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: charCount == 10
                                    ? AppColors.verifiedGreen
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Privacy Note
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 18,
                          color: AppColors.verifiedGreen,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your emergency contact details are encrypted and only targeted during critical SOS broadcasts or offline emergency SMS events.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.sosRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_isValidPhone && !_isSaving) ? _submitEmergencyContact : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sosRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.sosRed.withValues(alpha: 0.35),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: _isValidPhone ? 2 : 0,
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
                                Text(
                                  'Save Emergency Contact',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.check_circle_outline_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
