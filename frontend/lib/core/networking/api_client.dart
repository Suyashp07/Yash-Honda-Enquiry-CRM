import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: 'accessToken');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401 &&
            !error.requestOptions.path.contains('/auth/login') &&
            !error.requestOptions.path.contains('/auth/refresh')) {
          try {
            final refreshToken = await storage.read(key: 'refreshToken');
            if (refreshToken != null && refreshToken.isNotEmpty) {
              final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
              final refreshRes = await refreshDio.post(
                '/auth/refresh',
                data: {'refreshToken': refreshToken},
              );
              final newAccessToken = refreshRes.data['accessToken'] as String?;
              if (newAccessToken != null && newAccessToken.isNotEmpty) {
                await storage.write(key: 'accessToken', value: newAccessToken);
                error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                final response = await dio.fetch(error.requestOptions);
                return handler.resolve(response);
              }
            }
          } catch (_) {
            await storage.deleteAll();
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});

