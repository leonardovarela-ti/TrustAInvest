# Icons Directory

This directory contains icon assets used in the KYC Verifier application.

## Files

- `app_icon.svg` - The main application icon used for app launchers
- `app_icon_foreground.svg` - The foreground layer for adaptive icons on Android
- `document.svg` - Icon used for document-related features
- `user.svg` - Icon used for user profiles and accounts
- `verify.svg` - Icon used for verification actions

## Usage in Flutter

These icons are already configured in the pubspec.yaml file:

```yaml
assets:
  - assets/images/
  - assets/icons/
  - .env
```

To use these icons in your Flutter app:

```dart
// For SVG icons
import 'package:flutter_svg/flutter_svg.dart';

// ...

SvgPicture.asset(
  'assets/icons/verify.svg',
  width: 24,
  height: 24,
  color: Colors.blue, // You can tint SVG icons with a color
)

// For app icon (used by flutter_launcher_icons package)
// This is configured in pubspec.yaml:
flutter_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icons/app_icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icons/app_icon_foreground.png"
```

## Converting SVG to PNG

For the app icon and other cases where SVG is not supported, you'll need to convert the SVG files to PNG using tools like:

1. Inkscape (free, open-source)
2. Adobe Illustrator
3. Online converters like https://svgtopng.com/

When converting app icons, make sure to export at the following sizes:
- Android: 192x192 px (launcher icon), 432x432 px (adaptive icon foreground)
- iOS: 1024x1024 px

## Adding New Icons

When adding new icons to this directory:

1. Use descriptive filenames that indicate the purpose of the icon
2. Maintain a consistent style with existing icons
3. Prefer vector formats (SVG) for better scaling
4. Keep icons simple and recognizable
5. Use a consistent size (24x24 viewBox is standard for UI icons)
6. Update this README if adding icons with special purposes
