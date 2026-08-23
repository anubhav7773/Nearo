import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class DirectoryScreen extends StatelessWidget {
  const DirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final businesses = [
      {
        'name': 'Gupta Diagnostic Center',
        'category': 'Healthcare & Lab',
        'distance': '820m away',
        'verified': true,
        'tagline': 'Complete blood profile & radiology at 20% resident discount.',
      },
      {
        'name': 'Parihar Organic Mart',
        'category': 'Grocery & Produce',
        'distance': '950m away',
        'verified': true,
        'tagline': 'Farm-fresh dairy, cold-pressed oils, and seasonal vegetables.',
      },
      {
        'name': 'Ayodhya Electricians & Repair',
        'category': 'Home Services',
        'distance': '1.2km away',
        'verified': false,
        'tagline': 'Emergency short circuit repair and water pump servicing.',
      },
    ];

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
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: businesses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final b = businesses[index];
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
                                  b['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (b['verified'] == true) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 14, color: AppColors.verifiedGreen),
                              ],
                            ],
                          ),
                          Text(
                            '${b['category']} · ${b['distance']}',
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
                const SizedBox(height: 10),
                Text(
                  b['tagline'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () {},
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
    );
  }
}
