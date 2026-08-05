-- =====================================================
-- GESTION SCOLAIRE - BASE DE DONNÉES COMPLÈTE
-- =====================================================

IF NOT EXISTS (SELECT *
FROM sys.databases
WHERE name = 'MONAPPECOLE2')
BEGIN
    CREATE DATABASE MONAPPECOLE2;
END
GO

USE MONAPPECOLE2;
GO

-- =====================================================
-- TABLE USERROLE
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'USERROLE')
BEGIN
    CREATE TABLE USERROLE
    (
        ROLEID INT PRIMARY KEY,
        ROLENAME VARCHAR(50) NOT NULL UNIQUE
    );
END
GO

-- =====================================================
-- TABLE USERS
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'USERS')
BEGIN
    CREATE TABLE USERS
    (
        IDUSER INT IDENTITY(1,1) PRIMARY KEY,
        USERNAME NVARCHAR(100) NOT NULL UNIQUE,
        NOM NVARCHAR(100) NOT NULL,
        EMAIL NVARCHAR(100) UNIQUE NOT NULL,
        PWD NVARCHAR(255) NOT NULL,
        ROLEID INT NOT NULL,
        TELEPHONE NVARCHAR(20),
        ACTIVE BIT NOT NULL DEFAULT 1,
        DERNIERE_CONNEXION DATETIME,
        CREATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_AT DATETIME DEFAULT GETDATE(),
        DELETION_AT DATETIME NULL,
        DELETION_BY INT NULL,
        SESSION_TOKEN NVARCHAR(100),
        LAST_LOGIN DATETIME DEFAULT GETDATE(),
        LAST_PC NVARCHAR(100),
        MENU_PERMISSIONS NVARCHAR(MAX) NULL,
        BLOCKED_UNTIL DATETIME NULL,
        -- Nouvelle colonne pour les permissions

        CONSTRAINT FK_USER_ROLE FOREIGN KEY (ROLEID) REFERENCES USERROLE(ROLEID)
    );
END
GO

-- =====================================================
-- TABLE RANNEE
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'RANNEE')
BEGIN
    CREATE TABLE [dbo].[RANNEE]
    (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        ANNEE NVARCHAR(9) NOT NULL,
        -- ex: "1"
        DATE_DEBUT DATE NOT NULL,
        DATE_FIN DATE NOT NULL,
        CLOTURE BIT NOT NULL DEFAULT 0,
        DATE_CLOTURE DATETIME NULL,
        CREATED_AT DATETIME NOT NULL DEFAULT GETDATE(),
    );
END
GO

-- =====================================================
-- TABLE NIVEAUX
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'NIVEAUX')
BEGIN
    CREATE TABLE NIVEAUX
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        NOM NVARCHAR(50) NOT NULL UNIQUE,
        ORDRE INT DEFAULT 0,
        STATUT BIT NOT NULL DEFAULT 1,
        CREATED_AT DATETIME DEFAULT GETDATE()
    );
END
GO

-- =====================================================
-- TABLE SALLES
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'SALLES')
BEGIN
    CREATE TABLE SALLES
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        NUMERO NVARCHAR(50) NOT NULL UNIQUE,
        CAPACITE INT DEFAULT 30,
        STATUT BIT NOT NULL DEFAULT 1,
        CREATED_AT DATETIME DEFAULT GETDATE()
    );
END
GO

-- =====================================================
-- TABLE CLASSES
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'CLASSES')
BEGIN
    CREATE TABLE CLASSES
    (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        NOM NVARCHAR(50) UNIQUE NOT NULL,

        -- Clés Étrangères en UNIQUEIDENTIFIER (GUID)
        NIVEAU_ID UNIQUEIDENTIFIER NOT NULL,
        SALLE_ID UNIQUEIDENTIFIER NOT NULL,

        -- Relation avec l'enseignant titulaire (INT selon votre table USERROLE)
        TITULAIRE_ID INT NOT NULL,

        EFFECTIF INT DEFAULT 0,
        STATUT BIT NOT NULL DEFAULT 1,
        -- 1 pour Actif, 0 pour Inactif
        CREATED_AT DATETIME DEFAULT GETDATE(),
        CREATED_BY INT NULL,
        UPDATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_BY INT NULL;

        -- Définition des contraintes de clés étrangères
        CONSTRAINT FK_CLASSES_NIVEAU FOREIGN KEY (NIVEAU_ID) 
            REFERENCES NIVEAUX(ID),

        CONSTRAINT FK_CLASSES_SALLE FOREIGN KEY (SALLE_ID) 
            REFERENCES SALLES(ID),

        CONSTRAINT FK_CLASSES_USERS FOREIGN KEY (TITULAIRE_ID) 
            REFERENCES USERS(IDUSER)
    );
END
GO

-- =====================================================
-- TABLE MATIÈRES
-- =====================================================
-- Vérifier si la table MATIERES n'existe pas
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'MATIERES')
BEGIN
    CREATE TABLE MATIERES
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        NOM NVARCHAR(100) NOT NULL,
        ENSEIGNANT INT NOT NULL,
        COEFFICIENT DECIMAL(3,1) DEFAULT 1.0,
        HEURES_SEMAINE INT DEFAULT 3,
        CLASSE_ID INT NOT NULL,
        CREATED_AT DATETIME DEFAULT GETDATE(),
        CREATED_BY INT NULL,
        UPDATED_AT DATETIME NULL,
        UPDATED_BY INT NULL,
        DELETION_AT DATETIME NULL,
        DELETION_BY INT NULL,


        CONSTRAINT FK_MATIERES_CLASSES FOREIGN KEY (CLASSE_ID) 
            REFERENCES CLASSES(ID),

        CONSTRAINT FK_MATIERES_USERS FOREIGN KEY (ENSEIGNANT) 
            REFERENCES USERS(IDUSER),

        -- Contrainte d'unicité: une matière ne peut être enseignée qu'une fois par classe et enseignant
        CONSTRAINT UQ_MATIERE_CLASSE_ENSEIGNANT UNIQUE (NOM, CLASSE_ID, ENSEIGNANT)
    );
END
GO

-- =====================================================
-- TABLE COEFFICIENT
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'BULLETINS_COEFFS')
BEGIN
    CREATE TABLE BULLETINS_COEFFS
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        MATIERE_ID UNIQUEIDENTIFIER NOT NULL,
        CLASSE_ID INT NOT NULL,
        PERIODE NVARCHAR(10) NOT NULL,
        COEFF1 INT NOT NULL DEFAULT 1,
        COEFF2 INT NOT NULL DEFAULT 1,
        COEFF_PROJET INT NOT NULL DEFAULT 2,
        CREATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_AT DATETIME DEFAULT GETDATE(),

        CONSTRAINT FK_COEFFS_MATIERE FOREIGN KEY (MATIERE_ID) REFERENCES MATIERES(ID),
        CONSTRAINT FK_COEFFS_CLASSE FOREIGN KEY (CLASSE_ID) REFERENCES CLASSES(ID),
        CONSTRAINT UQ_COEFFS_MATIERE_CLASSE_PERIODE UNIQUE (MATIERE_ID, CLASSE_ID, PERIODE)
    );
END
GO

-- =====================================================
-- TABLE BULLETINS
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'BULLETINS')
BEGIN
    CREATE TABLE BULLETINS
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        ELEVE_MATRICULE NVARCHAR(20) NOT NULL,
        MATIERE_ID UNIQUEIDENTIFIER NOT NULL,
        
        NOTE1 DECIMAL(5,2) NULL,
        NOTE2 DECIMAL(5,2) NULL,
        NOTE_PROJET DECIMAL(5,2) NULL,
        TOTAL_NOTE DECIMAL(10,2) NULL,

        APPRECIATION NVARCHAR(500) NULL,
        PERIODE NVARCHAR(10) NOT NULL,
        STATUT NVARCHAR(20) DEFAULT 'Non saisi',

        DATE_EVAL1 DATE NULL,
        DATE_EVAL2 DATE NULL,
        DATE_EVAL_PROJET DATE NULL,

        CREATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_AT DATETIME DEFAULT GETDATE(),

        CONSTRAINT CHK_NOTE1 CHECK (NOTE1 BETWEEN 0 AND 20),
        CONSTRAINT CHK_NOTE2 CHECK (NOTE2 BETWEEN 0 AND 20),
        CONSTRAINT CHK_NOTE_PROJET CHECK (NOTE_PROJET BETWEEN 0 AND 20),
        CONSTRAINT CHK_PERIODE CHECK (PERIODE IN ('T1','T2','T3','Sem1','Sem2')),
        CONSTRAINT CHK_STATUT CHECK (STATUT IN ('Non saisi', 'En cours', 'Enregistré', 'Validé')),

        CONSTRAINT FK_BULLETINS_ELEVES FOREIGN KEY (ELEVE_MATRICULE) REFERENCES ELEVES(MATRICULE) ON DELETE CASCADE,
        CONSTRAINT FK_BULLETINS_MATIERES FOREIGN KEY (MATIERE_ID) REFERENCES MATIERES(ID) ON DELETE CASCADE,
        CONSTRAINT UQ_BULLETIN UNIQUE (ELEVE_MATRICULE, MATIERE_ID, PERIODE)
    );
END
GO

-- =====================================================
-- TABLE ÉLÈVES
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'ELEVES')
BEGIN
    CREATE TABLE ELEVES
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        MATRICULE NVARCHAR(20) UNIQUE NOT NULL,
        ANNEE_ID INT NOT NULL,
        NOM NVARCHAR(100) NOT NULL,
        CLASSE INT NOT NULL,
        STATUT NVARCHAR(20) DEFAULT 'actif'
            CHECK (STATUT IN ('actif','inactif','suspendu')),
        EMAIL NVARCHAR(100),
        TELEPHONE NVARCHAR(20),
        DATE_NAISSANCE DATE,
        GENRE NCHAR(1) DEFAULT 'M' CHECK (GENRE IN ('M','F')),
        ADRESSE NVARCHAR(MAX),
        PARENT NVARCHAR(100),
        DATE_INSCRIPTION DATE DEFAULT GETDATE(),
        CREATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_AT DATETIME DEFAULT GETDATE(),
        CREATED_BY INT NULL,
        UPDATED_BY INT NULL,
        DELETION_AT DATETIME NULL,
        DELETION_BY INT NULL,

        CONSTRAINT FK_ELEVES_CLASSES FOREIGN KEY (CLASSE) REFERENCES CLASSES(ID),
        CONSTRAINT FK_ELEVES_RANNEE FOREIGN KEY (ANNEE_ID) REFERENCES RANNEE(ID),
        CONSTRAINT FK_ELEVES_CREATED_BY FOREIGN KEY (CREATED_BY) REFERENCES USERS(IDUSER),
        CONSTRAINT FK_ELEVES_UPDATED_BY FOREIGN KEY (UPDATED_BY) REFERENCES USERS(IDUSER)
    );
END
GO

-- =====================================================
-- TABLE ABSENCES
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'ABSENCES')
BEGIN
    CREATE TABLE ABSENCES
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        ANNEE_ID INT NOT NULL,
        MATRICULE NVARCHAR(20) NOT NULL,
        NOM NVARCHAR(200) NOT NULL,
        CLASSE INT NOT NULL,
        DATE_DEBUT DATE NOT NULL,
        DATE_FIN DATE NOT NULL,
        MOTIF NVARCHAR(500) NULL,
        JUSTIFIE BIT DEFAULT 0,
        JUSTIFICATION NVARCHAR(500) NULL,
        PIECE_JOINTE NVARCHAR(200) NULL,
        CREATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_AT DATETIME NULL,
        DELETION_AT DATETIME NULL,
        DELETION_BY INT NULL,

        -- Clés étrangères
        CONSTRAINT FK_ABSENCES_RANNEE FOREIGN KEY (ANNEE_ID) 
        REFERENCES RANNEE(ID) ON DELETE CASCADE,
        CONSTRAINT FK_ABSENCES_ELEVES_MATRICULE FOREIGN KEY (MATRICULE) 
        REFERENCES ELEVES(MATRICULE) ON DELETE CASCADE,
        CONSTRAINT FK_ABSENCES_CLASSES FOREIGN KEY (CLASSE) 
        REFERENCES CLASSES(ID) ON DELETE CASCADE
    );
END
GO

-- =====================================================
-- TABLE RETARDS
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'RETARDS')
BEGIN
    CREATE TABLE RETARDS
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        ANNEE_ID INT NOT NULL,
        MATRICULE NVARCHAR(20) NOT NULL,
        NOM NVARCHAR(200) NOT NULL,
        CLASSE INT NOT NULL,
        DATE_RETARD DATE NOT NULL,
        HEURE_ARRIVEE TIME NOT NULL,
        HEURE_PREVUE TIME NOT NULL,
        DUREE INT NOT NULL,
        -- durée en minutes
        MOTIF NVARCHAR(500) NULL,
        JUSTIFIE BIT DEFAULT 0,
        JUSTIFICATION NVARCHAR(500) NULL,
        CREATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_AT DATETIME NULL,
        UPDATE_BY INT NULL,
        DELETION_AT DATETIME NULL,
        DELETION_BY INT NULL,

        -- Clés étrangères
        CONSTRAINT FK_RETARDS_RANNEE FOREIGN KEY (ANNEE_ID) 
        REFERENCES RANNEE(ID) ON DELETE CASCADE,
        CONSTRAINT FK_RETARDS_ELEVES_MATRICULE FOREIGN KEY (MATRICULE) 
        REFERENCES ELEVES(MATRICULE) ON DELETE CASCADE,
        CONSTRAINT FK_RETARDS_CLASSES FOREIGN KEY (CLASSE) 
        REFERENCES CLASSES(ID) ON DELETE CASCADE
    );
END
GO

-- =====================================================
-- TABLE TARIFS_ECOLAGE
-- Gère les tarifs d'écolage par classe et par année scolaire
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'TARIFS_ECOLAGE')
BEGIN
    CREATE TABLE TARIFS_ECOLAGE
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        ANNEE_ID INT NOT NULL,
        CLASSE_ID INT NOT NULL,
        MONTANT DECIMAL(18, 2) NOT NULL DEFAULT 0,
        DESCRIPTION NVARCHAR(200) NULL,
        STATUT BIT DEFAULT 1,
        CREATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_AT DATETIME DEFAULT GETDATE(),

        -- Clés étrangères
        CONSTRAINT FK_TARIFS_ECOLAGE_RANNEE FOREIGN KEY (ANNEE_ID) 
            REFERENCES RANNEE(ID) ON DELETE CASCADE,
        CONSTRAINT FK_TARIFS_ECOLAGE_CLASSES FOREIGN KEY (CLASSE_ID) 
            REFERENCES CLASSES(ID) ON DELETE CASCADE,

        -- Contrainte d'unicité: un seul tarif par année et par classe
        CONSTRAINT UQ_TARIFS_ECOLAGE_ANNEE_CLASSE UNIQUE (ANNEE_ID, CLASSE_ID)
    );
END
GO

-- =====================================================
-- TABLE FRAIS
-- =====================================================

IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'FRAIS')
BEGIN
    CREATE TABLE FRAIS
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        ANNEE_ID INT NOT NULL,
        TARIF_ID UNIQUEIDENTIFIER NULL,
        MATRICULE NVARCHAR(20) NOT NULL,
        NOM NVARCHAR(100) NOT NULL,
        CLASSE INT NOT NULL,

        -- Valeurs numériques avec virgule (Precision 18, échelle 2)
        TOTAL DECIMAL(18, 2) NULL DEFAULT 0,
        PAYE DECIMAL(18, 2) NULL DEFAULT 0,

        -- Colonne calculée pour le RESTE
        RESTE AS (ISNULL(TOTAL, 0) - ISNULL(PAYE, 0)),

        MODEPAIE NVARCHAR(20) NOT NULL DEFAULT 'Especes',
        REFERENCE NVARCHAR(100) NULL,
        COMMENTAIRE NVARCHAR(MAX) NULL,

        -- Colonne calculée pour la PROGRESSION (Évite la division par zéro)
        PROGRESSION AS (
        CASE 
            WHEN ISNULL(TOTAL, 0) = 0 THEN 0 
            ELSE (ISNULL(PAYE, 0) / ISNULL(TOTAL, 0)) * 100 
        END
    ),

        -- Colonne calculée pour le STATUT
        STATUT AS (
        CASE 
            WHEN ISNULL(PAYE, 0) = 0 THEN 'Non payé'
            WHEN ISNULL(PAYE, 0) >= ISNULL(TOTAL, 0) THEN 'Terminé'
            ELSE 'En cours'
        END
    ),

        DERNIER_PAIEMENT DATETIME NULL,
        CREATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_AT DATETIME DEFAULT GETDATE(),

        -- Clés étrangères
        CONSTRAINT FK_FRAIS_RANNEE FOREIGN KEY (ANNEE_ID) 
        REFERENCES RANNEE(ID) ON DELETE CASCADE,

        CONSTRAINT FK_FRAIS_ELEVES_MATRICULE FOREIGN KEY (MATRICULE) 
        REFERENCES ELEVES(MATRICULE) ON DELETE CASCADE,

        CONSTRAINT FK_FRAIS_CLASSES FOREIGN KEY (CLASSE) 
        REFERENCES CLASSES(ID) ON DELETE CASCADE,
        CONSTRAINT CHK_FRAIS_MODEPAIE 
        CHECK (MODEPAIE IN ('Especes', 'Cheques', 'Virement', 'MobileMoney'))
    );
END
GO

-- =====================================================
-- TABLE HISTORIQUE_PAIEMENTS
-- Stocke chaque transaction de paiement individuellement
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'HISTORIQUE_PAIEMENTS')
BEGIN
    CREATE TABLE HISTORIQUE_PAIEMENTS
    (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        FRAIS_ID UNIQUEIDENTIFIER NOT NULL,
        MATRICULE NVARCHAR(20) NOT NULL,
        NOM NVARCHAR(100) NOT NULL,
        CLASSE INT NOT NULL,
        ANNEE_ID INT NOT NULL,

        -- Détails du paiement
        MOIS NVARCHAR(20) NULL,
        ANNEE NVARCHAR(10) NULL,
        MONTANT DECIMAL(18, 2) NOT NULL,
        DATE_PAIEMENT DATETIME NOT NULL,
        MODE_PAIEMENT NVARCHAR(20) NOT NULL,
        REFERENCE NVARCHAR(100) NULL,
        COMMENTAIRE NVARCHAR(MAX) NULL,

        -- Informations sur l'utilisateur qui a enregistré le paiement
        USER_ID INT NULL,
        USERNAME NVARCHAR(100) NULL,

        -- État avant paiement
        ANCIEN_TOTAL DECIMAL(18, 2) NULL,
        ANCIEN_PAYE DECIMAL(18, 2) NULL,
        ANCIEN_RESTE DECIMAL(18, 2) NULL,

        -- État après paiement
        NOUVEAU_TOTAL DECIMAL(18, 2) NULL,
        NOUVEAU_PAYE DECIMAL(18, 2) NULL,
        NOUVEAU_RESTE DECIMAL(18, 2) NULL,

        CREATED_AT DATETIME DEFAULT GETDATE(),

        -- Clés étrangères
        CONSTRAINT FK_HISTORIQUE_FRAIS FOREIGN KEY (FRAIS_ID) 
            REFERENCES FRAIS(ID),
        CONSTRAINT FK_HISTORIQUE_ELEVES_MATRICULE FOREIGN KEY (MATRICULE) 
            REFERENCES ELEVES(MATRICULE),
        CONSTRAINT FK_HISTORIQUE_CLASSES FOREIGN KEY (CLASSE) 
            REFERENCES CLASSES(ID),
        CONSTRAINT FK_HISTORIQUE_RANNEE FOREIGN KEY (ANNEE_ID) 
            REFERENCES RANNEE(ID),
        CONSTRAINT CHK_HISTORIQUE_MODE_PAIEMENT 
            CHECK (MODE_PAIEMENT IN ('Especes', 'Cheque', 'Virement', 'MobileMoney'))
    );
END
GO

-- Table EVENTS pour l'agenda
IF NOT EXISTS (SELECT *
FROM sys.tables
WHERE name = 'EVENTS')
BEGIN
    CREATE TABLE EVENTS (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        USER_ID INT,
        TITLE NVARCHAR(200) NOT NULL,
        DATE DATE NOT NULL,
        TYPE NVARCHAR(50) DEFAULT 'autre',
        START_TIME TIME NULL,
        END_TIME TIME NULL,
        DESCRIPTION NVARCHAR(MAX) NULL,
        COLOR NVARCHAR(20) DEFAULT '#1e3a2f',
        CREATED_AT DATETIME DEFAULT GETDATE(),
        UPDATED_AT DATETIME DEFAULT GETDATE()
    );
END
GO


-- =====================================================
-- Table pour stocker les logs d'erreurs
-- =====================================================
IF NOT EXISTS (SELECT *
FROM sys.databases
WHERE name = 'ErrorLogs')
BEGIN
    CREATE TABLE ErrorLogs
    (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        LogDate DATETIME NOT NULL,
        Level VARCHAR(10) NOT NULL,
        -- ERROR, INFO, WARNING
        Source NVARCHAR(200) NULL,
        Message NVARCHAR(MAX) NULL,
        Exception NVARCHAR(MAX) NULL,
        UserIP VARCHAR(50) NULL,
        UserName NVARCHAR(100) NULL,
        Url NVARCHAR(500) NULL,
        CreatedAt DATETIME DEFAULT GETDATE()
    );
END
GO

-- =====================================================
-- Table pour EMPLOIS DU TEMPS
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'EMPLOI_TEMPS')
BEGIN
    -- Création de la table avec toutes les colonnes
CREATE TABLE EMPLOI_TEMPS (
    ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    CLASSE_ID INT NOT NULL,
    JOUR INT NOT NULL,  -- 1=Lundi, ..., 6=Samedi
    HEURE_DEBUT NVARCHAR(5) NOT NULL,  -- format HH:mm
    HEURE_FIN NVARCHAR(5) NULL,        -- format HH:mm, peut être NULL (au cas où)
    MATIERE_ID UNIQUEIDENTIFIER NOT NULL,
    PROFESSEUR NVARCHAR(100) NULL,
    SALLE NVARCHAR(50) NULL,
    COULEUR NVARCHAR(20) NULL DEFAULT '#007bff',   -- code hexadécimal
    TYPE NVARCHAR(30) NULL DEFAULT 'cours',        -- cours, td, tp, examen, autre
    URL NVARCHAR(500) NULL,
    DESCRIPTION NVARCHAR(MAX) NULL,
    CREATED_AT DATETIME DEFAULT GETDATE(),
    UPDATED_AT DATETIME NULL,                      -- pour suivi des modifications
    -- Contraintes de clé étrangère
    CONSTRAINT FK_EMPLOI_TEMPS_CLASSES FOREIGN KEY (CLASSE_ID) REFERENCES CLASSES(ID),
    CONSTRAINT FK_EMPLOI_TEMPS_MATIERES FOREIGN KEY (MATIERE_ID) REFERENCES MATIERES(ID)
);
END
GO

-- ─────────────────────────────────────────────────────────────────
--  1. TABLE DES MODÈLES (panneau gauche)
-- ─────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'EVENTTEMPLATES')
BEGIN
    CREATE TABLE EVENTTEMPLATES (
        ID              INT IDENTITY(1,1) PRIMARY KEY,
        NOM             NVARCHAR(200) NOT NULL,
        COULEUR         VARCHAR(20)   NULL DEFAULT '#6f42c1',
        HEURE_DEBUT     VARCHAR(5)    NULL,
        HEURE_FIN       VARCHAR(5)    NULL,
        DESCRIPTION     NVARCHAR(MAX) NULL,
        TYPE            VARCHAR(50)   NULL,  -- Pour correspondre au data-type des événements externes
        LIEU            NVARCHAR(200) NULL,  -- Ajouté car présent dans le formulaire
        PUBLIC          VARCHAR(20)   NULL DEFAULT 'all', -- Ajouté car présent dans le formulaire
        URL             NVARCHAR(500) NULL,  -- Ajouté car présent dans le formulaire
        CREATED_AT      DATETIME      NULL DEFAULT GETDATE()
    );
END
GO

-- ─────────────────────────────────────────────────────────────────
--  2. TABLE DES INSTANCES CALENDRIER
--     Conserve tous les champs de l'ancienne CalendarEvents
--     + FK vers le modèle d'origine (nullable : drop libre possible)
-- ─────────────────────────────────────────────────────────────────

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CALENDAREVENTS')
BEGIN
    CREATE TABLE CALENDAREVENTS (
        ID              UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        TEMPLATE_ID     INT           NULL,
        IDUSER          INT           NULL,
        TITRE           NVARCHAR(200) NULL,
        DATE_DEBUT      DATETIME      NULL,
        DATE_FIN        DATETIME      NULL,
        COULEUR         VARCHAR(20)   NULL DEFAULT '#6f42c1',
        HEURE_DEBUT     VARCHAR(5)    NULL,
        HEURE_FIN       VARCHAR(5)    NULL,
        DESCRIPTION     NVARCHAR(MAX) NULL,
        TYPE            VARCHAR(50)   NULL,  -- reunion_parents, examen, vacances, ferie, autre
        LIEU            NVARCHAR(200) NULL,  -- Ajouté
        PUBLIC          VARCHAR(20)   NULL DEFAULT 'all', -- eleves, parents, enseignants, personnel, all
        URL             NVARCHAR(500) NULL,  -- Ajouté
        CREATED_AT      DATETIME      NULL DEFAULT GETDATE(),

        CONSTRAINT FK_CALENDAREVENTS_EVENTTEMPLATES
            FOREIGN KEY (TEMPLATE_ID) REFERENCES EVENTTEMPLATES(ID)
            ON DELETE SET NULL
            ON UPDATE CASCADE,

        CONSTRAINT FK_CALENDAREVENTS_USERS
            FOREIGN KEY (IDUSER) REFERENCES USERS(IDUSER)
            ON DELETE SET NULL
            ON UPDATE CASCADE
    );
END
GO

-- ─────────────────────────────────────────────────────────────────
--  3. TABLE DES ÉVÉNEMENTS EXTERNES (pour le drag & drop)
-- ─────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'EXTERNALEVENTS')
BEGIN
    CREATE TABLE EXTERNALEVENTS (
        ID              INT IDENTITY(1,1) PRIMARY KEY,
        NOM             NVARCHAR(200) NOT NULL,
        TYPE            VARCHAR(50)   NOT NULL, -- reunion_parents, ferie, etc.
        COULEUR         VARCHAR(20)   NULL DEFAULT '#6f42c1',
        ACTIF           BIT           NULL DEFAULT 1,
        CREATED_AT      DATETIME      NULL DEFAULT GETDATE()
    );
    
    -- Insertion des événements par défaut (correspondant au code)
    INSERT INTO EXTERNALEVENTS (NOM, TYPE, COULEUR) VALUES 
    ('👨‍👩‍👦 Réunion Parents', 'reunion_parents', '#6f42c1'),
    ('🎉 Jour férié', 'ferie', '#fd7e14');
END
GO
-- =====================================================
-- INSERTION DES DONNÉES INITIALES
-- =====================================================

-- Insertion des ANNEE
IF NOT EXISTS (SELECT 1
FROM RANNEE)
BEGIN
    INSERT INTO RANNEE
        (ANNEE, DATE_DEBUT, DATE_FIN, CLOTURE)
    VALUES
        ('1', '2025-09-01', '2026-06-30', 0);
END

-- Insertion des USERROLE
IF NOT EXISTS (SELECT 1
FROM USERROLE)
BEGIN
    INSERT INTO USERROLE
        (ROLEID, ROLENAME)
    VALUES
        (0, 'SuperAdmin'),
        (1, 'Admin'),
        (2, 'User'),
        (3, 'Professeur'),
        (4, 'Secrétaire'),
        (5, 'Comptable');
END

-- Insertion des utilisateurs
IF NOT EXISTS (SELECT 1
FROM USERS)
BEGIN
    INSERT INTO USERS
        (USERNAME, NOM, EMAIL, PWD, ROLEID, TELEPHONE, ACTIVE)
    VALUES
        (N'SuperAdmin', N'SuperAdmin', N'admin@ecole.com', N'0', 0, N'0321234500', N'1')
    ;
END

