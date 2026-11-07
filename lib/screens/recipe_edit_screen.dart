import 'package:flutter/material.dart';

import '../main.dart';
import '../models/library_item.dart';
import '../models/packaging_entry.dart';
import '../models/recipe.dart';
import '../services/recipe_storage.dart';

class RecipeEditScreen extends StatefulWidget {
  final Recipe? recipe; // null → create new

  const RecipeEditScreen({super.key, this.recipe});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _storage = RecipeStorage();
  final _formKey = GlobalKey<FormState>();

  List<LibraryItem> _library = [];
  List<Recipe> _allRecipes = [];

  /// Selected package variant sizes (ml) + their price fields.
  late final List<int> _variantSizes;
  late final List<TextEditingController> _variantPriceControllers;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  // Recipe ingredient rows
  late final List<TextEditingController> _ingredientNameControllers;
  late final List<TextEditingController> _ingredientPercentControllers;
  late final List<String?> _ingredientIds;

  // Packaging rows


  bool _saving = false;
  bool _loading = true;

  bool get _isEditing => widget.recipe != null;

  List<LibraryItem> get _liquids =>
      _library.where((e) => e.unit == 'ml' || e.unit == 'g').toList();

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _nameController = TextEditingController(text: recipe?.name ?? '');
    _descriptionController =
        TextEditingController(text: recipe?.description ?? '');

    final ingredients = recipe?.ingredients ?? const <Ingredient>[];
    _ingredientNameControllers =
        ingredients.map((i) => TextEditingController(text: i.name)).toList();
    _ingredientPercentControllers = ingredients
        .map((i) => TextEditingController(text: _fmt(i.percent)))
        .toList();
    _ingredientIds = ingredients.map((i) => i.ingredientId).toList();

    final variants = recipe?.variants ?? const <RecipeVariant>[];
    if (variants.isEmpty && !_isEditing) {
      _variantSizes = [50];
      _variantPriceControllers = [TextEditingController()..addListener(_noop)];
    } else {
      _variantSizes = variants.map((v) => v.sizeMl).toList();
      _variantPriceControllers = [
        for (final v in variants)
          TextEditingController(text: _fmt(v.price))..addListener(_noop),
      ];
    }

    if (_ingredientNameControllers.isEmpty) _addIngredientRow();
    _loadLibrary();
  }

  void _noop() {}

  Future<void> _loadLibrary() async {
    final items = await _storage.loadLibrary();
    final recipes = await _storage.load();
    if (!mounted) return;
    setState(() {
      _library = items;
      _allRecipes = recipes;
      _loading = false;
    });
  }

  void _addVariant() {
    final remaining =
        kBottleSizes.where((s) => !_variantSizes.contains(s)).toList();
    if (remaining.isEmpty) return;
    setState(() {
      _variantSizes.add(remaining.first);
      _variantPriceControllers.add(
        TextEditingController()..addListener(_noop),
      );
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variantPriceControllers[index].dispose();
      _variantPriceControllers.removeAt(index);
      _variantSizes.removeAt(index);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final c in _ingredientNameControllers) {
      c.dispose();
    }
    for (final c in _ingredientPercentControllers) {
      c.dispose();
    }
    for (final c in _variantPriceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _refresh() => setState(() {});

  void _addIngredientRow() {
    final nameController = TextEditingController()..addListener(_refresh);
    final percentController = TextEditingController()..addListener(_refresh);
    setState(() {
      _ingredientNameControllers.add(nameController);
      _ingredientPercentControllers.add(percentController);
      _ingredientIds.add(null);
    });
  }

  void _removeIngredientRow(int index) {
    setState(() {
      _ingredientNameControllers[index].dispose();
      _ingredientPercentControllers[index].dispose();
      _ingredientNameControllers.removeAt(index);
      _ingredientPercentControllers.removeAt(index);
      _ingredientIds.removeAt(index);
    });
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  double get _totalPercent {
    var sum = 0.0;
    for (final c in _ingredientPercentControllers) {
      sum += _parse(c);
    }
    return sum;
  }

  String? _rowName(int index) {
    final id = _ingredientIds[index];
    if (id != null) {
      final match = _library.where((e) => e.id == id);
      if (match.isNotEmpty) return match.first.name;
    }
    return _ingredientNameControllers[index].text.trim();
  }

  bool get _isValid {
    if (_nameController.text.trim().isEmpty) return false;
    if ((_totalPercent - 100).abs() > 0.01) return false;
    for (var i = 0; i < _ingredientNameControllers.length; i++) {
      if ((_rowName(i) ?? '').isEmpty) return false;
      if (_parse(_ingredientPercentControllers[i]) <= 0) return false;
    }
    for (final c in _variantPriceControllers) {
      if (_parse(c) <= 0) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_isValid) return;
    setState(() => _saving = true);

    final ingredients = <Ingredient>[
      for (var i = 0; i < _ingredientNameControllers.length; i++)
        Ingredient(
          name: _rowName(i)!,
          percent: _parse(_ingredientPercentControllers[i]),
          ingredientId: _ingredientIds[i],
        ),
    ];

    final existing = widget.recipe;
    final recipe = Recipe(
      id: existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      ingredients: ingredients,
      variants: [
        for (var i = 0; i < _variantSizes.length; i++)
          RecipeVariant(
            sizeMl: _variantSizes[i],
            price: _parse(_variantPriceControllers[i]),
          ),
      ],
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    final all = await _storage.load();
    final updated = _isEditing
        ? all.map((r) => r.id == recipe.id ? recipe : r).toList()
        : [...all, recipe];
    await _storage.saveAll(updated);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalPercent;

    return Scaffold(
      appBar: gradientAppBar(
        title: Text(_isEditing ? 'Edit Recipe' : 'New Recipe'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Recipe name',
                      hintText: 'e.g. Aventus Klon',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final name = v?.trim() ?? '';
                      if (name.isEmpty) return 'Name is required';
                      if (RecipeStorage.isDuplicateRecipeName(
                        _allRecipes,
                        name,
                        excludeId: widget.recipe?.id,
                      )) {
                        return 'A recipe with this name already exists';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'e.g. Creed - Aventus clone',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(
                    icon: Icons.science_outlined,
                    title: 'Ingredients (% of total batch)',
                    color: AppColors.violet,
                  ),
                  const SizedBox(height: 4),
                  if (_library.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Library is empty — save ingredients with prices '
                        'first (menu on the home screen). You can '
                        'still type names manually without prices.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                    ),
                  ...List.generate(
                    _ingredientNameControllers.length,
                    (i) => _IngredientRow(
                      nameController: _ingredientNameControllers[i],
                      percentController: _ingredientPercentControllers[i],
                      selectedId: _ingredientIds[i],
                      options: _liquids,
                      canRemove: _ingredientNameControllers.length > 1,
                      onSelected: (item) => setState(
                        () => _ingredientIds[i] = item?.id,
                      ),
                      onRemoved: () => _removeIngredientRow(i),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addIngredientRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add ingredient'),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Package variants',
                    color: AppColors.teal,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set the full package price (bottle, cap, sprayer, label) '
                    'for each variant — it is added automatically on the '
                    'calculator screen.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_variantSizes.length, (i) {
                    final remainingForRow = kBottleSizes.toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              initialValue: _variantSizes[i],
                              decoration: const InputDecoration(
                                labelText: 'Bottle size',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                for (final size in remainingForRow)
                                  if (size == _variantSizes[i] ||
                                      !_variantSizes.contains(size))
                                    DropdownMenuItem(
                                      value: size,
                                      child: Text('$size ml'),
                                    ),
                              ],
                              onChanged: (v) => setState(
                                () => _variantSizes[i] = v ?? _variantSizes[i],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _variantPriceControllers[i],
                              decoration: const InputDecoration(
                                labelText: 'Price',
                                suffixText: '৳',
                                hintText: '150',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final n = double.tryParse(v?.trim() ?? '');
                                if (n == null || n <= 0) {
                                  return 'Enter a price > 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: theme.hintColor,
                            onPressed: () => _removeVariant(i),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _variantSizes.length < kBottleSizes.length
                          ? _addVariant
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add variant'),
                    ),
                  ),
                  _VariantProgress(count: _variantSizes.length),
                  const SizedBox(height: 16),
                  _TotalIndicator(total: total),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: (_isValid && !_saving) ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving
                        ? 'Saving...'
                        : _isEditing
                            ? 'Update recipe'
                            : 'Save recipe'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

}

/// Ingredient row: searchable dropdown from the library + percent field.
class _IngredientRow extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController percentController;
  final String? selectedId;
  final List<LibraryItem> options;
  final bool canRemove;
  final ValueChanged<LibraryItem?> onSelected;
  final VoidCallback onRemoved;

  const _IngredientRow({
    required this.nameController,
    required this.percentController,
    required this.selectedId,
    required this.options,
    required this.canRemove,
    required this.onSelected,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Autocomplete<LibraryItem>(
              initialValue: TextEditingValue(text: nameController.text),
              displayStringForOption: (item) => item.name,
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return options;
                return options
                    .where((o) => o.name.toLowerCase().contains(q))
                    .toList();
              },
              onSelected: (item) {
                nameController.text = item.name;
                onSelected(item);
              },
              fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
                // Keep the external controller authoritative so the name is
                // preserved in the recipe row.
                ctrl.addListener(() {
                  if (nameController.text != ctrl.text) {
                    nameController.text = ctrl.text;
                  }
                });
                return TextFormField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: 'Search ingredient…',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.search),
                  ),
                  textCapitalization: TextCapitalization.words,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: percentController,
              decoration: const InputDecoration(
                hintText: '%',
                suffixText: '%',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: Theme.of(context).hintColor,
            onPressed: canRemove ? onRemoved : null,
          ),
        ],
      ),
    );
  }
}

/// Small completeness bar for the package variants.
class _VariantProgress extends StatelessWidget {
  final int count;

  const _VariantProgress({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = kBottleSizes.length;
    final pct = (count / total * 100).round();
    final full = count >= total;
    final color = full ? AppColors.teal : AppColors.violet;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: count / total,
                minHeight: 6,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            full ? '100%' : '$pct%  ($count/$total)',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalIndicator extends StatelessWidget {
  final double total;

  const _TotalIndicator({required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHundred = (total - 100).abs() <= 0.01;
    final color = isHundred ? AppColors.violet : Colors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isHundred
                    ? 'Total: 100%'
                    : 'Total: ${total.toStringAsFixed(1)}% — must be 100%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isHundred ? AppColors.violet : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total.clamp(0.0, 100.0) / 100,
              minHeight: 8,
              backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
