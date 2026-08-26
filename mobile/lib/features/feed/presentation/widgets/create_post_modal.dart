import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/colors.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';

class CreatePostModal extends StatefulWidget {
  const CreatePostModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostModal(),
    );
  }

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _selectedCategory = 'civic_issue';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final feedBloc = context.read<FeedBloc>();
    final feedState = feedBloc.state;
    double lat = 26.7922;
    double lng = 82.1998;
    if (feedState is FeedLoaded) {
      lat = feedState.userLat;
      lng = feedState.userLng;
    }

    // 1. Dispatch CreatePostEvent to network
    feedBloc.add(
      CreatePostEvent(
        category: _selectedCategory,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        content: body,
        latitude: lat,
        longitude: lng,
      ),
    );

    // 2. Immediately trigger active feed reload with current coordinates
    feedBloc.add(FetchFeed(
      lat: lat,
      lng: lng,
      radiusMeters: feedState is FeedLoaded ? feedState.activeRadiusMeters : 1500,
      category: feedState is FeedLoaded ? feedState.activeCategory : 'all',
    ));

    // 3. Close modal bottom sheet
    Navigator.of(context).pop();

    // 4. Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post published to your neighborhood radius.'),
        backgroundColor: AppColors.verifiedGreen,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'New Neighborhood Post',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category Selection Chips
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                {'key': 'civic_issue', 'label': 'Civic Issue'},
                {'key': 'alert', 'label': 'Scam Alert'},
                {'key': 'help_needed', 'label': 'Help Needed'},
                {'key': 'trade', 'label': 'Buy & Sell'},
                {'key': 'general', 'label': 'General'},
              ].map((cat) {
                final isSel = cat['key'] == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat['label']!),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat['key']!);
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
            const SizedBox(height: 16),

            // Title Input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title (Optional)',
                hintText: 'e.g. Water Supply Line Repair near Gate 2',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Content / Body Input
            TextField(
              controller: _bodyController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description / Message *',
                hintText: 'Share relevant details with neighbors in your local radius...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),

            // Privacy Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, size: 14, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📍 DPDP Compliant: Location jittered by 200m–500m to protect your exact home address.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Publish Update',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
