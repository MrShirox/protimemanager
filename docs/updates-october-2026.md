# Ajustements client — octobre 2026

- **Planning** : cases compactes, uniquement le total travaillé sous le jour. Total hebdomadaire le dimanche. La fenêtre affiche toujours les débuts, fins et pauses ; les nuits restent séparées à minuit.
- **Pauses** : les boutons 20/30/45/50/60 minutes déduisent immédiatement la durée, sans suspendre le chronomètre. Chaque déduction peut être corrigée ou supprimée dans le planning. Même comportement depuis l'accueil et le widget Android. Les pauses déjà enregistrées dans les anciennes versions restent conservées avec leur fonctionnement historique.
- **Sauvegarde** : SQLite v8 ajoute `deductionMinutes`, sans supprimer de données. Une déduction est rattachée à son jour d'ajout, modifiable via la date d'imputation. Les pauses ne peuvent pas dépasser le temps écoulé sur le jour concerné.
- **Neuro / FAST** : FACE, ARM, SPEECH et TIME ont chacun deux cases exclusives OK/NON. Aucun résultat n'est présumé lorsque rien n'est coché. Les anciennes notes neuro restent conservées. Aucune interprétation clinique automatique.
- **Acétone** : sous la glycémie dans le formulaire et la fiche, avec conservation du résultat et de l'unité.
- **Médicaments** : mois/année uniquement. Orange et notification le premier jour du mois précédent ; rouge et notification le premier jour du mois indiqué. Exemple janvier 2027 : orange en décembre 2026, rouge en janvier 2027. Les anciennes dates précises utilisent désormais leur mois.
- **Widget Android** : ouvrir l'application une fois puis appui long sur l'accueil du téléphone → Widgets → ProTimeManager. Les commandes utilisent les mêmes transactions SQLite. Le titre ouvre l'application. Le widget natif iOS n'est pas implémenté.

Les tests couvrent les calculs, migrations, nuits, plusieurs déductions, correction dans le formulaire, FAST, choix mois/année et programmation des alertes. Les clics depuis le lanceur Android et la réception effective des notifications restent à vérifier sur appareil.
