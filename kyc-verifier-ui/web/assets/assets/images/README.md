# Images Directory

This directory contains image assets used in the KYC Verifier application.

## Files

- `logo.svg` - The main logo of the application, used in the app bar and login screen
- `splash.svg` - The splash screen image shown when the app is loading

## Usage in Flutter

These images are already configured in the pubspec.yaml file:

```yaml
assets:
  - assets/images/
  - assets/icons/
  - .env
```

To use these images in your Flutter app:

```dart
// For SVG images
import 'package:flutter_svg/flutter_svg.dart';

// ...

SvgPicture.asset(
  'assets/images/logo.svg',
  width: 200,
  height: 200,
)

// For PNG/JPEG images (if any are added later)
Image.asset(
  'assets/images/some_image.png',
  width: 200,
  height: 200,
)
```

## Converting SVG to PNG

For platforms or situations where SVG is not supported, you can convert the SVG files to PNG using tools like:

1. Inkscape (free, open-source)
2. Adobe Illustrator
3. Online converters like https://svgtopng.com/

When converting, make sure to export at various resolutions for different device densities:
- 1x (mdpi): Base size
- 1.5x (hdpi): 1.5 times the base size
- 2x (xhdpi): 2 times the base size
- 3x (xxhdpi): 3 times the base size
- 4x (xxxhdpi): 4 times the base size

## Adding New Images

When adding new images to this directory:

1. Use descriptive filenames that indicate the purpose of the image
2. Prefer vector formats (SVG) when possible for better scaling
3. Optimize images to reduce file size
4. Update this README if adding images with special purposes
