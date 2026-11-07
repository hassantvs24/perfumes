class Ingredient {
  final String name;
  final double percent; // 0–100 of total batch

  /// Link to the ingredient library. Null for legacy free-text rows.
  final String? ingredientId;

  const Ingredient({
    required this.name,
    required this.percent,
    this.ingredientId,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String,
        percent: (json['percent'] as num).toDouble(),
        ingredientId: json['ingredientId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'percent': percent,
        if (ingredientId != null) 'ingredientId': ingredientId,
      };

  Ingredient copyWith({String? name, double? percent, String? ingredientId}) =>
      Ingredient(
        name: name ?? this.name,
        percent: percent ?? this.percent,
        ingredientId: ingredientId ?? this.ingredientId,
      );
}

/// A package variant selected on a recipe, with its full-package price
/// (bottle + cap + sprayer + label) in Taka.
class RecipeVariant {
  final int sizeMl; // 15 | 30 | 50 | 100 | 150
  final double price;

  const RecipeVariant({required this.sizeMl, required this.price});

  factory RecipeVariant.fromJson(Map<String, dynamic> json) => RecipeVariant(
        sizeMl: (json['sizeMl'] as num).toInt(),
        price: (json['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'sizeMl': sizeMl, 'price': price};

  RecipeVariant copyWith({int? sizeMl, double? price}) => RecipeVariant(
        sizeMl: sizeMl ?? this.sizeMl,
        price: price ?? this.price,
      );
}

/// Packaging material attached to a recipe (bottle, cap, label…).
class PackagingItem {
  final String name;
  final double qty; // pieces per batch

  /// Link to the packaging library. Null for legacy rows.
  final String? packagingId;

  const PackagingItem({
    required this.name,
    required this.qty,
    this.packagingId,
  });

  factory PackagingItem.fromJson(Map<String, dynamic> json) => PackagingItem(
        name: json['name'] as String,
        qty: (json['qty'] as num).toDouble(),
        // 'ingredientId' keeps compatibility with recipes saved by v1
        packagingId:
            json['packagingId'] as String? ?? json['ingredientId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        if (packagingId != null) 'packagingId': packagingId,
      };

  PackagingItem copyWith({String? name, double? qty, String? packagingId}) =>
      PackagingItem(
        name: name ?? this.name,
        qty: qty ?? this.qty,
        packagingId: packagingId ?? this.packagingId,
      );
}

class Recipe {
  final String id;
  final String name;
  final String description;
  final List<Ingredient> ingredients;
  final List<PackagingItem> packaging;

  /// Selected package variants with prices. Empty = no package.
  final List<RecipeVariant> variants;

  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.name,
    this.description = '',
    required this.ingredients,
    this.packaging = const [],
    this.variants = const [],
    required this.createdAt,
  });

  /// Sum of all ingredient percents. Must not exceed 100.
  double get totalPercent =>
      ingredients.fold(0.0, (sum, i) => sum + i.percent);

  /// Remainder of the batch filled with base (alcohol/water).
  double get basePercent => (100 - totalPercent).clamp(0.0, 100.0);

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        ingredients: (json['ingredients'] as List<dynamic>)
            .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        packaging: (json['packaging'] as List<dynamic>? ?? [])
            .map((e) => PackagingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        variants: _variantsFromJson(json),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static List<RecipeVariant> _variantsFromJson(Map<String, dynamic> json) {
    final list = (json['variants'] as List<dynamic>?)
        ?.map((e) => RecipeVariant.fromJson(e as Map<String, dynamic>))
        .toList();
    if (list != null) return list;
    // Legacy v7/v6: plain size lists without prices (storage.load()
    // fills the prices from the packaging library and persists).
    final sizes = (json['bottleVariants'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList();
    final single = (json['bottleVariant'] as num?)?.toInt();
    if (single != null) sizes.add(single);
    return [for (final s in sizes) RecipeVariant(sizeMl: s, price: 0)];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        if (packaging.isNotEmpty)
          'packaging': packaging.map((e) => e.toJson()).toList(),
        if (variants.isNotEmpty)
          'variants': variants.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    List<Ingredient>? ingredients,
    List<PackagingItem>? packaging,
    List<RecipeVariant>? variants,
    DateTime? createdAt,
  }) =>
      Recipe(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        ingredients: ingredients ?? this.ingredients,
        packaging: packaging ?? this.packaging,
        variants: variants ?? this.variants,
        createdAt: createdAt ?? this.createdAt,
      );
}
