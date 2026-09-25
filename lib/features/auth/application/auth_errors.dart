import '../../../l10n/generated/app_localizations.dart';

/// Resolver for every `auth`-prefixed message key owned by the auth module.
String? authErrors(AppLocalizations l10n, String key, Map<String, String> args) =>
    switch (key) {
      'authSignInTitle' => l10n.authSignInTitle,
      'authSignInButton' => l10n.authSignInButton,
      'authUsernameLabel' => l10n.authUsernameLabel,
      'authSecretLabel' => l10n.authSecretLabel,
      'authSetupTitle' => l10n.authSetupTitle,
      'authSetupBlurb' => l10n.authSetupBlurb,
      'authConfirmLabel' => l10n.authConfirmLabel,
      'authCreateAccountButton' => l10n.authCreateAccountButton,
      'authSecretHelper' => l10n.authSecretHelper(args['min']!),
      'authUsernameMinLength' => l10n.authUsernameMinLength(args['min']!),
      'authSecretMinLength' => l10n.authSecretMinLength(args['min']!),
      'authPasswordMismatch' => l10n.authPasswordMismatch,
      'authAccountNotFound' => l10n.authAccountNotFound,
      'authInvalidCredentials' => l10n.authInvalidCredentials,
      'authAccountDisabled' => l10n.authAccountDisabled,
      'authLastAdminError' => l10n.authLastAdminError,
      'authUsernameTaken' => l10n.authUsernameTaken(args['username']!),
      _ => null,
    };
