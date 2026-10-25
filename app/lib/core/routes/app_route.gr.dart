// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i11;
import 'package:flutter/material.dart' as _i12;
import 'package:smartnotes/presentation/screens/entry_detail/entry_detail_screen.dart'
    as _i3;
import 'package:smartnotes/presentation/screens/entry_edit/entry_edit_screen.dart'
    as _i4;
import 'package:smartnotes/presentation/screens/home/journal_workspace_screen.dart'
    as _i6;
import 'package:smartnotes/presentation/screens/lock/lock_screen.dart' as _i7;
import 'package:smartnotes/presentation/screens/onboarding/onboarding_screen.dart'
    as _i8;
import 'package:smartnotes/presentation/screens/settings/data_settings_screens.dart'
    as _i1;
import 'package:smartnotes/presentation/screens/settings/embedding_models_screen.dart'
    as _i2;
import 'package:smartnotes/presentation/screens/settings/formatting_models_screen.dart'
    as _i5;
import 'package:smartnotes/presentation/screens/settings/settings_screen.dart'
    as _i9;
import 'package:smartnotes/presentation/screens/settings/speech_models_screen.dart'
    as _i10;

/// generated route for
/// [_i1.BackupSettingsScreen]
class BackupSettingsRoute extends _i11.PageRouteInfo<void> {
  const BackupSettingsRoute({List<_i11.PageRouteInfo>? children})
    : super(BackupSettingsRoute.name, initialChildren: children);

  static const String name = 'BackupSettingsRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i1.BackupSettingsScreen();
    },
  );
}

/// generated route for
/// [_i2.EmbeddingModelsScreen]
class EmbeddingModelsRoute extends _i11.PageRouteInfo<void> {
  const EmbeddingModelsRoute({List<_i11.PageRouteInfo>? children})
    : super(EmbeddingModelsRoute.name, initialChildren: children);

  static const String name = 'EmbeddingModelsRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i2.EmbeddingModelsScreen();
    },
  );
}

/// generated route for
/// [_i3.EntryDetailScreen]
class EntryDetailRoute extends _i11.PageRouteInfo<EntryDetailRouteArgs> {
  EntryDetailRoute({
    _i12.Key? key,
    required String entryId,
    List<_i11.PageRouteInfo>? children,
  }) : super(
         EntryDetailRoute.name,
         args: EntryDetailRouteArgs(key: key, entryId: entryId),
         initialChildren: children,
       );

  static const String name = 'EntryDetailRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EntryDetailRouteArgs>();
      return _i3.EntryDetailScreen(key: args.key, entryId: args.entryId);
    },
  );
}

class EntryDetailRouteArgs {
  const EntryDetailRouteArgs({this.key, required this.entryId});

  final _i12.Key? key;

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
/// [_i4.EntryEditScreen]
class EntryEditRoute extends _i11.PageRouteInfo<EntryEditRouteArgs> {
  EntryEditRoute({
    _i12.Key? key,
    String? entryId,
    String initialTitle = '',
    String initialSubtitle = '',
    List<_i11.PageRouteInfo>? children,
  }) : super(
         EntryEditRoute.name,
         args: EntryEditRouteArgs(
           key: key,
           entryId: entryId,
           initialTitle: initialTitle,
           initialSubtitle: initialSubtitle,
         ),
         initialChildren: children,
       );

  static const String name = 'EntryEditRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EntryEditRouteArgs>(
        orElse: () => const EntryEditRouteArgs(),
      );
      return _i4.EntryEditScreen(
        key: args.key,
        entryId: args.entryId,
        initialTitle: args.initialTitle,
        initialSubtitle: args.initialSubtitle,
      );
    },
  );
}

class EntryEditRouteArgs {
  const EntryEditRouteArgs({
    this.key,
    this.entryId,
    this.initialTitle = '',
    this.initialSubtitle = '',
  });

  final _i12.Key? key;

  final String? entryId;

  final String initialTitle;

  final String initialSubtitle;

  @override
  String toString() {
    return 'EntryEditRouteArgs{key: $key, entryId: $entryId, initialTitle: $initialTitle, initialSubtitle: $initialSubtitle}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EntryEditRouteArgs) return false;
    return key == other.key &&
        entryId == other.entryId &&
        initialTitle == other.initialTitle &&
        initialSubtitle == other.initialSubtitle;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      entryId.hashCode ^
      initialTitle.hashCode ^
      initialSubtitle.hashCode;
}

/// generated route for
/// [_i5.FormattingModelsScreen]
class FormattingModelsRoute extends _i11.PageRouteInfo<void> {
  const FormattingModelsRoute({List<_i11.PageRouteInfo>? children})
    : super(FormattingModelsRoute.name, initialChildren: children);

  static const String name = 'FormattingModelsRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i5.FormattingModelsScreen();
    },
  );
}

/// generated route for
/// [_i6.JournalEmptyScreen]
class JournalEmptyRoute extends _i11.PageRouteInfo<void> {
  const JournalEmptyRoute({List<_i11.PageRouteInfo>? children})
    : super(JournalEmptyRoute.name, initialChildren: children);

  static const String name = 'JournalEmptyRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i6.JournalEmptyScreen();
    },
  );
}

/// generated route for
/// [_i6.JournalWorkspaceScreen]
class HomeRoute extends _i11.PageRouteInfo<void> {
  const HomeRoute({List<_i11.PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i6.JournalWorkspaceScreen();
    },
  );
}

/// generated route for
/// [_i7.LockScreen]
class LockRoute extends _i11.PageRouteInfo<void> {
  const LockRoute({List<_i11.PageRouteInfo>? children})
    : super(LockRoute.name, initialChildren: children);

  static const String name = 'LockRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i7.LockScreen();
    },
  );
}

/// generated route for
/// [_i8.OnboardingScreen]
class OnboardingRoute extends _i11.PageRouteInfo<OnboardingRouteArgs> {
  OnboardingRoute({
    _i12.Key? key,
    bool fromSettings = false,
    List<_i11.PageRouteInfo>? children,
  }) : super(
         OnboardingRoute.name,
         args: OnboardingRouteArgs(key: key, fromSettings: fromSettings),
         initialChildren: children,
       );

  static const String name = 'OnboardingRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<OnboardingRouteArgs>(
        orElse: () => const OnboardingRouteArgs(),
      );
      return _i8.OnboardingScreen(
        key: args.key,
        fromSettings: args.fromSettings,
      );
    },
  );
}

class OnboardingRouteArgs {
  const OnboardingRouteArgs({this.key, this.fromSettings = false});

  final _i12.Key? key;

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
class SearchSettingsRoute extends _i11.PageRouteInfo<void> {
  const SearchSettingsRoute({List<_i11.PageRouteInfo>? children})
    : super(SearchSettingsRoute.name, initialChildren: children);

  static const String name = 'SearchSettingsRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i1.SearchSettingsScreen();
    },
  );
}

/// generated route for
/// [_i9.SettingsScreen]
class SettingsRoute extends _i11.PageRouteInfo<void> {
  const SettingsRoute({List<_i11.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i9.SettingsScreen();
    },
  );
}

/// generated route for
/// [_i10.SpeechModelsScreen]
class SpeechModelsRoute extends _i11.PageRouteInfo<SpeechModelsRouteArgs> {
  SpeechModelsRoute({
    _i12.Key? key,
    bool changeLanguage = false,
    String? requestedLanguage,
    List<_i11.PageRouteInfo>? children,
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

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SpeechModelsRouteArgs>(
        orElse: () => const SpeechModelsRouteArgs(),
      );
      return _i10.SpeechModelsScreen(
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

  final _i12.Key? key;

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
