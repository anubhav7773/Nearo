import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/api_endpoints.dart';
import 'secure_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  void Function()? onUnauthorized;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attach JWT bearer token if present
          final token = await SecureStorageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Handle 401 Unauthorized globally without infinite retry loops
          if (error.response?.statusCode == 401) {
            final alreadyRetried = error.requestOptions.extra['_retry'] == true;
            if (!alreadyRetried) {
              try {
                final firebaseUser = FirebaseAuth.instance.currentUser;
                final refreshedToken = await firebaseUser?.getIdToken(true);

                if (refreshedToken != null && refreshedToken.isNotEmpty) {
                  await SecureStorageService.saveAccessToken(refreshedToken);

                  // Retry original request once with the refreshed ID token
                  final retryOptions = error.requestOptions;
                  retryOptions.extra['_retry'] = true;
                  retryOptions.headers['Authorization'] = 'Bearer $refreshedToken';
                  final retryResponse = await dio.fetch(retryOptions);
                  return handler.resolve(retryResponse);
                }
              } catch (_) {}
            }

            // If refresh fails, already retried, or session expired -> purge and notify
            await SecureStorageService.clearSession();
            onUnauthorized?.call();
          }

          return handler.next(error);
        },
      ),
    );
  }
}
