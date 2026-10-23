import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
final class AppSystemBars {
  const AppSystemBars._();

  static const SystemUiOverlayStyle light = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static SystemUiOverlayStyle forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}
