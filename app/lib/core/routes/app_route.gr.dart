// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i10;
import 'package:flutter/material.dart' as _i11;
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_screen.dart'
    as _i2;
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_screen.dart'
    as _i3;
import 'package:smartnotes/presentation/screens/home/home_screen.dart' as _i5;
import 'package:smartnotes/presentation/screens/lock/lock_screen.dart' as _i6;
import 'package:smartnotes/presentation/screens/onboarding/onboarding_screen.dart'
    as _i7;
import 'package:smartnotes/presentation/screens/settings/data_settings_screens.dart'
    as _i1;
import 'package:smartnotes/presentation/screens/settings/formatting_models_screen.dart'
    as _i4;
import 'package:smartnotes/presentation/screens/settings/settings_screen.dart'
    as _i8;
import 'package:smartnotes/presentation/screens/settings/speech_models_screen.dart'
    as _i9;

/// generated route for
/// [_i1.BackupSettingsScreen]
class BackupSettingsRoute extends _i10.PageRouteInfo<void> {
  const BackupSettingsRoute({List<_i10.PageRouteInfo>? children})
    : super(BackupSettingsRoute.name, initialChildren: children);

  static const String name = 'BackupSettingsRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i1.BackupSettingsScreen();
    },
  );
}

/// generated route for
/// [_i2.EntryDetailScreen]
class EntryDetailRoute extends _i10.PageRouteInfo<EntryDetailRouteArgs> {
  EntryDetailRoute({
    _i11.Key? key,
    required String entryId,
    List<_i10.PageRouteInfo>? children,
  }) : super(
         EntryDetailRoute.name,
         args: EntryDetailRouteArgs(key: key, entryId: entryId),
         initialChildren: children,
       );

  static const String name = 'EntryDetailRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EntryDetailRouteArgs>();
      return _i2.EntryDetailScreen(key: args.key, entryId: args.entryId);
    },
  );
}

class EntryDetailRouteArgs {
  const EntryDetailRouteArgs({this.key, required this.entryId});

  final _i11.Key? key;

  final String entryId;

  @override
  String toString() {
    return 'EntryDetailRouteArgs{key: $key, entryId: $entryId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EntryDetailRouteArgs) return false;
    return key == other.key && entryId == other.entryId;
  }

  @override
  int get hashCode => key.hashCode ^ entryId.hashCode;
}

/// generated route for
/// [_i3.EntryEditScreen]
class EntryEditRoute extends _i10.PageRouteInfo<EntryEditRouteArgs> {
  EntryEditRoute({
    _i11.Key? key,
    required String entryId,
    List<_i10.PageRouteInfo>? children,
  }) : super(
         EntryEditRoute.name,
         args: EntryEditRouteArgs(key: key, entryId: entryId),
         initialChildren: children,
       );

  static const String name = 'EntryEditRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EntryEditRouteArgs>();
      return _i3.EntryEditScreen(key: args.key, entryId: args.entryId);
    },
  );
}

class EntryEditRouteArgs {
  const EntryEditRouteArgs({this.key, required this.entryId});

  final _i11.Key? key;

  final String entryId;

  @override
  String toString() {
    return 'EntryEditRouteArgs{key: $key, entryId: $entryId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EntryEditRouteArgs) return false;
    return key == other.key && entryId == other.entryId;
  }

  @override
  int get hashCode => key.hashCode ^ entryId.hashCode;
}

/// generated route for
/// [_i4.FormattingModelsScreen]
class FormattingModelsRoute extends _i10.PageRouteInfo<void> {
  const FormattingModelsRoute({List<_i10.PageRouteInfo>? children})
    : super(FormattingModelsRoute.name, initialChildren: children);

  static const String name = 'FormattingModelsRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i4.FormattingModelsScreen();
    },
  );
}

/// generated route for
/// [_i5.HomeScreen]
class HomeRoute extends _i10.PageRouteInfo<void> {
  const HomeRoute({List<_i10.PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i5.HomeScreen();
    },
  );
}

/// generated route for
/// [_i6.LockScreen]
class LockRoute extends _i10.PageRouteInfo<void> {
  const LockRoute({List<_i10.PageRouteInfo>? children})
    : super(LockRoute.name, initialChildren: children);

  static const String name = 'LockRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i6.LockScreen();
    },
  );
}

/// generated route for
/// [_i7.OnboardingScreen]
class OnboardingRoute extends _i10.PageRouteInfo<OnboardingRouteArgs> {
  OnboardingRoute({
    _i11.Key? key,
    bool fromSettings = false,
    List<_i10.PageRouteInfo>? children,
  }) : super(
         OnboardingRoute.name,
         args: OnboardingRouteArgs(key: key, fromSettings: fromSettings),
         initialChildren: children,
       );

  static const String name = 'OnboardingRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<OnboardingRouteArgs>(
        orElse: () => const OnboardingRouteArgs(),
      );
      return _i7.OnboardingScreen(
        key: args.key,
        fromSettings: args.fromSettings,
      );
    },
  );
}

class OnboardingRouteArgs {
  const OnboardingRouteArgs({this.key, this.fromSettings = false});

  final _i11.Key? key;

  final bool fromSettings;

  @override
  String toString() {
    return 'OnboardingRouteArgs{key: $key, fromSettings: $fromSettings}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OnboardingRouteArgs) return false;
    return key == other.key && fromSettings == other.fromSettings;
  }

  @override
  int get hashCode => key.hashCode ^ fromSettings.hashCode;
}

/// generated route for
/// [_i1.SearchSettingsScreen]
class SearchSettingsRoute extends _i10.PageRouteInfo<void> {
  const SearchSettingsRoute({List<_i10.PageRouteInfo>? children})
    : super(SearchSettingsRoute.name, initialChildren: children);

  static const String name = 'SearchSettingsRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i1.SearchSettingsScreen();
    },
  );
}

/// generated route for
/// [_i8.SettingsScreen]
class SettingsRoute extends _i10.PageRouteInfo<void> {
  const SettingsRoute({List<_i10.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      return const _i8.SettingsScreen();
    },
  );
}

/// generated route for
/// [_i9.SpeechModelsScreen]
class SpeechModelsRoute extends _i10.PageRouteInfo<SpeechModelsRouteArgs> {
  SpeechModelsRoute({
    _i11.Key? key,
    bool changeLanguage = false,
    String? requestedLanguage,
    List<_i10.PageRouteInfo>? children,
  }) : super(
         SpeechModelsRoute.name,
         args: SpeechModelsRouteArgs(
           key: key,
           changeLanguage: changeLanguage,
           requestedLanguage: requestedLanguage,
         ),
         initialChildren: children,
       );

  static const String name = 'SpeechModelsRoute';

  static _i10.PageInfo page = _i10.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SpeechModelsRouteArgs>(
        orElse: () => const SpeechModelsRouteArgs(),
      );
      return _i9.SpeechModelsScreen(
        key: args.key,
        changeLanguage: args.changeLanguage,
        requestedLanguage: args.requestedLanguage,
      );
    },
  );
}

class SpeechModelsRouteArgs {
  const SpeechModelsRouteArgs({
    this.key,
    this.changeLanguage = false,
    this.requestedLanguage,
  });

  final _i11.Key? key;

  final bool changeLanguage;

  final String? requestedLanguage;

  @override
  String toString() {
    return 'SpeechModelsRouteArgs{key: $key, changeLanguage: $changeLanguage, requestedLanguage: $requestedLanguage}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SpeechModelsRouteArgs) return false;
    return key == other.key &&
        changeLanguage == other.changeLanguage &&
        requestedLanguage == other.requestedLanguage;
  }

  @override
  int get hashCode =>
      key.hashCode ^ changeLanguage.hashCode ^ requestedLanguage.hashCode;
}
