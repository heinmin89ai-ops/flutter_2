import 'package:flutter_riverpod/flutter_riverpod.dart';
// `family` providers keep their own type out of the default namespace.
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../core/database/database_provider.dart';
import '../../../core/database/tables/credit_transactions.dart';
import '../../../core/rbac/permission.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../data/credit_repository.dart';

final Provider<CreditRepository> creditRepositoryProvider =
    Provider<CreditRepository>(
      (ref) => CreditRepository(ref.watch(appDatabaseProvider)),
    );

/// Whether the signed-in user may manage receivables/payables.
final Provider<bool> canManageCreditProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.manageCredit)),
);

/// The admin's "undo a payment" capability.
final Provider<bool> canDeleteTransactionProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.deleteTransaction)),
);

/// Customers who owe the shop.
final FutureProvider<List<PartyBalance>> debtorsProvider =
    FutureProvider.autoDispose<List<PartyBalance>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(creditRepositoryProvider).debtors();
    });

/// Suppliers the shop owes.
final FutureProvider<List<PartyBalance>> payablesProvider =
    FutureProvider.autoDispose<List<PartyBalance>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(creditRepositoryProvider).payables();
    });

/// One party's full statement, running balance included.
///
/// Keyed on the `(PartyType, id)` record so the same screen can pull a customer's
/// or a supplier's ledger through one provider without an id collision between
/// the two tables.
final FutureProviderFamily<List<StatementEntry>, (PartyType, int)>
statementProvider = FutureProvider.autoDispose
    .family<List<StatementEntry>, (PartyType, int)>((ref, key) {
      ref.watch(inventoryRevisionProvider);
      return ref
          .read(creditRepositoryProvider)
          .statement(partyType: key.$1, partyId: key.$2);
    });
