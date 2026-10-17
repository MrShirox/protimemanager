class Medication {
  final int? id;
  final String name;
  final String dosage;
  final int quantity;
  final DateTime? expiryDate;
  final String note;

  const Medication({
    this.id,
    required this.name,
    this.dosage = '',
    this.quantity = 1,
    this.expiryDate,
    this.note = '',
  });

  bool get isExpired => expiryDate != null &&
      DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day)
          .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

  bool get expiresToday => expiryDate != null &&
      expiryDate!.year == DateTime.now().year &&
      expiryDate!.month == DateTime.now().month &&
      expiryDate!.day == DateTime.now().day;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nom': name,
        'dosage': dosage,
        'quantite': quantity,
        'datePeremption': expiryDate?.toIso8601String(),
        'note': note,
      };

  factory Medication.fromMap(Map<String, dynamic> map) => Medication(
        id: map['id'] as int?,
        name: map['nom'] as String,
        dosage: map['dosage'] as String? ?? '',
        quantity: map['quantite'] as int? ?? 1,
        expiryDate: map['datePeremption'] == null
            ? null
            : DateTime.parse(map['datePeremption'] as String),
        note: map['note'] as String? ?? '',
      );
}
