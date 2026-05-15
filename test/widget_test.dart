import 'package:flutter_test/flutter_test.dart';

import 'package:codex_paralarm/main.dart';

void main() {
  testWidgets('settings screen is shown', (WidgetTester tester) async {
    await tester.pumpWidget(const ParalarmApp());

    expect(find.text('Par-alarm'), findsOneWidget);
    expect(find.text('ターゲット'), findsOneWidget);
    expect(find.text('現在の音量'), findsOneWidget);
  });
}
