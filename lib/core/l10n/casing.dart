/// Uppercasing for intl output, with ONE definition for the whole app.
///
/// Dart's `String.toUpperCase()` is locale-INDEPENDENT: it applies the default
/// Unicode mapping and knows nothing about the language the text is in. For
/// every language the app ships today (en, uk) that mapping is correct, so the
/// four labels below render correctly — but the calls were spread across four
/// files and two of them carried a comment claiming they were "locale-aware
/// uppercasing", which no Dart API is and `intl` does not provide either
/// (05-REVIEW WR-03). A wrong comment is worse than no comment: it stops the
/// next reader from looking.
///
/// So uppercasing gets the same treatment Amendment A3 gave sentence casing —
/// one named function, one place to fix, one place to read — plus the single
/// mapping the Unicode default gets wrong for a language that could plausibly
/// arrive as "one new ARB file": Turkish and Azeri, where the dotless/dotted i
/// pair means `i` must uppercase to `İ` and `ı` to `I`, not both to `I`.
///
/// Everything else in the pipeline is already locale-aware (`DateFormat` with
/// an explicit locale produces the words); only the casing step needed a home.
library;

/// [value] uppercased for [locale].
///
/// [locale] is the ACTIVE locale string (`Localizations.localeOf(context)`),
/// never a hardcoded tag — same rule as every `DateFormat` in the app.
///
/// The Turkish/Azeri branch is the one documented exception to Dart's default
/// mapping. It is deliberately narrow: it covers the dotted-i pair, which is
/// the mapping that changes the SHAPE of a word, and nothing else. If a
/// language whose casing needs more than this is ever added, this is the
/// single function that has to grow — not four call sites.
String bqUpperCase(String value, String locale) {
  if (locale.startsWith('tr') || locale.startsWith('az')) {
    // Order matters: map both members of the pair to their correct partner
    // BEFORE the default mapping runs, so neither collapses onto plain 'I'.
    // Both replacements are already uppercase, so the trailing default pass
    // leaves them alone and only uppercases the rest of the word.
    return value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }
  return value.toUpperCase();
}
