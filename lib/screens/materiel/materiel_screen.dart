import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/materiel_provider.dart';
import '../../models/materiel.dart';
import '../../theme/app_theme.dart';

const List<Map<String, String>> _defaultMateriels = [
  {'nom': 'Contention',        'cat': 'Ambulance'},
  {'nom': 'Cosselle',          'cat': 'Ambulance'},
  {'nom': 'Couverture',        'cat': 'Ambulance'},
  {'nom': 'Gants',             'cat': 'Ambulance'},
  {'nom': 'MID',               'cat': 'Ambulance'},
  {'nom': 'Oxygène 15 litres', 'cat': 'Ambulance'},
  {'nom': 'Oxygène 5 litres',  'cat': 'Ambulance'},
  {'nom': 'Produit',           'cat': 'Ambulance'},
  {'nom': 'Scoop',             'cat': 'Ambulance'},
  {'nom': 'Compresse',                   'cat': 'Sac jaune'},
  {'nom': 'Couverture de survie',        'cat': 'Sac jaune'},
  {'nom': 'Echarpe',                     'cat': 'Sac jaune'},
  {'nom': 'Kit plaie grand',             'cat': 'Sac jaune'},
  {'nom': 'Kit plaie petite',            'cat': 'Sac jaune'},
  {'nom': 'Kit à oxygène',               'cat': 'Sac jaune'},
  {'nom': 'Lunette à oxygène',           'cat': 'Sac jaune'},
  {'nom': 'Masque haute concentration',  'cat': 'Sac jaune'},
  {'nom': 'Masque moyenne concentration','cat': 'Sac jaune'},
  {'nom': 'Bavu',               'cat': 'Sac rouge'},
  {'nom': 'Bavu pédiatrique',   'cat': 'Sac rouge'},
  {'nom': 'DSA',                'cat': 'Sac rouge'},
  {'nom': 'Kit EPI',            'cat': 'Sac rouge'},
  {'nom': 'Kit de brûlure',     'cat': 'Sac rouge'},
  {'nom': 'Kit hémorragie',     'cat': 'Sac rouge'},
  {'nom': 'Kit maternité',      'cat': 'Sac rouge'},
  {'nom': 'Kit plaie grand',    'cat': 'Sac rouge'},
  {'nom': 'Kit sectionnement',  'cat': 'Sac rouge'},
  {'nom': 'Kit à oxygène',      'cat': 'Sac rouge'},
];

// Noms qui sont des kits avec date de péremption
const List<String> _kitNames = [
  'Kit plaie grand', 'Kit plaie petite', 'Kit à oxygène',
  'Kit EPI', 'Kit de brûlure', 'Kit hémorragie',
  'Kit maternité', 'Kit sectionnement',
];

bool _isKit(String nom) =>
    _kitNames.any((k) => nom.toLowerCase().contains(k.toLowerCase()));

const List<String> _categories = ['Tous', 'Ambulance', 'Sac jaune', 'Sac rouge'];

const Map<String, Color> _catColors = {
  'Ambulance': Color(0xFF42A5F5),
  'Sac jaune': Color(0xFFFFA726),
  'Sac rouge': Color(0xFFEF5350),
};

const Map<String, String> _catEmoji = {
  'Ambulance': '🚑',
  'Sac jaune': '🟡',
  'Sac rouge': '🔴',
};

class MaterielScreen extends StatefulWidget {
  const MaterielScreen({super.key});

  @override
  State<MaterielScreen> createState() => _MaterielScreenState();
}

class _MaterielScreenState extends State<MaterielScreen> {
  String _selectedCat = 'Tous';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initDefaults();
    }
  }

  Future<void> _initDefaults() async {
    final provider = context.read<MaterielProvider>();
    await provider.loadAll();
    if (provider.materiels.isEmpty) {
      for (final m in _defaultMateriels) {
        await provider.add(Materiel(
          nom: m['nom']!,
          categorie: m['cat'],
          disponible: true,
          quantite: 1,
          quantiteMin: 1,
        ));
      }
    }
  }

  List<Materiel> _sorted(List<Materiel> list) {
    // Manquants / indisponibles EN HAUT, puis alphabétique
    final manquants = list.where((m) => !m.disponible || m.isManquant).toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
    final ok = list.where((m) => m.disponible && !m.isManquant).toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
    return [...manquants, ...ok];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MaterielProvider>();
    final theme = Theme.of(context);

    final base = provider.materiels.where((m) {
      final matchCat = _selectedCat == 'Tous' || m.categorie == _selectedCat;
      final matchSearch = provider.searchQuery.isEmpty ||
          m.nom.toLowerCase().contains(provider.searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    final filtered = _sorted(base);

    // Alertes péremption
    final alertes = provider.materiels
        .where((m) => m.perimetionProche || m.isPerime)
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Matériel',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () => _showDialog(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('AJOUTER'),
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

            // ── Alerte péremption ──
            if (alertes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${alertes.length} kit(s) à vérifier : ${alertes.map((m) => m.nom).join(', ')}',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ),

            const SizedBox(height: 10),

            // ── Recherche ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: provider.setSearch,
                decoration: InputDecoration(
                  hintText: '🔍 Rechercher un matériel...',
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Filtres ──
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final selected = _selectedCat == cat;
                  final color = cat == 'Tous'
                      ? AppTheme.primaryColor
                      : _catColors[cat] ?? AppTheme.primaryColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCat = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? color
                            : color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        cat == 'Tous'
                            ? 'TOUS'
                            : '${_catEmoji[cat]} ${cat.toUpperCase()}',
                        style: TextStyle(
                          color: selected ? Colors.white : color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // ── Liste ──
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Aucun matériel'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final m = filtered[i];
                        final showSep = i > 0 &&
                            (!filtered[i - 1].disponible ||
                                    filtered[i - 1].isManquant) &&
                            (m.disponible && !m.isManquant);
                        return Column(
                          children: [
                            if (showSep)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('Disponibles',
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11)),
                                  ),
                                  const Expanded(child: Divider()),
                                ]),
                              ),
                            // Swipe gauche pour supprimer
                            // Swipe seulement si l'item a un id valide
                            if (m.id != null)
                              Dismissible(
                                key: Key('mat_${m.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white, size: 24),
                                ),
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Supprimer'),
                                      content: Text('Supprimer "${m.nom}" ?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Annuler')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Supprimer',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  ) ?? false;
                                },
                                onDismissed: (_) {
                                  if (m.id != null) provider.delete(m.id!);
                                },
                                child: _MaterielCard(
                                  materiel: m,
                                  onEdit: () => _showDialog(context, m),
                                  onDelete: () => _confirmDelete(context, m),
                                  onToggle: () => provider.update(
                                      m.copyWith(disponible: !m.disponible)),
                                ),
                              )
                            else
                              _MaterielCard(
                                materiel: m,
                                onEdit: () => _showDialog(context, m),
                                onDelete: () => _confirmDelete(context, m),
                                onToggle: () => provider.update(
                                    m.copyWith(disponible: !m.disponible)),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, Materiel? existing) {
    final nomCtrl = TextEditingController(text: existing?.nom ?? '');
    String cat = existing?.categorie ?? 'Ambulance';
    bool dispo = existing?.disponible ?? true;
    DateTime? datePerem = existing?.datePeremption;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          // Auto-détecte si c'est un kit à chaque rebuild
          final showPerem = _isKit(nomCtrl.text);
          return AlertDialog(
          title: Text(existing == null ? 'Ajouter matériel' : 'Modifier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  onChanged: (_) => setS(() {}), // rebuild → showPerem se met à jour
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: cat,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: ['Ambulance', 'Sac jaune', 'Sac rouge']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setS(() => cat = v!),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible'),
                  value: dispo,
                  onChanged: (v) => setS(() => dispo = v),
                ),
                // Date de péremption — apparaît automatiquement si "kit" dans le nom
                if (showPerem) ...[
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          datePerem == null
                              ? '📅 Date de péremption (obligatoire pour les kits)'
                              : 'Péremption : ${DateFormat('dd/MM/yyyy').format(datePerem!)}',
                          style: TextStyle(
                            color: datePerem != null &&
                                    datePerem!.isBefore(DateTime.now())
                                ? Colors.red
                                : datePerem != null &&
                                        datePerem!
                                            .difference(DateTime.now())
                                            .inDays <=
                                            30
                                    ? Colors.orange
                                    : Colors.orange,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: datePerem ??
                                DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 10)),
                          );
                          if (d != null) setS(() => datePerem = d);
                        },
                        child: const Text('Choisir'),
                      ),
                      if (datePerem != null)
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.red),
                          onPressed: () => setS(() => datePerem = null),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final provider = context.read<MaterielProvider>();
                if (existing == null) {
                  provider.add(Materiel(
                    nom: nomCtrl.text,
                    categorie: cat,
                    disponible: dispo,
                    datePeremption: datePerem,
                  ));
                } else {
                  provider.update(existing.copyWith(
                    nom: nomCtrl.text,
                    categorie: cat,
                    disponible: dispo,
                    datePeremption: datePerem,
                  ));
                }
                Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
            ),
          ],
        );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Materiel m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer "${m.nom}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<MaterielProvider>().delete(m.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Carte matériel ────────────────────────────────────────────────────────────
class _MaterielCard extends StatelessWidget {
  final Materiel materiel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _MaterielCard({
    required this.materiel,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = materiel.categorie ?? '';
    final catColor = _catColors[cat] ?? Colors.grey;
    final catEmoji = _catEmoji[cat] ?? '📦';
    final isManquant = !materiel.disponible || materiel.isManquant;
    final isPerime = materiel.isPerime;
    final peremProche = materiel.perimetionProche;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isManquant
            ? BorderSide(
                color: Colors.red.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (isManquant)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 16),
                      ),
                    Expanded(
                      child: Text(
                        materiel.nom,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isManquant ? Colors.red : null,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$catEmoji $cat',
                          style: TextStyle(
                              color: catColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                    // Date péremption
                    if (materiel.datePeremption != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPerime
                              ? Colors.red.withValues(alpha: 0.15)
                              : peremProche
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '📅 ${DateFormat('dd/MM/yy').format(materiel.datePeremption!)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPerime
                                ? Colors.red
                                : peremProche
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),

            // Bouton modifier
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onEdit,
              tooltip: 'Modifier',
            ),

            // Bouton dispo
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: materiel.disponible
                      ? Colors.green.withValues(alpha: 0.13)
                      : Colors.red.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: materiel.disponible
                        ? Colors.green.withValues(alpha: 0.5)
                        : Colors.red.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  materiel.disponible ? '✅ OK' : '❌ KO',
                  style: TextStyle(
                    color: materiel.disponible
                        ? Colors.green
                        : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}