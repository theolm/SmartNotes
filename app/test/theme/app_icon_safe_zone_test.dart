import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adaptive icon foreground fits the Android safe circle', () async {
    await expectImageFitsSafeCircle(
      path: 'assets/app_icon_foreground.png',
      expectedSize: 1024,
      safeDiameterFraction: 66 / 108,
    );
  });

  test('generated adaptive icon fits the Android safe circle', () async {
    await expectImageFitsSafeCircle(
      path:
          'android/app/src/main/res/drawable-xxxhdpi/'
          'ic_launcher_foreground.png',
      expectedSize: 432,
      safeDiameterFraction: 66 / 108,
    );
  });

  test('Android 12 splash icon fits the platform safe circle', () async {
    await expectImageFitsSafeCircle(
      path: 'assets/splash_icon.png',
      expectedSize: 1152,
      safeDiameterFraction: 768 / 1152,
    );
  });

  test('generated Android 12 splash fits the platform safe circle', () async {
    await expectImageFitsSafeCircle(
      path: 'android/app/src/main/res/drawable-xxxhdpi/android12splash.png',
      expectedSize: 1152,
      safeDiameterFraction: 768 / 1152,
    );
  });

  test('generated themed icon preserves the quote cutouts', () async {
    const generatedAssets = [
      'android/app/src/main/res/drawable-xxxhdpi/'
          'ic_launcher_foreground.png',
      'android/app/src/main/res/drawable-xxxhdpi/'
          'ic_launcher_monochrome.png',
    ];

    for (final path in generatedAssets) {
      expect(await pixelAlpha(path: path, x: 0.48, y: 0.438), 0);
      expect(await pixelAlpha(path: path, x: 0.5, y: 0.5), 255);
    }
  });
}

Future<int> pixelAlpha({
  required String path,
  required double x,
  required double y,
}) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final data = pixels!.buffer.asUint8List();
  final pixelX = (image.width * x).floor();
  final pixelY = (image.height * y).floor();

  return data[(pixelY * image.width + pixelX) * 4 + 3];
}

Future<void> expectImageFitsSafeCircle({
  required String path,
  required int expectedSize,
  required double safeDiameterFraction,
}) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  expect(image.width, expectedSize);
  expect(image.height, expectedSize);
  expect(pixels, isNotNull);

  final center = image.width / 2;
  final safeRadius = image.width * safeDiameterFraction / 2;
  final data = pixels!.buffer.asUint8List();
  var pixelsOutsideSafeCircle = 0;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final alpha = data[(y * image.width + x) * 4 + 3];
      if (alpha == 0) continue;

      final dx = x + 0.5 - center;
      final dy = y + 0.5 - center;
      if (dx * dx + dy * dy > safeRadius * safeRadius) {
        pixelsOutsideSafeCircle++;
      }
    }
  }

  expect(
    pixelsOutsideSafeCircle,
    0,
    reason:
        'Foreground pixels outside the adaptive icon safe circle can be '
        'cropped by device-specific launcher masks.',
  );
}
