import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/medication.dart';
import '../../providers/medications_provider.dart';
import '../../theme/app_theme.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  void _edit(BuildContext context, [Medication? item]) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MedicationForm(item: item),
    );
  }

  Future<void> _delete(BuildContext context, Medication item) async {
    final provider = context.read<MedicationsProvider>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce médicament ?'),
        content: Text(item.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      await provider.delete(item.id!);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Suppression impossible. Réessaie.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicationsProvider>();
    final dueToday = provider.expiringToday;
    final busy = provider.isLoading || provider.isBusy;
    return Scaffold(
      body: SafeArea(
          child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Row(children: [
            Expanded(
                child: Text('Médicaments',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold))),
            IconButton.filled(
              tooltip: 'Ajouter un médicament',
              onPressed:
                  busy || provider.error != null ? null : () => _edit(context),
              icon: const Icon(Icons.add),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(provider.notificationWarning ??
              'Rappels un mois avant puis à échéance, vers 9 h. Orange : remplacement à prévoir. Rouge : date de péremption atteinte.'),
        ),
        if (provider.notificationWarning != null)
          TextButton.icon(
            onPressed: busy ? null : provider.enableNotifications,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Activer / Réessayer'),
          ),
        if (dueToday.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
                'À vérifier aujourd’hui : ${dueToday.map((m) => m.name).join(', ')}',
                style: const TextStyle(color: Colors.red)),
          ),
        if (provider.isBusy) const LinearProgressIndicator(),
        Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(provider.error!),
                        TextButton(
                            onPressed: provider.load,
                            child: const Text('Réessayer')),
                      ]))
                    : provider.items.isEmpty
                        ? const Center(
                            child: Text(
                                'Aucun médicament enregistré.\nAjoute ton premier médicament avec +.',
                                textAlign: TextAlign.center))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: provider.items.length,
                            itemBuilder: (context, index) {
                              final item = provider.items[index];
                              final color = item.isDue
                                  ? Colors.red
                                  : item.needsReplacement
                                      ? Colors.orange
                                      : AppTheme.primaryColor;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                      backgroundColor:
                                          color.withValues(alpha: .12),
                                      child: Icon(Icons.medication_outlined,
                                          color: color)),
                                  title: Text(item.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                      [
                                        if (item.dosage.isNotEmpty) item.dosage,
                                        'Quantité : ${item.quantity}',
                                        if (item.expiryDate != null)
                                          'Péremption : ${DateFormat('dd/MM/yyyy').format(item.expiryDate!)}${item.isExpired ? ' • périmé' : item.expiresToday ? ' • aujourd’hui' : ''}'
                                        else
                                          'Date de péremption à compléter',
                                        if (item.note.isNotEmpty) item.note,
                                      ].join('\n'),
                                      style: TextStyle(
                                          color: item.isDue ||
                                                  item.needsReplacement
                                              ? color
                                              : null)),
                                  isThreeLine: true,
                                  onTap:
                                      busy ? null : () => _edit(context, item),
                                  trailing: IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: busy
                                        ? null
                                        : () => _delete(context, item),
                                  ),
                                ),
                              );
                            },
                          )),
      ])),
    );
  }
}

class _MedicationForm extends StatefulWidget {
  final Medication? item;
  const _MedicationForm({this.item});

  @override
  State<_MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends State<_MedicationForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _dosage, _quantity, _note;
  DateTime? _expiry;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _dosage = TextEditingController(text: widget.item?.dosage ?? '');
    _quantity = TextEditingController(text: '${widget.item?.quantity ?? 1}');
    _note = TextEditingController(text: widget.item?.note ?? '');
    _expiry = widget.item?.expiryDate;
  }

  @override
  void dispose() {
    for (final controller in [_name, _dosage, _quantity, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    if (_expiry == null) {
      setState(() => _error = 'Choisis une date de péremption.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<MedicationsProvider>().save(Medication(
            id: widget.item?.id,
            name: _name.text.trim(),
            dosage: _dosage.text.trim(),
            quantity: int.parse(_quantity.text),
            expiryDate: _expiry,
            note: _note.text.trim(),
          ));
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Enregistrement impossible. Tes saisies sont conservées, réessaie.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: Text(widget.item == null
              ? 'Ajouter un médicament'
              : 'Modifier le médicament'),
          content: SingleChildScrollView(
              child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Nom *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Saisis un nom.' : null),
              TextFormField(
                  controller: _dosage,
                  enabled: !_saving,
                  decoration:
                      const InputDecoration(labelText: 'Dosage (facultatif)')),
              TextFormField(
                  controller: _quantity,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Quantité'),
                  validator: (v) => int.tryParse(v ?? '') == null
                      ? 'Saisis une quantité entière.'
                      : null),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_expiry == null
                    ? 'Date de péremption *'
                    : 'Péremption : ${DateFormat('dd/MM/yyyy').format(_expiry!)}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: _saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                            context: context,
                            initialDate: _expiry ?? DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2200));
                        if (picked != null && mounted) {
                          setState(() {
                            _expiry = picked;
                            _error = null;
                          });
                        }
                      },
              ),
              const Text(
                  'Notification le jour de péremption vers 9 h. Si tu enregistres après 9 h pour aujourd’hui, le rappel est envoyé dès que possible.'),
              TextFormField(
                  controller: _note,
                  enabled: !_saving,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Note')),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
            ]),
          )),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
          ],
        ),
      );
}
