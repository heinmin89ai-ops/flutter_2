import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_controller.dart';
import '../../../core/rbac/permission.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../routing/routes.dart';
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          _LanguageSwitcher(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.signOut,
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
              title: Text(l10n.signedInAs(user?.username ?? '—')),
              subtitle: Text(l10n.role(user?.role.name ?? '—')),
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
          const SizedBox(height: 16),
          const _ModuleLinks(),
          const SizedBox(height: 8),
          Text(
            'Phase 5 — credit ledgers, expenses, daily profit reports and '
            'encrypted database backup.',
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

class _LanguageSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: l10n.language,
      onSelected: (value) {
        ref.read(localeProvider.notifier).setLocale(value);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'en',
          child: Row(
            children: [
              if (locale == 'en') const Icon(Icons.check, size: 18),
              if (locale == 'en') const SizedBox(width: 8),
              Text(l10n.english),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'my',
          child: Row(
            children: [
              if (locale == 'my') const Icon(Icons.check, size: 18),
              if (locale == 'my') const SizedBox(width: 8),
              Text(l10n.myanmar),
            ],
          ),
        ),
      ],
    );
  }
}

/// Module entry points the signed-in role may actually open.
///
/// Rendered from the same permissions the router enforces, so the dashboard never
/// advertises a screen that then bounces the user straight back here.
class _ModuleLinks extends ConsumerWidget {
  const _ModuleLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final links = <Widget>[
      if (ref.watch(permissionProvider(Permission.pos)))
        _Link(
          icon: Icons.point_of_sale,
          label: l10n.pointOfSale,
          target: AppRoutes.pos,
        ),
      if (ref.watch(permissionProvider(Permission.viewInventory)))
        _Link(
          icon: Icons.inventory_2_outlined,
          label: l10n.inventory,
          target: AppRoutes.inventory,
        ),
      if (ref.watch(permissionProvider(Permission.manageInventory)))
        _Link(
          icon: Icons.note_add_outlined,
          label: l10n.addMedicine,
          target: AppRoutes.addMedicine,
        ),
      if (ref.watch(permissionProvider(Permission.managePurchases)))
        _Link(
          icon: Icons.local_shipping_outlined,
          label: 'Record a delivery',
          target: AppRoutes.addPurchase,
        ),
      if (ref.watch(permissionProvider(Permission.manageCredit))) ...[
        _Link(
          icon: Icons.savings_outlined,
          label: l10n.customerCredit,
          target: AppRoutes.customerCredit,
        ),
        _Link(
          icon: Icons.payments_outlined,
          label: l10n.supplierCredit,
          target: AppRoutes.supplierCredit,
        ),
      ],
      if (ref.watch(permissionProvider(Permission.manageExpenses)))
        _Link(
          icon: Icons.receipt_long_outlined,
          label: l10n.expenses,
          target: AppRoutes.expenses,
        ),
      if (ref.watch(permissionProvider(Permission.viewProfitReports)))
        _Link(
          icon: Icons.insights_outlined,
          label: l10n.reports,
          target: AppRoutes.reports,
        ),
      if (ref.watch(permissionProvider(Permission.manageBackup)))
        _Link(
          icon: Icons.backup_outlined,
          label: l10n.backupRestore,
          target: AppRoutes.backup,
        ),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: links,
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.target});

  final IconData icon;
  final String label;
  final String target;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: () => GoRouter.of(context).push(target),
        icon: Icon(icon),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}

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
