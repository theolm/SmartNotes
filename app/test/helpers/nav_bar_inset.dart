import 'package:flutter/widgets.dart';

const double kNavBarInset = 34;

Widget withNavBarInset(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(
      viewPadding: EdgeInsets.only(bottom: kNavBarInset),
    ),
    child: child,
  );
}
