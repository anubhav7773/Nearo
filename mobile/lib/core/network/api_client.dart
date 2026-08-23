import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import 'secure_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
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
          // Handle 401 Unauthorized for token refresh
          if (error.response?.statusCode == 401) {
            final refreshToken = await SecureStorageService.getRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                // Attempt token refresh
                final refreshResponse = await Dio(
                  BaseOptions(baseUrl: ApiEndpoints.baseUrl),
                ).post(
                  ApiEndpoints.verifyOtp,
                  data: {'refresh_token': refreshToken},
                );

                if (refreshResponse.statusCode == 200 && refreshResponse.data != null) {
                  final newAccessToken = refreshResponse.data['access_token'];
                  if (newAccessToken != null) {
                    await SecureStorageService.saveAccessToken(newAccessToken);

                    // Retry original request with new access token
                    final retryOptions = error.requestOptions;
                    retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                    final retryResponse = await dio.fetch(retryOptions);
                    return handler.resolve(retryResponse);
                  }
                }
              } catch (_) {
                // If refresh fails, clear invalid session
                await SecureStorageService.clearSession();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
