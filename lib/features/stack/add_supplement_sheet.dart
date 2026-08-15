/// Add-supplement bottom sheet (plan 02-01 tracer slice: manual form only).
///
/// The catalog-search tab and `BqSegmented` arrive in a later Phase-2 plan;
/// this file owns the sheet chrome (drag handle, header, keyboard inset —
/// PF-6) and the manual entry form. Save is disabled while the trimmed name
/// is empty — the disabled state IS the whole validation surface (V-1).
///
/// UUIDs are minted at the save boundary only, never in `build()` (locked
/// project rule); persistence goes through [SupplementRepository] via
/// `supplementRepoProvider` — no Drift types appear here (D-22).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:boostque/core/domain/models.dart';
import 'package:boostque/core/l10n/l10n.dart';
import 'package:boostque/core/providers.dart';
import 'package:boostque/core/theme/tokens.dart';

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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Re-evaluate the save button's enabled state on every keystroke (V-1).
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  Future<void> _save() async {
    // Round-robin series color from the current stack size (UI-SPEC:
    // palette[stackCount % 8]); loading/error fall back to index 0.
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
    await ref.read(supplementRepoProvider).upsert(supplement);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      // Keyboard inset: the sheet body lifts above the keyboard so the
      // focused field is never covered (PF-6).
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
                    // BqColors.field stands in for the dragHandle token,
                    // which lands with the full token additions in a later
                    // Phase-2 plan.
                    color: BqColors.field,
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
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.nameLabel),
              ),
              const SizedBox(height: BqSpace.md),
              TextField(
                controller: _doseController,
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
                onPressed: _canSave ? _save : null,
                child: Text(l10n.addManualSupplement),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
