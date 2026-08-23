import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../data/models/feed_item_model.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final ApiClient _apiClient = ApiClient();

  FeedBloc() : super(FeedInitial()) {
    on<FetchFeed>(_onFetchFeed);
    on<RefreshFeed>(_onRefreshFeed);
    on<ChangeRadiusFilter>(_onChangeRadiusFilter);
    on<ChangeCategoryFilter>(_onChangeCategoryFilter);
    on<UpvotePost>(_onUpvotePost);
  }

  Future<Position?> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _onFetchFeed(FetchFeed event, Emitter<FeedState> emit) async {
    int radius = event.radiusMeters ?? 1500;
    String category = event.category ?? 'all';
    double lat = event.lat ?? 26.7922;
    double lng = event.lng ?? 82.1998;

    if (state is! FeedLoaded) {
      emit(FeedLoading());
    }

    // Try live GPS if not passed
    if (event.lat == null || event.lng == null) {
      final pos = await _determinePosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    }

    // Apply DPDP 200m–500m coordinate jitter for user privacy compliance
    final jittered = GeoUtils.applyJitter(
      latitude: lat,
      longitude: lng,
      minMeters: 200.0,
      maxMeters: 500.0,
    );
    final queryLat = jittered['latitude'] ?? lat;
    final queryLng = jittered['longitude'] ?? lng;

    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.feed,
        queryParameters: {
          'lat': queryLat,
          'lng': queryLng,
          'radius_meters': radius,
          'page': 1,
          'limit': 20,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawList = response.data['data'] as List<dynamic>? ?? [];
        List<FeedItem> items = rawList
            .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
            .toList();

        // Apply category filter if active
        if (category != 'all') {
          items = items.where((item) {
            if (item is CommunityPostItem) {
              return item.category.toLowerCase() == category.toLowerCase();
            }
            return true; // Keep ads in feed
          }).toList();
        }

        emit(FeedLoaded(
          items: items,
          activeRadiusMeters: radius,
          activeCategory: category,
          userLat: lat,
          userLng: lng,
        ));
      } else {
        emit(FeedError('Failed to fetch neighborhood feed.'));
      }
    } catch (e) {
      // If error occurs (e.g. offline/mock demo), emit fallback data
      final fallbackItems = _generateFallbackFeed();
      emit(FeedLoaded(
        items: fallbackItems,
        activeRadiusMeters: radius,
        activeCategory: category,
        userLat: lat,
        userLng: lng,
      ));
    }
  }

  Future<void> _onRefreshFeed(RefreshFeed event, Emitter<FeedState> emit) async {
    if (state is FeedLoaded) {
      final currentState = state as FeedLoaded;
      emit(currentState.copyWith(isRefreshing: true));
      add(FetchFeed(
        lat: currentState.userLat,
        lng: currentState.userLng,
        radiusMeters: currentState.activeRadiusMeters,
        category: currentState.activeCategory,
      ));
    } else {
      add(FetchFeed());
    }
  }

  Future<void> _onChangeRadiusFilter(
      ChangeRadiusFilter event, Emitter<FeedState> emit) async {
    if (state is FeedLoaded) {
      final current = state as FeedLoaded;
      add(FetchFeed(
        lat: current.userLat,
        lng: current.userLng,
        radiusMeters: event.radiusMeters,
        category: current.activeCategory,
      ));
    }
  }

  Future<void> _onChangeCategoryFilter(
      ChangeCategoryFilter event, Emitter<FeedState> emit) async {
    if (state is FeedLoaded) {
      final current = state as FeedLoaded;
      add(FetchFeed(
        lat: current.userLat,
        lng: current.userLng,
        radiusMeters: current.activeRadiusMeters,
        category: event.category,
      ));
    }
  }

  void _onUpvotePost(UpvotePost event, Emitter<FeedState> emit) {
    if (state is FeedLoaded) {
      final current = state as FeedLoaded;
      final updated = current.items.map((item) {
        if (item is CommunityPostItem && item.id == event.postId) {
          final isUpvoted = !item.isUpvoted;
          final upvotes = isUpvoted ? item.upvotes + 1 : item.upvotes - 1;
          return CommunityPostItem(
            id: item.id,
            authorAlias: item.authorAlias,
            category: item.category,
            title: item.title,
            content: item.content,
            upvotes: upvotes,
            isUpvoted: isUpvoted,
            commentsCount: item.commentsCount,
            latitude: item.latitude,
            longitude: item.longitude,
            mediaUrls: item.mediaUrls,
            createdAt: item.createdAt,
            distanceMeters: item.distanceMeters,
          );
        }
        return item;
      }).toList();

      emit(current.copyWith(items: updated));
    }
  }

  List<FeedItem> _generateFallbackFeed() {
    return [
      CommunityPostItem(
        id: 'post_1',
        authorAlias: 'Nagarik_99',
        category: 'civic_issue',
        title: 'Sector 4 Water Supply Line Maintenance',
        content:
            'The municipal pipeline repair is currently ongoing near the main gate. Water supply expected to resume by 5 PM.',
        upvotes: 14,
        commentsCount: 3,
        distanceMeters: 340,
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
      CommunityPostItem(
        id: 'post_2',
        authorAlias: 'AyodhyaResident_04',
        category: 'alert',
        title: 'Cyber Fraud / Fake Electricity Bill SMS Alert',
        content:
            'Residents received fake SMS asking to call an unknown number for immediate bill payment. Do not click any links or share OTPs!',
        upvotes: 28,
        commentsCount: 8,
        distanceMeters: 520,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      CommunityPostItem(
        id: 'post_3',
        authorAlias: 'KalyanSamiti_2',
        category: 'help_needed',
        title: 'Urgent B+ Blood Donor at District Hospital',
        content:
            'Emergency patient admitted in trauma ward. Anyone available near Civil Lines please contact hospital reception directly.',
        upvotes: 45,
        commentsCount: 12,
        distanceMeters: 750,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NativeAdItem(
        id: 'ad_1',
        businessName: 'Gupta Diagnostic Center',
        tagline:
            'Special 20% off full body checkups for verified neighborhood residents',
        ctaTitle: 'Chat on WhatsApp',
        whatsappUrl: 'https://wa.me/919876543210?text=Hello%20Nearo%20Offer',
        distanceMeters: 820,
      ),
      CommunityPostItem(
        id: 'post_4',
        authorAlias: 'Parihar_Shop',
        category: 'trade',
        title: 'Fresh Organic Mangoes Arrived',
        content:
            'Directly from Malihabad orchard. Available at Shop #12 near Central Mandir.',
        upvotes: 9,
        commentsCount: 2,
        distanceMeters: 950,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];
  }
}
