import 'package:flutter/material.dart';

import 'services/recipe_storage.dart';
import 'screens/recipes_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RecipeStorage().migrateLegacyPackaging();
  runApp(const PerfumeApp());
}

/// App-wide palette — matches the colorful icon artwork.
class AppColors {
  static const violet = Color(0xFF7C3AED);
  static const magenta = Color(0xFFDB2777);
  static const teal = Color(0xFF0D9488);
  static const cyan = Color(0xFF06B6D4);
  static const amber = Color(0xFFF59E0B);
  static const background = Color(0xFFFAF8FF);

  static const gradient = LinearGradient(
    colors: [violet, magenta],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const gradientTeal = LinearGradient(
    colors: [teal, cyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const gradientAmber = LinearGradient(
    colors: [Color(0xFFFFF7E6), Color(0xFFFFEDD5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class PerfumeApp extends StatelessWidget {
  const PerfumeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perfume Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.violet,
          secondary: AppColors.teal,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.violet.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.violet, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: AppColors.violet.withValues(alpha: 0.08),
          labelStyle: const TextStyle(color: AppColors.violet),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.violet,
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.magenta,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      home: const RecipesScreen(),
    );
  }
}

/// AppBar with the signature violet→magenta gradient and white foreground.
PreferredSizeWidget gradientAppBar({
  required Widget title,
  List<Widget>? actions,
  Widget? leading,
}) =>
    AppBar(
      title: title,
      actions: actions,
      leading: leading,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradient),
      ),
    );

/// Section header with a colorful icon dot — used across screens.
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.color = AppColors.violet,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
