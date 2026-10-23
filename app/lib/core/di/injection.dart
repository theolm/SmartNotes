import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'package:smartnotes/core/di/injection.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit(
  initializerName: r'$initGetIt',
  preferRelativeImports: false,
  asExtension: false,
)
Future<void> configureDependencies() async {
  await $initGetIt(getIt);
}
