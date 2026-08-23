import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearo/core/theme/app_theme.dart';
import 'package:nearo/features/feed/data/models/feed_item_model.dart';
import 'package:nearo/features/feed/presentation/widgets/feed_card_widget.dart';
import 'package:nearo/features/feed/presentation/widgets/sponsored_card_widget.dart';

void main() {
  group('Feed Card Widgets Test Suite', () {
    testWidgets('CommunityFeedCard renders author, title, content and upvotes correctly',
        (WidgetTester tester) async {
      final post = CommunityPostItem(
        id: 'post_test_1',
        authorAlias: 'AyodhyaResident_99',
        category: 'civic_issue',
        title: 'Water Supply Repair',
        content: 'Pipeline maintenance ongoing near Gate 2.',
        upvotes: 14,
        commentsCount: 3,
        distanceMeters: 340,
        createdAt: DateTime.now(),
      );

      bool upvoted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CommunityFeedCard(
              post: post,
              onUpvote: () {
                upvoted = true;
              },
            ),
          ),
        ),
      );

      // Verify Author Alias
      expect(find.text('AyodhyaResident_99'), findsOneWidget);
      // Verify Category Chip
      expect(find.text('Civic Issue'), findsOneWidget);
      // Verify Title
      expect(find.text('Water Supply Repair'), findsOneWidget);
      // Verify Content
      expect(find.text('Pipeline maintenance ongoing near Gate 2.'), findsOneWidget);
      // Verify Distance & Upvote text
      expect(find.textContaining('340m away'), findsOneWidget);
      expect(find.text('14 Upvotes'), findsOneWidget);

      // Test Upvote Tap callback
      await tester.tap(find.text('14 Upvotes'));
      expect(upvoted, isTrue);
    });

    testWidgets('SponsoredFeedCard renders business name, tagline, Sponsored badge and WhatsApp CTA',
        (WidgetTester tester) async {
      final ad = NativeAdItem(
        id: 'ad_test_1',
        businessName: 'Gupta Diagnostic Center',
        tagline: 'Special 20% discount for verified residents.',
        ctaTitle: 'Chat on WhatsApp',
        whatsappUrl: 'https://wa.me/919876543210',
        distanceMeters: 820,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SponsoredFeedCard(ad: ad),
          ),
        ),
      );

      // Verify Sponsored Tag
      expect(find.text('Sponsored'), findsOneWidget);
      // Verify Business Name
      expect(find.text('Gupta Diagnostic Center'), findsOneWidget);
      // Verify Tagline
      expect(find.text('Special 20% discount for verified residents.'), findsOneWidget);
      // Verify WhatsApp CTA Button
      expect(find.text('Chat on WhatsApp'), findsOneWidget);
      expect(find.byIcon(Icons.chat_outlined), findsOneWidget);
    });
  });
}
