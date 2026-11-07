/// Allowed package variant sizes (ml). Each variant's price includes the
/// full package: bottle + cap + sprayer + label.
const List<int> kBottleSizes = [15, 30, 50, 100, 150];

/// One priced package per bottle variant.
class PackagingEntry {
  final String id;
  final String name;
  final int sizeMl; // 15 | 30 | 50 | 100 | 150
  final double pricePerPc; // ৳ for the full package

  const PackagingEntry({
    required this.id,
    required this.name,
    required this.sizeMl,
    required this.pricePerPc,
  });

  bool get isBottle => kBottleSizes.contains(sizeMl);

  factory PackagingEntry.fromJson(Map<String, dynamic> json) {
    // Legacy v3 format: packSize (pieces per pack) + packPrice
    final legacySize = json['packSize'] as num?;
    final legacyPrice = json['packPrice'] as num?;
    final rawSize = json['sizeMl'];
    final size = rawSize is num
        ? rawSize.toInt()
        : sizeFromName(json['name'] as String);
    if (size == null || !kBottleSizes.contains(size)) {
      // Entries without a variant size are not supported anymore.
      throw const FormatException('packaging entry has no size');
    }
    return PackagingEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      sizeMl: size,
      pricePerPc: (json['pricePerPc'] as num?)?.toDouble() ??
          ((legacySize != null && legacyPrice != null && legacySize > 0)
              ? legacyPrice / legacySize
              : 0),
    );
  }

  /// Extracts a variant size (ml) from an entry name like "Bottole 50 ml";
  /// returns null when absent or not an allowed size.
  static int? sizeFromName(String name) {
    final match = RegExp(r'(\d+)\s*ml', caseSensitive: false).firstMatch(name);
    if (match == null) return null;
    final size = int.tryParse(match.group(1)!);
    return size != null && kBottleSizes.contains(size) ? size : null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sizeMl': sizeMl,
        'pricePerPc': pricePerPc,
      };

  PackagingEntry copyWith({
    String? id,
    String? name,
    int? sizeMl,
    double? pricePerPc,
  }) =>
      PackagingEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        sizeMl: sizeMl ?? this.sizeMl,
        pricePerPc: pricePerPc ?? this.pricePerPc,
      );
}
