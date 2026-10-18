import 'dart:convert';

const constanteSections = {
  'Cardiaque': [
    'TA Bras gauche',
    'TA Bras droit',
    'Pouls',
    'Rythme',
    'Perception'
  ],
  'Respiratoire': ['SpO2', 'FR'],
  'Neuro': [
    'FAST FACE',
    'FAST ARM',
    'FAST SPEECH',
    'FAST TIME',
    'Conscience',
    'Observations neurologiques'
  ],
  'Métabolique / autres': ['Température', 'Glycémie', 'Acétone', 'Remarques'],
};

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
      'champs': jsonEncode(
          champs.map((c) => {'label': c.label, 'valeur': c.valeur}).toList()),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Constante.fromMap(Map<String, dynamic> map) {
    final champsRaw = map['champs'] as String? ?? '';
    final champs = champsRaw.isEmpty
        ? <ConstanteChamp>[]
        : champsRaw.startsWith('[')
            ? (jsonDecode(champsRaw) as List)
                .map((e) => ConstanteChamp(
                    label: e['label'] as String, valeur: e['valeur'] as String))
                .toList()
            : champsRaw.split('||').map((e) {
                final parts = e.split('::');
                return ConstanteChamp(
                  label: parts[0],
                  valeur: parts.length > 1 ? parts.skip(1).join('::') : '',
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

  // Export rapide en format message : sections dans l'ordre du formulaire,
  // FAST résumé (OK si tout est OK, sinon uniquement ce qui ne l'est pas).
  String toMessage() {
    String? value(String label) {
      for (final c in champs) {
        if (c.label == label && c.valeur.trim().isNotEmpty) return c.valeur;
      }
      return null;
    }

    final known = constanteSections.values.expand((v) => v).toSet();
    final sections = <(String, List<String>)>[];

    final cardiaque = <String>[
      if (value('TA Bras gauche') case final v?) 'TA bras gauche : $v',
      if (value('TA Bras droit') case final v?) 'TA bras droit : $v',
    ];
    final rythme = value('Rythme');
    final perception = value('Perception');
    if (value('Pouls') case final pouls?) {
      final details = [
        if (rythme != null) rythme.toLowerCase(),
        if (perception != null) perception.toLowerCase(),
      ];
      cardiaque.add(
          'Pouls : $pouls${details.isEmpty ? '' : ' (${details.join(', ')})'}');
    } else {
      // Sans pouls saisi, n'afficher que les anomalies cochées.
      if (rythme == 'Irrégulier') cardiaque.add('Rythme : irrégulier');
      if (perception == 'Mal perçu') cardiaque.add('Pouls mal perçu');
    }
    sections.add(('❤️ CARDIAQUE', cardiaque));

    sections.add((
      '🫁 RESPIRATOIRE',
      [
        if (value('SpO2') case final v?) 'SpO2 : $v',
        if (value('FR') case final v?) 'FR : $v',
      ]
    ));

    const fastNames = ['FACE', 'ARM', 'SPEECH', 'TIME'];
    final fast = {for (final n in fastNames) n: value('FAST $n')};
    final notOk = [
      for (final n in fastNames)
        if (fast[n] != null && fast[n] != 'OK') '$n ${fast[n]}'
    ];
    final missing = [
      for (final n in fastNames)
        if (fast[n] == null) n
    ];
    final String? fastLine;
    if (missing.length == fastNames.length) {
      fastLine = null;
    } else if (notOk.isNotEmpty) {
      fastLine = 'FAST : ⚠️ ${notOk.join(' · ')}';
    } else if (missing.isEmpty) {
      fastLine = 'FAST : OK ✅';
    } else {
      fastLine = 'FAST : OK ✅ (non évalué : ${missing.join(', ')})';
    }
    sections.add((
      '🧠 NEURO',
      [
        if (fastLine != null) fastLine,
        if (value('Conscience') case final v?) 'Conscience : $v',
        if (value('Observations neurologiques') case final v?)
          'Observations : $v',
      ]
    ));

    sections.add((
      '🌡️ MÉTABOLIQUE',
      [
        if (value('Température') case final v?) 'Température : $v',
        if (value('Glycémie') case final v?) 'Glycémie : $v',
        if (value('Acétone') case final v?) 'Acétone : $v',
      ]
    ));

    sections.add((
      '📎 AUTRES',
      [
        for (final c in champs)
          if (!known.contains(c.label) && c.valeur.trim().isNotEmpty)
            '${c.label} : ${c.valeur}',
      ]
    ));

    final buffer = StringBuffer('📋 Constantes — $titre');
    for (final (title, lines) in sections) {
      if (lines.isEmpty) continue;
      buffer.write('\n\n$title');
      for (final line in lines) {
        buffer.write('\n• $line');
      }
    }
    if (value('Remarques') case final remarques?) {
      buffer.write('\n\n📝 REMARQUES\n$remarques');
    }
    return buffer.toString();
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
