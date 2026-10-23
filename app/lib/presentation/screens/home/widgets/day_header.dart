import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:smartnotes/core/theme/theme.dart';

class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.day, this.isFirst = false});

  final DateTime day;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        isFirst ? AppSpacing.md : AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFirst) ...[
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            _formatDay(day),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDay(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(day.year, day.month, day.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';

    return DateFormat.yMMMMd().format(day);
  }
}
