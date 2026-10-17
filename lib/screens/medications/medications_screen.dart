import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/medication.dart';
import '../../providers/medications_provider.dart';
import '../../theme/app_theme.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicationsProvider>();
    final theme = Theme.of(context);
    final dueToday = provider.expiringToday;
    return Scaffold(
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Row(children: [
            Expanded(child: Text('Médicaments', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
            IconButton.filled(onPressed: () => _edit(context), icon: const Icon(Icons.add)),
          ]),
        ),
        if (dueToday.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Text('À vérifier aujourd’hui : ${dueToday.map((m) => m.name).join(', ')}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600)),
          ),
        Expanded(child: provider.items.isEmpty
          ? const Center(child: Text('Aucun médicament enregistré.\nAjoute ton premier médicament avec +.', textAlign: TextAlign.center))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: provider.items.length,
              itemBuilder: (context, index) {
                final item = provider.items[index];
                final expired = item.isExpired;
                final today = item.expiresToday;
                final color = expired ? Colors.red : today ? Colors.orange : AppTheme.primaryColor;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(Icons.medication_outlined, color: color)),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (item.dosage.isNotEmpty) item.dosage,
                      'Quantité : ${item.quantity}',
                      if (item.expiryDate != null) 'Péremption : ${DateFormat('dd/MM/yyyy').format(item.expiryDate!)}${expired ? ' • périmé' : today ? ' • aujourd’hui' : ''}',
                      if (item.note.isNotEmpty) item.note,
                    ].join('\n'), style: TextStyle(color: expired || today ? color : null)),
                    isThreeLine: true,
                    onTap: () => _edit(context, item),
                    trailing: IconButton(
                      tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer ce médicament ?'),
                          content: Text(item.name),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer'))],
                        ));
                        if (yes == true && item.id != null) context.read<MedicationsProvider>().delete(item.id!);
                      },
                    ),
                  ),
                );
              },
            )),
      ])),
    );
  }

  Future<void> _edit(BuildContext context, [Medication? item]) async {
    final name = TextEditingController(text: item?.name ?? '');
    final dosage = TextEditingController(text: item?.dosage ?? '');
    final quantity = TextEditingController(text: '${item?.quantity ?? 1}');
    final note = TextEditingController(text: item?.note ?? '');
    DateTime? expiry = item?.expiryDate;
    final result = await showDialog<Medication>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      title: Text(item == null ? 'Ajouter un médicament' : 'Modifier le médicament'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom *')),
        TextField(controller: dosage, decoration: const InputDecoration(labelText: 'Dosage (facultatif)')),
        TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité')),
        ListTile(contentPadding: EdgeInsets.zero, title: Text(expiry == null ? 'Date de péremption' : 'Péremption : ${DateFormat('dd/MM/yyyy').format(expiry!)}'), trailing: const Icon(Icons.calendar_month), onTap: () async {
          final picked = await showDatePicker(context: ctx, initialDate: expiry ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) setState(() => expiry = picked);
        }),
        if (expiry != null) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => expiry = null), child: const Text('Retirer la date'))),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () {
          final n = name.text.trim();
          final q = int.tryParse(quantity.text.trim()) ?? 1;
          if (n.isEmpty || q < 0) return;
          Navigator.pop(ctx, Medication(id: item?.id, name: n, dosage: dosage.text.trim(), quantity: q, expiryDate: expiry, note: note.text.trim()));
        }, child: const Text('Enregistrer')),
      ],
    )));
    if (result != null && context.mounted) context.read<MedicationsProvider>().save(result);
  }
}
