import 'package:flutter_test/flutter_test.dart';
import 'package:rfu_hub/main.dart';

void main() {
  testWidgets('RFU Hub smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RFUHubApp());
    expect(find.text('RFU HUB'), findsWidgets);
  });
}
