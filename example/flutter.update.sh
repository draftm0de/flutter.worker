flutter clean
rm pubspec.lock
if [ -f "l10n.yaml" ]; then
  flutter gen-l10n
  echo "✔ flutter gen-l10n build successfully!"
fi
flutter pub upgrade --major-versions
flutter pub outdated --no-transitive