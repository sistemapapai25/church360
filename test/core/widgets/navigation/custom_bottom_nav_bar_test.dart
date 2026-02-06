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
            items: const [
              PremiumNavItem(
                label: 'Home',
                icon: Icons.home_rounded,
                activeColor: Colors.blue,
              ),
              PremiumNavItem(
                label: 'Bíblia',
                icon: Icons.menu_book_rounded,
                activeColor: Colors.purple,
              ),
              PremiumNavItem(
                label: 'Igreja',
                icon: Icons.church_outlined,
                activeColor: Colors.indigo,
              ),
              PremiumNavItem(
                label: 'Cursos',
                icon: Icons.school_rounded,
                activeColor: Colors.green,
              ),
              PremiumNavItem(
                label: 'Mais',
                icon: Icons.menu,
                activeColor: Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );

    // Verify all 5 items are present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Bíblia'), findsOneWidget);
    expect(find.text('Igreja'), findsOneWidget);
    expect(find.text('Cursos'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.church_outlined), findsOneWidget);
    expect(find.byIcon(Icons.school_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);

    // Tap Igreja (index 2)
    await tester.tap(find.text('Igreja'));
    await tester.pump();

    expect(selectedIndex, 2);
  });
}
