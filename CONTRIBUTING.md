# Contributing to Im Charts (`im_charts`)

Thank you for your interest in contributing to **Im Charts**! We welcome bug fixes, performance optimizations, new indicator algorithms, interactive drawing tools, and documentation improvements from the open-source community.

---

## 🛠️ Development Setup

### Prerequisites
- Flutter SDK `>=3.24.0` (Dart `>=3.5.0 <4.0.0`)
- macOS, Linux, or Windows with Chrome (for web testing) or desktop build tools

### 1. Fork & Clone
```bash
git clone https://github.com/<your-username>/im_charts.git
cd im_charts
```

### 2. Install Dependencies
```bash
flutter pub get
cd example && flutter pub get && cd ..
```

### 3. Run Automated Tests
```bash
flutter test
cd example && flutter test && cd ..
```

### 4. Run the Interactive Showcase
```bash
cd example
flutter run -d chrome
```

---

## 📐 Code Style & Formatting

We follow the standard Flutter/Dart style guide enforced by `analysis_options.yaml`:
```bash
# Format all code before committing
dart format .

# Verify zero analyzer warnings
flutter analyze .
cd example && flutter analyze . && cd ..
```

---

## 🧪 Testing Guidelines

- Every new indicator, drawing tool, or controller method **must include unit/widget tests** under `test/`.
- Run `flutter pub publish --dry-run` to ensure your changes adhere to pub.dev packaging standards without warnings.

---

## 🚀 Submitting a Pull Request

1. Create a descriptive feature branch:
   ```bash
   git checkout -b feat/supertrend-indicator
   ```
2. Commit your changes with conventional commit messages:
   ```bash
   git commit -m "feat(indicators): add Supertrend trend-following indicator"
   ```
3. Push to your fork and open a Pull Request against the `main` branch.
4. Provide a clear PR description detailing:
   - What problem is solved or feature is added.
   - Any manual or automated testing performed.
   - Screenshots/GIFs if modifying the UI, renderers, or drawing instruments.

---

## 💬 Community & Questions

Feel free to open an issue or discussion on GitHub:
- Bug Reports: [GitHub Issues](https://github.com/LykanImran/im_charts/issues)
- Feature Discussions: [GitHub Discussions](https://github.com/LykanImran/im_charts/discussions)
