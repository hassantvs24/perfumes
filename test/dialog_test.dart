import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perfumes/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PerfumeApp());
    await tester.pumpAndSettle();
  }

  testWidgets('Menu sheet navigates to the Ingredients library', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Ingredients library'), findsOneWidget);

    await tester.tap(find.text('Ingredients library'));
    await tester.pumpAndSettle();

    expect(find.text('Ingredients Library'), findsOneWidget); // app bar title
  });

  testWidgets('Delete recipe dialog shows Cancel/Delete in one row', (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.recipes':
          '[{"id":"r1","name":"Victus","description":"EDP","ingredients":[{"name":"X","percent":100}],"createdAt":"2026-11-07T00:00:00.000"}]',
    });
    await tester.pumpWidget(const PerfumeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final cancel = tester.getRect(find.text('Cancel'));
    final confirm = tester.getRect(find.text('Delete'));
    // same row: vertical ranges overlap
    expect(
      cancel.top < confirm.bottom && confirm.top < cancel.bottom,
      isTrue,
      reason: 'Cancel/Delete should be side by side, not stacked',
    );
    // and not full-width
    expect(cancel.width < 400, isTrue);
  });

  testWidgets('Add ingredient dialog shows full labels and a button row',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingredients library'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add ingredient'));
    await tester.pumpAndSettle();

    expect(find.text('Pack size'), findsOneWidget);
    expect(find.text('Pack price'), findsOneWidget);

    final cancel = tester.getRect(find.text('Cancel'));
    final save = tester.getRect(find.text('Save'));
    expect(
      cancel.top < save.bottom && save.top < cancel.bottom,
      isTrue,
      reason: 'Cancel/Save should be side by side',
    );
  });
}
