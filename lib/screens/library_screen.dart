import 'package:flutter/material.dart';

import '../main.dart';
import '../models/library_item.dart';
import '../services/recipe_storage.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

String _fmt(double v) =>
    v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _LibraryScreenState extends State<LibraryScreen> {
  final _storage = RecipeStorage();
  List<LibraryItem> _items = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _storage.loadLibrary();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  List<LibraryItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _delete(LibraryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ingredient?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${item.name}" will be removed from the library. '
                'Recipes already using it will keep the name but lose the price link.'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final updated = _items.where((e) => e.id != item.id).toList();
    await _storage.saveLibrary(updated);
    if (!mounted) return;
    setState(() => _items = updated);
  }

  Future<void> _edit([LibraryItem? item]) async {
    final saved = await showDialog<LibraryItem>(
      context: context,
      builder: (_) => _ItemEditorDialog(
        item: item,
        existingItems: _items,
      ),
    );
    if (saved == null) return;
    final updated = item == null
        ? [..._items, saved]
        : _items.map((e) => e.id == saved.id ? saved : e).toList();
    await _storage.saveLibrary(updated);
    if (!mounted) return;
    setState(() => _items = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    return Scaffold(
      appBar: gradientAppBar(
        title: const Text('Ingredients Library'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add ingredient'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Pre-saved ingredients with prices. Select them from the '
                  'dropdown when building a recipe.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search ingredient...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        _items.isEmpty
                            ? 'No ingredients yet.\nTap "+ Add ingredient" to save one with its price.'
                            : 'No ingredients match your search.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  ...filtered.map(
                    (i) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () => _edit(i),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.violet.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.water_drop_outlined,
                            color: AppColors.violet,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          i.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${i.packageLabel} — ৳${_fmt(i.packagePrice)}'
                          '  (৳${_fmt(i.unitPrice)} / ${i.unit})',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(i),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ItemEditorDialog extends StatefulWidget {
  final LibraryItem? item;
  final List<LibraryItem> existingItems;

  const _ItemEditorDialog({this.item, required this.existingItems});

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _sizeController;
  late final TextEditingController _priceController;
  late String _unit;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _sizeController = TextEditingController(
      text: item == null ? '' : _fmt(item.packageSize),
    );
    _priceController = TextEditingController(
      text: item == null ? '' : _fmt(item.packagePrice),
    );
    _unit = item?.unit == 'g' ? 'g' : 'ml';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sizeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      LibraryItem(
        id: widget.item?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        unit: _unit,
        packageSize: double.parse(_sizeController.text.trim()),
        packagePrice: double.parse(_priceController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit ingredient' : 'Add ingredient'),
      content: SizedBox(
        width: 380,
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ingredient name',
                hintText: 'e.g. Bergamot essential oil',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                final name = v?.trim() ?? '';
                if (name.isEmpty) return 'Name is required';
                if (RecipeStorage.isDuplicateIngredientName(
                  widget.existingItems,
                  name,
                  excludeId: widget.item?.id,
                )) {
                  return 'An ingredient with this name already exists';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: const [
                DropdownMenuItem(value: 'ml', child: Text('ml (liquid)')),
                DropdownMenuItem(value: 'g', child: Text('gram')),
              ],
              onChanged: (v) => setState(() => _unit = v ?? 'ml'),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sizeController,
                    decoration: InputDecoration(
                      labelText: 'Pack size',
                      suffixText: _unit,
                      hintText: 'e.g. 10 ml bottle',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n <= 0) return 'Enter a number > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Pack price',
                      suffixText: '৳',
                      hintText: 'e.g. 800',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n <= 0) return 'Enter a number > 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'The price per 1 $_unit is calculated automatically.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
