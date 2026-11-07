import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perfumes/main.dart';

void main() {
  testWidgets('App renders saved recipes empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PerfumeApp());
    await tester.pumpAndSettle();

    expect(find.text('Perfume Calculator'), findsWidgets);
    expect(find.text('Saved Recipes'), findsOneWidget);
    expect(find.textContaining('No recipes yet'), findsOneWidget);
    expect(find.text('New recipe'), findsOneWidget);
  });
}
