import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/rbac/permission.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../data/report_repository.dart';

final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>(
      (ref) => ReportRepository(ref.watch(appDatabaseProvider)),
    );

/// Whether the signed-in user may open the profit dashboard.
final Provider<bool> canSeeReportsProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.viewProfitReports)),
);

/// Today's dashboard figures.
///
/// Re-derives with the same revision counter the rest of the read layer uses,
/// so a recorded sale, payment or expense refreshes the board without a manual
/// reload.
final FutureProvider<DailyReport> dailyReportProvider =
    FutureProvider.autoDispose<DailyReport>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(reportRepositoryProvider).daily();
    });
