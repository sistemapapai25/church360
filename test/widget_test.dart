// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/main.dart';
import 'package:church360_app/core/constants/supabase_constants.dart';

void main() {
  testWidgets('App builds MaterialApp.router', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    );

    await tester.pumpWidget(const Church360App());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
