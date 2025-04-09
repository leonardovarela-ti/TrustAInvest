# Font Files

This directory should contain the following font files:
- Poppins-Regular.ttf
- Poppins-Medium.ttf
- Poppins-SemiBold.ttf
- Poppins-Bold.ttf

## How to Add Font Files

1. Download the Poppins font family from Google Fonts: https://fonts.google.com/specimen/Poppins
2. Extract the downloaded zip file
3. Copy the required font files to this directory:
   - Poppins-Regular.ttf
   - Poppins-Medium.ttf
   - Poppins-SemiBold.ttf
   - Poppins-Bold.ttf

## Usage in Flutter

The fonts are already configured in the pubspec.yaml file:

```yaml
fonts:
  - family: Poppins
    fonts:
      - asset: assets/fonts/Poppins-Regular.ttf
      - asset: assets/fonts/Poppins-Medium.ttf
        weight: 500
      - asset: assets/fonts/Poppins-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/Poppins-Bold.ttf
        weight: 700
```

To use the font in your Flutter app:

```dart
// Set as default font for the entire app
ThemeData(
  fontFamily: 'Poppins',
  // other theme properties
)

// Or use it for specific text widgets
Text(
  'Hello World',
  style: TextStyle(
    fontFamily: 'Poppins',
    fontWeight: FontWeight.w500, // Medium
  ),
)
```

## License

The Poppins font is licensed under the Open Font License. See LICENSE.txt for details.
