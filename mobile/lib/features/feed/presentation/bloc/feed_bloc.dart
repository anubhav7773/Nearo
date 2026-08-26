import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
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
    on<CreatePostEvent>(_onCreatePost);
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

    try {
      final queryParams = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'radius_meters': radius,
        'page': 1,
        'limit': 20,
      };
      if (category != 'all' && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.posts,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        List<dynamic> rawList = [];
        if (response.data is List) {
          rawList = response.data as List<dynamic>;
        } else if (response.data is Map && response.data['data'] is List) {
          rawList = response.data['data'] as List<dynamic>;
        }

        List<FeedItem> items = rawList
            .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
            .toList();

        // Client-side category matching if needed
        if (category != 'all' && category.isNotEmpty) {
          final normalizedCat = category.toLowerCase().replaceAll(' ', '_');
          items = items.where((item) {
            if (item is CommunityPostItem) {
              final postCat = item.category.toLowerCase().replaceAll(' ', '_');
              return postCat == normalizedCat || postCat.contains(normalizedCat);
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
        emit(FeedLoaded(
          items: const [],
          activeRadiusMeters: radius,
          activeCategory: category,
          userLat: lat,
          userLng: lng,
        ));
      }
    } catch (e) {
      // Clean fallback: empty feed if offline/error
      emit(FeedLoaded(
        items: const [],
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

  Future<void> _onUpvotePost(UpvotePost event, Emitter<FeedState> emit) async {
    if (state is FeedLoaded) {
      final current = state as FeedLoaded;
      final updated = current.items.map((item) {
        if (item is CommunityPostItem && item.id == event.postId) {
          final isUpvoted = !item.isUpvoted;
          final upvotes = isUpvoted ? item.upvotes + 1 : (item.upvotes > 0 ? item.upvotes - 1 : 0);
          return CommunityPostItem(
            id: item.id,
            authorAlias: item.authorAlias,
            authorTier: item.authorTier,
            authorAvatarUrl: item.authorAvatarUrl,
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
            distanceText: item.distanceText,
          );
        }
        return item;
      }).toList();

      emit(current.copyWith(items: updated));

      // Network sync in background
      try {
        await _apiClient.dio.post('${ApiEndpoints.posts}/${event.postId}/upvote');
      } catch (_) {}
    }
  }

  Future<void> _onCreatePost(CreatePostEvent event, Emitter<FeedState> emit) async {
    double validLat = event.latitude;
    double validLng = event.longitude;

    if (validLat == 0.0 && validLng == 0.0) {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null && pos.latitude != 0.0) {
          validLat = pos.latitude;
          validLng = pos.longitude;
        } else {
          validLat = 26.7922;
          validLng = 82.1998;
        }
      } catch (_) {
        validLat = 26.7922;
        validLng = 82.1998;
      }
    }

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.posts,
        data: {
          'title': event.title,
          'content': event.content,
          'category': event.category,
          'latitude': validLat,
          'longitude': validLng,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        add(RefreshFeed());
      }
    } catch (_) {
      add(RefreshFeed());
    }
  }
}
