import 'package:church360_app/core/widgets/navigation/custom_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PremiumBottomNavBar renders correctly and handles taps', (WidgetTester tester) async {
    int selectedIndex = 0;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: PremiumBottomNavBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              selectedIndex = index;
            },
          ),
        ),
      ),
    );

    // Verify all 5 items are present
    expect(find.text('Devocionais'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Contribua'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);

    expect(find.byIcon(Icons.menu_book), findsOneWidget);
    expect(find.byIcon(Icons.event), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volunteer_activism), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);

    // Tap Home (index 2)
    await tester.tap(find.text('Home'));
    await tester.pump();

    expect(selectedIndex, 2);
  });
}
