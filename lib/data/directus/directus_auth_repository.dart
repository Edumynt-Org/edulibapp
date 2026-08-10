import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/models/user.dart';

import '../../domain/repositories/sync_connector.dart';

class DirectusAuthRepository implements IAuthRepository {
  final String baseUrl;
  final http.Client client;
  final FlutterSecureStorage secureStorage;
  final ISyncConnector? syncConnector;

  DirectusAuthRepository({
    required this.baseUrl, 
    required this.client,
    this.secureStorage = const FlutterSecureStorage(),
    this.syncConnector,
  });

  static const _anonymousGuest = AppUser(
    id: 'guest',
    role: 'anonymous',
    isAnonymous: true,
    displayName: 'Guest Reader',
  );

  @override
  Future<AppUser> getCurrentUser() async {
    final token = await secureStorage.read(key: 'access_token');
    if (token == null) {
      return _anonymousGuest;
    }
    
    try {
      final response = await _fetchWithAuth('/users/me');
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return AppUser(
          id: result['data']['id'],
          email: result['data']['email'],
          displayName: result['data']['first_name'],
          role: result['data']['role'],
          isAnonymous: false,
        );
      }
    } catch (e) {
      // Fallback to guest on error
    }
    
    return _anonymousGuest;
  }

  bool _isRefreshing = false;
  Future<void>? _refreshFuture;

  Future<http.Response> _fetchWithAuth(
    String path, {
    Map<String, String>? headers,
  }) async {
    final accessToken = await secureStorage.read(key: 'access_token');
    
    final uri = Uri.parse('$baseUrl$path');
    final Map<String, String> mergedHeaders = {
      ...?headers,
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    var response = await client.get(uri, headers: mergedHeaders);

    if (response.statusCode == 401) {
      if (!_isRefreshing) {
        _isRefreshing = true;
        _refreshFuture = refreshSession().whenComplete(() {
          _isRefreshing = false;
          _refreshFuture = null;
        });
      }

      try {
        await _refreshFuture;
        final newAccessToken = await secureStorage.read(key: 'access_token');
        mergedHeaders['Authorization'] = 'Bearer $newAccessToken';
        response = await client.get(uri, headers: mergedHeaders);
      } catch (e) {
        // Refresh failed, return original 401
        return response;
      }
    }

    return response;
  }

  @override
  Future<AppUser> login(String email, String password) async {
    final response = await client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final result = jsonDecode(response.body);

    if (response.statusCode != 200) {
      final errorMessage = (result['errors'] != null && result['errors'].isNotEmpty)
          ? result['errors'][0]['message']
          : 'Login failed';
      throw Exception(errorMessage);
    }

    final accessToken = result['data']['access_token'];
    final refreshToken = result['data']['refresh_token'];

    await secureStorage.write(key: 'access_token', value: accessToken);
    await secureStorage.write(key: 'refresh_token', value: refreshToken);

    final userResponse = await _fetchWithAuth('/users/me');

    final userResult = jsonDecode(userResponse.body);

    if (userResponse.statusCode != 200) {
      throw Exception('Failed to fetch user profile');
    }

    if (syncConnector != null) {
      await syncConnector!.migrateGuestData(userResult['data']['id']);
    }

    return AppUser(
      id: userResult['data']['id'],
      email: userResult['data']['email'],
      displayName: userResult['data']['first_name'],
      role: userResult['data']['role'],
      isAnonymous: false,
    );
  }

  @override
  Future<void> logout() async {
    final refreshToken = await secureStorage.read(key: 'refresh_token');
    
    if (refreshToken != null) {
      await client.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    }

    await secureStorage.delete(key: 'access_token');
    await secureStorage.delete(key: 'refresh_token');
  }

  @override
  Future<void> refreshSession() async {
    final refreshToken = await secureStorage.read(key: 'refresh_token');
    
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final response = await client.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'refresh_token': refreshToken,
        'mode': 'json',
      }),
    );

    if (response.statusCode != 200) {
      await secureStorage.delete(key: 'access_token');
      await secureStorage.delete(key: 'refresh_token');
      throw Exception('Session expired');
    }

    final result = jsonDecode(response.body);
    final newAccessToken = result['data']['access_token'];
    final newRefreshToken = result['data']['refresh_token'];

    await secureStorage.write(key: 'access_token', value: newAccessToken);
    await secureStorage.write(key: 'refresh_token', value: newRefreshToken);
  }

  @override
  Future<void> migrateGuestState(String newProfileId) async {
    if (syncConnector != null) {
      try {
        await syncConnector!.migrateGuestData(newProfileId);
      } catch (e) {
        throw Exception('Failed to migrate guest data: $e');
      }
    }
  }

  @override
  Future<AppUser> register(String email, String password, String firstName, String lastName) async {
    final response = await client.post(
      Uri.parse('$baseUrl/users/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'verification_url': 'https://edumynt.org/verify-email',
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204) {
      final result = jsonDecode(response.body);
      final errorMessage = (result['errors'] != null && result['errors'].isNotEmpty)
          ? result['errors'][0]['message']
          : 'Registration failed';
      throw Exception(errorMessage);
    }

    // Directus returns 204 No Content on successful registration to prevent information leakage
    return AppUser(
      id: 'pending',
      email: email,
      displayName: firstName,
      username: firstName.isNotEmpty ? firstName : email.split('@')[0],
      role: 'pending',
    );
  }
}
