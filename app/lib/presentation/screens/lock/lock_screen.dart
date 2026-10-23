import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/routes/app_route.gr.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/presentation/app_store.dart';

@RoutePage()
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final AppStore _store = getIt<AppStore>();
  ReactionDisposer? _authReactionDisposer;
  bool _isUnlocking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authReactionDisposer ??= reaction(
      (_) => _store.isUnlocked,
      (state) {
        if (state) {
          context.replaceRoute(const HomeRoute());
        }
      },
    );
  }

  @override
  void dispose() {
    _authReactionDisposer?.call();
    super.dispose();
  }

  Future<void> _unlock() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isUnlocking = true;
    });
    await _store.unlock(reason: l10n.unlockReason);
    if (mounted) {
      setState(() {
        _isUnlocking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Observer(
          builder: (_) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.section),
                    Icon(
                      Icons.fingerprint,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.lockTitle,
                      style: Theme.of(context).textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.lockSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_store.lockErrorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _store.lockErrorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _isUnlocking ? null : _unlock,
                        child: _isUnlocking
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.unlock),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
