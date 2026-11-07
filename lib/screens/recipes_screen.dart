import 'package:flutter/material.dart';

import '../main.dart';
import '../models/recipe.dart';
import '../services/recipe_storage.dart';
import 'library_screen.dart';
import 'recipe_detail_screen.dart';
import 'recipe_edit_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _storage = RecipeStorage();
  List<Recipe> _recipes = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recipes = await _storage.load();
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _loading = false;
    });
  }

  List<Recipe> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _recipes;
    return _recipes.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.ingredients.any((i) => i.name.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _delete(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${recipe.name}" will be permanently removed.'),
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
    final updated = _recipes.where((r) => r.id != recipe.id).toList();
    await _storage.saveAll(updated);
    if (!mounted) return;
    setState(() => _recipes = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${recipe.name} deleted')),
    );
  }

  static String percentLabel(double v) =>
      v == v.truncateToDouble() ? '${v.toStringAsFixed(0)}%' : '$v%';

  void _openLibraryMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.format_list_bulleted,
                color: AppColors.violet,
              ),
              title: const Text('Ingredients library'),
              subtitle: const Text('Essences and liquids with prices'),
              onTap: () {
                Navigator.pop(ctx);
                // Defer the push until the sheet's pop has finished.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LibraryScreen()),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor([Recipe? recipe]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeEditScreen(recipe: recipe),
      ),
    );
    _load();
  }

  Future<void> _openDetail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipe: recipe),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    return Scaffold(
      appBar: gradientAppBar(
        title: const Row(
          children: [
            Icon(Icons.bubble_chart),
            SizedBox(width: 8),
            Text('Perfume Calculator'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Library menu',
            icon: const Icon(Icons.menu),
            onPressed: _openLibraryMenu,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New recipe'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const SectionHeader(
                    icon: Icons.auto_awesome,
                    title: 'Saved Recipes',
                    color: AppColors.magenta,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search recipe or ingredient...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${filtered.length} saved recipe${filtered.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 64,
                            color: AppColors.violet,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _recipes.isEmpty
                                ? 'No recipes yet.\nTap "+ New recipe" to create your first one.'
                                : 'No recipes match your search.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  else
                    ...filtered.map(
                      (r) => _RecipeCard(
                        recipe: r,
                        onTap: () => _openDetail(r),
                        onEdit: () => _openEditor(r),
                        onDelete: () => _delete(r),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) =>
                        v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
              if (recipe.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  recipe.description,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
              const Divider(height: 20),
              Row(
                children: [
                  _Chip(
                    icon: Icons.science_outlined,
                    label: '${recipe.ingredients.length} ingredients',
                    color: AppColors.violet,
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    icon: Icons.percent,
                    label: _RecipesScreenState.percentLabel(recipe.totalPercent),
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 8),
                  if (recipe.variants.isNotEmpty)
                    _Chip(
                      icon: Icons.shopping_bag_outlined,
                      label: recipe.variants
                          .map((v) => '${v.sizeMl} ml')
                          .join(', '),
                      color: AppColors.magenta,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({
    required this.icon,
    required this.label,
    this.color = AppColors.violet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
