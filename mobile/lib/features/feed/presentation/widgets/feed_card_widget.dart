import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/feed_item_model.dart';

class CommunityFeedCard extends StatelessWidget {
  final CommunityPostItem post;
  final VoidCallback onUpvote;

  const CommunityFeedCard({
    super.key,
    required this.post,
    required this.onUpvote,
  });

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'alert':
        return AppColors.sosRed;
      case 'civic_issue':
        return AppColors.warningOrange;
      case 'help_needed':
        return AppColors.accentBlue;
      case 'trade':
        return AppColors.verifiedGreen;
      default:
        return AppColors.primaryBlue;
    }
  }

  String _formatCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'civic_issue':
        return 'Civic Issue';
      case 'help_needed':
        return 'Help Needed';
      case 'alert':
        return 'Alert';
      case 'trade':
        return 'Buy & Sell';
      default:
        return 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor(post.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: Avatar + Alias + Verified Badge + Distance + Time
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.person,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.authorAlias,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.verifiedGreenBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 13,
                          color: AppColors.verifiedGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${post.distanceFormatted} · ${post.timeAgoFormatted}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2. Category Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: catColor.withValues(alpha: 0.2), width: 1),
              ),
              child: Text(
                _formatCategoryLabel(post.category),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: catColor,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 3. Post Title (Optional)
            if (post.title != null && post.title!.isNotEmpty) ...[
              Text(
                post.title!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
            ],

            // 4. Post Content
            Text(
              post.content,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 8),

            // 5. Actions Footer (Upvote, Comment, Share)
            Row(
              children: [
                InkWell(
                  onTap: onUpvote,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          post.isUpvoted ? Icons.arrow_upward : Icons.arrow_upward_outlined,
                          size: 16,
                          color: post.isUpvoted ? AppColors.accentBlue : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.upvotes} Upvotes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: post.isUpvoted ? AppColors.accentBlue : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.commentsCount} Comments',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
