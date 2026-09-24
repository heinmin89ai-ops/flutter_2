/// FEFO (First Expired, First Out) deduction arithmetic (Module 5).
///
/// Pure Dart with no drift or Flutter imports, exactly like `unit_hierarchy.dart`:
/// this decides which physical stock leaves the shelf and how much of each batch,
/// and a wrong answer here is a wrong voucher printed on a customer's receipt. It
/// must be testable to the pill without a database or a widget tree.
///
/// The rule the Phase 3 doc left open and this phase resolves: **strict FEFO**.
/// A line is always filled from the earliest-expiry batch that still has stock,
/// then the next, and so on. There is no "pick a fresher batch first" override at
/// the till — a cashier who wants to move a short-dated lot can do so through
/// Phase 5's write-offs, not by quietly selling against the rule and breaking the
/// audit trail this allocator guarantees.
library;

/// A batch as the allocator sees it: the bare facts a deduction needs.
///
/// Deliberately a tiny value type rather than a `StockBatch` or `MedicineBatch`,
/// so the allocator has no dependency on drift and its tests build inputs as
/// literals. [expiryDate] is only carried for the error message; ordering is the
/// caller's job (batches arrive soonest-expiry first, matching
/// `InventoryRepository.batchesFor`).
class FefoBatch {
  const FefoBatch({
    required this.batchId,
    required this.available,
    required this.costPya,
    required this.expiryDate,
  });

  final int batchId;

  /// Smallest units on hand, must be > 0.
  final int available;

  /// Cost per smallest unit in pya; used for the per-batch and blended cost.
  final int costPya;

  final DateTime expiryDate;
}

/// One batch's slice of a deduction.
class FefoAllocation {
  const FefoAllocation({required this.batch, required this.quantity});

  final FefoBatch batch;

  /// Smallest units taken from [batch].
  final int quantity;

  int get batchId => batch.batchId;

  /// Cost in pya of the units taken from this batch.
  int get costPya => quantity * batch.costPya;
}

/// Outcome of allocating one line's quantity across batches.
class FefoResult {
  const FefoResult({required this.allocations, required this.qtyInBase});

  final List<FefoAllocation> allocations;

  /// Total smallest units taken — always equals the requested quantity when this
  /// object is returned at all (the allocator throws instead of under-filling).
  final int qtyInBase;

  /// Sum of cost over all allocations, in pya. This is the line's contribution
  /// to the voucher's `total_cost`.
  int get totalCostPya => allocations.fold<int>(0, (sum, a) => sum + a.costPya);

  /// Blended cost of one smallest unit across the batches consumed, rounded
  /// half-up exactly like `blendUnitCost`.
  ///
  /// This is what `sale_items.unit_cost` stores so a report can restate margin
  /// per unit without walking the allocations again. When a line took from a
  /// single batch this is simply that batch's cost.
  int get blendedUnitCostPya {
    if (qtyInBase <= 0) return 0;
    final total = totalCostPya;
    return (total * 2 + qtyInBase) ~/ (2 * qtyInBase);
  }
}

/// Thrown when stock cannot cover a requested quantity.
///
/// Carries [requested] and [available] so the till can tell the cashier "only 4
/// Strips left" rather than a bare failure — the common real case is a miscount,
/// and naming the two numbers is what lets them fix it without a stock-take.
class FefoShortageException implements Exception {
  const FefoShortageException({
    required this.requested,
    required this.available,
  });

  final int requested;
  final int available;

  /// How many more smallest units the line needs to be sellable.
  int get shortfall => requested - available;

  @override
  String toString() =>
      'FefoShortageException: requested $requested, only $available available';
}

/// Allocates [qtyInBase] smallest units from [batches], earliest expiry first.
///
/// [batches] must already be sorted soonest-expiry first (the order
/// `InventoryRepository.batchesFor` returns, and the FEFO contract). Only batches
/// with `available > 0` are touched. If the sum of availability is less than
/// [qtyInBase] the whole call throws [FefoShortageException] before consuming
/// anything — a line is either filled exactly or not at all, never part-filled,
/// because a till that silently sells half an order and edits stock for it is the
/// bug that leaves the shelf and the voucher disagreeing.
FefoResult allocateFefo({
  required List<FefoBatch> batches,
  required int qtyInBase,
}) {
  if (qtyInBase <= 0) {
    throw ArgumentError.value(
      qtyInBase,
      'qtyInBase',
      'A sale line must take at least one smallest unit.',
    );
  }
  final available = batches.fold<int>(
    0,
    (sum, b) => sum + (b.available > 0 ? b.available : 0),
  );
  if (available < qtyInBase) {
    throw FefoShortageException(requested: qtyInBase, available: available);
  }

  final allocations = <FefoAllocation>[];
  var remaining = qtyInBase;
  for (final batch in batches) {
    if (remaining == 0) break;
    if (batch.available <= 0) continue;
    final take = batch.available >= remaining ? remaining : batch.available;
    allocations.add(FefoAllocation(batch: batch, quantity: take));
    remaining -= take;
  }
  // available >= qtyInBase was checked above, so `remaining` is provably 0 here;
  // this guards the invariant, not a user-facing case.
  assert(remaining == 0);
  return FefoResult(allocations: allocations, qtyInBase: qtyInBase);
}
