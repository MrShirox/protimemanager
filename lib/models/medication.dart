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

  DateTime? get expiryMonth =>
      expiryDate == null ? null : DateTime(expiryDate!.year, expiryDate!.month);
  DateTime? get warningDate => expiryDate == null
      ? null
      : DateTime(expiryDate!.year, expiryDate!.month - 1);
  bool get isExpired =>
      expiryMonth != null &&
      expiryMonth!
          .isBefore(DateTime(DateTime.now().year, DateTime.now().month));
  bool get expiresThisMonth =>
      expiryMonth == DateTime(DateTime.now().year, DateTime.now().month);
  bool warningAt(DateTime now) =>
      warningDate != null &&
      !DateTime(now.year, now.month).isBefore(warningDate!) &&
      !dueAt(now);
  bool dueAt(DateTime now) =>
      expiryMonth != null &&
      !DateTime(now.year, now.month).isBefore(expiryMonth!);
  bool get needsReplacement => warningAt(DateTime.now());
  bool get isDue => dueAt(DateTime.now());

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nom': name,
        'dosage': dosage,
        'quantite': quantity,
        'datePeremption': expiryMonth?.toIso8601String(),
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
