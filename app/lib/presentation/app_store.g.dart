// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AppStore on _AppStore, Store {
  Computed<bool>? _$isUnlockedComputed;

  @override
  bool get isUnlocked => (_$isUnlockedComputed ??= Computed<bool>(
    () => super.isUnlocked,
    name: '_AppStore.isUnlocked',
  )).value;

  late final _$browsingExistingJournalAtom = Atom(
    name: '_AppStore.browsingExistingJournal',
    context: context,
  );

  @override
  bool get browsingExistingJournal {
    _$browsingExistingJournalAtom.reportRead();
    return super.browsingExistingJournal;
  }

  @override
  set browsingExistingJournal(bool value) {
    _$browsingExistingJournalAtom.reportWrite(
      value,
      super.browsingExistingJournal,
      () {
        super.browsingExistingJournal = value;
      },
    );
  }

  late final _$isInitializedAtom = Atom(
    name: '_AppStore.isInitialized',
    context: context,
  );

  @override
  bool get isInitialized {
    _$isInitializedAtom.reportRead();
    return super.isInitialized;
  }

  @override
  set isInitialized(bool value) {
    _$isInitializedAtom.reportWrite(value, super.isInitialized, () {
      super.isInitialized = value;
    });
  }

  late final _$hasCompletedOnboardingAtom = Atom(
    name: '_AppStore.hasCompletedOnboarding',
    context: context,
  );

  @override
  bool get hasCompletedOnboarding {
    _$hasCompletedOnboardingAtom.reportRead();
    return super.hasCompletedOnboarding;
  }

  @override
  set hasCompletedOnboarding(bool value) {
    _$hasCompletedOnboardingAtom.reportWrite(
      value,
      super.hasCompletedOnboarding,
      () {
        super.hasCompletedOnboarding = value;
      },
    );
  }

  late final _$isLockedAtom = Atom(
    name: '_AppStore.isLocked',
    context: context,
  );

  @override
  bool get isLocked {
    _$isLockedAtom.reportRead();
    return super.isLocked;
  }

  @override
  set isLocked(bool value) {
    _$isLockedAtom.reportWrite(value, super.isLocked, () {
      super.isLocked = value;
    });
  }

  late final _$lockErrorMessageAtom = Atom(
    name: '_AppStore.lockErrorMessage',
    context: context,
  );

  @override
  String? get lockErrorMessage {
    _$lockErrorMessageAtom.reportRead();
    return super.lockErrorMessage;
  }

  @override
  set lockErrorMessage(String? value) {
    _$lockErrorMessageAtom.reportWrite(value, super.lockErrorMessage, () {
      super.lockErrorMessage = value;
    });
  }

  late final _$completeOnboardingAsyncAction = AsyncAction(
    '_AppStore.completeOnboarding',
    context: context,
  );

  @override
  Future<void> completeOnboarding() {
    return _$completeOnboardingAsyncAction.run(
      () => super.completeOnboarding(),
    );
  }

  late final _$initializeAsyncAction = AsyncAction(
    '_AppStore.initialize',
    context: context,
  );

  @override
  Future<void> initialize() {
    return _$initializeAsyncAction.run(() => super.initialize());
  }

  late final _$unlockAsyncAction = AsyncAction(
    '_AppStore.unlock',
    context: context,
  );

  @override
  Future<bool> unlock({required String reason}) {
    return _$unlockAsyncAction.run(() => super.unlock(reason: reason));
  }

  late final _$_AppStoreActionController = ActionController(
    name: '_AppStore',
    context: context,
  );

  @override
  void browseExistingJournal() {
    final _$actionInfo = _$_AppStoreActionController.startAction(
      name: '_AppStore.browseExistingJournal',
    );
    try {
      return super.browseExistingJournal();
    } finally {
      _$_AppStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
browsingExistingJournal: ${browsingExistingJournal},
isInitialized: ${isInitialized},
hasCompletedOnboarding: ${hasCompletedOnboarding},
isLocked: ${isLocked},
lockErrorMessage: ${lockErrorMessage},
isUnlocked: ${isUnlocked}
    ''';
  }
}
