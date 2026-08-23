abstract class FeedEvent {}

class FetchFeed extends FeedEvent {
  final double? lat;
  final double? lng;
  final int? radiusMeters;
  final String? category;

  FetchFeed({this.lat, this.lng, this.radiusMeters, this.category});
}

class RefreshFeed extends FeedEvent {}

class ChangeRadiusFilter extends FeedEvent {
  final int radiusMeters;

  ChangeRadiusFilter(this.radiusMeters);
}

class ChangeCategoryFilter extends FeedEvent {
  final String category;

  ChangeCategoryFilter(this.category);
}

class UpvotePost extends FeedEvent {
  final String postId;

  UpvotePost(this.postId);
}
