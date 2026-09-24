import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../auth/application/auth_providers.dart';
import '../application/license_providers.dart';

/// Module 1 boot screen. Enter the vendor activation key.
///
/// Reached when `license_config` is empty, or when the stored permission blob
/// could not be decoded. On success the router advances to login.
class ActivationKeyScreen extends ConsumerStatefulWidget {
  const ActivationKeyScreen({super.key, this.prefillKey});

  /// Demo key so the screen can be exercised without a vendor-issued value.
  final String? prefillKey;

  @override
  ConsumerState<ActivationKeyScreen> createState() =>
      _ActivationKeyScreenState();
}

class _ActivationKeyScreenState extends ConsumerState<ActivationKeyScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillKey != null) _controller.text = widget.prefillKey!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Enter your activation key.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await ref.read(licenseProvider.notifier).activate(key);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _busy = false;
        _error = ref.read(licenseProvider).message ?? 'Activation failed.';
      });
      return;
    }

    // Advance explicitly rather than relying on the route guard: a device that
    // has just been activated usually has no accounts yet, and the guard has no
    // way to know that without a synchronous user-count read on every redirect.
    final users = await ref.read(userRepositoryProvider).findAll();
    if (!mounted) return;
    context.go(users.isEmpty ? AppRoutes.setupAdmin : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.medication_liquid_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Activate your licence',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the activation key supplied with your pharmacy licence. '
                    'This is a one-time step.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    enabled: !_busy,
                    autocorrect: false,
                    // Must not force upper case: the payload segment is base64url
                    // and therefore case-sensitive.
                    textCapitalization: TextCapitalization.none,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: 'Activation key',
                      hintText: 'eyJhbGciOiJIUzI1NiIs…',
                      border: const OutlineInputBorder(),
                      errorText: _error,
                      suffixIcon: _error == null
                          ? null
                          : const Icon(Icons.error_outline),
                    ),
                    inputFormatters: [
                      // A JWT is three base64url segments joined by '.'. The
                      // separator must be allowed or the field silently drops
                      // every pasted key; spaces and newlines are stripped so a
                      // key wrapped across lines in an email still pastes.
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9_\-.]'),
                      ),
                    ],
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Activate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
