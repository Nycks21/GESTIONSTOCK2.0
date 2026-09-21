# GESTIONSTOCK 2.0
## Manuel Utilisateur

---

**Application :** GESTIONSTOCK 2.0  
**Version :** 2.0  
**Date :** Septembre 2026  
**Destinataires :** Tous les utilisateurs de l'application  

---

> ℹ️ **Important :** Ce manuel décrit l'ensemble des fonctionnalités de l'application GESTIONSTOCK 2.0. Certaines sections sont réservées aux administrateurs ou au Super Administrateur. Les captures d'écran sont remplacées par des descriptions détaillées des interfaces.

---

## TABLE DES MATIÈRES

1. [Présentation générale](#1-présentation-générale)
2. [Connexion à l'application](#2-connexion-à-lapplication)
   - 2.1 [Procédure de connexion](#21-procédure-de-connexion)
   - 2.2 [Messages d'erreur à la connexion](#22-messages-derreur-à-la-connexion)
   - 2.3 [Déconnexion](#23-déconnexion)
3. [Présentation de l'interface](#3-présentation-de-linterface)
   - 3.1 [Barre supérieure (Topbar)](#31-barre-supérieure-topbar)
   - 3.2 [Menu latéral (Sidebar)](#32-menu-latéral-sidebar)
   - 3.3 [Panneau de paramètres (Control Sidebar)](#33-panneau-de-paramètres-control-sidebar)
   - 3.4 [Tableau de bord](#34-tableau-de-bord)
4. [Gestion des utilisateurs et des droits](#4-gestion-des-utilisateurs-et-des-droits)
   - 4.1 [Rôles disponibles](#41-rôles-disponibles)
   - 4.2 [Permissions par menu](#42-permissions-par-menu)
5. [Module Paramètres](#5-module-paramètres)
   - 5.1 [Unités](#51-unités)
   - 5.2 [Catégories](#52-catégories)
   - 5.3 [Fournisseurs](#53-fournisseurs)
   - 5.4 [Emplacements](#54-emplacements)
6. [Module Mouvements](#6-module-mouvements)
   - 6.1 [Articles](#61-articles)
   - 6.2 [Entrées](#62-entrées)
   - 6.3 [Sorties](#63-sorties)
   - 6.4 [Stock](#64-stock)
7. [Module Demandes](#7-module-demandes)
   - 7.1 [Saisies](#71-saisies)
   - 7.2 [Accusés de réception](#72-accusés-de-réception)
8. [Module Rapports](#8-module-rapports)
   - 8.1 [Exploitations](#81-exploitations)
   - 8.2 [Inventaire](#82-inventaire)
9. [Module Administration](#9-module-administration)
   - 9.1 [Changer le mot de passe](#91-changer-le-mot-de-passe)
   - 9.2 [Utilisateurs](#92-utilisateurs)
   - 9.3 [Requêtes SQL](#93-requêtes-sql)
10. [Workflows des processus métier](#10-workflows-des-processus-métier)
    - 10.1 [Workflow des demandes de sortie](#101-workflow-des-demandes-de-sortie)
    - 10.2 [Workflow des bons d'entrée](#102-workflow-des-bons-dentrée)
    - 10.3 [Workflow des bons de sortie](#103-workflow-des-bons-de-sortie)
11. [Gestion des erreurs](#11-gestion-des-erreurs)
12. [Conseils d'utilisation et bonnes pratiques](#12-conseils-dutilisation-et-bonnes-pratiques)
13. [Glossaire](#13-glossaire)

---

## 1. Présentation générale

**GESTIONSTOCK 2.0** est une application web de gestion de stock conçue pour faciliter le suivi des mouvements de marchandises au sein d'une organisation. Elle permet de gérer l'ensemble du cycle de vie des articles en stock : de leur référencement jusqu'à leur sortie définitive, en passant par les demandes internes, les bons d'entrée et de sortie, et les rapports d'exploitation.

### Fonctionnalités principales

- **Gestion des articles** : référencement, catégorisation, suivi des seuils d'alerte
- **Mouvements de stock** : enregistrement des entrées et sorties avec validation
- **Demandes internes** : circuit de demande de matériel avec validation hiérarchique
- **Accusés de réception** : confirmation de la réception physique des articles sortis
- **Rapports et inventaire** : analyse des mouvements, état du stock en temps réel
- **Administration** : gestion des utilisateurs, des droits d'accès, et des paramètres système
- **Multilingue** : interface disponible en Français (FR), Anglais (EN) et Malgache (MG)
- **Mode sombre** : interface adaptable selon les préférences visuelles

### Architecture de l'application

L'application est organisée en sections accessibles depuis le menu latéral :

| Section | Modules |
|---|---|
| Accueil | Tableau de bord |
| Paramètres | Unités, Catégories, Fournisseurs, Emplacements |
| Mouvements | Articles, Entrées, Sorties, Stock |
| Demandes | Saisies, Accusés de réception |
| Rapports | Exploitations, Inventaire |
| Administration | Changer mot de passe, Utilisateurs, Requêtes SQL |

> ⚠️ **Attention :** L'accès à chaque module dépend du rôle et des permissions attribués à votre compte. Certains menus peuvent ne pas être visibles si vous n'y avez pas accès.

---

## 2. Connexion à l'application

### 2.1 Procédure de connexion

> 📸 **Figure 1 — Page de connexion**
> *La page de connexion affiche un formulaire centré avec deux champs de saisie (Nom d'utilisateur et Mot de passe) et un bouton "Se connecter". Le logo de l'application apparaît en haut du formulaire.*

**Étapes pour se connecter :**

1. Ouvrez votre navigateur web et accédez à l'URL de l'application.
2. Sur la page de connexion, saisissez votre **Nom d'utilisateur** dans le premier champ.
3. Saisissez votre **Mot de passe** dans le second champ.
4. Cliquez sur le bouton **Se connecter**.
5. Si vos identifiants sont corrects, vous serez redirigé vers le tableau de bord.

> 💡 **Astuce :** Si vous avez oublié votre mot de passe, contactez votre administrateur pour qu'il réinitialise votre accès.

> ⚠️ **Attention :** Après **5 tentatives de connexion échouées**, votre compte sera temporairement bloqué pendant **60 secondes**. Attendez ce délai avant de réessayer.

### 2.2 Messages d'erreur à la connexion

L'application peut afficher les messages suivants lors de la connexion :

| Message | Cause | Action à effectuer |
|---|---|---|
| ❌ Licence expirée depuis le [date] | La licence de l'application a expiré | Contacter l'administrateur système |
| ❌ Licence invalide. | La clé de licence n'est pas reconnue | Contacter l'administrateur système |
| ❌ Nombre maximum d'utilisateurs atteint (X). | Le quota de licences utilisateurs est atteint | Attendre qu'un autre utilisateur se déconnecte ou contacter l'admin |
| Connexion à la base de données impossible. Veuillez contacter l'administrateur. | Le serveur de base de données est inaccessible | Contacter l'administrateur système |
| Compte bloqué temporairement. Réessayez dans 1 minute. | Trop de tentatives échouées | Attendre 60 secondes puis réessayer |

**Messages de redirection** (affichés après une déconnexion automatique) :

| Code | Message affiché |
|---|---|
| maintenance | Vous avez été déconnecté pour cause de maintenance. |
| disconnected | Vous avez été déconnecté par l'administrateur. |
| session_expired | Votre session a expiré. Veuillez vous reconnecter. |
| blocked | Compte bloqué temporairement. Réessayez dans 1 minute. |
| other_pc | Déconnecté car une autre session a été ouverte. |

> ℹ️ **Important :** L'application gère les sessions uniques. Si vous vous connectez depuis un autre poste, votre session précédente sera automatiquement fermée.

**Alertes de licence :** Lorsque la licence approche de son expiration, un message d'avertissement s'affiche à la connexion selon le nombre de jours restants (45, 15, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 ou 0 jours). Signalez ces alertes à votre administrateur sans délai.

### 2.3 Déconnexion

Pour vous déconnecter de l'application :

1. Cliquez sur le **bouton de déconnexion** situé dans la barre supérieure (icône de sortie).
2. Votre session est immédiatement fermée et vous êtes redirigé vers la page de connexion.

> ⚠️ **Attention :** Pensez toujours à vous déconnecter lorsque vous quittez votre poste de travail, afin d'éviter tout accès non autorisé à votre compte.

---

## 3. Présentation de l'interface

Après une connexion réussie, l'interface principale se compose de trois zones principales : la barre supérieure (topbar), le menu latéral (sidebar) et la zone de contenu centrale.

> 📸 **Figure 2 — Interface principale**
> *L'interface affiche en haut une barre de navigation horizontale (topbar), à gauche un menu latéral vertical (sidebar) avec les sections et modules, et au centre la zone de contenu qui affiche le tableau de bord par défaut.*

### 3.1 Barre supérieure (Topbar)

> 📸 **Figure 3 — Barre supérieure**
> *La topbar est une barre horizontale sombre en haut de l'écran. De gauche à droite : bouton hamburger, badge du projet au centre, puis à droite les icônes de langue, mode sombre, notifications (Super Admin), déconnexion, plein écran et paramètres BDD.*

La barre supérieure contient les éléments suivants :

| Élément | Description | Visibilité |
|---|---|---|
| 🍔 Bouton hamburger | Affiche ou masque le menu latéral | Tous les utilisateurs |
| Badge projet | Affiche le code du projet (ex : "TALIM") au centre | Tous les utilisateurs |
| Sélecteur de langue | Permet de choisir entre FR 🇫🇷, EN 🇬🇧 et MG 🇲🇬 | Tous les utilisateurs |
| 🌙 Mode sombre | Active ou désactive le thème sombre | Tous les utilisateurs |
| 🔔 Cloche notifications | Affiche les notifications système | Super Administrateur uniquement |
| 🚪 Déconnexion | Ferme la session en cours | Tous les utilisateurs |
| ⛶ Plein écran | Passe l'application en mode plein écran | Tous les utilisateurs |
| ⚙️ Paramètres BDD | Ouvre le panneau de paramètres (Control Sidebar) | Administrateur (sur page Utilisateurs) |

**Changer la langue de l'interface :**
1. Cliquez sur le sélecteur de langue dans la topbar.
2. Choisissez la langue souhaitée (FR, EN ou MG).
3. L'interface se recharge dans la langue sélectionnée.

### 3.2 Menu latéral (Sidebar)

> 📸 **Figure 4 — Menu latéral**
> *Le menu latéral est une colonne verticale à gauche de l'écran. En haut : logo et titre "Gestion de Stock". En dessous : bloc profil avec le rôle et le nom de l'utilisateur. Puis les sections de menu avec leurs icônes et libellés. Un badge rouge sur "Sorties" indique les bons non validés.*

Le menu latéral organise la navigation par sections :

**Section Accueil**
- 🏠 **Accueil** — Tableau de bord principal

**Section Paramètres**
- 📏 **Unité** — Gestion des unités de mesure
- 🏷️ **Catégories** — Gestion des catégories d'articles
- 🚚 **Fournisseurs** — Gestion des fournisseurs
- 📍 **Emplacements** — Gestion des emplacements de stockage

**Section Mouvements**
- 📦 **Articles** — Référentiel des articles
- ⬇️ **Entrées** — Bons d'entrée en stock
- ⬆️ **Sorties** — Bons de sortie de stock *(badge rouge : nombre de bons non validés)*
- 🏭 **Stock** — État actuel du stock

**Section Demandes**
- 📄 **Saisies** — Saisie de demandes de matériel
- ✅ **Accusés de réception** — Confirmation de réception

**Section Rapports**
- 📊 **Exploitations** — Analyse des mouvements
- 📋 **Inventaire** — État complet de l'inventaire

**Section Administration**
- 🔑 **Changer mot de passe** — Modification du mot de passe personnel
- 👤 **Utilisateurs** — Gestion des comptes utilisateurs
- 💻 **Requêtes SQL** — Exécution de requêtes SQL *(Super Admin uniquement)*

> ℹ️ **Important :** Seuls les menus auxquels vous avez accès sont affichés dans la sidebar. Les menus non autorisés sont masqués automatiquement.

> 💡 **Astuce :** Le badge rouge sur le menu "Sorties" vous indique en temps réel le nombre de bons de sortie en attente de validation. Cliquez dessus pour les traiter rapidement.

### 3.3 Panneau de paramètres (Control Sidebar)

> 📸 **Figure 5 — Panneau de paramètres (Control Sidebar)**
> *Un panneau latéral droit qui s'ouvre en cliquant sur le bouton paramètres BDD. Il affiche la date d'expiration de la licence, le nombre maximum d'utilisateurs autorisés, et pour le Super Admin, trois boutons d'action : Vérifier mises à jour, Sauvegarder BDD, Restaurer BDD.*

Ce panneau est accessible via le bouton ⚙️ **Paramètres BDD** dans la topbar (visible sur la page Utilisateurs pour les Administrateurs).

**Informations affichées :**
- **Date d'expiration de la licence** : date limite de validité de la licence
- **Nombre max d'utilisateurs** : quota d'utilisateurs simultanés autorisés

**Actions disponibles (Super Administrateur uniquement) :**

| Bouton | Action |
|---|---|
| Vérifier mises à jour | Vérifie si une nouvelle version de l'application est disponible |
| Sauvegarder BDD | Crée une sauvegarde de la base de données |
| Restaurer BDD | Restaure la base de données depuis une sauvegarde |

> ⚠️ **Attention :** Les opérations de sauvegarde et restauration de la base de données sont irréversibles et doivent être effectuées avec précaution. Seul le Super Administrateur peut les exécuter.

### 3.4 Tableau de bord

> 📸 **Figure 6 — Tableau de bord**
> *La page d'accueil affiche en haut une rangée de cartes KPI colorées (indicateurs clés), puis deux graphiques côte à côte (évolution des mouvements et répartition par catégorie), et en bas un tableau des alertes de stock.*

Le tableau de bord est la page d'accueil de l'application. Il offre une vue synthétique de l'état du stock.

**Cartes KPI (indicateurs clés de performance) :**

| Indicateur | Description | Lien |
|---|---|---|
| Articles actifs | Nombre total d'articles actifs dans le référentiel | → Module Articles |
| Alertes stock | Nombre d'articles sous le seuil d'alerte | → Module Stock |
| Entrées du mois | Nombre de bons d'entrée du mois en cours | → Module Entrées |
| Sorties du mois | Nombre de bons de sortie du mois en cours | → Module Sorties |
| Demandes en cours | Nombre de demandes en attente de traitement | → Module Saisies |
| Valeur totale du stock | Valeur financière totale du stock actuel | — |

> ℹ️ **Important :** Les cartes KPI sont affichées selon vos permissions. Si vous n'avez pas accès à un module, la carte correspondante peut ne pas être visible.

**Graphiques :**
- **Évolution des mouvements** : courbe ou histogramme montrant les entrées et sorties sur une période
- **Répartition par catégorie** : graphique en secteurs montrant la distribution du stock par catégorie

**Alertes stock :** En bas de la page, un tableau liste les articles dont le stock est inférieur au seuil d'alerte ou en rupture totale. Ces alertes nécessitent une action rapide (commande de réapprovisionnement).

> 💡 **Astuce :** Cliquez sur une carte KPI pour accéder directement au module correspondant et obtenir le détail des données.

---

## 4. Gestion des utilisateurs et des droits

### 4.1 Rôles disponibles

GESTIONSTOCK 2.0 définit cinq niveaux de rôles utilisateurs, chacun avec des droits spécifiques :

| Rôle | Code | Description |
|---|---|---|
| **Super Administrateur** | Rôle 0 | Accès total à TOUS les menus, y compris Requêtes SQL. Peut effectuer des sauvegardes/restaurations de la BDD et vérifier les mises à jour. |
| **Administrateur** | Rôle 1 | Accès à tous les menus SAUF Requêtes SQL. |
| **Utilisateur** | Rôle 2 | Accès limité selon les permissions définies par l'administrateur. |
| **Logisticien** | Rôle 3 | Accès limité selon les permissions définies par l'administrateur. |
| **Comptable** | Rôle 4 | Accès limité selon les permissions définies par l'administrateur. |

> ℹ️ **Important :** Les rôles Utilisateur, Logisticien et Comptable ont des accès personnalisables. L'administrateur définit précisément quels menus sont accessibles pour chaque compte.

### 4.2 Permissions par menu

Les permissions sont gérées individuellement par menu. Voici la liste des codes de menu gérés par le système :

| Code menu | Module correspondant |
|---|---|
| `accueil` | Tableau de bord |
| `unites` | Unités |
| `categories` | Catégories |
| `fournisseurs` | Fournisseurs |
| `emplacements` | Emplacements |
| `articles` | Articles |
| `entrees` | Entrées |
| `sorties` | Sorties |
| `stock` | Stock |
| `saisies` | Saisies de demandes |
| `accuses` | Accusés de réception |
| `exploitation` | Exploitations |
| `resetpwd` | Changer mot de passe |
| `utilisateurs` | Utilisateurs |
| `requetes` | Requêtes SQL |

> 💡 **Astuce :** Pour modifier les permissions d'un utilisateur, rendez-vous dans **Administration → Utilisateurs**, puis cliquez sur **Modifier** pour l'utilisateur concerné. Cochez ou décochez les cases correspondant aux menus autorisés.

---

## 5. Module Paramètres

Les paramètres constituent les données de référence de l'application. Ils doivent être configurés avant de commencer à utiliser les modules de mouvements.

> ⚠️ **Attention :** La suppression d'un paramètre (unité, catégorie, fournisseur, emplacement) peut affecter les articles qui y sont associés. Vérifiez les dépendances avant toute suppression.

### 5.1 Unités

**Accès :** Menu latéral → Section Paramètres → **Unité**  
**URL :** `/pages/parametres/unites/unites.aspx`

> 📸 **Figure 7 — Module Unités**
> *La page affiche un tableau listant toutes les unités de mesure avec leurs colonnes : Code, Libellé, Description, Statut et Actions. En haut à droite, les boutons Ajouter et Rafraîchir.*

**Objectif :** Gérer les unités de mesure utilisées pour quantifier les articles en stock (ex : pièce, kg, litre, mètre, boîte, etc.).

**Description du tableau :**

| Colonne | Description |
|---|---|
| Code | Identifiant court de l'unité (ex : PCS, KG, L) |
| Libellé | Nom complet de l'unité (ex : Pièce, Kilogramme, Litre) |
| Description | Description optionnelle de l'unité |
| Statut | Actif ou Inactif |
| Actions | Boutons Modifier et Supprimer |

**Boutons disponibles :**
- **Ajouter** : ouvre le formulaire de création d'une nouvelle unité
- **Rafraîchir** : recharge la liste des unités

**Procédure — Ajouter une unité :**
1. Cliquez sur le bouton **Ajouter**.
2. Dans le formulaire qui s'ouvre, renseignez les champs :
   - **Code** *(obligatoire)* : saisissez un code court et unique (ex : PCS)
   - **Libellé** *(obligatoire)* : saisissez le nom complet de l'unité
   - **Description** *(optionnel)* : ajoutez une description si nécessaire
   - **Statut** : sélectionnez **Actif** ou **Inactif**
3. Cliquez sur **Enregistrer**.
4. Le message "Opération effectuée avec succès" confirme la création.

**Procédure — Modifier une unité :**
1. Dans le tableau, cliquez sur le bouton **Modifier** de la ligne concernée.
2. Modifiez les champs souhaités dans le formulaire.
3. Cliquez sur **Enregistrer**.

**Procédure — Supprimer une unité :**
1. Cliquez sur le bouton **Supprimer** de la ligne concernée.
2. Une boîte de dialogue demande : *"Voulez-vous vraiment supprimer cet élément ?"*
3. Confirmez pour procéder à la suppression.

> ⚠️ **Attention :** Une unité ne peut pas être supprimée si elle est utilisée par des articles existants.

### 5.2 Catégories

**Accès :** Menu latéral → Section Paramètres → **Catégories**  
**URL :** `/pages/parametres/categories/categories.aspx`

> 📸 **Figure 8 — Module Catégories**
> *La page affiche trois cartes de synthèse en haut (Catégories totales, Catégories actives, Catégories inactives), puis un tableau avec les colonnes Nom, Description, Statut et Actions. Les boutons Ajouter et Rafraîchir sont en haut à droite.*

**Objectif :** Organiser les articles par familles ou types pour faciliter la recherche et les rapports.

**Cartes de synthèse :**
- **Catégories totales** : nombre total de catégories enregistrées
- **Catégories actives** : nombre de catégories avec statut Actif
- **Catégories inactives** : nombre de catégories avec statut Inactif

**Description du tableau :**

| Colonne | Description |
|---|---|
| Nom | Nom de la catégorie |
| Description | Description de la catégorie |
| Statut | Actif ou Inactif |
| Actions | Boutons Modifier et Supprimer |

**Procédure — Ajouter une catégorie :**
1. Cliquez sur **Ajouter**.
2. Renseignez les champs :
   - **Nom de la catégorie** *(obligatoire)*
   - **Description** *(optionnel)*
   - **Statut** : Actif ou Inactif
3. Cliquez sur **Enregistrer**.

> 💡 **Astuce :** Créez des catégories cohérentes avec votre organisation (ex : Fournitures de bureau, Matériel informatique, Consommables, etc.) pour faciliter les rapports d'exploitation.

### 5.3 Fournisseurs

**Accès :** Menu latéral → Section Paramètres → **Fournisseurs**  
**URL :** `/pages/parametres/fournisseurs/fournisseurs.aspx`

> 📸 **Figure 9 — Module Fournisseurs**
> *La page affiche quatre cartes de synthèse (Total fournisseurs, Actifs, Inactifs, Avec email), puis un tableau avec les colonnes Nom, Contact, Email, Téléphone, Adresse, Statut et Actions. Les boutons Ajouter et Exporter Excel sont en haut à droite.*

**Objectif :** Gérer le répertoire des fournisseurs auprès desquels les articles sont approvisionnés.

**Cartes de synthèse :**
- **Total fournisseurs** : nombre total de fournisseurs
- **Actifs** : fournisseurs avec statut Actif
- **Inactifs** : fournisseurs avec statut Inactif
- **Avec email** : fournisseurs ayant une adresse email renseignée

**Description du tableau :**

| Colonne | Description |
|---|---|
| Nom | Raison sociale ou nom du fournisseur |
| Contact | Nom du contact principal |
| Email | Adresse email du fournisseur |
| Téléphone | Numéro de téléphone |
| Adresse | Adresse postale |
| Statut | Actif ou Inactif |
| Actions | Boutons Modifier et Supprimer |

**Boutons disponibles :**
- **Ajouter** : ouvre le formulaire de création
- **Exporter Excel** : exporte la liste des fournisseurs au format Excel

**Procédure — Ajouter un fournisseur :**
1. Cliquez sur **Ajouter**.
2. Renseignez les champs :
   - **Nom** *(obligatoire)* : raison sociale ou nom du fournisseur
   - **Contact** *(optionnel)* : nom du contact principal
   - **Email** *(optionnel)* : adresse email (doit être valide)
   - **Téléphone** *(optionnel)* : numéro de téléphone
   - **Adresse** *(optionnel)* : adresse postale complète
   - **Statut** : Actif ou Inactif
3. Cliquez sur **Enregistrer**.

> ℹ️ **Important :** Si vous saisissez une adresse email, elle doit être au format valide (ex : contact@fournisseur.com). Un message d'erreur "Adresse email invalide" s'affichera sinon.

### 5.4 Emplacements

**Accès :** Menu latéral → Section Paramètres → **Emplacements**  
**URL :** `/pages/parametres/emplacements/emplacements.aspx`

> 📸 **Figure 10 — Module Emplacements**
> *La page affiche un tableau listant les emplacements de stockage avec les colonnes Code, Libellé, Description, Statut et Actions. Les boutons Ajouter et Rafraîchir sont en haut à droite.*

**Objectif :** Définir les zones physiques de stockage (entrepôts, rayons, armoires, etc.) pour localiser précisément chaque article.

**Description du tableau :**

| Colonne | Description |
|---|---|
| Code | Identifiant court de l'emplacement (ex : ENT-A, RAYON-01) |
| Libellé | Nom complet de l'emplacement |
| Description | Description optionnelle |
| Statut | Actif ou Inactif |
| Actions | Boutons Modifier et Supprimer |

**Procédure — Ajouter un emplacement :**
1. Cliquez sur **Ajouter**.
2. Renseignez les champs :
   - **Code** *(obligatoire)* : code unique de l'emplacement
   - **Libellé** *(obligatoire)* : nom descriptif de l'emplacement
   - **Description** *(optionnel)*
   - **Statut** : Actif ou Inactif
3. Cliquez sur **Enregistrer**.

> 💡 **Astuce :** Utilisez une nomenclature cohérente pour les codes d'emplacement (ex : ZONE-A-01, ZONE-A-02) pour faciliter la localisation physique des articles.

---

## 6. Module Mouvements

### 6.1 Articles

**Accès :** Menu latéral → Section Mouvements → **Articles**  
**URL :** `/pages/modules/articles/articles.aspx`

> 📸 **Figure 11 — Module Articles**
> *La page affiche quatre cartes de synthèse colorées (Articles actifs, Stock normal, En alerte, En rupture), puis un tableau complet des articles avec toutes leurs informations. Les boutons Ajouter, Exporter et Rafraîchir sont en haut à droite du tableau.*

**Objectif :** Gérer le référentiel complet des articles gérés en stock. C'est le module central de l'application.

**Cartes de synthèse :**
- **Articles actifs** : nombre total d'articles avec statut Actif
- **Stock normal** : articles dont le stock est au-dessus du seuil d'alerte
- **En alerte** : articles dont le stock est inférieur ou égal au seuil d'alerte
- **En rupture** : articles avec un stock à zéro

**Description du tableau :**

| Colonne | Description |
|---|---|
| Code | Code unique de l'article |
| Désignation | Nom ou description de l'article |
| Catégorie | Catégorie à laquelle appartient l'article |
| Unité | Unité de mesure de l'article |
| Emplacement | Zone de stockage de l'article |
| Fournisseur | Fournisseur principal de l'article |
| Stock actuel | Quantité actuellement en stock |
| Seuil d'alerte | Quantité minimale déclenchant une alerte |
| Statut | Actif ou Inactif |
| Actions | Boutons Modifier et Supprimer |

**Boutons disponibles :**
- **Ajouter** : ouvre le formulaire de création d'un article
- **Exporter** : exporte la liste des articles au format Excel
- **Rafraîchir** : recharge la liste

**Procédure — Ajouter un article :**
1. Cliquez sur **Ajouter**.
2. Renseignez les champs du formulaire :
   - **Code article** *(obligatoire)* : code unique identifiant l'article
   - **Désignation** *(obligatoire)* : nom complet de l'article
   - **Catégorie** *(obligatoire)* : sélectionnez dans la liste déroulante
   - **Unité** *(obligatoire)* : sélectionnez l'unité de mesure
   - **Emplacement** *(obligatoire)* : sélectionnez la zone de stockage
   - **Fournisseur** *(optionnel)* : sélectionnez le fournisseur principal
   - **Seuil d'alerte** *(obligatoire)* : quantité minimale avant alerte
   - **Statut** : Actif ou Inactif
3. Cliquez sur **Enregistrer**.
4. Le message "Opération effectuée avec succès" confirme la création.

**Procédure — Modifier un article :**
1. Cliquez sur **Modifier** sur la ligne de l'article.
2. Modifiez les champs nécessaires.
3. Cliquez sur **Enregistrer**.

**Procédure — Supprimer un article :**
1. Cliquez sur **Supprimer** sur la ligne de l'article.
2. Confirmez la suppression dans la boîte de dialogue.

> ⚠️ **Attention :** La suppression d'un article est irréversible. Vérifiez qu'aucun mouvement de stock en cours ne concerne cet article avant de le supprimer. Préférez le passage en statut **Inactif** pour conserver l'historique.

> ℹ️ **Important :** Le stock actuel d'un article est automatiquement mis à jour lors de la validation des bons d'entrée et de sortie. Ne modifiez pas manuellement cette valeur.

### 6.2 Entrées

**Accès :** Menu latéral → Section Mouvements → **Entrées**  
**URL :** `/pages/modules/entrees/entrees.aspx`

> 📸 **Figure 12 — Module Entrées (Bons d'entrée)**
> *La page titre "Bons d'entrée" affiche quatre cartes de synthèse (Total bons, Validés, Brouillons, Annulés), puis un tableau des bons d'entrée avec filtres. Les boutons Nouveau bon d'entrée, Exporter PDF, Exporter Excel et Rafraîchir sont en haut à droite.*

**Objectif :** Enregistrer les réceptions de marchandises et mettre à jour le stock en conséquence.

**Cartes de synthèse :**
- **Total bons** : nombre total de bons d'entrée
- **Validés** : bons d'entrée validés (stock mis à jour)
- **Brouillons** : bons en cours de saisie, non encore validés
- **Annulés** : bons annulés

**Structure d'un bon d'entrée :**

| Champ | Description |
|---|---|
| Numéro | Numéro automatique du bon d'entrée |
| Date | Date de réception des marchandises |
| Fournisseur | Fournisseur ayant livré les articles |
| Articles | Liste des lignes : article + quantité reçue |
| Statut | Brouillon / Validé / Annulé |
| Observations | Notes ou commentaires libres |

**Statuts d'un bon d'entrée :**
- **Brouillon** : bon créé mais non validé, modifiable
- **Validé** : bon validé, stock mis à jour, non modifiable
- **Annulé** : bon annulé, sans effet sur le stock

**Boutons disponibles :**
- **Nouveau bon d'entrée** : crée un nouveau bon
- **Exporter PDF** : exporte la liste en PDF
- **Exporter Excel** : exporte la liste en Excel
- **Rafraîchir** : recharge la liste

**Actions par ligne :**

| Action | Disponibilité | Description |
|---|---|---|
| Voir détail | Tous statuts | Affiche le détail complet du bon |
| Modifier | Brouillon uniquement | Modifie le bon |
| Valider | Brouillon uniquement | Valide le bon et met à jour le stock |
| Annuler | Brouillon uniquement | Annule le bon |
| Supprimer | Brouillon uniquement | Supprime définitivement le bon |

**Procédure — Créer un bon d'entrée :**
1. Cliquez sur **Nouveau bon d'entrée**.
2. Renseignez les informations générales :
   - **Date** *(obligatoire)* : date de réception
   - **Fournisseur** *(obligatoire)* : sélectionnez le fournisseur
   - **Observations** *(optionnel)* : notes complémentaires
3. Ajoutez les lignes d'articles :
   - Sélectionnez l'**article** dans la liste déroulante
   - Saisissez la **quantité** reçue
   - Répétez pour chaque article reçu
4. Cliquez sur **Enregistrer** pour sauvegarder en brouillon.

**Procédure — Valider un bon d'entrée :**
1. Dans le tableau, repérez le bon en statut **Brouillon**.
2. Cliquez sur **Valider**.
3. Confirmez la validation.
4. Le stock des articles concernés est automatiquement mis à jour.

> ⚠️ **Attention :** La validation d'un bon d'entrée est irréversible. Une fois validé, le bon ne peut plus être modifié ni supprimé. Vérifiez soigneusement les quantités avant de valider.

> 💡 **Astuce :** Utilisez le statut **Brouillon** pour préparer un bon d'entrée à l'avance et le valider uniquement lors de la réception physique des marchandises.

### 6.3 Sorties

**Accès :** Menu latéral → Section Mouvements → **Sorties**  
**URL :** `/pages/modules/sorties/sorties.aspx`

> 📸 **Figure 13 — Module Sorties (Bons de sortie)**
> *La page titre "Bons de sortie" affiche quatre cartes de synthèse (Total bons, Validés, QR vide et En cours, Annulés), puis un tableau des bons de sortie. Les boutons Nouveau bon de sortie, Exporter PDF, Exporter Excel et Rafraîchir sont en haut à droite. Un badge rouge dans le menu latéral indique le nombre de bons non validés.*

**Objectif :** Enregistrer les sorties de marchandises du stock et gérer leur validation.

**Cartes de synthèse :**
- **Total bons** : nombre total de bons de sortie
- **Validés** : bons de sortie validés (stock mis à jour)
- **QR vide et En cours** : bons en attente de traitement
- **Annulés** : bons annulés

**Structure d'un bon de sortie :**

| Champ | Description |
|---|---|
| Numéro | Numéro automatique du bon de sortie |
| Date | Date de la sortie |
| Demandeur | Personne ou service demandant les articles |
| Articles | Liste des lignes : article + quantité sortie |
| Statut | Brouillon / Validé / Annulé |
| Observations | Notes ou commentaires libres |

**Actions par ligne :**

| Action | Description |
|---|---|
| Voir détail | Affiche le détail complet du bon |
| Modifier | Modifie le bon (si modifiable) |
| Valider | Valide le bon et met à jour le stock |
| Annuler | Annule le bon |
| Supprimer | Supprime le bon |

**Procédure — Créer un bon de sortie :**
1. Cliquez sur **Nouveau bon de sortie**.
2. Renseignez les informations générales :
   - **Date** *(obligatoire)*
   - **Demandeur** *(obligatoire)* : personne ou service bénéficiaire
   - **Observations** *(optionnel)*
3. Ajoutez les lignes d'articles :
   - Sélectionnez l'**article**
   - Saisissez la **quantité** à sortir
4. Cliquez sur **Enregistrer**.

**Procédure — Valider un bon de sortie :**
1. Repérez le bon à valider dans le tableau.
2. Cliquez sur **Valider**.
3. Confirmez la validation.
4. Le stock est mis à jour et le bon passe en statut **Validé**.
5. Le bon devient éligible à l'accusé de réception.

> ⚠️ **Attention :** Vous ne pouvez pas sortir une quantité supérieure au stock disponible. L'application bloquera la validation si le stock est insuffisant.

> ℹ️ **Important :** Après validation d'un bon de sortie, le destinataire doit effectuer un **accusé de réception** pour confirmer la réception physique des articles (voir section 7.2).

### 6.4 Stock

**Accès :** Menu latéral → Section Mouvements → **Stock**  
**URL :** `/pages/modules/stock/stock.aspx`

> 📸 **Figure 14 — Module Stock**
> *La page titre "Stock" affiche quatre cartes de synthèse (Articles en stock, Quantité totale, Sous seuil d'alerte, En rupture), puis un tableau de l'état du stock avec des filtres en haut. Les boutons Exporter PDF, Exporter Excel et Rafraîchir sont disponibles.*

**Objectif :** Consulter en temps réel l'état du stock pour tous les articles.

**Cartes de synthèse :**
- **Articles en stock** : nombre d'articles avec une quantité positive
- **Quantité totale** : somme de toutes les quantités en stock
- **Sous seuil d'alerte** : articles dont le stock est inférieur au seuil défini
- **En rupture (0)** : articles avec un stock à zéro

**Description du tableau :**

| Colonne | Description |
|---|---|
| Article | Code et désignation de l'article |
| Catégorie | Catégorie de l'article |
| Emplacement | Zone de stockage |
| Quantité en stock | Quantité actuellement disponible |
| Seuil d'alerte | Quantité minimale définie |
| Statut stock | Normal / Alerte / Rupture |

**Filtres disponibles :**
- **Par catégorie** : affiche uniquement les articles d'une catégorie
- **Par emplacement** : affiche uniquement les articles d'une zone de stockage
- **Par statut stock** : filtre par Normal, Alerte ou Rupture

**Boutons disponibles :**
- **Exporter PDF** : exporte l'état du stock en PDF
- **Exporter Excel** : exporte l'état du stock en Excel
- **Rafraîchir** : recharge les données

> 💡 **Astuce :** Utilisez les filtres combinés pour identifier rapidement les articles en rupture dans une zone spécifique et déclencher les commandes de réapprovisionnement.

> ℹ️ **Important :** Le stock est en lecture seule dans ce module. Les modifications de stock se font uniquement via les bons d'entrée et de sortie.

---

## 7. Module Demandes

### 7.1 Saisies

**Accès :** Menu latéral → Section Demandes → **Saisies**  
**URL :** `/pages/demandes/saisie/saisies.aspx`

> 📸 **Figure 15 — Module Saisies**
> *La page titre "Saisie de demande" affiche quatre cartes de synthèse personnelles (Total demandes, Validées, En cours, Annulées), puis le tableau des demandes de l'utilisateur connecté. Les boutons Nouvelle demande, Exporter PDF et Exporter Excel sont disponibles.*

**Objectif :** Permettre aux utilisateurs de soumettre des demandes de matériel qui seront traitées par le gestionnaire de stock.

**Cartes de synthèse (données personnelles) :**
- **Total demandes** : nombre total de vos demandes
- **Validées** : demandes approuvées et traitées
- **En cours** : demandes en attente de traitement
- **Annulées** : demandes annulées

**Structure d'une demande :**

| Champ | Description |
|---|---|
| Date | Date de la demande (automatique) |
| Demandeur | Nom de l'utilisateur connecté (automatique) |
| Articles demandés | Liste des articles et quantités souhaitées |
| Motif/Observations | Justification de la demande |
| Statut | En cours / Validé / Annulé |

**Statuts d'une demande :**
- **En cours** : demande soumise, en attente de traitement par le gestionnaire
- **Validé** : demande approuvée, un bon de sortie a été créé
- **Annulé** : demande annulée (par l'utilisateur ou le gestionnaire)

**Actions par ligne :**

| Action | Disponibilité | Description |
|---|---|---|
| Voir | Tous statuts | Affiche le détail de la demande |
| Modifier | En cours uniquement | Modifie la demande |
| Annuler | En cours uniquement | Annule la demande |
| Supprimer | En cours uniquement | Supprime la demande |

**Procédure — Créer une nouvelle demande :**
1. Cliquez sur **Nouvelle demande**.
2. Le champ **Demandeur** est automatiquement rempli avec votre nom.
3. Ajoutez les articles demandés :
   - Sélectionnez l'**article** dans la liste
   - Saisissez la **quantité** souhaitée
   - Répétez pour chaque article
4. Renseignez le **Motif/Observations** pour justifier votre demande.
5. Cliquez sur **Enregistrer**.
6. Votre demande est soumise avec le statut **En cours**.

> 💡 **Astuce :** Soyez précis dans le champ Motif/Observations pour faciliter le traitement de votre demande par le gestionnaire.

> ℹ️ **Important :** Une fois votre demande validée par le gestionnaire, un bon de sortie est créé. Vous devrez ensuite effectuer un **accusé de réception** pour confirmer que vous avez bien reçu les articles.

### 7.2 Accusés de réception

**Accès :** Menu latéral → Section Demandes → **Accusés de réception**  
**URL :** `/pages/demandes/accuse/accuses.aspx`

> 📸 **Figure 16 — Module Accusés de réception**
> *La page titre "Accusés de réception" affiche trois cartes de synthèse (Total, En attente de validation, Annulés), puis un tableau des bons de sortie validés en attente d'accusé. Les boutons Exporter PDF et Exporter Excel sont disponibles.*

**Objectif :** Confirmer la réception physique des articles issus des bons de sortie validés. Cette étape clôture le cycle de la demande.

**Cartes de synthèse :**
- **Total** : nombre total d'accusés de réception
- **En attente de validation** : bons de sortie validés en attente d'accusé
- **Annulés** : accusés annulés

**Procédure — Accuser réception :**
1. Dans le tableau, repérez le bon de sortie en attente d'accusé.
2. Cliquez sur **Accuser réception**.
3. Confirmez que vous avez bien reçu physiquement les articles listés.
4. Le bon passe au statut **Terminé** et le cycle de la demande est clôturé.

> ⚠️ **Attention :** N'accusez réception que si vous avez effectivement reçu les articles. Cette action confirme la réception physique et clôture définitivement le bon de sortie.

---

## 8. Module Rapports

### 8.1 Exploitations

**Accès :** Menu latéral → Section Rapports → **Exploitations**  
**URL :** `/pages/exploitations/exp/exploitations.aspx`

> 📸 **Figure 17 — Module Exploitations**
> *La page titre "Exploitations — Analyse des mouvements de stock" affiche une barre de filtres en haut (dates, type, article, demandeur), puis un tableau des mouvements filtrés. Les boutons Exporter PDF et Exporter Excel sont disponibles.*

**Objectif :** Analyser l'historique des mouvements de stock (entrées et sorties) sur une période donnée.

**Filtres disponibles :**

| Filtre | Description |
|---|---|
| Date début | Date de début de la période d'analyse |
| Date fin | Date de fin de la période d'analyse |
| Type | Tous / Entrée / Sortie |
| Article | Filtrer sur un article spécifique |
| Demandeur | Filtrer par demandeur |

**Procédure — Analyser les mouvements :**
1. Définissez la **Date début** et la **Date fin** de la période.
2. Sélectionnez le **Type** de mouvement (Tous, Entrée ou Sortie).
3. Optionnellement, filtrez par **Article** ou **Demandeur**.
4. Cliquez sur **Rechercher** (ou le tableau se met à jour automatiquement).
5. Consultez les résultats dans le tableau.

**Boutons disponibles :**
- **Exporter PDF** : exporte les résultats filtrés en PDF
- **Exporter Excel** : exporte les résultats filtrés en Excel

> 💡 **Astuce :** Pour un rapport mensuel, définissez la date début au 1er du mois et la date fin au dernier jour du mois. Exportez en Excel pour effectuer des analyses complémentaires.

### 8.2 Inventaire

**Accès :** Menu latéral → Section Rapports → **Inventaire**  
**URL :** `/pages/exploitations/inv/inventaires.aspx`

> 📸 **Figure 18 — Module Inventaire**
> *La page titre "Inventaire — Consultation et analyse de l'état actuel des stocks" affiche six cartes de synthèse (Total articles, Articles en stock, Stock faible, En rupture, Valeur totale, Catégories), puis un tableau d'inventaire complet. Les boutons Exporter PDF et Exporter Excel sont disponibles.*

**Objectif :** Obtenir une vue complète et détaillée de l'état actuel de l'inventaire, incluant les valorisations.

**Cartes de synthèse :**
- **Total articles** : nombre total d'articles dans le référentiel
- **Articles en stock** : articles avec une quantité positive
- **Stock faible** : articles sous le seuil d'alerte
- **En rupture** : articles avec stock à zéro
- **Valeur totale** : valeur financière totale de l'inventaire
- **Catégories** : nombre de catégories représentées

**Boutons disponibles :**
- **Exporter PDF** : exporte l'inventaire complet en PDF
- **Exporter Excel** : exporte l'inventaire complet en Excel

> 💡 **Astuce :** Exportez l'inventaire en Excel en fin de période pour archiver l'état du stock et le comparer aux périodes précédentes.

> ℹ️ **Important :** L'inventaire reflète l'état du stock en temps réel au moment de la consultation. Pour un inventaire à une date précise, utilisez le module Exploitations avec les filtres de date.

---

## 9. Module Administration

> ⚠️ **Attention :** Les fonctionnalités d'administration sont réservées aux Administrateurs et au Super Administrateur. Un accès non autorisé à ces modules est bloqué par le système.

### 9.1 Changer le mot de passe

**Accès :** Menu latéral → Section Administration → **Changer mot de passe**  
**URL :** `/pages/administrations/reset/resetpwd.aspx`

> 📸 **Figure 19 — Changer le mot de passe**
> *La page affiche un formulaire avec trois champs (Ancien mot de passe, Nouveau mot de passe, Confirmation du nouveau mot de passe) et un indicateur de force du mot de passe (Faible / Moyen / Fort). Le bouton Enregistrer est en bas du formulaire.*

**Objectif :** Permettre à chaque utilisateur de modifier son propre mot de passe de connexion.

**Champs du formulaire :**

| Champ | Description |
|---|---|
| Ancien mot de passe | Votre mot de passe actuel |
| Nouveau mot de passe | Le nouveau mot de passe souhaité |
| Confirmation du nouveau mot de passe | Répétition du nouveau mot de passe |

**Indicateur de force du mot de passe :**
- 🔴 **Faible** : mot de passe trop simple ou trop court
- 🟡 **Moyen** : mot de passe acceptable
- 🟢 **Fort** : mot de passe sécurisé (recommandé)

**Procédure — Changer son mot de passe :**
1. Saisissez votre **Ancien mot de passe**.
2. Saisissez votre **Nouveau mot de passe**.
3. Observez l'indicateur de force : visez le niveau **Fort**.
4. Saisissez à nouveau le nouveau mot de passe dans **Confirmation**.
5. Cliquez sur **Enregistrer**.
6. Le message "Opération effectuée avec succès" confirme le changement.

**Messages d'erreur possibles :**

| Message | Cause |
|---|---|
| Le mot de passe doit contenir au moins {min} caractères | Nouveau mot de passe trop court |
| Les mots de passe ne correspondent pas | La confirmation ne correspond pas au nouveau mot de passe |
| Ce champ est obligatoire | Un champ est vide |

> 💡 **Astuce :** Choisissez un mot de passe fort combinant majuscules, minuscules, chiffres et caractères spéciaux. Changez votre mot de passe régulièrement pour renforcer la sécurité de votre compte.

### 9.2 Utilisateurs

**Accès :** Menu latéral → Section Administration → **Utilisateurs**  
**URL :** `/pages/administrations/utilisateur/utilisateur.aspx`

> 📸 **Figure 20 — Module Utilisateurs**
> *La page titre "Liste des utilisateurs" affiche un tableau avec les colonnes Nom d'utilisateur, Nom complet, Email, Rôle, Téléphone, Date de création, Statut et Actions. Les boutons Ajouter et Exporter Excel sont en haut à droite. Le bouton Paramètres BDD apparaît dans la topbar.*

**Objectif :** Gérer les comptes utilisateurs de l'application : création, modification, suppression et gestion des droits d'accès.

**Description du tableau :**

| Colonne | Description |
|---|---|
| Nom d'utilisateur | Identifiant de connexion |
| Nom complet | Prénom et nom de l'utilisateur |
| Email | Adresse email |
| Rôle | Rôle attribué (Super Admin, Admin, Utilisateur, Logisticien, Comptable) |
| Téléphone | Numéro de téléphone |
| Date de création | Date de création du compte |
| Statut | Actif ou Inactif |
| Actions | Boutons Modifier, Supprimer, Déconnecter |

**Boutons disponibles :**
- **Ajouter** : crée un nouveau compte utilisateur
- **Exporter Excel** : exporte la liste des utilisateurs

**Actions par ligne :**

| Action | Description |
|---|---|
| Modifier | Modifie les informations et permissions de l'utilisateur |
| Supprimer | Supprime définitivement le compte |
| Déconnecter | Force la déconnexion immédiate de l'utilisateur |

**Procédure — Créer un utilisateur :**
1. Cliquez sur **Ajouter**.
2. Renseignez les informations du compte :
   - **Nom d'utilisateur** *(obligatoire)* : identifiant unique de connexion
   - **Nom complet** *(obligatoire)* : prénom et nom
   - **Email** *(optionnel)* : adresse email valide
   - **Téléphone** *(optionnel)*
   - **Rôle** *(obligatoire)* : sélectionnez le rôle approprié
   - **Mot de passe** *(obligatoire)* : mot de passe initial
3. Définissez les **Permissions et accès au menu** :
   - Une liste de cases à cocher apparaît pour chaque menu disponible
   - Cochez les menus auxquels l'utilisateur doit avoir accès
4. Cliquez sur **Enregistrer**.

**Procédure — Forcer la déconnexion d'un utilisateur :**
1. Repérez l'utilisateur dans le tableau.
2. Cliquez sur **Déconnecter**.
3. L'utilisateur est immédiatement déconnecté et verra le message : *"Vous avez été déconnecté par l'administrateur."*

> ⚠️ **Attention :** La suppression d'un compte utilisateur est irréversible. Préférez le passage en statut **Inactif** pour désactiver temporairement un compte sans perdre l'historique.

> ℹ️ **Important :** Le nombre maximum d'utilisateurs actifs est limité par la licence. Si ce quota est atteint, la création de nouveaux comptes sera bloquée.

### 9.3 Requêtes SQL

**Accès :** Menu latéral → Section Administration → **Requêtes SQL**  
**URL :** `/pages/administrations/requete/requetes.aspx`

> 📸 **Figure 21 — Module Requêtes SQL**
> *La page affiche un éditeur de texte permettant de saisir des requêtes SQL, avec un bouton d'exécution et une zone d'affichage des résultats.*

**Objectif :** Permettre au Super Administrateur d'exécuter des requêtes SQL directement sur la base de données pour des opérations avancées de consultation ou de maintenance.

> ⚠️ **Attention :** Ce module est **exclusivement réservé au Super Administrateur**. L'exécution de requêtes SQL incorrectes peut endommager irrémédiablement la base de données. N'utilisez ce module que si vous maîtrisez parfaitement le SQL et la structure de la base de données.

> ⚠️ **Attention :** Évitez les requêtes de type `DROP`, `TRUNCATE` ou `DELETE` sans clause `WHERE` précise. Effectuez toujours une sauvegarde de la base de données avant toute opération critique.

---

## 10. Workflows des processus métier

### 10.1 Workflow des demandes de sortie

Ce workflow décrit le cycle complet d'une demande de matériel, de la saisie jusqu'à la confirmation de réception.

```
┌─────────────────────────────────────────────────────────────────────┐
│                  WORKFLOW DES DEMANDES DE SORTIE                    │
└─────────────────────────────────────────────────────────────────────┘

  [UTILISATEUR]              [GESTIONNAIRE/ADMIN]         [UTILISATEUR]
       │                            │                           │
       ▼                            │                           │
  Saisie de la              ┌───────┴──────┐                   │
  demande                   │              │                   │
  (Module Saisies)          │              │                   │
       │                    │              │                   │
       ▼                    │              │                   │
  Statut: EN COURS ─────────►  Traitement  │                   │
                            │  de la       │                   │
                            │  demande     │                   │
                            │              │                   │
                    ┌───────┴──────┐       │                   │
                    │              │       │                   │
                    ▼              ▼       │                   │
               VALIDATION      REFUS/     │                   │
               de la demande   ANNULATION │                   │
                    │                     │                   │
                    ▼                     │                   │
              Création d'un              │                   │
              Bon de sortie              │                   │
              (Module Sorties)           │                   │
                    │                    │                   │
                    ▼                    │                   │
              Statut: VALIDÉ ────────────┼──────────────────►│
                                         │              Accusé de
                                         │              réception
                                         │              (Module Accusés)
                                         │                   │
                                         │                   ▼
                                         │             Statut: TERMINÉ
                                         │
```

**Résumé du workflow :**

| Étape | Acteur | Action | Statut résultant |
|---|---|---|---|
| 1 | Utilisateur | Saisit une demande de matériel | En cours |
| 2 | Gestionnaire/Admin | Traite la demande | — |
| 3a | Gestionnaire/Admin | Valide la demande → crée un bon de sortie | Validé |
| 3b | Gestionnaire/Admin | Refuse ou annule la demande | Annulé |
| 4 | Gestionnaire/Admin | Valide le bon de sortie | Stock mis à jour |
| 5 | Utilisateur | Accuse réception des articles | Terminé |

### 10.2 Workflow des bons d'entrée

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW DES BONS D'ENTRÉE                       │
└─────────────────────────────────────────────────────────────────────┘

  [GESTIONNAIRE/ADMIN]
         │
         ▼
    Création du bon
    d'entrée
    (Fournisseur + Articles + Quantités)
         │
         ▼
    Statut: BROUILLON
    (Modifiable, non comptabilisé)
         │
         ├──────────────────────────────────────────┐
         │                                          │
         ▼                                          ▼
    VALIDATION                                  ANNULATION
    du bon d'entrée                             du bon
         │                                          │
         ▼                                          ▼
    Statut: VALIDÉ                           Statut: ANNULÉ
    Stock mis à jour                         (Sans effet sur le stock)
    (Irréversible)
```

**Résumé du workflow :**

| Étape | Action | Statut résultant |
|---|---|---|
| 1 | Création du bon d'entrée | Brouillon |
| 2a | Validation du bon | Validé (stock incrémenté) |
| 2b | Annulation du bon | Annulé |

### 10.3 Workflow des bons de sortie

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW DES BONS DE SORTIE                      │
└─────────────────────────────────────────────────────────────────────┘

  [GESTIONNAIRE/ADMIN]                              [UTILISATEUR]
         │                                               │
         ▼                                               │
    Création du bon                                      │
    de sortie                                            │
    (Demandeur + Articles + Quantités)                   │
         │                                               │
         ▼                                               │
    Statut: BROUILLON / QR VIDE                          │
    (Modifiable)                                         │
         │                                               │
         ├──────────────────────────────────┐            │
         │                                  │            │
         ▼                                  ▼            │
    VALIDATION                          ANNULATION       │
    du bon de sortie                    du bon           │
         │                                  │            │
         ▼                                  ▼            │
    Statut: VALIDÉ                    Statut: ANNULÉ     │
    Stock décrémenté ─────────────────────────────────►  │
    (Irréversible)                                  Accusé de
                                                    réception
                                                         │
                                                         ▼
                                                   Statut: TERMINÉ
```

**Résumé du workflow :**

| Étape | Acteur | Action | Statut résultant |
|---|---|---|---|
| 1 | Gestionnaire | Crée le bon de sortie | Brouillon/QR vide |
| 2a | Gestionnaire | Valide le bon | Validé (stock décrémenté) |
| 2b | Gestionnaire | Annule le bon | Annulé |
| 3 | Utilisateur | Accuse réception | Terminé |

---

## 11. Gestion des erreurs

### Messages d'erreur système

| Message | Cause probable | Solution |
|---|---|---|
| "Opération effectuée avec succès" | — | Opération réussie, aucune action requise |
| "Une erreur est survenue" | Erreur technique interne | Rafraîchissez la page et réessayez. Si le problème persiste, contactez l'administrateur |
| "Accès non autorisé" | Tentative d'accès à un module non autorisé | Contactez votre administrateur pour obtenir les droits nécessaires |
| "Votre session a expiré. Veuillez vous reconnecter." | Inactivité prolongée | Reconnectez-vous à l'application |
| "Ce champ est obligatoire" | Un champ requis est vide | Renseignez tous les champs obligatoires |
| "Adresse email invalide" | Format d'email incorrect | Vérifiez le format de l'adresse email (ex : nom@domaine.com) |
| "Le mot de passe doit contenir au moins {min} caractères" | Mot de passe trop court | Choisissez un mot de passe plus long |
| "Les mots de passe ne correspondent pas" | Confirmation incorrecte | Ressaisissez les deux mots de passe identiques |
| "Voulez-vous vraiment supprimer cet élément ?" | — | Confirmez ou annulez la suppression |
| "Connexion à la base de données impossible." | Serveur BDD inaccessible | Contactez immédiatement l'administrateur système |

### Erreurs de connexion

| Message | Cause | Solution |
|---|---|---|
| ❌ Licence expirée | Licence arrivée à échéance | Contacter l'administrateur pour renouveler la licence |
| ❌ Licence invalide | Clé de licence incorrecte | Contacter l'administrateur système |
| ❌ Nombre maximum d'utilisateurs atteint | Quota de licences dépassé | Attendre qu'un utilisateur se déconnecte |
| Compte bloqué temporairement | 5 tentatives échouées | Attendre 60 secondes et réessayer |

### Erreurs lors des opérations de stock

| Situation | Cause | Solution |
|---|---|---|
| Impossible de valider un bon de sortie | Stock insuffisant pour un article | Vérifiez le stock disponible et ajustez les quantités |
| Impossible de supprimer un article | Article utilisé dans des mouvements | Passez l'article en statut Inactif plutôt que de le supprimer |
| Impossible de supprimer une unité/catégorie | Élément utilisé par des articles | Vérifiez les dépendances avant suppression |

---

## 12. Conseils d'utilisation et bonnes pratiques

### Organisation des données de référence

1. **Configurez les paramètres en premier** : avant de commencer à utiliser l'application, créez les unités, catégories, fournisseurs et emplacements. Ces données sont nécessaires pour créer les articles.

2. **Utilisez des codes cohérents** : adoptez une nomenclature standardisée pour les codes d'articles, d'unités et d'emplacements (ex : ART-001, ART-002 pour les articles ; ZONE-A, ZONE-B pour les emplacements).

3. **Définissez des seuils d'alerte réalistes** : le seuil d'alerte doit correspondre au délai de réapprovisionnement multiplié par la consommation moyenne. Un seuil trop bas génère des ruptures, un seuil trop haut immobilise du capital.

### Gestion des mouvements

4. **Validez les bons rapidement** : les bons en statut Brouillon ne mettent pas à jour le stock. Validez-les dès que la réception ou la sortie physique est confirmée.

5. **Ne supprimez pas, désactivez** : préférez toujours le passage en statut Inactif à la suppression définitive pour conserver l'historique des données.

6. **Vérifiez avant de valider** : la validation d'un bon (entrée ou sortie) est irréversible. Vérifiez soigneusement les articles et quantités avant de confirmer.

### Sécurité et accès

7. **Déconnectez-vous systématiquement** : fermez toujours votre session lorsque vous quittez votre poste, même brièvement.

8. **Changez votre mot de passe régulièrement** : modifiez votre mot de passe tous les 3 mois et choisissez un mot de passe fort (au moins 8 caractères, mélange de lettres, chiffres et symboles).

9. **Ne partagez pas vos identifiants** : chaque utilisateur doit avoir son propre compte. Le partage de comptes compromet la traçabilité des opérations.

### Rapports et exports

10. **Exportez régulièrement** : effectuez des exports Excel de l'inventaire et des exploitations à intervalles réguliers pour archiver l'historique.

11. **Utilisez les filtres** : dans les modules Exploitations et Stock, utilisez les filtres pour cibler précisément les données dont vous avez besoin et éviter de traiter des volumes inutiles.

12. **Surveillez le tableau de bord** : consultez le tableau de bord quotidiennement pour détecter rapidement les alertes de stock et les demandes en attente.

### Administration

13. **Sauvegardez la base de données** : le Super Administrateur doit effectuer des sauvegardes régulières de la base de données (quotidiennes ou hebdomadaires selon le volume d'activité).

14. **Gérez les permissions avec précision** : attribuez à chaque utilisateur uniquement les permissions dont il a réellement besoin (principe du moindre privilège).

15. **Surveillez les alertes de licence** : dès qu'une alerte d'expiration de licence apparaît, contactez immédiatement l'administrateur pour éviter toute interruption de service.

---

## 13. Glossaire

| Terme | Définition |
|---|---|
| **Article** | Tout bien ou produit géré en stock, identifié par un code unique et une désignation. |
| **Bon d'entrée** | Document enregistrant la réception de marchandises en stock, associé à un fournisseur. |
| **Bon de sortie** | Document enregistrant la sortie de marchandises du stock, associé à un demandeur. |
| **Brouillon** | Statut d'un bon créé mais non encore validé. Le stock n'est pas encore impacté. |
| **Catégorie** | Regroupement logique d'articles partageant des caractéristiques communes. |
| **Demande** | Requête interne d'un utilisateur pour obtenir des articles du stock. |
| **Emplacement** | Zone physique de stockage où sont rangés les articles (entrepôt, rayon, armoire, etc.). |
| **Fournisseur** | Entreprise ou personne auprès de laquelle les articles sont approvisionnés. |
| **Inventaire** | État complet et valorisé de tous les articles en stock à un instant donné. |
| **KPI** | Key Performance Indicator — Indicateur clé de performance affiché sur le tableau de bord. |
| **Licence** | Autorisation d'utilisation de l'application, limitée dans le temps et en nombre d'utilisateurs. |
| **Mouvement** | Toute opération modifiant la quantité en stock d'un article (entrée ou sortie). |
| **Permission** | Droit d'accès accordé à un utilisateur pour consulter ou utiliser un module spécifique. |
| **Rôle** | Niveau d'accès global attribué à un utilisateur (Super Admin, Admin, Utilisateur, Logisticien, Comptable). |
| **Rupture de stock** | Situation où la quantité en stock d'un article est égale à zéro. |
| **Seuil d'alerte** | Quantité minimale en stock en dessous de laquelle une alerte est déclenchée. |
| **Statut** | État actuel d'un document ou d'un article (Brouillon, Validé, Annulé, Terminé, Actif, Inactif, etc.). |
| **Stock** | Ensemble des articles disponibles physiquement dans les zones de stockage. |
| **Unité** | Unité de mesure utilisée pour quantifier un article (pièce, kilogramme, litre, mètre, etc.). |
| **Validation** | Action de confirmer définitivement un bon d'entrée ou de sortie, entraînant la mise à jour du stock. |
| **Accusé de réception** | Confirmation par le destinataire qu'il a bien reçu physiquement les articles d'un bon de sortie validé. |
| **Session** | Période de connexion active d'un utilisateur à l'application. |
| **Super Administrateur** | Utilisateur disposant des droits les plus élevés dans l'application, incluant l'accès aux requêtes SQL et aux opérations de maintenance. |

---

*Manuel Utilisateur GESTIONSTOCK 2.0 — Version 2.0 — Septembre 2026*  
*Document généré pour usage interne. Toute reproduction ou diffusion externe est soumise à autorisation.*
