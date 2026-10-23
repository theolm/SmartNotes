import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/presentation/app_store.dart';

class LocalLockGuard extends AutoRouteGuard {
  LocalLockGuard([AppStore? appStore])
    : _appStore = appStore ?? getIt<AppStore>();

  final AppStore _appStore;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (!_appStore.isInitialized) {
      unawaited(_resolveAfterInitialization(resolver, router));
      return;
    }
    _resolve(resolver, router);
  }

  Future<void> _resolveAfterInitialization(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    await mobx.asyncWhen((_) => _appStore.isInitialized);
    _resolve(resolver, router);
  }

  void _resolve(NavigationResolver resolver, StackRouter router) {
    if (!_appStore.isUnlocked) {
      resolver.redirectUntil(const LockRoute());
    } else if (!_appStore.hasCompletedOnboarding &&
        !_appStore.browsingExistingJournal) {
      resolver.redirectUntil(OnboardingRoute());
    } else {
      resolver.next();
    }
  }
}
