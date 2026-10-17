class Constante {
  final int? id;
  final String titre;
  final List<ConstanteChamp> champs;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Constante({
    this.id,
    required this.titre,
    required this.champs,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'titre': titre,
      'champs': champs.map((c) => '${c.label}::${c.valeur}').join('||'),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Constante.fromMap(Map<String, dynamic> map) {
    final champsRaw = map['champs'] as String? ?? '';
    final champs = champsRaw.isEmpty
        ? <ConstanteChamp>[]
        : champsRaw.split('||').map((e) {
            final parts = e.split('::');
            return ConstanteChamp(
              label: parts[0],
              valeur: parts.length > 1 ? parts[1] : '',
            );
          }).toList();

    return Constante(
      id: map['id'] as int?,
      titre: map['titre'] as String,
      champs: champs,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  // Export rapide en format message
  String toMessage() {
    final buffer = StringBuffer();
    buffer.writeln('📋 $titre');
    buffer.writeln('─────────────────');
    for (final champ in champs) {
      buffer.writeln('${champ.label} : ${champ.valeur}');
    }
    return buffer.toString().trim();
  }

  Constante copyWith({
    int? id,
    String? titre,
    List<ConstanteChamp>? champs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Constante(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      champs: champs ?? this.champs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ConstanteChamp {
  final String label;
  final String valeur;

  ConstanteChamp({required this.label, required this.valeur});

  ConstanteChamp copyWith({String? label, String? valeur}) {
    return ConstanteChamp(
      label: label ?? this.label,
      valeur: valeur ?? this.valeur,
    );
  }
}