import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<DateTime?> showExpiryMonthPicker(
    BuildContext context, DateTime? initial) {
  var year = (initial ?? DateTime.now()).year;
  var month = (initial ?? DateTime.now()).month;
  return showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('Mois de péremption'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<int>(
                  initialValue: month,
                  decoration: const InputDecoration(labelText: 'Mois'),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(
                          value: m,
                          child: Text(DateFormat('MMMM', 'fr_FR')
                              .format(DateTime(2000, m))))
                  ],
                  onChanged: (value) => setState(() => month = value!),
                ),
                DropdownButtonFormField<int>(
                  initialValue: year,
                  decoration: const InputDecoration(labelText: 'Année'),
                  items: [
                    for (var y = 1900; y <= 2200; y++)
                      DropdownMenuItem(value: y, child: Text('$y'))
                  ],
                  onChanged: (value) => setState(() => year = value!),
                ),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, DateTime(year, month)),
                    child: const Text('Valider')),
              ],
            ),
          ));
}
