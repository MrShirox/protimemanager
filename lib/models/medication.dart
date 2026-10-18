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

  bool get isExpired =>
      expiryDate != null &&
      DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day).isBefore(
          DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day));

  bool get expiresToday =>
      expiryDate != null &&
      expiryDate!.year == DateTime.now().year &&
      expiryDate!.month == DateTime.now().month &&
      expiryDate!.day == DateTime.now().day;

  /// One calendar month, clamped to the last day of the previous month.
  DateTime? get warningDate {
    final expiry = expiryDate;
    if (expiry == null) return null;
    final last = DateTime(expiry.year, expiry.month, 0);
    return DateTime(
        last.year, last.month, expiry.day > last.day ? last.day : expiry.day);
  }

  bool warningAt(DateTime now) =>
      warningDate != null &&
      !DateTime(now.year, now.month, now.day).isBefore(warningDate!) &&
      !dueAt(now);
  bool dueAt(DateTime now) =>
      expiryDate != null &&
      !DateTime(now.year, now.month, now.day).isBefore(
          DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day));
  bool get needsReplacement => warningAt(DateTime.now());
  bool get isDue => dueAt(DateTime.now());

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
