import 'package:fernecito_frontend/core/promos_hot.dart';
import 'package:fernecito_frontend/widgets/flyer_red_con_fallback.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('URL vacía usa el asset de marca', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: SizedBox(
          width: 120,
          height: 180,
          child: FlyerRedConFallback(url: ''),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      kAssetFlyerMarcaDefault,
    );
  });
}
