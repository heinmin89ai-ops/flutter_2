import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';

/// Module 2 login. Local username + secret against `users`.
///
/// The first Admin is created by [SetupAdminScreen] on a fresh database, not
/// seeded with a hard-coded PIN — see `docs/PHASE1_ARCHITECTURE.md` §4.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _secret = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref
        .read(authProvider.notifier)
        .signIn(username: _username.text, secret: _secret.text);

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!result.isSuccess) _error = result.message;
    });
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
                  Icon(
                    Icons.lock_outline,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
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
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'PIN or password',
                      border: const OutlineInputBorder(),
                      errorText: _error,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
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
