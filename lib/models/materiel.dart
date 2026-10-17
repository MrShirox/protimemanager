class Materiel {
  final int? id;
  final String nom;
  final String? categorie;
  final bool disponible;
  final int quantite;
  final int quantiteMin; // seuil alerte "manquant"
  final DateTime? datePeremption;
  final String? note;

  Materiel({
    this.id,
    required this.nom,
    this.categorie,
    this.disponible = true,
    this.quantite = 1,
    this.quantiteMin = 1,
    this.datePeremption,
    this.note,
  });

  bool get isManquant => quantite < quantiteMin;

  bool get isPerime {
    if (datePeremption == null) return false;
    return datePeremption!.isBefore(DateTime.now());
  }

  bool get perimetionProche {
    if (datePeremption == null) return false;
    final diff = datePeremption!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 30;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'categorie': categorie,
      'disponible': disponible ? 1 : 0,
      'quantite': quantite,
      'quantiteMin': quantiteMin,
      'datePeremption': datePeremption?.toIso8601String(),
      'note': note,
    };
  }

  factory Materiel.fromMap(Map<String, dynamic> map) {
    return Materiel(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      categorie: map['categorie'] as String?,
      disponible: (map['disponible'] as int? ?? 1) == 1,
      quantite: map['quantite'] as int? ?? 1,
      quantiteMin: map['quantiteMin'] as int? ?? 1,
      datePeremption: map['datePeremption'] != null
          ? DateTime.parse(map['datePeremption'] as String)
          : null,
      note: map['note'] as String?,
    );
  }

  Materiel copyWith({
    int? id,
    String? nom,
    String? categorie,
    bool? disponible,
    int? quantite,
    int? quantiteMin,
    DateTime? datePeremption,
    String? note,
  }) {
    return Materiel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      categorie: categorie ?? this.categorie,
      disponible: disponible ?? this.disponible,
      quantite: quantite ?? this.quantite,
      quantiteMin: quantiteMin ?? this.quantiteMin,
      datePeremption: datePeremption ?? this.datePeremption,
      note: note ?? this.note,
    );
  }
}