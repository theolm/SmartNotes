import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.dart';
import 'package:smartnotes/presentation/screens/settings/settings_store.dart';
import 'package:smartnotes/presentation/app_store.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/application/journal_lifecycle.dart';
import 'package:smartnotes/data/services/model_verification.dart';
import 'package:smartnotes/data/services/processing_feedback_service.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Whisper model',
    ], await rootBundle.loadString('assets/licenses/whisper-model-MIT.txt'));
    yield LicenseEntryWithLineBreaks(
      [
        'Qwen3 formatting and embedding models',
      ],
      await rootBundle.loadString('assets/licenses/qwen3-model-Apache-2.0.txt'),
    );
  });

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await configureDependencies();

  final appStore = getIt<AppStore>();
  await appStore.initialize();

  final settingsStore = getIt<SettingsStore>();
  try {
    await settingsStore.load();
  } catch (_) {
    // AppStore initialized the lock fail-closed. Optional preference/device
    // capability loading must not leave the user behind the native splash.
  }

  runApp(const SmartNotesApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final processingFeedback = getIt<ProcessingFeedbackService>();
    processingFeedback.entryOpens.listen(
      (entryId) => unawaited(
        appRouter.push<void>(EntryDetailRoute(entryId: entryId)),
      ),
    );
    unawaited(processingFeedback.initialize());
    getIt<ModelVerificationStore>().allowVerification();
    unawaited(appStore.checkModels());
    getIt<JournalLifecycle>().start();
  });
}

final appRouter = AppRouter();

class SmartNotesApp extends StatelessWidget {
  const SmartNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SmartNotes',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter.config(),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppSystemBars.forBrightness(Theme.of(context).brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
