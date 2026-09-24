/// Named route paths.
///
/// Constants rather than literals so a redirect typo fails at compile time
/// instead of producing a 404 at runtime on a shop's till.
abstract final class AppRoutes {
  static const String boot = '/';
  static const String activate = '/activate';
  static const String setupAdmin = '/setup-admin';
  static const String login = '/login';
  static const String home = '/home';

  // Added in later phases:
  // static const String inventory = '/inventory';   // Phase 2
  // static const String pos = '/pos';               // Phase 4
  // static const String reports = '/reports';       // Phase 6
}
