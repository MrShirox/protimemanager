import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../providers/constantes_provider.dart';
import '../../models/constante.dart';
import '../../theme/app_theme.dart';

class ConstantesScreen extends StatelessWidget {
  const ConstantesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConstantesProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Constantes',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () => showConstanteDialog(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('NOUVELLE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.constantes.isEmpty
                  ? const Center(child: Text('Aucune fiche constante'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: provider.constantes.length,
                      itemBuilder: (context, i) {
                        final c = provider.constantes[i];
                        return _ConstanteCard(
                          constante: c,
                          onEdit: () => showConstanteDialog(context, c),
                          onDelete: () =>
                              context.read<ConstantesProvider>().delete(c.id!),
                          onShare: () => Share.share(c.toMessage()),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

void showConstanteDialog(BuildContext context, Constante? existing) {
  showDialog(
    context: context,
    builder: (ctx) => _ConstanteForm(existing: existing),
  );
}

class _ConstanteForm extends StatefulWidget {
  final Constante? existing;
  const _ConstanteForm({this.existing});

  @override
  State<_ConstanteForm> createState() => _ConstanteFormState();
}

class _ConstanteFormState extends State<_ConstanteForm> {
  late TextEditingController taGSys, taGDia, taDSys, taDDia;
  late TextEditingController pouls, temp, spo2, glyc, note;
  late TextEditingController fr, acetone, conscience, neuro;
  bool _saving = false;
  String? _error;
  late bool rythmeRegulier, bienPercu;

  final List<FocusNode> _fNodes = List.generate(9, (_) => FocusNode());

  String _get(String label) {
    if (widget.existing == null) return '';
    try {
      final value =
          widget.existing!.champs.firstWhere((c) => c.label == label).valeur;
      return switch (label) {
        'Pouls' => value.replaceAll(' bpm', ''),
        'Température' => value.replaceAll(' °C', ''),
        'SpO2' => value.replaceAll(' %', ''),
        'FR' => value.replaceAll(' /min', ''),
        'Glycémie' => value.replaceFirst(RegExp(r' mmol/L.*$'), ''),
        _ => value,
      };
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    // Bras gauche : on reparse "120/80 mmHg"
    final taG = _get('TA Bras gauche').replaceAll(' mmHg', '').split('/');
    final taD = _get('TA Bras droit').replaceAll(' mmHg', '').split('/');

    taGSys = TextEditingController(text: taG.isNotEmpty ? taG[0] : '');
    taGDia = TextEditingController(text: taG.length > 1 ? taG[1] : '');
    taDSys = TextEditingController(text: taD.isNotEmpty ? taD[0] : '');
    taDDia = TextEditingController(text: taD.length > 1 ? taD[1] : '');
    pouls =
        TextEditingController(text: _get('Pouls').isEmpty ? '' : _get('Pouls'));
    temp = TextEditingController(
        text: _get('Température').isEmpty ? '' : _get('Température'));
    spo2 =
        TextEditingController(text: _get('SpO2').isEmpty ? '' : _get('SpO2'));
    glyc = TextEditingController(text: _get('Glycémie'));
    note = TextEditingController(text: _get('Remarques'));
    fr = TextEditingController(text: _get('FR'));
    acetone = TextEditingController(text: _get('Acétone'));
    conscience = TextEditingController(text: _get('Conscience'));
    neuro = TextEditingController(text: _get('Observations neurologiques'));
    rythmeRegulier = _get('Rythme') != 'Irrégulier';
    bienPercu = _get('Perception') != 'Mal perçu';
  }

  @override
  void dispose() {
    for (final c in [
      taGSys,
      taGDia,
      taDSys,
      taDDia,
      pouls,
      temp,
      spo2,
      glyc,
      note,
      fr,
      acetone,
      conscience,
      neuro
    ]) {
      c.dispose();
    }
    for (final f in _fNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _next(int i) {
    if (i < _fNodes.length - 1) {
      FocusScope.of(context).requestFocus(_fNodes[i + 1]);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Widget _numField(TextEditingController ctrl, String hint, int idx,
      {bool decimal = false}) {
    return TextField(
      controller: ctrl,
      focusNode: _fNodes[idx],
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        decimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      textInputAction: idx < _fNodes.length - 1
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: (_) => _next(idx),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null
                  ? 'Nouvelle fiche constantes'
                  : 'Modifier la fiche',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // ── Tension ──
            _section('Cardiaque'),
            const Text('Tension artérielle'),
            const Text('Bras gauche',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _numField(taGSys, 'ex : 120', 0)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('/', style: TextStyle(fontSize: 20)),
              ),
              Expanded(child: _numField(taGDia, 'ex : 80', 1)),
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('mmHg',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 10),
            const Text('Bras droit',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _numField(taDSys, 'ex : 120', 2)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('/', style: TextStyle(fontSize: 20)),
              ),
              Expanded(child: _numField(taDDia, 'ex : 80', 3)),
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('mmHg',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ]),
            const Divider(height: 24),

            // ── Pouls ──
            _section('Pouls'),
            const Text('Fréquence (bpm)',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            _numField(pouls, 'ex : 72', 4),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Rythme régulier  (décoché = irrégulier)'),
              value: rythmeRegulier,
              activeColor: AppTheme.primaryColor,
              onChanged: (v) => setState(() => rythmeRegulier = v ?? true),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                  'Bien perçu  (décoché = mal perçu / imperceptible)'),
              value: bienPercu,
              activeColor: AppTheme.primaryColor,
              onChanged: (v) => setState(() => bienPercu = v ?? true),
            ),
            const Divider(height: 24),

            // ── SpO2 ──
            _section('Respiratoire'),
            const Text('Saturation SpO2 (%)'),
            _numField(spo2, 'ex : 98', 6),
            TextField(
                controller: fr,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'FR — fréquence respiratoire (/min)')),
            const Divider(height: 24),
            _section('Neuro'),
            TextField(
                controller: conscience,
                decoration: const InputDecoration(labelText: 'Conscience')),
            TextField(
                controller: neuro,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Observations neurologiques')),
            const Divider(height: 24),
            _section('Métabolique / autres'),
            const Text('Température (°C)'),
            _numField(temp, 'ex : 37.2', 5, decimal: true),
            TextField(
                controller: acetone,
                decoration: const InputDecoration(
                    labelText: 'Acétone',
                    hintText: 'Résultat et unité ou lecture de la bandelette')),
            const Divider(height: 24),

            // ── Glycémie ──
            _section('Glycémie'),
            TextField(
              controller: glyc,
              focusNode: _fNodes[7],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _next(7),
              decoration: const InputDecoration(
                hintText: 'ex : 5.4 mmol/L',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              ),
            ),
            const Divider(height: 24),

            // ── Remarques ──
            _section('Notes / Observations'),
            TextField(
              controller: note,
              focusNode: _fNodes[8],
              maxLines: 3,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Remarques...',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              ),
            ),
            const SizedBox(height: 24),

            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            // ── Actions ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('ANNULER'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving
                      ? 'ENREGISTREMENT…'
                      : widget.existing == null
                          ? 'CRÉER'
                          : 'ENREGISTRER'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    // Titre = heure d'enregistrement
    final titre = DateFormat('HH:mm  –  dd/MM/yyyy', 'fr_FR').format(now);

    final champs = [
      for (final c in widget.existing?.champs ?? <ConstanteChamp>[])
        if (!constanteSections.values.expand((v) => v).contains(c.label)) c,
      if (fr.text.trim().isNotEmpty)
        ConstanteChamp(label: 'FR', valeur: '${fr.text.trim()} /min'),
      if (acetone.text.trim().isNotEmpty)
        ConstanteChamp(label: 'Acétone', valeur: acetone.text.trim()),
      if (conscience.text.trim().isNotEmpty)
        ConstanteChamp(label: 'Conscience', valeur: conscience.text.trim()),
      if (neuro.text.trim().isNotEmpty)
        ConstanteChamp(
            label: 'Observations neurologiques', valeur: neuro.text.trim()),
      if (taGSys.text.isNotEmpty || taGDia.text.isNotEmpty)
        ConstanteChamp(
            label: 'TA Bras gauche',
            valeur: '${taGSys.text}/${taGDia.text} mmHg'),
      if (taDSys.text.isNotEmpty || taDDia.text.isNotEmpty)
        ConstanteChamp(
            label: 'TA Bras droit',
            valeur: '${taDSys.text}/${taDDia.text} mmHg'),
      if (pouls.text.isNotEmpty)
        ConstanteChamp(label: 'Pouls', valeur: '${pouls.text} bpm'),
      ConstanteChamp(
          label: 'Rythme', valeur: rythmeRegulier ? 'Régulier' : 'Irrégulier'),
      ConstanteChamp(
          label: 'Perception', valeur: bienPercu ? 'Bien perçu' : 'Mal perçu'),
      if (temp.text.isNotEmpty)
        ConstanteChamp(label: 'Température', valeur: '${temp.text} °C'),
      if (spo2.text.isNotEmpty)
        ConstanteChamp(label: 'SpO2', valeur: '${spo2.text} %'),
      if (glyc.text.isNotEmpty)
        ConstanteChamp(
            label: 'Glycémie',
            valeur: '${glyc.text} mmol/L — ${DateFormat('HH:mm').format(now)}'),
      if (note.text.isNotEmpty)
        ConstanteChamp(label: 'Remarques', valeur: note.text),
    ];

    final prov = context.read<ConstantesProvider>();
    try {
      if (widget.existing == null) {
        await prov.add(Constante(titre: titre, champs: champs));
      } else {
        await prov
            .update(widget.existing!.copyWith(champs: champs, updatedAt: now));
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Enregistrement impossible. Réessaie.';
        });
      }
    }
  }
}

class _ConstanteCard extends StatelessWidget {
  final Constante constante;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _ConstanteCard({
    required this.constante,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(constante.titre,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold))),
                Row(children: [
                  IconButton(
                      icon: const Icon(Icons.share, size: 20),
                      onPressed: onShare),
                  IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: onEdit),
                  IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: onDelete),
                ]),
              ],
            ),
            const Divider(height: 12),
            for (final section in {
              ...constanteSections,
              'Autres': constante.champs
                  .map((c) => c.label)
                  .where((label) => !constanteSections.values
                      .expand((v) => v)
                      .contains(label))
                  .toList()
            }.entries)
              if (constante.champs
                  .any((c) => section.value.contains(c.label))) ...[
                Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Text(section.key,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                ...constante.champs
                    .where((c) => section.value.contains(c.label))
                    .map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            SizedBox(
                              width: 130,
                              child: Text(c.label,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ),
                            Expanded(
                              child: Text(c.valeur,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                            ),
                          ]),
                        )),
              ],
          ],
        ),
      ),
    );
  }
}
