import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roll_tycoon/app/app.dart';

void main() {
  testWidgets('App boots without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PastelParkApp()),
    );
    // One pump to lay everything out, then end the test before the
    // simulation timer fires so we don't leak a periodic Timer.
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
