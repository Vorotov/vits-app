/// Bundled locale-aware supplement catalog + cross-locale search
/// (plan 02-05, STACK-01, RESEARCH P-1/P-2).
///
/// The catalog lives in two coordinated pieces (P-1):
/// 1. ARB keys (`catalog{Id}Name` / `catalog{Id}Dose`) in BOTH locale files —
///    translator-owned, compile-time checked by gen-l10n ("a new language =
///    one new .arb file, no code changes").
/// 2. This descriptor list — id, color, and function references resolving the
///    gen-l10n getters per active locale.
///
/// Copy-on-add semantics (P-1): selecting an entry copies the CURRENT
/// locale's name/doseText into the `Supplement` row. From that moment it is
/// user data — switching the app language later must NOT rename supplements
/// already in the stack (Phase 5: this is intended behavior, not a bug).
///
/// Content rules (PF-5/D4): names verbatim from the mockup (incl. the
/// "Зверобій" spelling — A4, user copy call at UAT); every mockup
/// `note`/`score`/`schedule` field is STRIPPED — no interaction or medical
/// claims anywhere. Colors are `BqSeriesColors.palette` tokens only (D-07):
/// the 7 BASE_STACK names use their mockup PLAN palette indices; the 8
/// CATALOG names are assigned round-robin over the palette.
library;

import 'dart:ui';

import 'package:boostque/core/l10n/gen/app_localizations.dart';
import 'package:boostque/core/theme/tokens.dart';

/// One bundled catalog entry: stable id, palette color token, and
/// locale-resolving name/doseText functions (RESEARCH P-1).
class CatalogEntry {
  /// Stable identifier (also the ARB key stem, e.g. `creatine` →
  /// `catalogCreatineName`).
  final String id;

  /// Supplement tag color — always a `BqSeriesColors.palette` token (D-07).
  final Color color;

  /// Resolves the localized display name from the given [AppLocalizations].
  final String Function(AppLocalizations) name;

  /// Resolves the localized neutral form/dose text.
  final String Function(AppLocalizations) doseText;

  const CatalogEntry({
    required this.id,
    required this.color,
    required this.name,
    required this.doseText,
  });
}

/// The v1 catalog: the union of the mockup's CATALOG (8) and BASE_STACK (7)
/// lists — exactly 15 entries, declaration order = display order for an
/// empty query (UI-SPEC #8).
///
/// CATALOG 8 first (round-robin palette indices 0..7), then BASE_STACK 7
/// with their mockup PLAN colors (palette indices: D3 0, Омега-3 1,
/// Хондропротектор 2, Магній 3, Зверобій 4, Цинк 5, Куркумін 6).
final List<CatalogEntry> kCatalogEntries = List.unmodifiable(<CatalogEntry>[
  // --- CATALOG 8 (mockup lines 596-604; notes/scores stripped, PF-5) ---
  CatalogEntry(
    id: 'ashwagandha',
    color: BqSeriesColors.palette[0],
    name: (l) => l.catalogAshwagandhaName,
    doseText: (l) => l.catalogAshwagandhaDose,
  ),
  CatalogEntry(
    id: 'creatine',
    color: BqSeriesColors.palette[1],
    name: (l) => l.catalogCreatineName,
    doseText: (l) => l.catalogCreatineDose,
  ),
  CatalogEntry(
    id: 'melatonin',
    color: BqSeriesColors.palette[2],
    name: (l) => l.catalogMelatoninName,
    doseText: (l) => l.catalogMelatoninDose,
  ),
  CatalogEntry(
    id: 'nmn',
    color: BqSeriesColors.palette[3],
    name: (l) => l.catalogNmnName,
    doseText: (l) => l.catalogNmnDose,
  ),
  CatalogEntry(
    id: 'b12',
    color: BqSeriesColors.palette[4],
    name: (l) => l.catalogB12Name,
    doseText: (l) => l.catalogB12Dose,
  ),
  CatalogEntry(
    id: 'q10',
    color: BqSeriesColors.palette[5],
    name: (l) => l.catalogQ10Name,
    doseText: (l) => l.catalogQ10Dose,
  ),
  CatalogEntry(
    id: 'iodine',
    color: BqSeriesColors.palette[6],
    name: (l) => l.catalogIodineName,
    doseText: (l) => l.catalogIodineDose,
  ),
  CatalogEntry(
    id: 'iron',
    color: BqSeriesColors.palette[7],
    name: (l) => l.catalogIronName,
    doseText: (l) => l.catalogIronDose,
  ),
  // --- BASE_STACK 7 (mockup lines 587-595; PLAN colors, lines 630-638) ---
  CatalogEntry(
    id: 'hypericum',
    color: BqSeriesColors.palette[4],
    name: (l) => l.catalogHypericumName,
    doseText: (l) => l.catalogHypericumDose,
  ),
  CatalogEntry(
    id: 'magnesium',
    color: BqSeriesColors.palette[3],
    name: (l) => l.catalogMagnesiumName,
    doseText: (l) => l.catalogMagnesiumDose,
  ),
  CatalogEntry(
    id: 'chondro',
    color: BqSeriesColors.palette[2],
    name: (l) => l.catalogChondroName,
    doseText: (l) => l.catalogChondroDose,
  ),
  CatalogEntry(
    id: 'd3',
    color: BqSeriesColors.palette[0],
    name: (l) => l.catalogD3Name,
    doseText: (l) => l.catalogD3Dose,
  ),
  CatalogEntry(
    id: 'omega3',
    color: BqSeriesColors.palette[1],
    name: (l) => l.catalogOmega3Name,
    doseText: (l) => l.catalogOmega3Dose,
  ),
  CatalogEntry(
    id: 'zinc',
    color: BqSeriesColors.palette[5],
    name: (l) => l.catalogZincName,
    doseText: (l) => l.catalogZincDose,
  ),
  CatalogEntry(
    id: 'curcumin',
    color: BqSeriesColors.palette[6],
    name: (l) => l.catalogCurcuminName,
    doseText: (l) => l.catalogCurcuminDose,
  ),
]);

/// English names resolved once for cross-locale matching (P-2): the
/// generated `lookupAppLocalizations` is synchronous, so a uk-locale user
/// typing latin ("creatine", "b12") still finds entries.
final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

/// Case-insensitive substring search over the [active] locale's names AND
/// the en names (P-2). Empty/whitespace query returns the full catalog in
/// declaration order (mockup line 707 uses `contains`, not prefix).
///
/// No diacritic-stripping layer: uk Cyrillic ї/й/є/і are distinct letters,
/// not accents — `toLowerCase()`'s Unicode default mappings suffice
/// (Don't Hand-Roll).
List<CatalogEntry> searchCatalog(String query, AppLocalizations active) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kCatalogEntries;
  return [
    for (final e in kCatalogEntries)
      if (e.name(active).toLowerCase().contains(q) ||
          e.name(_en).toLowerCase().contains(q))
        e,
  ];
}
