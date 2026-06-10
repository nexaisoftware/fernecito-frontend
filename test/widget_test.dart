/// Tests de widgets para la aplicación Fernecito.
/// 
/// Este archivo contiene tests básicos de widgets usando flutter_test.
/// Verifica que los componentes principales se construyan correctamente.
/// 
/// Para ejecutar: `flutter test`
/// 
/// Nota: Los tests que requieren Supabase pueden necesitar mocks o configuración
/// de test environment (ver test/helpers/ si se crean).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fernecito_frontend/app.dart';

void main() {
  testWidgets('La app se construye correctamente', (WidgetTester tester) async {
    // Construye la app y renderiza un frame
    await tester.pumpWidget(const AppFernecito());

    // Verifica que la app se construye sin errores
    expect(find.byType(AppFernecito), findsOneWidget);
  });
}
