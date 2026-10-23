// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_downloads_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ModelDownloadsStore on _ModelDownloadsStore, Store {
  late final _$notificationsAllowedAtom = Atom(
    name: '_ModelDownloadsStore.notificationsAllowed',
    context: context,
  );

  @override
  bool? get notificationsAllowed {
    _$notificationsAllowedAtom.reportRead();
    return super.notificationsAllowed;
  }

  @override
  set notificationsAllowed(bool? value) {
    _$notificationsAllowedAtom.reportWrite(
      value,
      super.notificationsAllowed,
      () {
        super.notificationsAllowed = value;
      },
    );
  }

  late final _$refreshAsyncAction = AsyncAction(
    '_ModelDownloadsStore.refresh',
    context: context,
  );

  @override
  Future<List<ModelTransfer>> refresh() {
    return _$refreshAsyncAction.run(() => super.refresh());
  }

  @override
  String toString() {
    return '''
notificationsAllowed: ${notificationsAllowed}
    ''';
  }
}
