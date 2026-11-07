import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/library_item.dart';
import '../models/packaging_entry.dart';
import '../models/recipe.dart';

class RecipeStorage {
  static const _recipesKey = 'recipes';
  static const _libraryKey = 'ingredients_library';
  static const _packagingKey = 'packaging_library';

  Future<List<Recipe>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recipesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final recipes = list
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
          .toList();
      // Migrate legacy variant lists (sizes without prices): fill the
      // price from the packaging library and persist the new format.
      final needsPriceFill = recipes.any(
        (r) => r.variants.isNotEmpty && r.variants.any((v) => v.price <= 0),
      );
      if (needsPriceFill) {
        final packaging = await loadPackaging();
        double? priceFor(int sizeMl) {
          final match = packaging.where((e) => e.sizeMl == sizeMl);
          return match.isEmpty ? null : match.first.pricePerPc;
        }

        final migrated = [
          for (final r in recipes)
            r.variants.any((v) => v.price <= 0)
                ? r.copyWith(
                    variants: [
                      for (final v in r.variants)
                        v.price > 0
                            ? v
                            : RecipeVariant(
                                sizeMl: v.sizeMl,
                                price: priceFor(v.sizeMl) ?? 0,
                              ),
                    ],
                  )
                : r,
        ];
        await saveAll(migrated);
        return migrated;
      }
      return recipes;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(recipes.map((e) => e.toJson()).toList());
    await prefs.setString(_recipesKey, raw);
  }

  Future<List<LibraryItem>> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_libraryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LibraryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLibrary(List<LibraryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_libraryKey, raw);
  }

  /// One-time migration: packaging items saved as unit 'pcs' inside the
  /// ingredient library (v2) are moved into the packaging library.
  /// Ids are preserved so existing recipe links keep working.
  Future<void> migrateLegacyPackaging() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_libraryKey);
    if (raw == null || raw.isEmpty) return;
    List<LibraryItem> library;
    try {
      library = (jsonDecode(raw) as List<dynamic>)
          .map((e) => LibraryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return;
    }
    final legacy = library.where((e) => e.unit == 'pcs').toList();
    if (legacy.isEmpty) return;
    final packaging = await loadPackaging();
    final existingIds = packaging.map((e) => e.id).toSet();
    final migrated = [
      ...packaging,
      for (final item in legacy)
        if (!existingIds.contains(item.id))
          if (PackagingEntry.sizeFromName(item.name) != null)
            PackagingEntry(
              id: item.id,
              name: item.name,
              sizeMl: PackagingEntry.sizeFromName(item.name)!,
              // unitPrice = packagePrice ÷ packageSize = price per piece.
              pricePerPc: item.unitPrice,
            ),
    ];
    await savePackaging(migrated);
    await saveLibrary(library.where((e) => e.unit != 'pcs').toList());
  }

  Future<List<PackagingEntry>> loadPackaging() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_packagingKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final result = <PackagingEntry>[];
      for (final e in list) {
        try {
          result.add(PackagingEntry.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // entries without a variant size are dropped
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> savePackaging(List<PackagingEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_packagingKey, raw);
  }

  // ---- Duplicate guards (case-insensitive) ----

  static String _norm(String s) => s.trim().toLowerCase();

  /// True when another recipe already uses [name] (excluding [excludeId]).
  static bool isDuplicateRecipeName(
    List<Recipe> recipes,
    String name, {
    String? excludeId,
  }) =>
      recipes.any(
        (r) => r.id != excludeId && _norm(r.name) == _norm(name),
      );

  /// True when another ingredient already uses [name].
  static bool isDuplicateIngredientName(
    List<LibraryItem> items,
    String name, {
    String? excludeId,
  }) =>
      items.any(
        (i) => i.id != excludeId && _norm(i.name) == _norm(name),
      );

  /// True when another packaging item has the same [name] and [sizeMl].
  static bool isDuplicatePackaging(
    List<PackagingEntry> items,
    String name,
    int? sizeMl, {
    String? excludeId,
  }) =>
      items.any(
        (i) =>
            i.id != excludeId &&
            _norm(i.name) == _norm(name) &&
            i.sizeMl == sizeMl,
      );
}
