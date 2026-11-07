import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perfumes/services/recipe_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy pcs items migrate from ingredient to packaging library', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.ingredients_library': jsonEncode([
        {
          'id': 'a1',
          'name': 'Essence',
          'unit': 'ml',
          'packageSize': 10.0,
          'packagePrice': 800.0,
        },
        {
          'id': 'b2',
          'name': 'Bottole 50 ml',
          'unit': 'pcs',
          'packageSize': 1.0,
          'packagePrice': 140.0,
        },
      ]),
    });

    final storage = RecipeStorage();
    await storage.migrateLegacyPackaging();

    final library = await storage.loadLibrary();
    expect(library.length, 1);
    expect(library.single.name, 'Essence');

    final packaging = await storage.loadPackaging();
    expect(packaging.single.id, 'b2'); // id preserved for recipe links
    expect(packaging.single.name, 'Bottole 50 ml');
    expect(packaging.single.pricePerPc, 140);
    expect(packaging.single.sizeMl, 50); // size parsed from legacy name
  });

  test('legacy bottleVariants get prices from the packaging library', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.recipes': jsonEncode([
        {
          'id': 'r1',
          'name': 'Victus',
          'ingredients': [
            {'name': 'X', 'percent': 100}
          ],
          'bottleVariants': [15, 100],
          'createdAt': '2026-11-07T06:00:00.000',
        }
      ]),
      'flutter.packaging_library': jsonEncode([
        {'id': 'p1', 'name': 'Package', 'sizeMl': 100, 'pricePerPc': 150.0},
      ]),
    });

    final storage = RecipeStorage();
    final recipes = await storage.load();

    final variants = recipes.single.variants;
    expect(variants.map((v) => v.sizeMl), [15, 100]);
    expect(variants[0].price, 0); // no 15 ml package in the library
    expect(variants[1].price, 150); // price filled from the library

    // migrated format persisted
    final again = await storage.load();
    expect(again.single.variants[1].price, 150);
  });

  test('migration is a no-op without legacy pcs items', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.ingredients_library': jsonEncode([
        {
          'id': 'a1',
          'name': 'Essence',
          'unit': 'ml',
          'packageSize': 10.0,
          'packagePrice': 800.0,
        },
      ]),
    });

    final storage = RecipeStorage();
    await storage.migrateLegacyPackaging();

    expect((await storage.loadLibrary()).length, 1);
    expect((await storage.loadPackaging()), isEmpty);
  });
}
