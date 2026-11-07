class LibraryItem {
  final String id;
  final String name;

  /// 'ml' | 'g'
  final String unit;

  /// Size of the purchased package in [unit]. E.g. 10 (ml), 100 (g).
  final double packageSize;

  /// Price of that package in Taka.
  final double packagePrice;

  const LibraryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.packageSize,
    required this.packagePrice,
  });

  /// Price per single unit (1 ml or 1 g).
  double get unitPrice =>
      packageSize > 0 ? packagePrice / packageSize : 0;

  String get packageLabel => '$packageSize $unit';

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    // v4 format: pricePer100 (converted back to a 100-unit pack)
    final per100 = json['pricePer100'] as num?;
    return LibraryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String? ?? 'ml',
      packageSize: (json['packageSize'] as num?)?.toDouble() ??
          (per100 != null ? 100 : 0),
      packagePrice: (json['packagePrice'] as num?)?.toDouble() ??
          per100?.toDouble() ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'packageSize': packageSize,
        'packagePrice': packagePrice,
      };

  LibraryItem copyWith({
    String? id,
    String? name,
    String? unit,
    double? packageSize,
    double? packagePrice,
  }) =>
      LibraryItem(
        id: id ?? this.id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        packageSize: packageSize ?? this.packageSize,
        packagePrice: packagePrice ?? this.packagePrice,
      );
}
