import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/colors.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';
import '../../data/models/feed_item_model.dart';
import '../widgets/feed_card_widget.dart';
import '../widgets/sponsored_card_widget.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<Map<String, String>> _categories = [
    {'key': 'all', 'label': 'All Updates'},
    {'key': 'civic_issue', 'label': 'Civic Issues'},
    {'key': 'alert', 'label': 'Scam Alerts'},
    {'key': 'help_needed', 'label': 'Help Needed'},
    {'key': 'trade', 'label': 'Buy & Sell'},
  ];

  @override
  void initState() {
    super.initState();
    context.read<FeedBloc>().add(FetchFeed());
  }

  void _showRadiusModal(BuildContext context, int currentRadius) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Neighborhood Radius',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nearo connects you strictly with verified residents inside your chosen radius boundary.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _buildRadiusOption(ctx, '1.0 km · Immediate Colony', 1000, currentRadius),
              _buildRadiusOption(ctx, '1.5 km · Neighborhood (Default)', 1500, currentRadius),
              _buildRadiusOption(ctx, '3.0 km · Ward / Suburban Zone', 3000, currentRadius),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadiusOption(BuildContext ctx, String title, int radius, int selectedRadius) {
    final isSelected = radius == selectedRadius;
    return InkWell(
      onTap: () {
        context.read<FeedBloc>().add(ChangeRadiusFilter(radius));
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostModal(BuildContext context) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedCategory = 'civic_issue';
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
                          onPressed: () => Navigator.pop(modalCtx),
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
                        final isSel = cat['key'] == selectedCategory;
                        return ChoiceChip(
                          label: Text(cat['label']!),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedCategory = cat['key']!);
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
                      controller: titleController,
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
                      controller: bodyController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description / Message *',
                        hintText: 'Share relevant details with neighbors in your local radius...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Privacy Jitter Notice
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
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final body = bodyController.text.trim();
                                if (body.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a description.')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final feedState = context.read<FeedBloc>().state;
                                double lat = 26.7922;
                                double lng = 82.1998;
                                if (feedState is FeedLoaded) {
                                  lat = feedState.userLat;
                                  lng = feedState.userLng;
                                }

                                context.read<FeedBloc>().add(
                                      CreatePostEvent(
                                        category: selectedCategory,
                                        title: titleController.text.trim().isNotEmpty
                                            ? titleController.text.trim()
                                            : null,
                                        content: body,
                                        latitude: lat,
                                        longitude: lng,
                                      ),
                                    );

                                Navigator.pop(modalCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Neighborhood update published successfully!'),
                                    backgroundColor: AppColors.verifiedGreen,
                                  ),
                                );
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
                                'Publish Update',
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

  Widget _buildShimmerSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 100,
                    height: 14,
                    color: Colors.grey.shade200,
                  ),
                  const Spacer(),
                  Container(
                    width: 60,
                    height: 12,
                    color: Colors.grey.shade200,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(width: 140, height: 16, color: Colors.grey.shade200),
              const SizedBox(height: 8),
              Container(width: double.infinity, height: 12, color: Colors.grey.shade200),
              const SizedBox(height: 6),
              Container(width: 200, height: 12, color: Colors.grey.shade200),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: BlocBuilder<FeedBloc, FeedState>(
          builder: (context, state) {
            int radius = 1500;
            if (state is FeedLoaded) {
              radius = state.activeRadiusMeters;
            }
            final km = (radius / 1000).toStringAsFixed(1);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nearo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Ayodhya Central ($km km)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          BlocBuilder<FeedBloc, FeedState>(
            builder: (context, state) {
              int currentRadius = 1500;
              if (state is FeedLoaded) {
                currentRadius = state.activeRadiusMeters;
              }
              final km = (currentRadius / 1000).toStringAsFixed(1);
              return TextButton.icon(
                onPressed: () => _showRadiusModal(context, currentRadius),
                icon: const Icon(Icons.radar, size: 16, color: AppColors.primaryBlue),
                label: Text(
                  '$km km',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Scrollable Chips
          BlocBuilder<FeedBloc, FeedState>(
            builder: (context, state) {
              String activeCat = 'all';
              if (state is FeedLoaded) {
                activeCat = state.activeCategory;
              }
              return Container(
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
                    final isSelected = cat['key'] == activeCat;
                    return ChoiceChip(
                      label: Text(cat['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          context.read<FeedBloc>().add(ChangeCategoryFilter(cat['key']!));
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
              );
            },
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Feed List View
          Expanded(
            child: BlocBuilder<FeedBloc, FeedState>(
              builder: (context, state) {
                if (state is FeedLoading) {
                  return _buildShimmerSkeleton();
                }

                if (state is FeedLoaded) {
                  if (state.items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_city_outlined,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No active community updates within this radius.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Be the first to share news, maintenance info, or help your neighborhood!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showCreatePostModal(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Post Neighborhood Update'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(200, 42),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primaryBlue,
                    onRefresh: () async {
                      context.read<FeedBloc>().add(RefreshFeed());
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.items.length,
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        if (item is CommunityPostItem) {
                          return CommunityFeedCard(
                            post: item,
                            onUpvote: () {
                              context.read<FeedBloc>().add(UpvotePost(item.id));
                            },
                          );
                        } else if (item is NativeAdItem) {
                          return SponsoredFeedCard(ad: item);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  );
                }

                if (state is FeedError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: AppColors.sosRed),
                        const SizedBox(height: 8),
                        Text(state.message),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => context.read<FeedBloc>().add(FetchFeed()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePostModal(context),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.edit, color: Colors.white, size: 18),
        label: const Text(
          'Post',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
