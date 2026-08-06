-- =====================================================
-- BASE DE DONNÉES : GESTIONSTOCKUFP
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'GESTIONSTOCKUFP')
BEGIN
    CREATE DATABASE GESTIONSTOCKUFP;
END
GO

USE GESTIONSTOCKUFP;
GO

-- =====================================================
-- TABLE USERROLE
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USERROLE')
BEGIN
    CREATE TABLE USERROLE (
        ID          UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        ROLENAME    VARCHAR(50) NOT NULL,
        DESCRIPTION NVARCHAR(200) NULL,
        CREATED_AT  DATETIME DEFAULT GETDATE()
    );

    -- Insertion des rôles par défaut
    INSERT INTO USERROLE (ROLENAME, DESCRIPTION)
    VALUES 
        ('SuperAdmin', 'Accès complet à toutes les fonctionnalités'),
        ('Admin',      'Administration générale'),
        ('Logisticien','Gestion des réceptions, stocks, sorties et inventaires'),
        ('Demandeur',  'Consultation, demandes et accusés de réception'),
        ('Finance',    'Consultation des rapports et données financières');
END
GO

-- =====================================================
-- TABLE USERS
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USERS')
BEGIN
    CREATE TABLE USERS (
        IDUSER             UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        IDROLE             UNIQUEIDENTIFIER NULL,
        USERNAME           NVARCHAR(50) NOT NULL UNIQUE,
        NOM                NVARCHAR(100) NOT NULL,
        EMAIL              NVARCHAR(100) NOT NULL UNIQUE,
        PWD                NVARCHAR(255) NOT NULL,   -- hash du mot de passe
        TELEPHONE          NVARCHAR(20) NULL,
        ACTIVE             BIT NOT NULL DEFAULT 1,
        DERNIERE_CONNEXION DATETIME NULL,            -- dernière connexion
        LAST_PC            NVARCHAR(100) NULL,       -- poste utilisé
        SESSION_TOKEN      NVARCHAR(500) NULL,       -- token JWT ou session
        MENU_PERMISSIONS   NVARCHAR(MAX) NULL,       -- permissions personnalisées
        BLOCKED_UNTIL      DATETIME NULL,            -- verrouillage temporaire

        -- Audit
        CREATED_AT         DATETIME DEFAULT GETDATE(),
        CREATED_BY         UNIQUEIDENTIFIER NULL,
        UPDATED_AT         DATETIME NULL,
        UPDATE_BY          UNIQUEIDENTIFIER NULL,
        DELETION_AT        DATETIME NULL,            -- suppression logique
        DELETION_BY        UNIQUEIDENTIFIER NULL,

        CONSTRAINT FK_USERS_ROLE FOREIGN KEY (IDROLE) REFERENCES USERROLE(ID),
        -- On peut ajouter une contrainte pour s'assurer que l'utilisateur ne se supprime pas lui-même (géré en application)
        CONSTRAINT FK_USERS_CREATED_BY FOREIGN KEY (CREATED_BY) REFERENCES USERS(IDUSER),
        CONSTRAINT FK_USERS_UPDATE_BY FOREIGN KEY (UPDATE_BY) REFERENCES USERS(IDUSER),
        CONSTRAINT FK_USERS_DELETION_BY FOREIGN KEY (DELETION_BY) REFERENCES USERS(IDUSER)
    );

END
GO