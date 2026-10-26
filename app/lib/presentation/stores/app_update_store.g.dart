// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AppUpdateStore on _AppUpdateStore, Store {
  late final _$busyAtom = Atom(name: '_AppUpdateStore.busy', context: context);

  @override
  bool get busy {
    _$busyAtom.reportRead();
    return super.busy;
  }

  @override
  set busy(bool value) {
    _$busyAtom.reportWrite(value, super.busy, () {
      super.busy = value;
    });
  }

  late final _$errorAtom = Atom(
    name: '_AppUpdateStore.error',
    context: context,
  );

  @override
  String? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(String? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$installedAtom = Atom(
    name: '_AppUpdateStore.installed',
    context: context,
  );

  @override
  String get installed {
    _$installedAtom.reportRead();
    return super.installed;
  }

  @override
  set installed(String value) {
    _$installedAtom.reportWrite(value, super.installed, () {
      super.installed = value;
    });
  }

  late final _$releaseAtom = Atom(
    name: '_AppUpdateStore.release',
    context: context,
  );

  @override
  AppRelease? get release {
    _$releaseAtom.reportRead();
    return super.release;
  }

  @override
  set release(AppRelease? value) {
    _$releaseAtom.reportWrite(value, super.release, () {
      super.release = value;
    });
  }

  late final _$assetAtom = Atom(
    name: '_AppUpdateStore.asset',
    context: context,
  );

  @override
  ReleaseAsset? get asset {
    _$assetAtom.reportRead();
    return super.asset;
  }

  @override
  set asset(ReleaseAsset? value) {
    _$assetAtom.reportWrite(value, super.asset, () {
      super.asset = value;
    });
  }

  late final _$promptPendingAtom = Atom(
    name: '_AppUpdateStore.promptPending',
    context: context,
  );

  @override
  bool get promptPending {
    _$promptPendingAtom.reportRead();
    return super.promptPending;
  }

  @override
  set promptPending(bool value) {
    _$promptPendingAtom.reportWrite(value, super.promptPending, () {
      super.promptPending = value;
    });
  }

  late final _$checkedAtom = Atom(
    name: '_AppUpdateStore.checked',
    context: context,
  );

  @override
  bool get checked {
    _$checkedAtom.reportRead();
    return super.checked;
  }

  @override
  set checked(bool value) {
    _$checkedAtom.reportWrite(value, super.checked, () {
      super.checked = value;
    });
  }

  late final _$openRequestedAtom = Atom(
    name: '_AppUpdateStore.openRequested',
    context: context,
  );

  @override
  bool get openRequested {
    _$openRequestedAtom.reportRead();
    return super.openRequested;
  }

  @override
  set openRequested(bool value) {
    _$openRequestedAtom.reportWrite(value, super.openRequested, () {
      super.openRequested = value;
    });
  }

  late final _$downloadAtom = Atom(
    name: '_AppUpdateStore.download',
    context: context,
  );

  @override
  UpdateDownload get download {
    _$downloadAtom.reportRead();
    return super.download;
  }

  @override
  set download(UpdateDownload value) {
    _$downloadAtom.reportWrite(value, super.download, () {
      super.download = value;
    });
  }

  late final _$refreshAsyncAction = AsyncAction(
    '_AppUpdateStore.refresh',
    context: context,
  );

  @override
  Future<void> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  late final _$checkAsyncAction = AsyncAction(
    '_AppUpdateStore.check',
    context: context,
  );

  @override
  Future<void> check({bool manual = false}) {
    return _$checkAsyncAction.run(() => super.check(manual: manual));
  }

  late final _$deferAsyncAction = AsyncAction(
    '_AppUpdateStore.defer',
    context: context,
  );

  @override
  Future<void> defer({required bool ignore}) {
    return _$deferAsyncAction.run(() => super.defer(ignore: ignore));
  }

  late final _$actAsyncAction = AsyncAction(
    '_AppUpdateStore.act',
    context: context,
  );

  @override
  Future<void> act(Map<String, String> notification) {
    return _$actAsyncAction.run(() => super.act(notification));
  }

  late final _$openReleaseAsyncAction = AsyncAction(
    '_AppUpdateStore.openRelease',
    context: context,
  );

  @override
  Future<void> openRelease() {
    return _$openReleaseAsyncAction.run(() => super.openRelease());
  }

  late final _$installAsyncAction = AsyncAction(
    '_AppUpdateStore.install',
    context: context,
  );

  @override
  Future<void> install({required bool Function() allowed}) {
    return _$installAsyncAction.run(() => super.install(allowed: allowed));
  }

  late final _$cancelAsyncAction = AsyncAction(
    '_AppUpdateStore.cancel',
    context: context,
  );

  @override
  Future<void> cancel() {
    return _$cancelAsyncAction.run(() => super.cancel());
  }

  late final _$_AppUpdateStoreActionController = ActionController(
    name: '_AppUpdateStore',
    context: context,
  );

  @override
  void consumePrompt() {
    final _$actionInfo = _$_AppUpdateStoreActionController.startAction(
      name: '_AppUpdateStore.consumePrompt',
    );
    try {
      return super.consumePrompt();
    } finally {
      _$_AppUpdateStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void consumeOpenRequest() {
    final _$actionInfo = _$_AppUpdateStoreActionController.startAction(
      name: '_AppUpdateStore.consumeOpenRequest',
    );
    try {
      return super.consumeOpenRequest();
    } finally {
      _$_AppUpdateStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
busy: ${busy},
error: ${error},
installed: ${installed},
release: ${release},
asset: ${asset},
promptPending: ${promptPending},
checked: ${checked},
openRequested: ${openRequested},
download: ${download}
    ''';
  }
}
