# Médicaments et rappels par mois

La saisie demande un mois et une année, sans jour. Exemple : **janvier 2027**.
La liste devient orange dès le **1er décembre 2026**, puis rouge dès le **1er janvier 2027**.
Le rouge signifie que le mois indiqué sur la fiche est atteint.

Deux notifications locales Android/iOS sont programmées à 09 h dans le fuseau du téléphone : le premier jour du mois précédent, puis le premier jour du mois de péremption. Lors d'un ajout pendant un de ces mois, le rappel déjà dû est programmé dès que possible, une seule fois par phase et par mois enregistré. Aucun rattrapage n'est émis pour les mois de péremption déjà passés.

Les anciennes dates restent lisibles : seul leur mois est utilisé pour l'affichage, les couleurs et les rappels. À la prochaine sauvegarde, la date SQLite est normalisée au premier jour du mois. Les identifiants de notification restent l'identifiant SQLite et son opposé négatif ; une modification ou suppression réconcilie les deux rappels. Les anciens marqueurs journaliers sont remplacés par des marqueurs mensuels et les rappels reprogrammés à l'ouverture ou au retour dans l'application.

Les notifications nécessitent l'autorisation du téléphone. Android utilise des alarmes non exactes, susceptibles d'être différées par les restrictions d'énergie ; les alarmes sont restaurées après redémarrage. Sur iOS, les 64 prochains rappels sont sélectionnés ; Android en sélectionne au maximum 450. L'application signale les refus et échecs de programmation sans annuler la sauvegarde.

## Vérification sur appareil

1. Ajouter un médicament dont la péremption est le mois prochain, autoriser les notifications et vérifier le rappel orange de rattrapage.
2. Rouvrir l'application : le même rappel ne doit pas être répété.
3. Modifier pour le mois actuel : vérifier le rouge et le rappel de mois atteint.
4. Modifier puis supprimer une fiche : vérifier l'annulation des anciens rappels.
5. Vérifier la livraison après redémarrage Android et avec les réglages d'économie d'énergie du téléphone.

Les tests automatisés vérifient la programmation, les changements d'année, les douze mois, la sauvegarde et le sélecteur mois/année. La livraison système nécessite un téléphone ou un émulateur ; iOS doit être compilé et vérifié sur macOS.
