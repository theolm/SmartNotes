import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const res = 'android/app/src/main/res';
String resource(String path) => File('$res/$path').readAsStringSync();

void main() {
  test('adaptive and themed icons share a transparent native vector', () {
    final adaptive = resource('mipmap-anydpi-v26/ic_launcher.xml');
    expect(adaptive, contains('@color/ic_launcher_background'));
    expect(
      '@drawable/smartnotes_foreground'.allMatches(adaptive).length,
      2,
    );
    final vector = resource('drawable-anydpi/smartnotes_foreground.xml');
    expect(vector, contains('<vector'));
    expect(vector, contains('android:width="108dp"'));
    expect(vector, contains('android:fillType="evenOdd"'));
    expect(vector, isNot(contains('<bitmap')));
    expect(vector, isNot(contains('#000000')));
  });

  test('both Android 12 themes use the vector splash', () {
    for (final qualifier in ['values-v31', 'values-night-v31']) {
      expect(
        resource('$qualifier/styles.xml'),
        contains('>@drawable/smartnotes_splash</item>'),
      );
    }
    expect(
      resource('drawable-anydpi/smartnotes_splash.xml'),
      contains('android:width="288dp"'),
    );
  });

  test('older Android splash and launcher do not select density bitmaps', () {
    for (final qualifier in ['drawable', 'drawable-night']) {
      final background = resource('$qualifier/launch_background.xml');
      expect(background, contains('@drawable/smartnotes_splash'));
      expect(background, isNot(contains('<bitmap')));
    }
    expect(
      resource('mipmap-anydpi/ic_launcher.xml'),
      contains('@drawable/smartnotes_foreground'),
    );
  });

  test('raster generators cannot overwrite native Android icons', () {
    final config = File('pubspec.yaml').readAsStringSync();
    for (final generator in ['flutter_launcher_icons', 'flutter_native_splash']) {
      expect(config, contains('$generator:\n  android: false'));
    }
  });
}
