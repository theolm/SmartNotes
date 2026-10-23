import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/domain/services/i_platform_model_downloader.dart';
import 'package:smartnotes/presentation/screens/onboarding/onboarding_store.dart';
import 'package:smartnotes/presentation/screens/settings/formatting_models_store.dart';
import 'package:smartnotes/presentation/screens/settings/speech_models_store.dart';
import 'package:smartnotes/presentation/stores/model_downloads_store.dart';

/// Dedicated simulator / isolated test package only; never a user's journal.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'production graph shares downloader state and restores both catalogs',
    (tester) async {
      await configureDependencies();
      addTearDown(() => getIt.reset());
      final downloads = getIt<ModelDownloadsStore>();
      expect(getIt<IPlatformModelDownloader>().supported, true);
      expect(identical(getIt<SpeechModelsStore>().downloads, downloads), true);
      expect(
        identical(getIt<FormattingModelsStore>().downloads, downloads),
        true,
      );
      expect(identical(getIt<OnboardingStore>().downloads, downloads), true);
      await getIt<SpeechModelsStore>().load(null);
      await getIt<FormattingModelsStore>().load();
      expect(getIt<SpeechModelsStore>().error, isNull);
      expect(getIt<FormattingModelsStore>().error, isNull);
      expect(downloads.notificationsAllowed, isNotNull);
    },
  );
}
