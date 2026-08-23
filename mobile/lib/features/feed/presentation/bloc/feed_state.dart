import '../../data/models/feed_item_model.dart';

abstract class FeedState {}

class FeedInitial extends FeedState {}

class FeedLoading extends FeedState {}

class FeedLoaded extends FeedState {
  final List<FeedItem> items;
  final int activeRadiusMeters;
  final String activeCategory;
  final double userLat;
  final double userLng;
  final bool isRefreshing;

  FeedLoaded({
    required this.items,
    this.activeRadiusMeters = 1500,
    this.activeCategory = 'all',
    this.userLat = 26.7922,
    this.userLng = 82.1998,
    this.isRefreshing = false,
  });

  FeedLoaded copyWith({
    List<FeedItem>? items,
    int? activeRadiusMeters,
    String? activeCategory,
    double? userLat,
    double? userLng,
    bool? isRefreshing,
  }) {
    return FeedLoaded(
      items: items ?? this.items,
      activeRadiusMeters: activeRadiusMeters ?? this.activeRadiusMeters,
      activeCategory: activeCategory ?? this.activeCategory,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class FeedError extends FeedState {
  final String message;

  FeedError(this.message);
}
