/// Result of resolving a scanned barcode.
enum ScanResult {
  /// Barcode was blank or empty; ignore it.
  ignoreEmpty,

  /// Exact barcode match found; add the medicine to cart/form.
  addProduct,

  /// No exact match found; show "not found" message.
  showNotFound,
}

/// Resolves a scanned barcode to an action.
///
/// Pure function: no platform dependencies, no context. Given a barcode string
/// and a lookup function, returns what the caller should do.
///
/// [findByBarcode] returns the medicine ID if an exact barcode match exists,
/// or null if not found.
ScanResult resolveScan({
  required String code,
  required int? Function(String code) findByBarcode,
}) {
  final trimmed = code.trim();
  if (trimmed.isEmpty) {
    return ScanResult.ignoreEmpty;
  }

  final medicineId = findByBarcode(trimmed);
  if (medicineId != null) {
    return ScanResult.addProduct;
  }

  return ScanResult.showNotFound;
}
