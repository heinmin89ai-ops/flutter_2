import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/users.dart';
import '../application/auth_providers.dart';

/// First-run setup: create the initial Admin account.
///
/// Exists instead of a hard-coded `admin/admin123` seed because a fixed default
/// PIN on an offline device that also holds cost prices and customer debt is the
/// weakest possible link — and it cannot be rotated remotely. The shop owner
/// chooses the credential while the device is still in their hands.
class SetupAdminScreen extends ConsumerStatefulWidget {
  const SetupAdminScreen({super.key});

  @override
  ConsumerState<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends ConsumerState<SetupAdminScreen> {
  final TextEditingController _username = TextEditingController(text: 'admin');
  final TextEditingController _secret = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String? _error;
  bool _busy = false;

  static const int _minSecretLength = 6;

  @override
  void dispose() {
    _username.dispose();
    _secret.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final secret = _secret.text;

    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters.');
      return;
    }
    if (secret.length < _minSecretLength) {
      setState(() => _error = 'Use at least $_minSecretLength characters.');
      return;
    }
    if (secret != _confirm.text) {
      setState(() => _error = 'The two entries do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(userRepositoryProvider)
          .create(username: username, secret: secret, role: UserRole.admin);
      await ref
          .read(authProvider.notifier)
          .signIn(username: username, secret: secret);
    } on Object catch (e) {
      if (mounted) setState(() => _busy = false);
      if (mounted) setState(() => _error = e.toString());
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create the owner account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This account can see cost prices, edit stock and manage '
                    'staff. Choose something you will remember — there is no '
                    'server reset for an offline device.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _username,
                    enabled: !_busy,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _secret,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'PIN or password',
                      helperText: 'Minimum 6 characters',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm',
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: const Text('Create account'),
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
