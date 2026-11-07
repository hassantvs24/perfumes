# 🧪 Perfume Calculator

A Flutter app for perfume makers: save recipes, calculate ingredient amounts for any batch size, and track costs in Taka (৳) — with package pricing per bottle variant.

![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20iOS%20%7C%20Web%20%7C%20macOS%20%7C%20Linux-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter)
![Version](https://img.shields.io/badge/version-1.0.0-7C3AED)

## ✨ Features

- **Saved recipes** — create, edit, delete and search recipes; ingredients as percentages of the batch (must total exactly 100%)
- **Batch calculator** — enter any batch size (quick chips for 15/30/50/100/150 ml) and get exact amounts for every ingredient, priced per 1 ml
- **Ingredients library** — pre-save essences and liquids with pack size & price (৳); Select2-style search when building recipes; duplicate names blocked
- **Package variants** — attach 15/30/50/100/150 ml variants to a recipe with a full-package price (bottle + cap + sprayer + label); the package is added automatically on the calculator screen when the batch matches a variant
- **Cost breakdown** — liquid cost, packaging cost and total batch cost, live as you type
- **Colorful modern UI** — gradient theme with platform-adaptive artwork icons
- **Cross-platform** — Android, iOS, Windows, macOS, Linux and web from a single Flutter codebase
- **Local persistence** — everything stored on-device via `shared_preferences`

## 🚀 Getting started

```bash
flutter pub get
flutter run            # pick a device (android / windows / chrome ...)
```

### Build

```bash
flutter build apk --release     # Android
flutter build windows --release # Windows
```

### Regenerate launcher icons

```bash
python tools/make_icon.py       # prepares assets/icon from the source artwork
dart run flutter_launcher_icons # generates all platform icons
```

## 🧪 Tests

```bash
flutter analyze
flutter test
```

## 📁 Project structure

```
lib/
  main.dart                     # app entry, colorful theme, shared widgets
  models/                       # Recipe, Ingredient, RecipeVariant, LibraryItem
  services/recipe_storage.dart  # JSON persistence + data migrations
  screens/                      # recipes list, edit, calculator, ingredients library
assets/icon/                    # app icon sources
tools/make_icon.py              # icon artwork processor
```

## 📦 Release v1.0.0

First stable release: recipes, batch calculator, ingredients library with prices, package variants per bottle size, and full cost tracking in Taka.

## 📄 License

MIT
