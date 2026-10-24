import 'package:flutter/material.dart';
import 'package:smartnotes/core/theme/theme.dart';

/// Shared presentation only. Catalogs retain selection, compatibility and
/// installation policy; every family uses the same geometry and controls.
class ModelCatalogTile extends StatelessWidget {
  const ModelCatalogTile({
    super.key,
    required this.name,
    required this.metadata,
    required this.active,
    required this.activeLabel,
    required this.detailsTitle,
    required this.description,
    required this.status,
    required this.trailing,
    this.recommendedLabel,
    this.onTap,
    this.onDetails,
    this.detailsTooltip,
    this.warnings = const [],
  });

  final String name;
  final String metadata;
  final bool active;
  final String activeLabel;
  final String? recommendedLabel;
  final String detailsTitle;
  final String description;
  final String status;
  final Widget trailing;
  final VoidCallback? onTap;
  final VoidCallback? onDetails;
  final String? detailsTooltip;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Semantics(
        selected: active,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? colors.primary : colors.outlineVariant,
              width: active ? 2 : 1,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(11),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (active || recommendedLabel != null) ...[
                            Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.xs,
                              children: [
                                if (recommendedLabel != null)
                                  Text(
                                    recommendedLabel!,
                                    style: text.labelMedium?.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                if (active)
                                  Text(
                                    activeLabel,
                                    style: text.labelMedium?.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          Text(name, style: text.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(metadata, style: text.bodySmall),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  detailsTitle,
                                  style: text.titleSmall,
                                ),
                              ),
                              if (onDetails != null)
                                IconButton(
                                  tooltip: detailsTooltip,
                                  onPressed: onDetails,
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(description, style: text.bodyMedium),
                          for (final warning in warnings) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(warning, style: text.bodyMedium),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Text(status, style: text.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    trailing,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ModelCatalogAction { checking, pending, download, delete, unavailable }

/// The shared 48dp trailing action: progress/cancel, download, or deletion.
/// Tooltip and callback remain family-specific; active deletion is disabled.
class ModelCatalogActionButton extends StatelessWidget {
  const ModelCatalogActionButton({
    super.key,
    required this.action,
    required this.tooltip,
    this.onPressed,
    this.buttonKey,
  });
  final ModelCatalogAction action;
  final String tooltip;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: tooltip,
    onPressed: onPressed,
    icon: switch (action) {
      ModelCatalogAction.checking ||
      ModelCatalogAction.pending => SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      ModelCatalogAction.download => const Icon(Icons.download_outlined),
      ModelCatalogAction.delete => const Icon(Icons.delete_outline),
      ModelCatalogAction.unavailable => const Icon(Icons.block_outlined),
    },
  );
}
