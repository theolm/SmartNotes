import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

String localModelSize(BuildContext context, int bytes) {
  final gb = bytes >= 1000000000;
  final number = NumberFormat(
    gb ? '0.00' : '0.0',
    Localizations.localeOf(context).toLanguageTag(),
  );
  return '${number.format(bytes / (gb ? 1000000000 : 1000000))} ${gb ? 'GB' : 'MB'}';
}
