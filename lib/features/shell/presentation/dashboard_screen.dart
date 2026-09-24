import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/permission.dart';
import '../../auth/application/auth_providers.dart';
import '../../license/application/license_providers.dart';
import '../../license/application/license_secret.dart';

/// Landing screen after sign-in.
///
/// Still a placeholder by design — the real navigation shell arrives with POS
/// (Phase 4). What changed since Phase 1 is that it now surfaces the licence the
/// shop is actually running on: customer name, expiry countdown and granted
/// modules. A licence that silently expires mid-year is a support call at 8am;
/// showing the countdown here is the cheap fix.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final license = ref.watch(licenseProvider);
    final maySeeCost = ref.watch(permissionProvider(Permission.viewCostPrice));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy POS'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('Signed in as ${user?.username ?? '—'}'),
              subtitle: Text('Role: ${user?.role.name ?? '—'}'),
            ),
          ),
          const SizedBox(height: 8),
          if (license.expiringSoon) _ExpiryBanner(license: license),
          if (kDebugMode && kUsingDevelopmentLicenseSecret)
            const _Card(
              icon: Icons.warning_amber_rounded,
              tone: CardTone.warning,
              title: 'Development licence secret in use',
              body:
                  'This build verifies keys against the placeholder secret that '
                  'is committed to the repository. Build with '
                  '--dart-define=PHARMACY_LICENSE_SECRET=… before issuing a '
                  'customer key.',
            ),
          _Card(
            icon: Icons.workspace_premium_outlined,
            title: license.client == null
                ? 'Licence'
                : 'Licence: ${license.client}',
            body:
                'Status: ${license.status.name}\n'
                'Expires: ${_expiryLabel(license.expiresAt)}\n'
                'Modules: ${license.features.isEmpty ? '—' : license.features.keys.join(', ')}',
          ),
          _Card(
            icon: Icons.lock_outline,
            title: 'Your access',
            body: maySeeCost
                ? 'Cost prices and profit reports are visible to your role.'
                : 'Cost prices and profit reports are hidden for the '
                      '${user?.role.name ?? 'current'} role.',
          ),
          const SizedBox(height: 8),
          Text(
            'Phase 2 — signed licences. Inventory, FEFO allocation and batches '
            'land next.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _expiryLabel(DateTime? expiry) => expiry == null
      ? 'never (perpetual licence)'
      : expiry.toIso8601String().split('T').first;
}

class _ExpiryBanner extends ConsumerWidget {
  const _ExpiryBanner({required this.license});

  final LicenseState license;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = license.daysRemaining ?? 0;
    return _Card(
      icon: Icons.event_busy_outlined,
      tone: CardTone.warning,
      title: remaining >= 0
          ? 'Licence expires in $remaining day${remaining == 1 ? '' : 's'}'
          : 'Licence expired ${-remaining} day${remaining == -1 ? '' : 's'} ago',
      body:
          'Renew before then to keep using the app. Your data stays on this '
          'device; entering a new activation key restores access immediately.',
    );
  }
}

enum CardTone { neutral, warning }

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.body,
    this.tone = CardTone.neutral,
  });

  final IconData icon;
  final String title;
  final String body;
  final CardTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = tone == CardTone.warning
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHighest;
    return Card(
      color: tint,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(body),
        isThreeLine: body.contains('\n'),
      ),
    );
  }
}
