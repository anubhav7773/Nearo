abstract class FeedItem {
  final String id;
  final String type;
  final int? distanceMeters;

  FeedItem({
    required this.id,
    required this.type,
    this.distanceMeters,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final itemType = json['type'] as String? ?? 'community_post';
    if (itemType == 'native_ad') {
      return NativeAdItem.fromJson(json);
    }
    return CommunityPostItem.fromJson(json);
  }

  String get distanceFormatted {
    if (distanceMeters == null) return 'Nearby';
    if (distanceMeters! < 1000) {
      return '${distanceMeters}m away';
    }
    final km = (distanceMeters! / 1000).toStringAsFixed(1);
    return '${km}km away';
  }
}

class CommunityPostItem extends FeedItem {
  final String authorAlias;
  final String category;
  final String? title;
  final String content;
  int upvotes;
  bool isUpvoted;
  final int commentsCount;
  final double? latitude;
  final double? longitude;
  final List<String> mediaUrls;
  final DateTime createdAt;

  CommunityPostItem({
    required super.id,
    required this.authorAlias,
    required this.category,
    this.title,
    required this.content,
    required this.upvotes,
    this.isUpvoted = false,
    this.commentsCount = 0,
    this.latitude,
    this.longitude,
    this.mediaUrls = const [],
    required this.createdAt,
    super.distanceMeters,
  }) : super(type: 'community_post');

  factory CommunityPostItem.fromJson(Map<String, dynamic> json) {
    return CommunityPostItem(
      id: json['id'] as String? ?? '',
      authorAlias: json['author_alias'] as String? ?? 'Neighbor',
      category: json['category'] as String? ?? 'general',
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      upvotes: json['upvotes'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      mediaUrls: (json['media_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      distanceMeters: json['distance_meters'] as int?,
    );
  }

  String get timeAgoFormatted {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class NativeAdItem extends FeedItem {
  final String businessName;
  final String? tagline;
  final String ctaTitle;
  final String? whatsappUrl;

  NativeAdItem({
    required super.id,
    required this.businessName,
    this.tagline,
    required this.ctaTitle,
    this.whatsappUrl,
    super.distanceMeters,
  }) : super(type: 'native_ad');

  factory NativeAdItem.fromJson(Map<String, dynamic> json) {
    return NativeAdItem(
      id: json['id'] as String? ?? '',
      businessName: json['business_name'] as String? ?? 'Local Partner',
      tagline: json['tagline'] as String?,
      ctaTitle: json['cta_title'] as String? ?? 'Contact on WhatsApp',
      whatsappUrl: json['whatsapp_url'] as String?,
      distanceMeters: json['distance_meters'] as int?,
    );
  }
}
