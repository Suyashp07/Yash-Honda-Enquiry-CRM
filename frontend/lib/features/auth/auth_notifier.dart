import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../core/networking/api_client.dart';
import '../../core/providers/branch_provider.dart';
import '../../shared/models/user_model.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio dio;
  final FlutterSecureStorage storage;
  final Ref? ref;

  AuthNotifier({required this.dio, required this.storage, this.ref}) : super(AuthState(isLoading: true)) {
    checkInitialAuth();
  }

  Future<void> checkInitialAuth() async {
    try {
      final token = await storage.read(key: 'accessToken');
      final userStr = await storage.read(key: 'userData');

      if (token != null && userStr != null) {
        final userJson = jsonDecode(userStr);
        final user = UserModel.fromJson(userJson);
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: user,
        );

        // When Owner or Super Admin logs in, always default to all branches
        if (user.isSuperAdmin || user.isOwner) {
          ref?.read(selectedBranchIdProvider.notifier).state = 'all';
        } else if (user.branches.isNotEmpty) {
          ref?.read(selectedBranchIdProvider.notifier).state = user.branches.first.id;
        }
        return;
      }
    } catch (_) {}

    state = state.copyWith(isLoading: false, isAuthenticated: false);
  }

  Future<bool> login(String mobile, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await dio.post('/auth/login', data: {
        'mobile': mobile,
        'password': password,
      });

      final data = response.data;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final user = UserModel.fromJson(data['user']);

      await storage.write(key: 'accessToken', value: accessToken);
      await storage.write(key: 'refreshToken', value: refreshToken);
      await storage.write(key: 'userData', value: jsonEncode(user.toJson()));

      // Super Admin and Owner must always see all branches by default on login
      if (user.isSuperAdmin || user.isOwner) {
        ref?.read(selectedBranchIdProvider.notifier).state = 'all';
      } else if (user.branches.isNotEmpty) {
        ref?.read(selectedBranchIdProvider.notifier).state = user.branches.first.id;
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Login failed. Please check credentials.';
      state = state.copyWith(isLoading: false, error: message.toString());
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await storage.deleteAll();
    state = AuthState();
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(dio: dio, storage: storage, ref: ref);
});

