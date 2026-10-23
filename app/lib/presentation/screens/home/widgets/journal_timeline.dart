import 'package:flutter/material.dart';

import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/entities/journal_entry.dart';
import 'day_header.dart';

/// Keeps incoming entries above the reader from moving their current place.
/// Deferred entries become visible when the reader returns to the top.
class JournalTimeline extends StatefulWidget {
  const JournalTimeline({
    super.key,
    required this.entries,
    required this.itemBuilder,
    this.isSearching = false,
    this.showDayHeaders = true,
    this.header,
    this.footer,
    this.scrollIdentity,
  });

  final List<JournalEntry> entries;
  final Widget Function(JournalEntry) itemBuilder;
  final bool isSearching;
  final bool showDayHeaders;
  final Widget? header;
  final Widget? footer;
  final Object? scrollIdentity;

  @override
  State<JournalTimeline> createState() => _JournalTimelineState();
}

class _JournalTimelineState extends State<JournalTimeline> {
  final _controller = ScrollController();
  late Set<String> _visibleIds;
  final _entering = <String>{};

  @override
  void initState() {
    super.initState();
    _visibleIds = widget.entries.map((entry) => entry.id).toSet();
    _controller.addListener(_revealPending);
  }

  void _revealPending() {
    if (_controller.offset > 0) return;
    final pending = widget.entries
        .map((entry) => entry.id)
        .where((id) => !_visibleIds.contains(id))
        .toSet();
    if (pending.isEmpty) return;
    setState(() {
      _visibleIds.addAll(pending);
      _entering.addAll(pending);
    });
    _clearOffscreenEntrances();
  }

  void _clearOffscreenEntrances() {
    // Entries outside the viewport must not animate later while scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) => _entering.clear());
  }

  @override
  void didUpdateWidget(JournalTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollIdentity != oldWidget.scrollIdentity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpTo(0);
      });
    }
    final ids = widget.entries.map((entry) => entry.id).toSet();
    _visibleIds.retainAll(ids);
    _entering.retainAll(ids);
    if (widget.isSearching || oldWidget.isSearching) {
      _visibleIds = ids;
      _entering.clear();
    } else if (!_controller.hasClients || _controller.offset <= 0) {
      _entering.addAll(ids.difference(_visibleIds));
      _visibleIds = ids;
    }
    _clearOffscreenEntrances();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = <({String key, DateTime day, JournalEntry? entry})>[];
    DateTime? lastDay;
    for (final entry in widget.entries) {
      if (!_visibleIds.contains(entry.id)) continue;
      final date = entry.effectiveEntryDate;
      final day = DateTime(date.year, date.month, date.day);
      if (widget.showDayHeaders && day != lastDay) {
        rows.add((key: 'day:$day', day: day, entry: null));
        lastDay = day;
      }
      rows.add((key: 'entry:${entry.id}', day: day, entry: entry));
    }
    final headerCount = widget.header == null ? 0 : 1;
    final indices = <Key, int>{
      if (widget.header != null) const ValueKey('search-header'): 0,
      for (var i = 0; i < rows.length; i++)
        ValueKey(rows[i].key): i + headerCount,
      if (widget.footer != null)
        const ValueKey('search-footer'): rows.length + headerCount,
    };
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.builder(
          key: const PageStorageKey('journal-timeline'),
          controller: _controller,
          padding: AppInsets.scrollContentPadding(
            context,
            extra: AppSpacing.section,
          ),
          itemCount:
              rows.length + headerCount + (widget.footer == null ? 0 : 1),
          findChildIndexCallback: (key) => indices[key],
          itemBuilder: (context, index) {
            if (widget.header != null && index == 0) {
              return KeyedSubtree(
                key: const ValueKey('search-header'),
                child: widget.header!,
              );
            }
            index -= headerCount;
            if (index == rows.length) {
              return KeyedSubtree(
                key: const ValueKey('search-footer'),
                child: widget.footer!,
              );
            }
            final row = rows[index];
            final entry = row.entry;
            final animate = entry != null && _entering.remove(entry.id);
            return TweenAnimationBuilder<double>(
              key: ValueKey(row.key),
              tween: Tween(begin: animate && !reducedMotion ? 0 : 1, end: 1),
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - value)),
                  child: child,
                ),
              ),
              child: entry == null
                  ? DayHeader(day: row.day, isFirst: index == 0)
                  : widget.itemBuilder(entry),
            );
          },
        ),
      ),
    );
  }
}
