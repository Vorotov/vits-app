/// The zero-hardcoded-strings source gate (plan 05-03 task 2, L10N-04,
/// 05-RESEARCH V-2 / A-2 / PF-4 / PF-5).
///
/// The audit that opened this phase found ZERO hardcoded user-visible strings
/// in `lib/` — and no mechanical gate protecting that. A property nothing
/// checks is a property that holds until the next hurried commit, which is the
/// only kind of commit that ever introduces one. This file is that check.
///
/// Two gates, from opposite directions:
///
/// 1. **Widget-position gate.** No literal carrying translatable words may
///    appear as a `Text(` argument or as the value of a user-facing named
///    parameter (`label:`, `tooltip:`, `hintText:`, `labelText:`, `helperText:`,
///    `errorText:`, `semanticsLabel:`, `title:`, `message:`).
/// 2. **Classification gate.** EVERY literal in `lib/` carrying translatable
///    words must fall into one of the named [stringLiteralAllowlist]
///    categories — the same categories the phase audit classified by hand.
///    A literal nothing can classify is a hardcoded string, wherever it sits.
///
/// **What "translatable words" means, and why the rule is this and not
/// `Text\('`.** A literal is translatable when, after its `$interpolations`
/// are removed, two or more letters remain. `Text('${l10n.substancesCount(x)} · ')`
/// therefore does NOT trip: every word in it came from an ARB key and only a
/// separator is literal. `Text('Cycles')` does. This is a SHARPER rule than
/// "a literal appears here", not a looser one — it names exactly the thing a
/// translator would have to be given. (Composing sentences out of localized
/// fragments is a separate, real i18n smell — PF-5 — but it is a word-order
/// problem, not an untranslated-text problem, and a gate that conflates the two
/// reports the wrong defect.)
///
/// **Allowlist discipline.** [stringLiteralAllowlist] is one `const` collection,
/// one entry per line, each with a rationale. When a legitimate literal is
/// flagged, add a named entry with its reason — never widen a flagging pattern.
/// The difference between those two responses is the difference between a gate
/// that holds and a gate that erodes.
///
/// **Scope, deliberately.** `lib/` only. `lib/core/l10n/gen/` is generated
/// output and is excluded from the glob entirely. `test/` is excluded because
/// test files legitimately assert against literal expected strings — that is
/// what a test IS. Drift's `*.g.dart` output stays inside the glob and is
/// handled by a named allowlist entry rather than a silent exclusion, so the
/// file count stays honest.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Flagging patterns — named constants, resolved once, referenced by name at
// every use. An inlined RegExp is a pattern nobody can grep for and nobody can
// reason about as a whole.
// ---------------------------------------------------------------------------

/// A `$identifier` or `${expression}` inside a string literal.
final interpolationPattern = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*');

/// Two or more consecutive letters in ANY script — Latin and Cyrillic alike.
final translatableWordPattern = RegExp(r'\p{L}{2,}', unicode: true);

/// Named parameters whose value is rendered to, or read aloud to, a user.
const userFacingParameters = <String>[
  'label',
  'tooltip',
  'hintText',
  'labelText',
  'helperText',
  'errorText',
  'semanticsLabel',
  'title',
  'message',
];

/// A `void initState() {` declaration; the body is extracted by brace matching
/// rather than by regex, because a regex cannot balance braces.
final initStateSignaturePattern = RegExp(r'void\s+initState\s*\(\s*\)\s*\{');

/// A `late final` field declaration up to its initializer.
final lateFinalPattern = RegExp(r'late\s+final\b[^;]*;');

/// Reads that must never happen outside `build` — a value captured from any of
/// these outlives the locale change that should have invalidated it (PF-4).
final localeDependentReadPattern =
    RegExp(r'\b(l10n|DateFormat|NumberFormat|context)\b');

/// A `.toString()` call. Inside a `Text(` argument it means a raw numeral
/// reached the tree in ASCII digits with no locale grouping applied.
final toStringCallPattern = RegExp(r'\.toString\s*\(\s*\)');

/// A BARE identifier interpolation — `$name` or `${name}` — inside a string.
///
/// This is the OTHER, far more common way to write the `.toString()` defect:
/// `Text('$taken/$total')` stringifies exactly as `taken.toString()` does, and
/// the gate that only matched the `.toString()` token let it through for five
/// phases (WR-07 / TW-3).
///
/// Deliberately does NOT match `${expr.method(...)}` or `${obj.field}`: a
/// braced expression with a `.` in it has been through something — a
/// `NumberFormat`, a `DateFormat`, an ARB key — and that is the sanctioned
/// shape. Dart's simple `$name` form can only ever be a bare identifier, so
/// the first alternative needs no such carve-out.
final bareInterpolationPattern = RegExp(
  r'\$[A-Za-z_][A-Za-z0-9_]*|\$\{\s*[A-Za-z_][A-Za-z0-9_]*\s*\}',
);

/// A Dart triple-quoted string. This scanner reads single-line literals only;
/// the gate asserts none exist rather than mis-parsing one silently.
final tripleQuotePattern = RegExp("'''" r'|"""');

/// A `Text(` constructor call; the argument list is extracted by paren
/// matching, because a regex cannot balance parentheses.
final textConstructorPattern = RegExp(r'\bText\s*\(');

/// A character Dart allows inside an identifier.
final identifierCharPattern = RegExp(r'[A-Za-z0-9_$]');

// ---------------------------------------------------------------------------
// Source collection
// ---------------------------------------------------------------------------

/// Every Dart source under `lib/`, resolved by GLOB rather than by a list, so a
/// screen added by a later phase is gated the day it lands.
List<File> libSources() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('core/l10n/gen/'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// [source] with every comment line removed.
///
/// Line comments only, because this codebase writes no block comments — a fact
/// this gate asserts on its own behalf below, so the day one appears the gate
/// says so instead of silently reading commentary as code. Stripping is not
/// optional here: several files carry doc comments that quote the very copy
/// they must never hardcode, and a gate that trips on its own documentation is
/// a gate a team deletes instead of the defect.
String stripComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// One string literal found in a source file, with the context needed to
/// classify it.
class Literal {
  Literal({
    required this.path,
    required this.value,
    required this.offset,
    required this.enclosingCall,
    required this.precedingNamedArg,
  });

  /// Path of the file it was found in.
  final String path;

  /// The literal's text, without its quotes.
  final String value;

  /// Byte offset in the comment-stripped source.
  final int offset;

  /// The identifier of the call whose argument list this literal sits in
  /// directly — `DateFormat` for `DateFormat('LLLL')`, `Text` for
  /// `Text('...')`, null when the literal is not a call argument.
  final String? enclosingCall;

  /// The named parameter this literal is the value of, if any.
  final String? precedingNamedArg;

  /// True when the literal carries words a translator would have to be given.
  bool get isTranslatable => translatableWordPattern
      .hasMatch(value.replaceAll(interpolationPattern, ' '));

  /// True when the literal sits where a user will read or hear it.
  bool get isUserFacingPosition =>
      enclosingCall == 'Text' ||
      (precedingNamedArg != null &&
          userFacingParameters.contains(precedingNamedArg));

  @override
  String toString() => "$path: '$value' "
      '(in ${enclosingCall ?? 'no call'}'
      "${precedingNamedArg == null ? '' : ', arg $precedingNamedArg'})";
}

/// Every single-line string literal in [source], plus [source] with each
/// literal's CONTENT blanked out.
///
/// The masked copy is what enclosing-call detection walks backwards over: a
/// literal containing a bracket or a quote would otherwise desynchronise the
/// scan and mislabel the literal after it.
({List<({int offset, String value})> literals, String masked}) scanLiterals(
  String source,
) {
  final literals = <({int offset, String value})>[];
  final masked = List<String>.from(source.split(''));
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch != "'" && ch != '"') {
      i++;
      continue;
    }
    final raw = i > 0 && source[i - 1] == 'r';
    final quote = ch;
    final start = i;
    final buffer = StringBuffer();
    var closed = false;
    i++;
    while (i < source.length) {
      final c = source[i];
      if (c == '\n') break;
      if (!raw && c == '\\') {
        buffer.write(c);
        i += 2;
        continue;
      }
      if (c == quote) {
        closed = true;
        i++;
        break;
      }
      buffer.write(c);
      i++;
    }
    if (closed) {
      literals.add((offset: start, value: buffer.toString()));
      for (var k = start + 1; k < i - 1; k++) {
        masked[k] = ' ';
      }
    }
  }
  return (literals: literals, masked: masked.join());
}

bool _isIdentifierChar(String c) => identifierCharPattern.hasMatch(c);

/// The identifier of the call whose argument list contains [offset], or null.
String? enclosingCall(String masked, int offset) {
  var depth = 0;
  var i = offset - 1;
  while (i >= 0) {
    final c = masked[i];
    if (c == ')' || c == ']' || c == '}') {
      depth++;
    } else if (c == '(') {
      if (depth == 0) {
        var j = i - 1;
        while (j >= 0 && (masked[j] == ' ' || masked[j] == '\n')) {
          j--;
        }
        if (j >= 0 && masked[j] == '>') {
          var generics = 0;
          while (j >= 0) {
            if (masked[j] == '>') generics++;
            if (masked[j] == '<') {
              generics--;
              if (generics == 0) {
                j--;
                break;
              }
            }
            j--;
          }
        }
        final end = j + 1;
        while (j >= 0 && _isIdentifierChar(masked[j])) {
          j--;
        }
        final name = masked.substring(j + 1, end);
        return name.isEmpty ? null : name;
      }
      depth--;
    } else if (c == '[' || c == '{') {
      if (depth == 0) return null;
      depth--;
    } else if (c == ';' && depth == 0) {
      return null;
    }
    i--;
  }
  return null;
}

/// The named parameter [offset] is the value of, if the literal is one.
String? precedingNamedArg(String masked, int offset) {
  var j = offset - 1;
  while (j >= 0 && (masked[j] == ' ' || masked[j] == '\n')) {
    j--;
  }
  if (j < 0 || masked[j] != ':') return null;
  j--;
  final end = j + 1;
  while (j >= 0 && _isIdentifierChar(masked[j])) {
    j--;
  }
  final name = masked.substring(j + 1, end);
  return name.isEmpty ? null : name;
}

/// Every literal in every globbed source, with its context resolved.
List<Literal> allLiterals(Map<String, String> sources) {
  final result = <Literal>[];
  sources.forEach((path, source) {
    final scan = scanLiterals(source);
    for (final literal in scan.literals) {
      result.add(Literal(
        path: path,
        value: literal.value,
        offset: literal.offset,
        enclosingCall: enclosingCall(scan.masked, literal.offset),
        precedingNamedArg: precedingNamedArg(scan.masked, literal.offset),
      ));
    }
  });
  return result;
}

// ---------------------------------------------------------------------------
// The allowlist — ONE const collection, one entry per line, one rationale each.
//
// Every entry names a category the phase audit (05-RESEARCH A-2) classified by
// hand. Adding an entry is a visible decision in a diff; widening a flagging
// pattern above is not, which is why the second is forbidden.
// ---------------------------------------------------------------------------

bool _isGeneratedDriftOutput(Literal l) => l.path.endsWith('.g.dart');

bool _isImportPath(Literal l) =>
    l.value.startsWith('dart:') ||
    l.value.startsWith('package:') ||
    l.value.endsWith('.dart');

bool _isDateFormatPattern(Literal l) => l.enclosingCall == 'DateFormat';

bool _isWidgetKey(Literal l) =>
    l.enclosingCall == 'ValueKey' || l.enclosingCall == 'Key';

bool _isBundledFontFamily(Literal l) =>
    l.value == 'Instrument Sans' || l.value == 'JetBrains Mono';

bool _isDiagnosticMessage(Literal l) => const {
      'assert',
      'StateError',
      'ArgumentError',
      'UnimplementedError',
      'UnsupportedError',
      'Exception',
      'FormatException',
      // The two crash-report constructors: a failure that is reported to the
      // logger INSTEAD of being surfaced still has to say what it was.
      'FlutterErrorDetails',
      'ErrorDescription',
    }.contains(l.enclosingCall);

bool _isStableDomainId(Literal l) => const {
      'CatalogEntry',
      '_LegendEntry',
      'Regimen',
      'driftDatabase',
    }.contains(l.enclosingCall);

bool _isPreferencesKey(Literal l) => l.value == 'app_locale';

bool _isLocaleTag(Literal l) => l.enclosingCall == 'Locale';

bool _isCasingLanguageSubtag(Literal l) =>
    l.path.endsWith('core/l10n/casing.dart');

/// The three platform identifiers the notification layer must spell literally.
///
/// Scoped by VALUE **and** by path, in that order of importance. A path-only
/// predicate is forbidden here: [allowlistEntryFor] returns the FIRST matching
/// entry, so `l.path.startsWith('lib/core/notifications/')` alone would
/// permanently bless every string literal anywhere in the notification layer, in
/// this phase and every future one — and it would silently shadow the
/// preferences-key entry for any key that comes to live under that path. The
/// value set is what keeps the exemption the size of its own reason.
bool _isNotificationPlatformIdentifier(Literal l) =>
    l.path.startsWith('lib/core/notifications/') &&
    const {'doses_v1', 'today', '@mipmap/ic_launcher'}.contains(l.value);

/// Literal categories that are NOT user-visible copy, each with the reason it
/// is not. Extend HERE, never by loosening a pattern.
const stringLiteralAllowlist = <({
  String name,
  String why,
  bool Function(Literal) allows,
})>[
  (
    name: 'generated Drift output (*.g.dart)',
    why: 'SQL column, table and alias names plus toString() buffers, written '
        'by drift_dev from the table definitions and regenerated on every '
        'build — no human edits the file and nothing in it reaches the tree',
    allows: _isGeneratedDriftOutput,
  ),
  (
    name: 'import / export / part paths',
    why: 'library URIs are Dart syntax, not copy; translating one would break '
        'the build rather than the translation',
    allows: _isImportPath,
  ),
  (
    name: 'DateFormat skeleton patterns',
    why: "'EEEE, d MMMM' names FIELDS, not words: intl renders it in whatever "
        'locale is passed alongside it, which is exactly how dates stay '
        'locale-formatted (L10N-04)',
    allows: _isDateFormatPattern,
  ),
  (
    name: 'ValueKey / Key identity strings',
    why: 'a widget identity handle read by the framework and by tests, never '
        'painted; localizing one would make every keyed finder locale-dependent',
    allows: _isWidgetKey,
  ),
  (
    name: 'the two bundled font family names',
    why: "'Instrument Sans' / 'JetBrains Mono' are pubspec asset family names "
        'that must match the declaration byte for byte (UI-SPEC LOCKED-FONT)',
    allows: _isBundledFontFamily,
  ),
  (
    name: 'assertion, thrown-error and crash-report messages',
    why: 'developer-facing diagnostics that must never reach the tree — the '
        'error surfaces render documented ARB copy plus retry, never exception '
        'text (T-02-08, T-03-16). FlutterErrorDetails/ErrorDescription carry '
        'the same kind of text to the crash logger for the two failures the '
        'app absorbs rather than shows (a prefs store that will not open, a '
        'language write that is rejected — CR-02, DECIDED-8)',
    allows: _isDiagnosticMessage,
  ),
  (
    name: 'stable domain identifiers',
    why: 'catalog ids, legend slugs and the database file name are opaque '
        'keys; the user-visible name for each comes from its own ARB key, '
        'which is why renaming a supplement in Ukrainian cannot orphan a row',
    allows: _isStableDomainId,
  ),
  (
    name: 'the single SharedPreferences key',
    why: "'app_locale' is a storage key (D-10); translating it would lose "
        "every user's saved language on the next launch",
    allows: _isPreferencesKey,
  ),
  (
    name: "language tags inside Locale('xx')",
    why: 'a BCP-47 subtag names a language, it is not a word in one. The only '
        "site is the catalog's English-name index for cross-locale search "
        '(P-2), which points at the DECLARED fallback language rather than at '
        'a shipped language list — adding an ARB file requires no edit there, '
        'so it is not the per-language code path criterion 4 forbids',
    allows: _isLocaleTag,
  ),
  (
    name: 'the dotted-i language subtags in core/l10n/casing.dart',
    why: "'tr' / 'az' name the ONE language pair whose uppercase mapping Dart's "
        'locale-independent toUpperCase() gets wrong (i -> İ, ı -> I). They '
        'are a Unicode casing rule, not copy, and they live in the single '
        'function every uppercased label in the app goes through — scoped to '
        'that one file so the entry cannot bless a language code anywhere '
        'else (WR-03)',
    allows: _isCasingLanguageSubtag,
  ),
  (
    name: 'notification platform identifiers (channel id, tap payload, small icon)',
    why: 'THREE values, each a platform key the operating system holds rather '
        "than a word: 'doses_v1' is the Android channel id, persisted exactly "
        "like 'app_locale' — translating it would orphan the channel settings "
        "the user made and silently create a second channel in Android's own "
        "list; 'today' is the tap payload, a cross-process routing token the OS "
        'persists and can replay after an app update, validated by equality and '
        "never rendered, so localizing it would make the whitelist "
        "locale-dependent; '@mipmap/ic_launcher' is a drawable RESOURCE PATH "
        'that must match the launcher-icon resources under '
        'android/app/src/main/res/mipmap-* byte for byte, the same category as '
        'the bundled-font-family entry above. Scoped by VALUE and by path: a '
        'path-only predicate would bless every literal in the notification '
        'layer forever, which is the failure mode this file exists to prevent '
        '(07-UI-SPEC condition 27, corrected from two literals to three — the '
        'small-icon name is translatable under the word pattern and matches no '
        'other predicate)',
    allows: _isNotificationPlatformIdentifier,
  ),
];

/// The allowlist entry that covers [literal], or null when nothing does.
({String name, String why, bool Function(Literal) allows})? allowlistEntryFor(
  Literal literal,
) {
  for (final entry in stringLiteralAllowlist) {
    if (entry.allows(literal)) return entry;
  }
  return null;
}

/// The balanced `{...}` body starting at [openBrace].
String balancedBody(String source, int openBrace) {
  var depth = 0;
  for (var i = openBrace; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(openBrace, i + 1);
    }
  }
  return source.substring(openBrace);
}

/// The POSITIONAL arguments of the balanced `(...)` text [args].
///
/// Only these become the string a user reads. `key:`, `style:`, `semanticsLabel:`
/// and friends are NAMED, and at least one of them legitimately interpolates an
/// identifier — `key: ValueKey<String>('month-$index-label')` is a widget key,
/// not copy. Splitting on named-ness keeps the numeral gate below sharp instead
/// of forcing an allowlist entry per keyed widget.
///
/// Top-level commas are located in a copy with every string literal's CONTENT
/// blanked (the same masking `scanLiterals` already does), so a comma inside a
/// literal cannot split an argument; the slices are then taken from the RAW
/// text so the literal content is still there to inspect.
List<String> positionalArgs(String args) {
  if (args.length < 2) return const [];
  final inner = args.substring(1, args.length - 1);
  final masked = scanLiterals(inner).masked;

  final cuts = <int>[];
  var depth = 0;
  for (var i = 0; i < masked.length; i++) {
    final c = masked[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ',' && depth == 0) cuts.add(i);
  }

  final segments = <String>[];
  var start = 0;
  for (final cut in [...cuts, inner.length]) {
    segments.add(inner.substring(start, cut));
    start = cut + 1;
  }
  return [
    for (final segment in segments)
      if (!namedArgumentPattern.hasMatch(segment)) segment,
  ];
}

/// An argument that opens with `name:` — a named parameter.
final namedArgumentPattern = RegExp(r'^\s*[A-Za-z_][A-Za-z0-9_]*\s*:');

/// The balanced `(...)` argument text starting at [openParen].
String balancedArgs(String source, int openParen) {
  var depth = 0;
  for (var i = openParen; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return source.substring(openParen, i + 1);
    }
  }
  return source.substring(openParen);
}

void main() {
  late Map<String, String> sources;
  late List<Literal> literals;

  setUpAll(() {
    sources = {
      for (final file in libSources())
        file.path: stripComments(file.readAsStringSync()),
    };
    literals = allLiterals(sources);
  });

  // -------------------------------------------------------------------
  // The glob proof runs FIRST. Every gate below iterates over `sources`
  // or over literals derived from it; over an empty set they all pass.
  // -------------------------------------------------------------------

  test(
      'the lib/ glob actually resolves the source files — a gate over an empty '
      'file set is worse than no gate (L10N-04)', () {
    expect(sources, isNotEmpty);
    expect(
      sources.length,
      greaterThanOrEqualTo(20),
      reason: 'the app ships well over twenty source files under lib/; a '
          'smaller set means the glob stopped matching (a moved directory, a '
          'widened exclusion) and this file is reporting "no hardcoded '
          'strings" about source it never read',
    );
    expect(
      sources.keys.any((p) => p.contains('features/')),
      isTrue,
      reason: 'the screens are where user-visible copy lives; a glob that '
          'misses lib/features/ gates nothing that matters',
    );
    expect(
      sources.keys.any((p) => p.contains('core/l10n/gen/')),
      isFalse,
      reason: 'generated localizations are the OUTPUT of the ARB files and are '
          'full of English literals by construction',
    );
  });

  test(
      'no source carries a block comment or a triple-quoted string, so the '
      'line-comment strip and the single-line literal scan are complete', () {
    sources.forEach((path, source) {
      expect(source.contains('/*'), isFalse,
          reason: '$path opened a block comment; stripComments only removes '
              'line comments, so commentary would be read as code');
      expect(tripleQuotePattern.hasMatch(source), isFalse,
          reason: '$path uses a triple-quoted string; the literal scanner '
              'reads single-line literals only and would mis-parse it');
    });
  });

  // -------------------------------------------------------------------
  // Gate 1 — the widget positions (V-2, L10N-04).
  // -------------------------------------------------------------------

  test(
      'no translatable literal reaches a Text() or a user-facing named '
      'parameter (L10N-04, V-2)', () {
    final violations = literals
        .where((l) => l.isUserFacingPosition && l.isTranslatable)
        .where((l) => allowlistEntryFor(l) == null)
        .toList();

    expect(
      violations,
      isEmpty,
      reason: 'each of these paints a word that no ARB file contains, so it '
          'stays English (or stays Ukrainian) in every other language and no '
          'translator is ever shown it. The fix is an ARB key, never a wider '
          'pattern in this test:\n${violations.join('\n')}',
    );
  });

  // -------------------------------------------------------------------
  // Gate 2 — everything else in lib/ is classified, or it is a violation.
  // -------------------------------------------------------------------

  test(
      'every translatable literal in lib/ falls into a NAMED allowlist '
      'category (L10N-04, A-2)', () {
    final unclassified = literals
        .where((l) => l.isTranslatable)
        .where((l) => allowlistEntryFor(l) == null)
        .toList();

    expect(
      unclassified,
      isEmpty,
      reason: 'a literal carrying words that no category explains is a '
          'hardcoded string wherever it sits — today it is out of sight, '
          'tomorrow someone renders it. Either route it through an ARB key or '
          'add an allowlist entry naming what kind of string it is and why it '
          'is not copy:\n${unclassified.join('\n')}',
    );
  });

  test('every allowlist entry still classifies something in the tree', () {
    for (final entry in stringLiteralAllowlist) {
      expect(
        literals.where((l) => l.isTranslatable).any(entry.allows),
        isTrue,
        reason: 'the "${entry.name}" entry matches nothing any more. A dead '
            'allowlist entry is a standing permission nobody is using and '
            'nobody re-examines; delete it, and the gate gets stricter for '
            'free',
      );
    }
  });

  // -------------------------------------------------------------------
  // Gate 3 — the PF-4 companion: nothing locale-dependent may be cached
  // outside build().
  // -------------------------------------------------------------------

  test(
      'no initState body reads l10n, a formatter or context — a cached string '
      'outlives the locale change (PF-4, L10N-03)', () {
    sources.forEach((path, source) {
      if (!path.contains('features/')) return;
      for (final match in initStateSignaturePattern.allMatches(source)) {
        final body = balancedBody(source, match.end - 1);
        final read = localeDependentReadPattern.firstMatch(body);
        expect(
          read,
          isNull,
          reason: '$path caches "${read?.group(0)}" in initState. initState '
              'runs once; a locale change rebuilds the widget but does NOT '
              're-run it, so the screen keeps rendering the previous '
              "language's string while every neighbour switches — the classic "
              'i18n pitfall. Read context.l10n and construct formatters '
              'INSIDE build',
        );
      }
    });
  });

  test(
      'no late final field is initialised from l10n, a formatter or context '
      '(PF-4)', () {
    sources.forEach((path, source) {
      if (!path.contains('features/')) return;
      for (final match in lateFinalPattern.allMatches(source)) {
        final declaration = match.group(0)!;
        final read = localeDependentReadPattern.firstMatch(declaration);
        expect(
          read,
          isNull,
          reason: '$path initialises a late final field from '
              '"${read?.group(0)}": it is computed once on first access and '
              'then frozen for the life of the widget, which is the same '
              'stale-language defect as the initState case with a longer fuse',
        );
      }
    });
  });

  // -------------------------------------------------------------------
  // Gate 4 — numerals reach the tree formatted, not stringified
  // (criterion 4's "numbers are locale-formatted" clause).
  // -------------------------------------------------------------------

  test(
      'no Text() argument stringifies a value — neither .toString() nor a '
      'bare interpolation (L10N-04, WR-07)', () {
    sources.forEach((path, source) {
      if (!path.contains('features/')) return;
      for (final match in textConstructorPattern.allMatches(source)) {
        final args = balancedArgs(source, match.end - 1);
        for (final arg in positionalArgs(args)) {
          expect(
            toStringCallPattern.hasMatch(arg),
            isFalse,
            reason: '$path renders a .toString() inside a Text(). A '
                'stringified number is ASCII digits with no locale grouping '
                'and no plural agreement around it; the count must go through '
                'its own ARB plural key, a NumberFormat, or BqText.mono for a '
                'tabular figure. (A locale TAG is not a numeral — the codebase '
                'already hoists Localizations.localeOf(context).toString() '
                'into a local above the widget at every one of its call sites, '
                'and it should stay hoisted.)',
          );
          final bare = bareInterpolationPattern.firstMatch(arg);
          expect(
            bare,
            isNull,
            reason: '$path interpolates "${bare?.group(0)}" straight into a '
                'Text(). That is the SAME defect as .toString() written the '
                'way people actually write it, which is why the gate that '
                'matched only the .toString() token missed a live violation '
                'for five phases (WR-07/TW-3). Route the value through a '
                'NumberFormat, a DateFormat or an ARB key — '
                '"\${format.format(x)}" is what this gate is asking for, and '
                'is deliberately not matched.',
          );
        }
      }
    });
  });
}
