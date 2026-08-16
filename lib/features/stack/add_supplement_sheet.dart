/// Add-supplement bottom sheet — full S2 contract (plan 02-05; tracer manual
/// form was plan 02-01).
///
/// Two `BqSegmented` tabs below the header:
/// - Пошук у базі: catalog search input + result rows filtered live through
///   `searchCatalog` (synchronous in-memory const list — no loading/error UI
///   exists for it by construction, UI-SPEC #17). Empty query lists the full
///   15-entry catalog (#8); no matches renders `noResultsCatalog` — the
///   rewritten copy with no scanning promise (#9/D3).
/// - Вручну: the manual entry form (name required after trim — V-1). The
///   manual tab REPLACES the mockup's camera tab (D1); no camera/scanning
///   code path exists here.
///
/// Both add paths create the supplement through [SupplementRepository], pop
/// the sheet, and push [RegimenEditorScreen] for the new id (STACK-01/02).
///
/// Copy-on-add (P-1, note for Phase 5's l10n verification): picking a catalog
/// entry copies the CURRENT locale's name/doseText into the Supplement row.
/// From that moment it is user data — switching the app language later must
/// NOT rename supplements already in the stack. This is intended behavior,
/// not a missed localization.
///
/// UUIDs are minted at the save boundary only, never in `build()` (locked
/// project rule); keyboard inset handling per PF-6 covers both tabs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:boostque/core/widgets/bq_segmented.dart';
import 'package:boostque/features/stack/catalog.dart';
import 'package:boostque/features/stack/regimen_editor_screen.dart';

/// Opens the modal add-supplement sheet above [context]'s navigator.
Future<void> showAddSupplementSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BqColors.paper,
    builder: (_) => const _AddSupplementSheet(),
  );
}

class _AddSupplementSheet extends ConsumerStatefulWidget {
  const _AddSupplementSheet();

  @override
  ConsumerState<_AddSupplementSheet> createState() =>
      _AddSupplementSheetState();
}

class _AddSupplementSheetState extends ConsumerState<_AddSupplementSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();

  /// 0 = catalog search, 1 = manual entry.
  int _tabIndex = 0;

  /// In-flight guard (WR-01): both add paths short-circuit re-entry so a
  /// double tap (same catalog row, two rows, or the manual save button) can
  /// never mint two supplement UUIDs or run [_popThenPushEditor] twice —
  /// the second run would pop the freshly pushed EDITOR, not the sheet.
  /// Never reset on the success path: the sheet is popped and disposed.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the result list / save button on every keystroke.
    _searchController.addListener(_onTextChanged);
    _nameController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  bool get _canSaveManual => _nameController.text.trim().isNotEmpty;

  /// Shared exit for both add paths: close the sheet, then open the regimen
  /// editor for the freshly created supplement (S2 "On pick/save").
  void _popThenPushEditor(NavigatorState navigator, String supplementId) {
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RegimenEditorScreen(supplementId: supplementId),
      ),
    );
  }

  /// Catalog pick (STACK-01): copy-on-add — the ACTIVE locale's name and
  /// doseText are snapshotted into the row as user data (P-1; Phase 5 must
  /// not read later locale switches not renaming this as a bug).
  Future<void> _addFromCatalog(CatalogEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final supplement = Supplement(
      id: const Uuid().v4(),
      name: entry.name(l10n),
      doseText: entry.doseText(l10n),
      colorValue: entry.color.toARGB32(),
      note: '',
    );
    try {
      await ref.read(supplementRepoProvider).upsert(supplement);
    } catch (_) {
      _showSaveFailed();
      return;
    }
    if (!mounted) return;
    _popThenPushEditor(navigator, supplement.id);
  }

  /// Manual save (STACK-02): round-robin series color from the current stack
  /// size (UI-SPEC: palette[stackCount % 8]); loading/error fall back to 0.
  Future<void> _saveManual() async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final entries = ref.read(stackEntriesProvider);
    var count = 0;
    if (entries case AsyncData(value: final data)) {
      count = data.length;
    }
    final supplement = Supplement(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      doseText: _doseController.text.trim(),
      colorValue: BqSeriesColors
          .palette[count % BqSeriesColors.palette.length]
          .toARGB32(),
      note: '',
    );
    try {
      await ref.read(supplementRepoProvider).upsert(supplement);
    } catch (_) {
      _showSaveFailed();
      return;
    }
    if (!mounted) return;
    _popThenPushEditor(navigator, supplement.id);
  }

  /// WR-04: a failed write keeps the sheet open (nothing was persisted),
  /// re-enables both add paths, and surfaces a SnackBar.
  void _showSaveFailed() {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.saveFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      // Keyboard inset: the sheet body lifts above the keyboard so the
      // focused field is never covered on either tab (PF-6).
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          // Sheet padding 10 top / 20 horizontal / 26 bottom (UI-SPEC S2).
          padding: const EdgeInsetsDirectional.only(
            start: 20,
            end: 20,
            top: 10,
            bottom: 26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BqColors.dragHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: BqSpace.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.addSupplement,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: BqColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.close,
                      style: const TextStyle(
                        fontSize: 13,
                        color: BqColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BqSpace.md),
              // Tabs switch content in place — no page transition (S2; the
              // manual tab replaces the mockup camera tab, D1).
              BqSegmented(
                labels: [l10n.searchTab, l10n.manualTab],
                selectedIndex: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
              const SizedBox(height: BqSpace.md),
              if (_tabIndex == 0)
                _SearchTab(
                  controller: _searchController,
                  onPick: _addFromCatalog,
                )
              else
                _ManualTab(
                  nameController: _nameController,
                  doseController: _doseController,
                  // Disabled while an add is in flight (WR-01).
                  canSave: _canSaveManual && !_busy,
                  onSave: _saveManual,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Catalog search tab: themed input + live-filtered result rows (S2).
class _SearchTab extends StatelessWidget {
  const _SearchTab({required this.controller, required this.onPick});

  final TextEditingController controller;
  final ValueChanged<CatalogEntry> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Synchronous search over the const catalog — no loading, no error
    // state exists by construction (UI-SPEC #17).
    final results = searchCatalog(controller.text, l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: l10n.searchCatalogHint),
        ),
        const SizedBox(height: BqSpace.md),
        if (results.isEmpty)
          // Rewritten no-results copy — no scanning promise (#9/D3).
          Text(
            l10n.noResultsCatalog,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: BqColors.textMuted,
            ),
          )
        else
          for (final (i, entry) in results.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            _CatalogResultRow(entry: entry, onPick: onPick),
          ],
      ],
    );
  }
}

/// One catalog result row: wrapping name + dose, trailing accent "+" that
/// never wraps away (#10). The whole row is the tap target.
class _CatalogResultRow extends StatelessWidget {
  const _CatalogResultRow({required this.entry, required this.onPick});

  final CatalogEntry entry;
  final ValueChanged<CatalogEntry> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onPick(entry),
      child: Container(
        // Mockup-exact result-row padding 13/14 (UI-SPEC spacing override).
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 13,
          horizontal: 14,
        ),
        decoration: BoxDecoration(
          color: BqColors.surface,
          border: Border.all(color: BqColors.cardBorder),
          borderRadius: BorderRadius.circular(BqRadii.button),
        ),
        child: Row(
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Long names (Вітамін B12 метилкобаламін) wrap within the
                  // row — no fixed width, no ellipsis (#10).
                  Text(
                    entry.name(l10n),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: BqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.doseText(l10n),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: BqColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // The trailing "+" keeps intrinsic size — it never wraps away
            // (#10); icon-only affordance carries a Semantics label (S2).
            Semantics(
              // The whole sentence — separator included — lives in the ARB
              // (PF-5). Concatenating two localized fragments in Dart
              // hardcodes word order and punctuation across every language,
              // which the "one new ARB file" contract cannot survive; both
              // parts are passed in finished, the weekLoadLabel idiom.
              label: l10n.addSupplementCatalogSemantics(
                l10n.addSupplement,
                entry.name(l10n),
              ),
              button: true,
              excludeSemantics: true,
              child: const Text(
                '+',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  color: BqColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Manual entry tab: name (required, V-1) + dose form, save disabled until
/// the trimmed name is non-empty — the disabled state IS the validation
/// surface (#11).
class _ManualTab extends StatelessWidget {
  const _ManualTab({
    required this.nameController,
    required this.doseController,
    required this.canSave,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController doseController;
  final bool canSave;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l10n.nameLabel),
        ),
        const SizedBox(height: BqSpace.md),
        TextField(
          controller: doseController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l10n.doseLabel),
        ),
        const SizedBox(height: BqSpace.lg),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BqColors.accent,
            foregroundColor: BqColors.surface,
            overlayColor: BqColors.accentPressed,
            padding: const EdgeInsetsDirectional.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BqRadii.button),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: canSave ? onSave : null,
          child: Text(l10n.addManualSupplement),
        ),
      ],
    );
  }
}
