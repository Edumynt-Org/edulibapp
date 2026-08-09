import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:edulibapp/data/directus/directus_auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late DirectusAuthRepository repository;
  late MockHttpClient mockHttpClient;
  late MockFlutterSecureStorage mockSecureStorage;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockSecureStorage = MockFlutterSecureStorage();
    
    // Default mocks for secure storage
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
        
    repository = DirectusAuthRepository(
      baseUrl: 'http://localhost:8056',
      client: mockHttpClient,
      secureStorage: mockSecureStorage,
    );
  });

  group('register', () {
    test('calls Directus users endpoint with correct payload', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'data': {
                'id': 'new-user-id',
                'email': 'test@example.com',
                'first_name': 'Test User'
              }
            }),
            200,
          ));

      final user = await repository.register('test@example.com', 'password123', 'Test User', 'testuser');

      verify(() => mockHttpClient.post(
            Uri.parse('http://localhost:8056/users'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': 'test@example.com',
              'password': 'password123',
              'first_name': 'Test User',
              'username': 'testuser',
              'role': '0e0d3c31-4754-4856-bbe8-71ff7803e082',
            }),
          )).called(1);

      expect(user.id, 'new-user-id');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
    });

    test('throws an error if request fails', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'errors': [
                {'message': 'Email already exists'}
              ]
            }),
            400,
          ));

      expect(
        () => repository.register('test@example.com', 'password123', 'Test User', 'testuser'),
        throwsException,
      );
    });
  });

  group('login', () {
    test('calls Directus auth endpoint and returns user', () async {
      when(() => mockHttpClient.post(
            Uri.parse('http://localhost:8056/auth/login'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'data': {
                'access_token': 'access-token',
                'refresh_token': 'refresh-token',
                'expires': 900000,
              }
            }),
            200,
          ));

      when(() => mockHttpClient.get(
            Uri.parse('http://localhost:8056/users/me'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'data': {
                'id': 'user-id',
                'email': 'test@example.com',
                'first_name': 'Test User',
                'role': '0e0d3c31-4754-4856-bbe8-71ff7803e082',
              }
            }),
            200,
          ));

      final user = await repository.login('test@example.com', 'password123');

      verify(() => mockHttpClient.post(
            Uri.parse('http://localhost:8056/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': 'test@example.com',
              'password': 'password123',
            }),
          )).called(1);

      expect(user.id, 'user-id');
      expect(user.email, 'test@example.com');
      
      verify(() => mockSecureStorage.write(key: 'access_token', value: 'access-token')).called(1);
      verify(() => mockSecureStorage.write(key: 'refresh_token', value: 'refresh-token')).called(1);
    });
  });

  group('logout', () {
    test('calls Directus logout endpoint and clears storage', () async {
      when(() => mockSecureStorage.read(key: 'refresh_token'))
          .thenAnswer((_) async => 'stored-refresh-token');
          
      when(() => mockHttpClient.post(
            Uri.parse('http://localhost:8056/auth/logout'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({}),
            200,
          ));

      await repository.logout();

      verify(() => mockHttpClient.post(
            Uri.parse('http://localhost:8056/auth/logout'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': 'stored-refresh-token'}),
          )).called(1);
          
      verify(() => mockSecureStorage.delete(key: 'access_token')).called(1);
      verify(() => mockSecureStorage.delete(key: 'refresh_token')).called(1);
    });
  });
}
