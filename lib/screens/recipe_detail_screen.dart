import 'package:flutter/material.dart';

import '../main.dart';
import '../models/library_item.dart';
import '../models/recipe.dart';
import '../services/recipe_storage.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _storage = RecipeStorage();
  late final TextEditingController _batchController;
  List<LibraryItem> _library = [];
  bool _loading = true;

  double get _batchSize => double.tryParse(_batchController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _batchController = TextEditingController(text: '100');
    _batchController.addListener(() => setState(() {}));
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final items = await _storage.loadLibrary();
    if (!mounted) return;
    setState(() {
      _library = items;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  void _setBatch(double ml) {
    _batchController.text =
        ml == ml.truncateToDouble() ? ml.toStringAsFixed(0) : ml.toString();
  }

  LibraryItem? _findItem(String? id) {
    if (id == null) return null;
    final match = _library.where((e) => e.id == id);
    return match.isEmpty ? null : match.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = widget.recipe;
    final batch = _batchSize;

    var liquidCost = 0.0;
    var packagingCost = 0.0;

    // Package price applies only to batches matching a selected variant.
    final variants = recipe.variants;
    RecipeVariant? matched;
    for (final v in variants) {
      if ((batch - v.sizeMl).abs() <= 0.01) matched = v;
    }
    if (matched != null) packagingCost += matched.price;

    return Scaffold(
      appBar: gradientAppBar(title: Text(recipe.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (recipe.description.isNotEmpty) ...[
                  Text(
                    recipe.description,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 16),
                ],
                const SectionHeader(
                  icon: Icons.water_drop_outlined,
                  title: 'Batch size (ml)',
                  color: AppColors.cyan,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _batchController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 100',
                    suffixText: 'ml',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.water_drop_outlined),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [15, 30, 50, 100, 150]
                      .map(
                        (ml) => ActionChip(
                          label: Text('$ml'),
                          onPressed: () => _setBatch(ml.toDouble()),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                const SectionHeader(
                  icon: Icons.science_outlined,
                  title: 'Ingredients needed',
                  color: AppColors.violet,
                ),
                const SizedBox(height: 8),
                if (batch <= 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Enter a batch size to see amounts.'),
                    ),
                  )
                else ...[
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        ...List.generate(recipe.ingredients.length, (i) {
                          final ingredient = recipe.ingredients[i];
                          final amount = batch * ingredient.percent / 100;
                          final item = _findItem(ingredient.ingredientId);
                          final cost = item == null
                              ? null
                              : amount * item.unitPrice;
                          liquidCost += cost ?? 0;
                          return _AmountRow(
                            name: ingredient.name,
                            percent: ingredient.percent,
                            amount: amount,
                            cost: cost,
                            isLast: i == recipe.ingredients.length - 1,
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Package',
                    color: AppColors.teal,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        if (variants.isEmpty)
                          _PackageHint(
                            text: 'No package selected — add variants in the '
                                'recipe edit screen.',
                          )
                        else if (matched == null)
                          _PackageHint(
                            text: 'Package price applies to these batches: '
                                '${variants.map((v) => '${v.sizeMl} ml').join(', ')}.',
                          )
                        else
                          _BottleRow(
                            name: '${matched.sizeMl} ml package',
                            qty: 1,
                            unitPrice: matched.price,
                            cost: matched.price,
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CostSummary(
                    liquidCost: liquidCost,
                    packagingCost: packagingCost,
                    hasUnpriced: recipe.ingredients
                        .any((e) => _findItem(e.ingredientId) == null),
                  ),
                ],
              ],
            ),
    );
  }
}

String _taka(double v) => '৳${v.toStringAsFixed(2)}';

class _AmountRow extends StatelessWidget {
  final String name;
  final double percent;
  final double amount;
  final double? cost;
  final bool isLast;

  const _AmountRow({
    required this.name,
    required this.percent,
    required this.amount,
    required this.cost,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = AppColors.violet;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${amount.toStringAsFixed(2)} ml',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (cost != null)
                    Text(
                      _taka(cost!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

/// Grey hint row inside the package card.
class _PackageHint extends StatelessWidget {
  final String text;

  const _PackageHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

/// Auto-selected package row on the detail screen.
class _BottleRow extends StatelessWidget {
  final String name;
  final int qty;
  final double unitPrice;
  final double cost;
  final bool isLast;

  const _BottleRow({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.cost,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'auto — $qty ${qty == 1 ? 'pc' : 'pcs'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_taka(unitPrice)} / pc',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                  Text(
                    _taka(cost),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _CostSummary extends StatelessWidget {
  final double liquidCost;
  final double packagingCost;
  final bool hasUnpriced;

  const _CostSummary({
    required this.liquidCost,
    required this.packagingCost,
    required this.hasUnpriced,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = liquidCost + packagingCost;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.gradientAmber,
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _summaryRow(theme, 'Liquid cost', _taka(liquidCost)),
          if (packagingCost > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(theme, 'Packaging cost', _taka(packagingCost)),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total batch cost',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                _taka(total),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
          if (hasUnpriced) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Some items are not linked to the library — their cost is not included.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
