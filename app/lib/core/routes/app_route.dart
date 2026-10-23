import 'package:auto_route/auto_route.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/routes/local_lock_guard.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: LockRoute.page, path: '/lock'),
    AutoRoute(page: OnboardingRoute.page, path: '/onboarding'),
    AutoRoute(
      page: HomeRoute.page,
      path: '/',
      initial: true,
      guards: [LocalLockGuard()],
    ),
    AutoRoute(page: EntryDetailRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: EntryEditRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: SettingsRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: SearchSettingsRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: BackupSettingsRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: SpeechModelsRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: FormattingModelsRoute.page, guards: [LocalLockGuard()]),
  ];
}
