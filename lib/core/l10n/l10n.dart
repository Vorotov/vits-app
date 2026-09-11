import 'package:flutter/widgets.dart';

import 'package:vitomy/core/l10n/gen/app_localizations.dart';

export 'package:vitomy/core/l10n/gen/app_localizations.dart';

/// Shorthand for reading localized strings: `context.l10n.tabStack`.
///
/// Every user-visible string in the app comes from [AppLocalizations]
/// (zero hardcoded strings — project-wide i18n rule). `nullable-getter: false`
/// in l10n.yaml makes [AppLocalizations.of] non-null, so no `!` is needed.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
