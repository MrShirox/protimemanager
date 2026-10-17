# Médicaments et rappels de péremption

L'écran Médicaments permet d'ajouter, modifier et supprimer les fiches SQLite.
Le nom, la quantité entière et la date de péremption sont validés avant sauvegarde.
Les anciennes fiches sans date restent lisibles et demandent une date à l'édition.

Une notification locale Android/iOS est programmée vers 9 h, dans le fuseau du
téléphone, le jour de péremption. Pour une saisie le jour même après 9 h, le rappel
est programmé dès que possible. Les dates déjà dépassées restent signalées dans
la liste et ne déclenchent pas de notification rétroactive.

L'identifiant SQLite sert d'identifiant de notification : une modification
remplace le rappel, une suppression l'annule. Les rappels sont réconciliés au
démarrage et au retour dans l'application. Android les restaure après redémarrage
du téléphone. Un marqueur persistant évite de renvoyer le rappel du jour à chaque
ouverture. La programmation dépend de l'autorisation du téléphone ; un bandeau
signale un refus ou un échec sans perdre les données déjà sauvegardées.

Android utilise des alarmes non exactes : l'économie d'énergie peut décaler
l'heure de réception. Un arrêt forcé ou les restrictions du fabricant peuvent
empêcher la réception. Sur iOS, les 64 prochaines péremptions sont programmées
pour respecter la limite système ; un message demande de rouvrir régulièrement
l'application lorsque cette limite est dépassée.

## Vérification sur appareil

1. Ajouter un médicament et accepter la demande de notifications.
2. Choisir aujourd'hui après 9 h, quitter l'application normalement et vérifier
   la notification système. Android peut différer l'alarme non exacte.
3. Rouvrir l'application : aucun nouveau rappel identique ne doit être envoyé.
4. Programmer une date future, la modifier, puis supprimer la fiche : vérifier
   qu'aucun rappel de l'ancienne fiche ne subsiste.
5. Refuser les notifications : vérifier le bandeau, puis les autoriser dans les
   réglages et revenir à l'application.
6. Vérifier aussi une péremption future après redémarrage Android.

Les tests automatisés simulent les API natives de notification. Ils ne remplacent
pas ces vérifications de réception. La configuration iOS doit être compilée et
testée sur macOS avec un iPhone ou un simulateur.
