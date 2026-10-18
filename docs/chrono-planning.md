# Chronomètre et planning

Chaque démarrage après un arrêt crée une session indépendante. Une session de
nuit conserve le même identifiant du début à la fin : le passage à minuit ne
crée aucune écriture ni session supplémentaire. Le calendrier affiche la portion
de chaque session comprise entre minuit et le minuit suivant, pauses déduites.

Exemple de trois nuits 20 h–5 h : lundi 4 h, mardi 9 h, mercredi 9 h, jeudi 5 h.
Le dimanche affiche la somme des journées du lundi au dimanche, y compris quand
la semaine traverse deux mois. Une nuit du dimanche au lundi contribue donc aux
deux semaines correspondantes. La borne de fin de journée est 24:00, sans minute
perdue à 23:59.

Le chrono montre le temps net de la session complète en cours, même après minuit.
Les sessions du jour et le total du jour montrent seulement les portions de ce
jour. Les pauses multiples sont horodatées avec une date complète ; une pause
qui traverse minuit est répartie de la même façon que le travail.

Les commandes de début/fin de journée et les pauses de 20, 30, 45, 50 ou 60 minutes
sont disponibles dans le chrono et l'accueil. La fin prévue de pause est enregistrée :
le travail reprend automatiquement dans les calculs même après fermeture. Une reprise
anticipée ou un arrêt pendant la pause ne déduit que la durée écoulée. Le widget
Android propose les mêmes commandes (voir [les détails](updates-october-2026.md)).

La fenêtre du jour affiche les portions quotidiennes. « Modifier la session »
ouvre les dates et horaires de la session complète. Corriger 09:00 en 08:00 à
09:00 affiche immédiatement 1 h de travail au chrono. Une correction, un ajout
manuel, une suppression ou l'arrêt manuel d'une session actualise les deux
écrans et tous les totaux. Supprimer une session de nuit supprime ses portions
sur tous les jours concernés, après confirmation. Retirer une couleur de journée
conserve les horaires.

## Sauvegarde et compatibilité

`WorkSessions` est la source partagée par les deux providers. Les écritures sont
sérialisées et chaque session avec ses pauses est sauvegardée dans une transaction
SQLite. Une fenêtre d'édition devenue obsolète ne peut pas écraser une action
plus récente. Les chevauchements, pauses hors session et plusieurs sessions
simultanément actives sont refusés.

Le temps écoulé est calculé à partir des horaires, pas du nombre de secondes où
l'application est ouverte. Une pause ou session active est retrouvée après
fermeture. Les nouveaux instants sont stockés en UTC puis affichés dans le fuseau
local pour conserver les durées au changement d'heure.

La migration SQLite v6 ajoute les dates complètes des pauses et une révision aux
sessions sans supprimer les fiches existantes. Les anciennes nuits déjà découpées
en plusieurs lignes restent séparées : aucun regroupement incertain n'est fait.
Pour les anciennes sessions qui ne contiennent qu'un total de pause sans plages,
le total est conservé en reconstituant une pause au début ; son emplacement exact
doit être vérifié dans l'éditeur. Les anciennes heures ambiguës lors d'un changement
d'heure ne peuvent pas être reconstruites avec certitude sans l'information de fuseau.

La migration v7 ajoute le marqueur de pause programmée, sans modifier les anciennes pauses.

## Vérification

Les tests utilisent une vraie base SQLite temporaire et couvrent les nuits
consécutives, pauses multiples, reprise après fermeture, passage de semaine et de
mois, minuit exact, changements d'heure, édition et suppression actives, rollback
d'une écriture échouée, doubles appuis et migration v4/v5. Les tests d'interface
vérifient le calendrier sur un écran de téléphone et la correction 09:00 → 08:00
avec le sélecteur d'heure.

Sur téléphone, vérifier aussi une journée réelle : démarrer, faire deux pauses,
corriger le début dans le planning, fermer puis rouvrir l'application et terminer.
