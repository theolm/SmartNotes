import 'package:auto_route/auto_route.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/routes/local_lock_guard.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  /// The active workspace installs its guarded entry-selection action here.
  /// Notification navigation follows the same dirty-editor flow as a list tap.
  Future<void> Function(String)? journalEntryOpener;

  Future<void> openJournalEntry(String id) async {
    final open = journalEntryOpener;
    if (open != null) {
      // Settings sit above the workspace, and contain no note edit session.
      while (current.name != HomeRoute.name && canPop()) {
        if (current.name == LockRoute.name ||
            current.name == OnboardingRoute.name) {
          return;
        }
        if (!await maybePop()) return;
      }
      await open(id);
    } else {
      await navigate(
        HomeRoute(
          children: [
            const JournalEmptyRoute(),
            EntryDetailRoute(entryId: id),
          ],
        ),
      );
    }
  }

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: LockRoute.page, path: '/lock'),
    AutoRoute(page: OnboardingRoute.page, path: '/onboarding'),
    AutoRoute(
      page: HomeRoute.page,
      path: '/',
      initial: true,
      guards: [LocalLockGuard()],
      children: [
        AutoRoute(page: JournalEmptyRoute.page, path: '', initial: true),
        AutoRoute(
          page: EntryDetailRoute.page,
          path: 'entry',
          guards: [LocalLockGuard()],
        ),
        AutoRoute(
          page: EntryEditRoute.page,
          path: 'edit',
          guards: [LocalLockGuard()],
        ),
      ],
    ),
    AutoRoute(page: SettingsRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: SearchSettingsRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: BackupSettingsRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: SpeechModelsRoute.page, guards: [LocalLockGuard()]),
    AutoRoute(page: FormattingModelsRoute.page, guards: [LocalLockGuard()]),
  ];
}
