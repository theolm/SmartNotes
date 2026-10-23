import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:local_auth/local_auth.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
abstract class RegisterModule {
  @singleton
  AudioRecorder get audioRecorder => AudioRecorder();

  @singleton
  http.Client get httpClient => http.Client();

  @singleton
  LocalAuthentication get localAuthentication => LocalAuthentication();

  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
