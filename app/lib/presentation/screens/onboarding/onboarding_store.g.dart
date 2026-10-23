// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$OnboardingStore on _OnboardingStore, Store {
  Computed<LocalAiModel>? _$modelComputed;

  @override
  LocalAiModel get model => (_$modelComputed ??= Computed<LocalAiModel>(
    () => super.model,
    name: '_OnboardingStore.model',
  )).value;
  Computed<bool>? _$modelReadyComputed;

  @override
  bool get modelReady => (_$modelReadyComputed ??= Computed<bool>(
    () => super.modelReady,
    name: '_OnboardingStore.modelReady',
  )).value;
  Computed<bool>? _$formattingReadyComputed;

  @override
  bool get formattingReady => (_$formattingReadyComputed ??= Computed<bool>(
    () => super.formattingReady,
    name: '_OnboardingStore.formattingReady',
  )).value;
  Computed<bool>? _$currentModelReadyComputed;

  @override
  bool get currentModelReady => (_$currentModelReadyComputed ??= Computed<bool>(
    () => super.currentModelReady,
    name: '_OnboardingStore.currentModelReady',
  )).value;
  Computed<bool>? _$isDownloadingComputed;

  @override
  bool get isDownloading => (_$isDownloadingComputed ??= Computed<bool>(
    () => super.isDownloading,
    name: '_OnboardingStore.isDownloading',
  )).value;
  Computed<double>? _$downloadProgressComputed;

  @override
  double get downloadProgress =>
      (_$downloadProgressComputed ??= Computed<double>(
        () => super.downloadProgress,
        name: '_OnboardingStore.downloadProgress',
      )).value;
  Computed<bool>? _$isBusyComputed;

  @override
  bool get isBusy => (_$isBusyComputed ??= Computed<bool>(
    () => super.isBusy,
    name: '_OnboardingStore.isBusy',
  )).value;

  late final _$embeddingModelReadyAtom = Atom(
    name: '_OnboardingStore.embeddingModelReady',
    context: context,
  );

  @override
  bool get embeddingModelReady {
    _$embeddingModelReadyAtom.reportRead();
    return super.embeddingModelReady;
  }

  @override
  set embeddingModelReady(bool value) {
    _$embeddingModelReadyAtom.reportWrite(value, super.embeddingModelReady, () {
      super.embeddingModelReady = value;
    });
  }

  late final _$embeddingCheckingAtom = Atom(
    name: '_OnboardingStore.embeddingChecking',
    context: context,
  );

  @override
  bool get embeddingChecking {
    _$embeddingCheckingAtom.reportRead();
    return super.embeddingChecking;
  }

  @override
  set embeddingChecking(bool value) {
    _$embeddingCheckingAtom.reportWrite(value, super.embeddingChecking, () {
      super.embeddingChecking = value;
    });
  }

  late final _$embeddingDownloadingAtom = Atom(
    name: '_OnboardingStore.embeddingDownloading',
    context: context,
  );

  @override
  bool get embeddingDownloading {
    _$embeddingDownloadingAtom.reportRead();
    return super.embeddingDownloading;
  }

  @override
  set embeddingDownloading(bool value) {
    _$embeddingDownloadingAtom.reportWrite(
      value,
      super.embeddingDownloading,
      () {
        super.embeddingDownloading = value;
      },
    );
  }

  late final _$embeddingTransferStateAtom = Atom(
    name: '_OnboardingStore.embeddingTransferState',
    context: context,
  );

  @override
  ModelTransferState? get embeddingTransferState {
    _$embeddingTransferStateAtom.reportRead();
    return super.embeddingTransferState;
  }

  @override
  set embeddingTransferState(ModelTransferState? value) {
    _$embeddingTransferStateAtom.reportWrite(
      value,
      super.embeddingTransferState,
      () {
        super.embeddingTransferState = value;
      },
    );
  }

  late final _$downloadedBytesAtom = Atom(
    name: '_OnboardingStore.downloadedBytes',
    context: context,
  );

  @override
  int get downloadedBytes {
    _$downloadedBytesAtom.reportRead();
    return super.downloadedBytes;
  }

  @override
  set downloadedBytes(int value) {
    _$downloadedBytesAtom.reportWrite(value, super.downloadedBytes, () {
      super.downloadedBytes = value;
    });
  }

  late final _$stepAtom = Atom(name: '_OnboardingStore.step', context: context);

  @override
  OnboardingStep get step {
    _$stepAtom.reportRead();
    return super.step;
  }

  @override
  set step(OnboardingStep value) {
    _$stepAtom.reportWrite(value, super.step, () {
      super.step = value;
    });
  }

  late final _$optionalFormattingEnabledAtom = Atom(
    name: '_OnboardingStore.optionalFormattingEnabled',
    context: context,
  );

  @override
  bool get optionalFormattingEnabled {
    _$optionalFormattingEnabledAtom.reportRead();
    return super.optionalFormattingEnabled;
  }

  @override
  set optionalFormattingEnabled(bool value) {
    _$optionalFormattingEnabledAtom.reportWrite(
      value,
      super.optionalFormattingEnabled,
      () {
        super.optionalFormattingEnabled = value;
      },
    );
  }

  late final _$workingAtom = Atom(
    name: '_OnboardingStore.working',
    context: context,
  );

  @override
  bool get working {
    _$workingAtom.reportRead();
    return super.working;
  }

  @override
  set working(bool value) {
    _$workingAtom.reportWrite(value, super.working, () {
      super.working = value;
    });
  }

  late final _$audioLanguageAtom = Atom(
    name: '_OnboardingStore.audioLanguage',
    context: context,
  );

  @override
  String? get audioLanguage {
    _$audioLanguageAtom.reportRead();
    return super.audioLanguage;
  }

  @override
  set audioLanguage(String? value) {
    _$audioLanguageAtom.reportWrite(value, super.audioLanguage, () {
      super.audioLanguage = value;
    });
  }

  late final _$errorAtom = Atom(
    name: '_OnboardingStore.error',
    context: context,
  );

  @override
  OnboardingFailure? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(OnboardingFailure? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    '_OnboardingStore.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$selectLanguageAsyncAction = AsyncAction(
    '_OnboardingStore.selectLanguage',
    context: context,
  );

  @override
  Future<void> selectLanguage(String? language) {
    return _$selectLanguageAsyncAction.run(
      () => super.selectLanguage(language),
    );
  }

  late final _$downloadModelAsyncAction = AsyncAction(
    '_OnboardingStore.downloadModel',
    context: context,
  );

  @override
  Future<void> downloadModel() {
    return _$downloadModelAsyncAction.run(() => super.downloadModel());
  }

  late final _$finishAsyncAction = AsyncAction(
    '_OnboardingStore.finish',
    context: context,
  );

  @override
  Future<bool> finish() {
    return _$finishAsyncAction.run(() => super.finish());
  }

  late final _$_OnboardingStoreActionController = ActionController(
    name: '_OnboardingStore',
    context: context,
  );

  @override
  void next() {
    final _$actionInfo = _$_OnboardingStoreActionController.startAction(
      name: '_OnboardingStore.next',
    );
    try {
      return super.next();
    } finally {
      _$_OnboardingStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void back() {
    final _$actionInfo = _$_OnboardingStoreActionController.startAction(
      name: '_OnboardingStore.back',
    );
    try {
      return super.back();
    } finally {
      _$_OnboardingStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
embeddingModelReady: ${embeddingModelReady},
embeddingChecking: ${embeddingChecking},
embeddingDownloading: ${embeddingDownloading},
embeddingTransferState: ${embeddingTransferState},
downloadedBytes: ${downloadedBytes},
step: ${step},
optionalFormattingEnabled: ${optionalFormattingEnabled},
working: ${working},
audioLanguage: ${audioLanguage},
error: ${error},
model: ${model},
modelReady: ${modelReady},
formattingReady: ${formattingReady},
currentModelReady: ${currentModelReady},
isDownloading: ${isDownloading},
downloadProgress: ${downloadProgress},
isBusy: ${isBusy}
    ''';
  }
}
