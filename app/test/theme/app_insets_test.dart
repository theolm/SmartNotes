import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/core/theme/theme.dart';

void main() {
  group('AppInsets', () {
    testWidgets('bottomSystemPadding returns the navigation bar inset', (
      tester,
    ) async {
      double? result;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: 34, top: 59),
          ),
          child: Builder(
            builder: (context) {
              result = AppInsets.bottomSystemPadding(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, 34);
    });

    testWidgets(
      'scrollContentPadding adds default spacing below scrollable content',
      (tester) async {
        EdgeInsets? result;

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: Builder(
              builder: (context) {
                result = AppInsets.scrollContentPadding(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(result, const EdgeInsets.only(bottom: 34 + AppSpacing.lg));
      },
    );

    testWidgets('scrollContentPadding accepts custom extra spacing', (
      tester,
    ) async {
      EdgeInsets? result;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: 34),
          ),
          child: Builder(
            builder: (context) {
              result = AppInsets.scrollContentPadding(
                context,
                extra: AppSpacing.xxl,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, const EdgeInsets.only(bottom: 34 + AppSpacing.xxl));
    });

    testWidgets('falls back to zero when there is no navigation bar inset', (
      tester,
    ) async {
      EdgeInsets? result;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              result = AppInsets.scrollContentPadding(context, extra: 0);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, EdgeInsets.zero);
    });

    testWidgets(
      'withBottomSystemPadding adds the inset on top of a base padding',
      (tester) async {
        EdgeInsets? result;

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: Builder(
              builder: (context) {
                result = AppInsets.withBottomSystemPadding(
                  context,
                  const EdgeInsets.all(AppSpacing.lg),
                );
                return const SizedBox();
              },
            ),
          ),
        );

        expect(
          result,
          const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + 34,
          ),
        );
      },
    );

    testWidgets(
      'withBottomSystemPadding leaves padding untouched without inset',
      (tester) async {
        EdgeInsets? result;

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Builder(
              builder: (context) {
                result = AppInsets.withBottomSystemPadding(
                  context,
                  const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                );
                return const SizedBox();
              },
            ),
          ),
        );

        expect(
          result,
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
        );
      },
    );
  });
}
