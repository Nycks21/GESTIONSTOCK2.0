-- =====================================================
-- GESTION STOCK — BASE DE DONNÉES COMPLÈTE
-- Script idempotent : réexécutable sans erreur ni perte de données
-- =====================================================

SET NOCOUNT ON;
GO

-- =====================================================
-- 0. CRÉATION DE LA BASE
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'GESTIONSTOCK')
BEGIN
    CREATE DATABASE GESTIONSTOCK;
    PRINT '✓ Base GESTIONSTOCK créée';
END
ELSE
    PRINT '→ Base GESTIONSTOCK existe déjà';
GO

USE GESTIONSTOCK;
GO

-- =====================================================
-- 1. TABLE USERROLE
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USERROLE')
BEGIN
    CREATE TABLE USERROLE
    (
        ROLEID   INT PRIMARY KEY,
        ROLENAME VARCHAR(50) NOT NULL UNIQUE
    );
    PRINT '✓ Table USERROLE créée';
END
GO

-- =====================================================
-- 2. TABLE USERS
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USERS')
BEGIN
    CREATE TABLE USERS
    (
        IDUSER           INT IDENTITY(1,1) PRIMARY KEY,
        USERNAME         NVARCHAR(100) NOT NULL UNIQUE,
        NOM              NVARCHAR(100) NOT NULL,
        EMAIL            NVARCHAR(100) UNIQUE NOT NULL,
        PWD              NVARCHAR(255) NOT NULL,
        ROLEID           INT NOT NULL,
        TELEPHONE        NVARCHAR(20),
        ACTIVE           BIT NOT NULL DEFAULT 1,
        CREATED_AT       DATETIME DEFAULT GETDATE(),
        CREATED_BY       INT NULL,
        UPDATED_AT       DATETIME NULL,
        UPDATED_BY       INT NULL,
        DELETION_AT      DATETIME NULL,
        DELETION_BY      INT NULL,
        SESSION_TOKEN    NVARCHAR(100),
        LAST_LOGIN       DATETIME,
        LAST_PC          NVARCHAR(100),
        MENU_PERMISSIONS NVARCHAR(MAX) NULL,
        BLOCKED_UNTIL    DATETIME NULL,

        CONSTRAINT FK_USER_ROLE FOREIGN KEY (ROLEID) REFERENCES USERROLE(ROLEID)
    );
    PRINT '✓ Table USERS créée';
END
GO

-- =====================================================
-- 3. DONNÉES SYSTÈME (RÔLES + SUPERADMIN)
-- =====================================================
IF NOT EXISTS (SELECT 1 FROM USERROLE WHERE ROLEID = 0)
BEGIN
    INSERT INTO USERROLE (ROLEID, ROLENAME) VALUES
        (0, 'SuperAdmin'),
        (1, 'Admin'),
        (2, 'User'),
        (3, 'Logisticien'),
        (4, 'Comptable');
    PRINT '✓ Rôles insérés';
END
GO

IF NOT EXISTS (SELECT 1 FROM USERS WHERE USERNAME = 'SuperAdmin')
BEGIN
    INSERT INTO USERS (USERNAME, NOM, EMAIL, PWD, ROLEID, TELEPHONE, ACTIVE)
    VALUES (N'SuperAdmin', N'SuperAdmin', N'admin@ecole.com', N'0', 0, N'0321234500', 1);
    PRINT '✓ Utilisateur SuperAdmin créé';
END
GO

-- ============================================================
-- EXTENSION STOCK
-- ============================================================

-- =====================================================
-- 4. UNITÉS DE MESURE
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SUNITE_SEQUENCE')
BEGIN
    CREATE TABLE SUNITE_SEQUENCE (
        PROJET_CODE    VARCHAR(50) NOT NULL PRIMARY KEY,
        DERNIER_NUMERO INT         NOT NULL DEFAULT 0
    );
    PRINT '✓ Table SUNITE_SEQUENCE créée';
END
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SUNITE')
BEGIN
    CREATE TABLE SUNITE (
        ID          UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        CODE        VARCHAR(20) NOT NULL,
        NOM         VARCHAR(100) NOT NULL,
        ACTIVE      BIT DEFAULT 1,
        CREATED_BY  INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT  DATETIME DEFAULT GETDATE(),
        UPDATED_AT  DATETIME NULL,
        UPDATED_BY  INT NULL,
        DELETION_AT DATETIME NULL,
        DELETION_BY INT NULL
    );
    PRINT '✓ Table SUNITE créée';
END
GO

-- =====================================================
-- 5. CATÉGORIES D'ARTICLES
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SCATEGORIE_SEQUENCE')
BEGIN
    CREATE TABLE SCATEGORIE_SEQUENCE (
        PROJET_CODE    VARCHAR(50) NOT NULL PRIMARY KEY,
        DERNIER_NUMERO INT         NOT NULL DEFAULT 0
    );
    PRINT '✓ Table SCATEGORIE_SEQUENCE créée';
END
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SCATEGORIE')
BEGIN
    CREATE TABLE SCATEGORIE (
        ID          UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        CODE        VARCHAR(50) NOT NULL,
        NOM         VARCHAR(200) NOT NULL,
        DESCRIPTION NVARCHAR(500),
        PARENT_ID   UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES SCATEGORIE(ID),
        ACTIVE      BIT DEFAULT 1,
        CREATED_BY  INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT  DATETIME DEFAULT GETDATE(),
        UPDATED_AT  DATETIME NULL,
        UPDATED_BY  INT NULL,
        DELETION_AT DATETIME NULL,
        DELETION_BY INT NULL
    );
    PRINT '✓ Table SCATEGORIE créée';
END
GO

-- =====================================================
-- 6. FOURNISSEURS
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SFOURNISSEUR_SEQUENCE')
BEGIN
    CREATE TABLE SFOURNISSEUR_SEQUENCE (
        PROJET_CODE    VARCHAR(50) NOT NULL PRIMARY KEY,
        DERNIER_NUMERO INT         NOT NULL DEFAULT 0
    );
    PRINT '✓ Table SFOURNISSEUR_SEQUENCE créée';
END
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SFOURNISSEUR')
BEGIN
    CREATE TABLE SFOURNISSEUR (
        ID                  UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        CODE                VARCHAR(50) NOT NULL,
        NOM                 VARCHAR(200) NOT NULL,
        ADRESSE             NVARCHAR(500),
        TELEPHONE           VARCHAR(50),
        EMAIL               VARCHAR(100),
        CONTACT_NOM         VARCHAR(100),
        CONTACT_TELEPHONE   VARCHAR(50),
        SIRET               VARCHAR(20),
        ACTIVE              BIT DEFAULT 1,
        CREATED_BY          INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT          DATETIME DEFAULT GETDATE(),
        UPDATED_AT          DATETIME NULL,
        UPDATED_BY          INT NULL,
        DELETION_AT         DATETIME NULL,
        DELETION_BY         INT NULL
    );
    PRINT '✓ Table SFOURNISSEUR créée';
END
GO

-- =====================================================
-- 7. EMPLACEMENTS DE STOCKAGE
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SEMPLACEMENT_SEQUENCE')
BEGIN
    CREATE TABLE SEMPLACEMENT_SEQUENCE (
        PROJET_CODE    VARCHAR(50) NOT NULL PRIMARY KEY,
        DERNIER_NUMERO INT         NOT NULL DEFAULT 0
    );
    PRINT '✓ Table SEMPLACEMENT_SEQUENCE créée';
END
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SEMPLACEMENT')
BEGIN
    CREATE TABLE SEMPLACEMENT (
        ID          UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        CODE        VARCHAR(50) NOT NULL,
        NOM         VARCHAR(200) NOT NULL,
        TYPE        VARCHAR(20),
        PARENT_ID   UNIQUEIDENTIFIER NULL FOREIGN KEY REFERENCES SEMPLACEMENT(ID),
        ACTIVE      BIT DEFAULT 1,
        CREATED_BY  INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT  DATETIME DEFAULT GETDATE(),
        UPDATED_AT  DATETIME NULL,
        UPDATED_BY  INT NULL,
        DELETION_AT DATETIME NULL,
        DELETION_BY INT NULL
    );
    PRINT '✓ Table SEMPLACEMENT créée';
END
GO

-- =====================================================
-- 8. ARTICLES (CŒUR DU STOCK)
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MARTICLE_SEQUENCE')
BEGIN
    CREATE TABLE MARTICLE_SEQUENCE (
        PROJET_CODE    VARCHAR(50) NOT NULL PRIMARY KEY,
        DERNIER_NUMERO INT         NOT NULL DEFAULT 0
    );
    PRINT '✓ Table MARTICLE_SEQUENCE créée';
END
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MARTICLE')
BEGIN
    CREATE TABLE MARTICLE (
        ID                   UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        CODE                 VARCHAR(50) NOT NULL,
        CODE_BARRE           VARCHAR(50) NULL,
        NOM                  VARCHAR(200) NOT NULL,
        DESCRIPTION          NVARCHAR(500),

        CATEGORIE_ID         UNIQUEIDENTIFIER FOREIGN KEY REFERENCES SCATEGORIE(ID),
        UNITE_MESURE_ID      UNIQUEIDENTIFIER FOREIGN KEY REFERENCES SUNITE(ID),
        FOURNISSEUR_PREFERE_ID UNIQUEIDENTIFIER FOREIGN KEY REFERENCES SFOURNISSEUR(ID),
        EMPLACEMENT_ID       UNIQUEIDENTIFIER FOREIGN KEY REFERENCES SEMPLACEMENT(ID),

        SEUIL_MIN            DECIMAL(18,2) DEFAULT 0,
        SEUIL_MAX            DECIMAL(18,2) DEFAULT 0,
        SEUIL_ALERTE         DECIMAL(18,2) DEFAULT 0,
        POIDS                DECIMAL(10,2) NULL,
        VOLUME               DECIMAL(10,2) NULL,

        ACTIVE               BIT DEFAULT 1,
        EST_SERVICE          BIT DEFAULT 0,
        EST_PERISSABLE       BIT DEFAULT 0,
        DATE_PEREMPTION      DATE NULL,

        CREATED_BY           INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT           DATETIME DEFAULT GETDATE(),
        UPDATED_AT           DATETIME NULL,
        UPDATED_BY           INT NULL,
        DELETION_AT          DATETIME NULL,
        DELETION_BY          INT NULL
    );
    PRINT '✓ Table MARTICLE créée';
END
GO

-- =====================================================
-- 9. STOCK
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SSTOCK')
BEGIN
    CREATE TABLE SSTOCK (
        ID                  INT PRIMARY KEY IDENTITY(1,1),
        ARTICLE_ID          UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES MARTICLE(ID),
        EMPLACEMENT_ID      UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES SEMPLACEMENT(ID),
        STATUT              VARCHAR(20) DEFAULT 'NORMALE'
                            CHECK (STATUT IN ('NORMALE', 'ALERTE', 'RUPTURE')),
        QUANTITE_MVT        DECIMAL(18,2) NOT NULL DEFAULT 0,
        QUANTITE_ACTUELLE   DECIMAL(18,2) NOT NULL DEFAULT 0,
        CREATED_BY          INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT          DATETIME DEFAULT GETDATE(),
        UPDATED_AT          DATETIME NULL,
        UPDATED_BY          INT NULL,
        DELETION_AT         DATETIME NULL,
        DELETION_BY         INT NULL,

        CONSTRAINT UQ_STOCK_ARTICLE_EMPLACEMENT UNIQUE(ARTICLE_ID, EMPLACEMENT_ID)
    );
    PRINT '✓ Table SSTOCK créée';
END
GO

-- =====================================================
-- 10. MOUVEMENTS DE STOCK
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MSTOCK')
BEGIN
    CREATE TABLE MSTOCK (
        ID                  UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        ARTICLE_ID          UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES MARTICLE(ID),
        EMPLACEMENT_ID      UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES SEMPLACEMENT(ID),

        TYPE                VARCHAR(20) NOT NULL,
        QUANTITE            DECIMAL(18,2) NOT NULL,
        QUANTITE_AVANT      DECIMAL(18,2) NOT NULL,
        QUANTITE_APRES      DECIMAL(18,2) NOT NULL,

        REFERENCE_TYPE      VARCHAR(50),
        REFERENCE_ID        INT,
        REFERENCE_NUMERO    VARCHAR(50),

        MOTIF               NVARCHAR(500),
        PRIX_UNITAIRE       DECIMAL(18,2) NULL,
        MONTANT_TOTAL       DECIMAL(18,2) NULL,

        CREATED_BY          INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT          DATETIME DEFAULT GETDATE(),
        UPDATED_AT          DATETIME NULL,
        UPDATED_BY          INT NULL,
        DELETION_AT         DATETIME NULL,
        DELETION_BY         INT NULL
    );
    PRINT '✓ Table MSTOCK créée';
END
GO

-- =====================================================
-- 11. BONS D'ENTRÉE
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SENTREE_SEQUENCE')
BEGIN
    CREATE TABLE SENTREE_SEQUENCE (
        PROJET_CODE    VARCHAR(50) NOT NULL PRIMARY KEY,
        DERNIER_NUMERO INT         NOT NULL DEFAULT 0
    );
    PRINT '✓ Table SENTREE_SEQUENCE créée';
END
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SENTREE')
BEGIN
    CREATE TABLE SENTREE (
        ID              UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        NUMERO          VARCHAR(50) NOT NULL,
        DATE_ENTREE     DATETIME NOT NULL DEFAULT GETDATE(),
        FOURNISSEUR_ID  UNIQUEIDENTIFIER FOREIGN KEY REFERENCES SFOURNISSEUR(ID),

        STATUT          VARCHAR(20) DEFAULT 'BROUILLON'
                        CHECK (STATUT IN ('BROUILLON', 'VALIDE', 'ANNULE')),

        TOTAL_HT        DECIMAL(18,2) DEFAULT 0,
        TOTAL_TVA       DECIMAL(18,2) DEFAULT 0,
        TOTAL_TTC       DECIMAL(18,2) DEFAULT 0,

        REFERENCE       VARCHAR(100),
        NOTES           NVARCHAR(500),

        CREATED_BY      INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT      DATETIME DEFAULT GETDATE(),
        VALIDE_BY       INT FOREIGN KEY REFERENCES USERS(IDUSER),
        VALIDE_AT       DATETIME NULL,
        UPDATED_AT      DATETIME NULL,
        UPDATED_BY      INT NULL,
        DELETION_AT     DATETIME NULL,
        DELETION_BY     INT NULL
    );
    PRINT '✓ Table SENTREE créée';
END
GO

-- =====================================================
-- 12. LIGNES DE BON D'ENTRÉE
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MLENTREE')
BEGIN
    CREATE TABLE MLENTREE (
        ID                  UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        BON_ENTREE_ID       UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES SENTREE(ID),
        ARTICLE_ID          UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES MARTICLE(ID),

        QUANTITE            DECIMAL(18,2) NOT NULL,
        PRIX_UNITAIRE_HT    DECIMAL(18,2) NOT NULL,
        TVA_TX              DECIMAL(5,2) DEFAULT 0,
        PRIX_UNITAIRE_TTC   DECIMAL(18,2) NOT NULL,

        TOTAL_HT            DECIMAL(18,2) NOT NULL,
        TOTAL_TVA           DECIMAL(18,2) NOT NULL,
        TOTAL_TTC           DECIMAL(18,2) NOT NULL,

        DATE_PEREMPTION     DATE NULL,
        LOT_NUMERO          VARCHAR(50) NULL,

        UPDATED_AT          DATETIME NULL,
        UPDATED_BY          INT NULL,
        DELETION_AT         DATETIME NULL,
        DELETION_BY         INT NULL
    );
    PRINT '✓ Table MLENTREE créée';
END
GO

-- =====================================================
-- 13. BONS DE SORTIE
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SSORTIE_SEQUENCE')
BEGIN
    CREATE TABLE SSORTIE_SEQUENCE (
        PROJET_CODE    VARCHAR(50) NOT NULL PRIMARY KEY,
        DERNIER_NUMERO INT         NOT NULL DEFAULT 0
    );
    PRINT '✓ Table SSORTIE_SEQUENCE créée';
END
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SSORTIE')
BEGIN
    CREATE TABLE SSORTIE (
        ID              UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        NUMERO          VARCHAR(50) NOT NULL,
        DATE_SORTIE     DATETIME NOT NULL DEFAULT GETDATE(),
        DESTINATION     VARCHAR(200),

        STATUT          VARCHAR(20) DEFAULT 'BROUILLON'
                        CHECK (STATUT IN ('BROUILLON', 'VALIDE', 'ANNULE', 'TERMINE')),

        NOM             VARCHAR(200),
        FONCTION        VARCHAR(50),
        NOTES           NVARCHAR(500),
        DATE_RECEPTION  DATE NULL,

        CREATED_BY      INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT      DATETIME DEFAULT GETDATE(),
        VALIDE_BY       INT FOREIGN KEY REFERENCES USERS(IDUSER),
        VALIDE_AT       DATETIME NULL,
        UPDATED_AT      DATETIME NULL,
        UPDATED_BY      INT NULL,
        DELETION_AT     DATETIME NULL,
        DELETION_BY     INT NULL
    );
    PRINT '✓ Table SSORTIE créée';
END
GO

-- =====================================================
-- 14. LIGNES DE BON DE SORTIE
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MLSORTIE')
BEGIN
    CREATE TABLE MLSORTIE (
        ID              UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
        BON_SORTIE_ID   UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES SSORTIE(ID),
        ARTICLE_ID      UNIQUEIDENTIFIER NOT NULL FOREIGN KEY REFERENCES MARTICLE(ID),

        QUANTITE_D      DECIMAL(18,2) NOT NULL,
        QUANTITE_R      DECIMAL(18,2) NOT NULL,
        OBSERVATIONS    NVARCHAR(500) NULL,

        CREATED_BY      INT FOREIGN KEY REFERENCES USERS(IDUSER),
        CREATED_AT      DATETIME DEFAULT GETDATE(),
        UPDATED_AT      DATETIME NULL,
        UPDATED_BY      INT NULL,
        DELETION_AT     DATETIME NULL,
        DELETION_BY     INT NULL
    );
    PRINT '✓ Table MLSORTIE créée';
END
GO

-- =====================================================
-- 15. INDEX DE PERFORMANCE (idempotents)
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_MSTOCK_CREATED_AT' AND object_id = OBJECT_ID('MSTOCK'))
BEGIN
    CREATE INDEX IX_MSTOCK_CREATED_AT ON MSTOCK(CREATED_AT DESC);
    PRINT '✓ Index IX_MSTOCK_CREATED_AT créé';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_MSTOCK_ARTICLE_ID' AND object_id = OBJECT_ID('MSTOCK'))
BEGIN
    CREATE INDEX IX_MSTOCK_ARTICLE_ID ON MSTOCK(ARTICLE_ID);
    PRINT '✓ Index IX_MSTOCK_ARTICLE_ID créé';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SSTOCK_STATUT' AND object_id = OBJECT_ID('SSTOCK'))
BEGIN
    CREATE INDEX IX_SSTOCK_STATUT ON SSTOCK(STATUT);
    PRINT '✓ Index IX_SSTOCK_STATUT créé';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SENTREE_STATUT' AND object_id = OBJECT_ID('SENTREE'))
BEGIN
    CREATE INDEX IX_SENTREE_STATUT ON SENTREE(STATUT);
    PRINT '✓ Index IX_SENTREE_STATUT créé';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SSORTIE_STATUT' AND object_id = OBJECT_ID('SSORTIE'))
BEGIN
    CREATE INDEX IX_SSORTIE_STATUT ON SSORTIE(STATUT);
    PRINT '✓ Index IX_SSORTIE_STATUT créé';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_MARTICLE_CODE' AND object_id = OBJECT_ID('MARTICLE'))
BEGIN
    CREATE INDEX IX_MARTICLE_CODE ON MARTICLE(CODE);
    PRINT '✓ Index IX_MARTICLE_CODE créé';
END
GO

-- =====================================================
-- 16. MIGRATIONS FUTURES
-- =====================================================
-- Ajoutez ici toutes les futures modifications.
-- Chaque bloc doit être idempotent.

-- Exemple : ajouter une colonne
-- IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('MARTICLE') AND name = 'NOUVELLE_COLONNE')
-- BEGIN
--     ALTER TABLE MARTICLE ADD NOUVELLE_COLONNE VARCHAR(50) NULL;
--     PRINT '✓ Colonne NOUVELLE_COLONNE ajoutée à MARTICLE';
-- END
-- GO

-- Exemple : supprimer une colonne
-- IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('MARTICLE') AND name = 'ANCIENNE_COLONNE')
-- BEGIN
--     ALTER TABLE MARTICLE DROP COLUMN ANCIENNE_COLONNE;
--     PRINT '✓ Colonne ANCIENNE_COLONNE supprimée de MARTICLE';
-- END
-- GO

-- Exemple : modifier un type
-- IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('MARTICLE') AND name = 'CODE' AND max_length < 100)
-- BEGIN
--     ALTER TABLE MARTICLE ALTER COLUMN CODE VARCHAR(100) NOT NULL;
--     PRINT '✓ Colonne CODE élargie à 100 caractères';
-- END
-- GO

-- =====================================================
-- 17. FIN
-- =====================================================
PRINT '======================================';
PRINT '✓ Script terminé avec succès';
PRINT '======================================';
GO
