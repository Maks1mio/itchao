import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itchao/app.dart';

void main() {
  testWidgets('app opens gate screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ItchaoApp()));
    await tester.pump();
    expect(find.text('Вход'), findsOneWidget);
  });
}
