import 'package:flutter_test/flutter_test.dart';
import 'package:perfumes/models/library_item.dart';
import 'package:perfumes/models/packaging_entry.dart';
import 'package:perfumes/models/recipe.dart';
import 'package:perfumes/services/recipe_storage.dart';

void main() {
  group('LibraryItem', () {
    test('unitPrice divides pack price by pack size', () {
      const item = LibraryItem(
        id: '1',
        name: 'Begomot',
        unit: 'ml',
        packageSize: 10,
        packagePrice: 800,
      );
      expect(item.unitPrice, 80);
    });

    test('v4 pricePer100 converts back to a 100-unit pack', () {
      final item = LibraryItem.fromJson({
        'id': '2',
        'name': 'Essence',
        'unit': 'ml',
        'pricePer100': 1800.0,
      });
      expect(item.packageSize, 100);
      expect(item.packagePrice, 1800);
      expect(item.unitPrice, 18);
    });

    test('JSON round-trip keeps all fields', () {
      const item = LibraryItem(
        id: '3',
        name: 'Musk',
        unit: 'g',
        packageSize: 100,
        packagePrice: 1200,
      );
      expect(LibraryItem.fromJson(item.toJson()).toJson(), item.toJson());
    });
  });

  group('PackagingEntry', () {
    test('legacy pack fields convert to pricePerPc; size parsed from name', () {
      final bottle = PackagingEntry.fromJson({
        'id': 'p1',
        'name': 'Bottole 50 ml',
        'packSize': 1.0,
        'packPrice': 140.0,
      });
      expect(bottle.pricePerPc, 140);
      expect(bottle.sizeMl, 50);
      expect(bottle.isBottle, isTrue);
    });

    test('entry without a variant size is rejected', () {
      expect(
        () => PackagingEntry.fromJson({
          'id': 'p3',
          'name': 'Label',
          'packSize': 1.0,
          'packPrice': 5.0,
        }),
        throwsFormatException,
      );
    });

    test('JSON round-trip keeps all fields', () {
      const bottle = PackagingEntry(
        id: 'p4',
        name: 'Glass bottle',
        sizeMl: 100,
        pricePerPc: 150,
      );
      expect(
        PackagingEntry.fromJson(bottle.toJson()).toJson(),
        bottle.toJson(),
      );
    });
  });

  group('duplicate guards', () {
    final recipes = [
      Recipe(
        id: 'r1',
        name: 'Aventus',
        ingredients: const [],
        createdAt: DateTime(2026),
      ),
    ];
    final ingredients = const [
      LibraryItem(
        id: 'i1',
        name: 'Begomot',
        unit: 'ml',
        packageSize: 100,
        packagePrice: 1800,
      ),
    ];
    final packaging = const [
      PackagingEntry(id: 'p1', name: 'Package', sizeMl: 50, pricePerPc: 160),
      PackagingEntry(id: 'p2', name: 'Package', sizeMl: 100, pricePerPc: 150),
    ];

    test('recipe names are blocked case-insensitively', () {
      expect(RecipeStorage.isDuplicateRecipeName(recipes, 'aventus'), isTrue);
      expect(RecipeStorage.isDuplicateRecipeName(recipes, 'Sauvage'), isFalse);
      // editing itself is allowed
      expect(
        RecipeStorage.isDuplicateRecipeName(recipes, 'Aventus', excludeId: 'r1'),
        isFalse,
      );
    });

    test('ingredient names are blocked case-insensitively', () {
      expect(
        RecipeStorage.isDuplicateIngredientName(ingredients, ' BEGOMOT '),
        isTrue,
      );
      expect(
        RecipeStorage.isDuplicateIngredientName(ingredients, 'Premix'),
        isFalse,
      );
    });

    test('packaging blocks same name + size only', () {
      expect(
        RecipeStorage.isDuplicatePackaging(packaging, 'package', 50),
        isTrue,
      );
      expect(
        RecipeStorage.isDuplicatePackaging(packaging, 'Package', 150),
        isFalse,
      );
      expect(
        RecipeStorage.isDuplicatePackaging(packaging, 'Other', 50),
        isFalse,
      );
    });
  });

  group('Recipe', () {
    test('totalPercent, basePercent and packaging JSON round-trip', () {
      final recipe = Recipe(
        id: 'r1',
        name: 'Test',
        ingredients: const [
          Ingredient(name: 'A', percent: 20, ingredientId: '1'),
          Ingredient(name: 'B', percent: 15, ingredientId: '2'),
        ],
        variants: const [
          RecipeVariant(sizeMl: 15, price: 50),
          RecipeVariant(sizeMl: 100, price: 150),
        ],
        createdAt: DateTime(2026, 11, 7),
      );
      expect(recipe.totalPercent, 35);
      expect(recipe.basePercent, 65);

      final restored = Recipe.fromJson(recipe.toJson());
      expect(restored.ingredients[0].ingredientId, '1');
      expect(restored.variants.length, 2);
      expect(restored.variants[0].sizeMl, 15);
      expect(restored.variants[0].price, 50);
      expect(restored.variants[1].sizeMl, 100);
    });

    test('variants is empty when not saved', () {
      final recipe = Recipe.fromJson({
        'id': 'old',
        'name': 'Legacy',
        'ingredients': [
          {'name': 'X', 'percent': 100}
        ],
        'createdAt': '2026-01-01T00:00:00.000',
      });
      expect(recipe.variants, isEmpty);
    });

    test('legacy bottleVariants/bottleVariant parse with price 0', () {
      final fromList = Recipe.fromJson({
        'id': 'v7',
        'name': 'Old',
        'ingredients': [
          {'name': 'X', 'percent': 100}
        ],
        'bottleVariants': [15, 100],
        'createdAt': '2026-01-01T00:00:00.000',
      });
      expect(fromList.variants.map((v) => v.sizeMl), [15, 100]);
      expect(fromList.variants.every((v) => v.price == 0), isTrue);

      final fromSingle = Recipe.fromJson({
        'id': 'v6',
        'name': 'Old',
        'ingredients': [
          {'name': 'X', 'percent': 100}
        ],
        'bottleVariant': 100,
        'createdAt': '2026-01-01T00:00:00.000',
      });
      expect(fromSingle.variants.single.sizeMl, 100);
    });

    test('legacy JSON without ids/packaging still loads', () {
      final recipe = Recipe.fromJson({
        'id': 'old',
        'name': 'Legacy',
        'ingredients': [
          {'name': 'X', 'percent': 30}
        ],
        'createdAt': '2026-01-01T00:00:00.000',
      });
      expect(recipe.ingredients.single.ingredientId, isNull);
      expect(recipe.packaging, isEmpty);
      expect(recipe.basePercent, 70);
    });

    test('cost math: batch 100ml of 20% at ৳800/10ml costs ৳1600', () {
      const item = LibraryItem(
        id: '1',
        name: 'A',
        unit: 'ml',
        packageSize: 10,
        packagePrice: 800,
      );
      const ingredient = Ingredient(name: 'A', percent: 20, ingredientId: '1');
      final amount = 100 * ingredient.percent / 100;
      expect(amount * item.unitPrice, 1600);
    });
  });
}
