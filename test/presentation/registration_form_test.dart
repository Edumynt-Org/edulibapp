import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edulibapp/presentation/registration_form.dart';

void main() {
  group('RegistrationForm', () {
    testWidgets('renders all required fields', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RegistrationForm(),
        ),
      ));

      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
      expect(find.byKey(const Key('full_name_field')), findsOneWidget);
      expect(find.byKey(const Key('username_field')), findsOneWidget);
      expect(find.byKey(const Key('register_button')), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RegistrationForm(),
        ),
      ));

      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Full Name is required'), findsOneWidget);
      expect(find.text('Username is required'), findsOneWidget);
    });
    
    testWidgets('calls onSubmit with correct values', (WidgetTester tester) async {
      Map<String, String>? submittedData;
      
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RegistrationForm(
            onSubmit: (data) {
              submittedData = data;
            },
          ),
        ),
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'password123');
      await tester.enterText(find.byKey(const Key('full_name_field')), 'Test User');
      await tester.enterText(find.byKey(const Key('username_field')), 'testuser');
      
      await tester.tap(find.byKey(const Key('register_button')));
      await tester.pump();

      expect(submittedData, isNotNull);
      expect(submittedData!['email'], 'test@example.com');
      expect(submittedData!['password'], 'password123');
      expect(submittedData!['fullName'], 'Test User');
      expect(submittedData!['username'], 'testuser');
    });
  });
}
