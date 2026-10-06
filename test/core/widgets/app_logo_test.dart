import 'package:church360_app/core/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String> assetOf(
    WidgetTester tester,
    AppLogo logo, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Center(child: logo),
      ),
    );
    await tester.pumpAndSettle(); // a troca de tema do MaterialApp é animada
    final image = tester.widget<Image>(find.byType(Image)).image as AssetImage;
    // Falha se o arquivo não estiver declarado no pubspec.
    await rootBundle.load(image.assetName);
    return image.assetName;
  }

  testWidgets('auto segue o tema', (tester) async {
    expect(
      await assetOf(tester, const AppLogo()),
      'assets/images/logo_colorida.png',
    );
    expect(
      await assetOf(tester, const AppLogo(), brightness: Brightness.dark),
      'assets/images/logo_branca.png',
    );
  });

  testWidgets('variantes fixas ignoram o tema', (tester) async {
    expect(
      await assetOf(
        tester,
        const AppLogo(variant: AppLogoVariant.colorida),
        brightness: Brightness.dark,
      ),
      'assets/images/logo_colorida.png',
    );
    expect(
      await assetOf(tester, const AppLogo(variant: AppLogoVariant.branca)),
      'assets/images/logo_branca.png',
    );
    expect(
      await assetOf(tester, const AppLogo(variant: AppLogoVariant.selo)),
      'assets/images/logo_selo.png',
    );
  });

  testWidgets('color pinta a silhueta branca', (tester) async {
    expect(
      await assetOf(
        tester,
        const AppLogo(variant: AppLogoVariant.selo, color: Colors.red),
      ),
      'assets/images/logo_branca.png',
    );
  });
}
