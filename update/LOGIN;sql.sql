-- =====================================================
-- INSERTION DES UTILISATEURS DE DÉMONSTRATION
-- =====================================================
USE GESTIONSTOCKUFP;
GO

DECLARE @SuperAdminRoleId UNIQUEIDENTIFIER, @AdminRoleId UNIQUEIDENTIFIER, @DemandeurRoleId UNIQUEIDENTIFIER;

SELECT @SuperAdminRoleId = ID FROM USERROLE WHERE ROLENAME = 'SuperAdmin';
SELECT @AdminRoleId = ID FROM USERROLE WHERE ROLENAME = 'Admin';
SELECT @DemandeurRoleId = ID FROM USERROLE WHERE ROLENAME = 'Demandeur';

-- 1. SuperAdmin
IF NOT EXISTS (SELECT 1 FROM USERS WHERE USERNAME = 'superadmin')
BEGIN
    INSERT INTO USERS (IDUSER, IDROLE, USERNAME, NOM, EMAIL, PWD, TELEPHONE, ACTIVE, CREATED_AT)
    VALUES (
        NEWID(),
        @SuperAdminRoleId,
        'superadmin',
        'Super Administrateur',
        'superadmin@gestionscolaire.com',
        '0',
        '0321112311',
        1,
        GETDATE()
    );
END

-- 2. Admin
IF NOT EXISTS (SELECT 1 FROM USERS WHERE USERNAME = 'admin')
BEGIN
    INSERT INTO USERS (IDUSER, IDROLE, USERNAME, NOM, EMAIL, PWD, TELEPHONE, ACTIVE, CREATED_AT)
    VALUES (
        NEWID(),
        @AdminRoleId,
        'admin',
        'Administrateur',
        'admin@gestionscolaire.com',
        'Admin123',
        '0321112312',
        1,
        GETDATE()
    );
END

-- 3. Demandeur (Jean Dupont)
IF NOT EXISTS (SELECT 1 FROM USERS WHERE USERNAME = 'jdupont')
BEGIN
    INSERT INTO USERS (IDUSER, IDROLE, USERNAME, NOM, EMAIL, PWD, TELEPHONE, ACTIVE, CREATED_AT)
    VALUES (
        NEWID(),
        @DemandeurRoleId,
        'jdupont',
        'Jean Dupont',
        'jdupont@exemple.com',
        'Demandeur123',
        '0321112313',
        1,
        GETDATE()
    );
END