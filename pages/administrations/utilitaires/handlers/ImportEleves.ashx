<%@ WebHandler Language="C#" Class="ImportEleves" %>

using System;
using System.Web;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web.Script.Serialization;
using System.IO;
using System.Configuration;

public class ImportEleves : IHttpHandler {

    // ─── Modèles ─────────────────────────────────────────────────────
    public class ImportRequest {
        public List<Dictionary<string, string>> eleves { get; set; }
    }

    public class EleveDoublon {
        public string MATRICULE { get; set; }
        public string NOM       { get; set; }
        public string raison    { get; set; }
    }

    public class EleveErreur {
        public string MATRICULE { get; set; }
        public string message   { get; set; }
    }

    public class ImportResponse {
        public bool               success    { get; set; }
        public string             message    { get; set; }
        public int                inserted   { get; set; }
        public int                updated    { get; set; }
        public int                skipped    { get; set; }
        public List<EleveDoublon> duplicates { get; set; }
        public List<EleveErreur>  errors     { get; set; }
    }

    // ─── Point d'entrée ──────────────────────────────────────────────
    public void ProcessRequest(HttpContext context) {
        // ✅ Sécurité : accepter toute session utilisateur authentifiée
        bool isAuthenticated = false;
        if (context.Session != null)
        {
            object authFlag = context.Session["authenticated"];
            if (authFlag is bool)
            {
                isAuthenticated = (bool)authFlag;
            }
            else if (authFlag != null)
            {
                bool parsed;
                isAuthenticated = bool.TryParse(authFlag.ToString(), out parsed) && parsed;
            }

            if (!isAuthenticated)
            {
                object userId = context.Session["IDUSER"];
                if (userId != null)
                {
                    int parsedUserId;
                    isAuthenticated = int.TryParse(userId.ToString(), out parsedUserId) && parsedUserId > 0;
                }
            }

            if (!isAuthenticated)
            {
                object username = context.Session["username"];
                isAuthenticated = username != null && !string.IsNullOrWhiteSpace(username.ToString());
            }
        }

        if (!isAuthenticated)
        {
            context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        int userRole = GetUserRole(context);
        bool isAuthorizedForImport = userRole == 0 || userRole == 1 || userRole == 4;
        if (!isAuthorizedForImport)
        {
            context.Response.Write("{\"success\":false,\"message\":\"Accès refusé pour ce rôle\"}");
            return;
        }

        if (userRole == 0 || userRole == 1)
        {
            context.Session["USERROLE"] = 4;
        }
        
        context.Response.ContentType = "application/json";
        context.Response.Headers["Cache-Control"] = "no-cache";

        var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };

        try {
            string json;
            using (var reader = new StreamReader(context.Request.InputStream)) {
                json = reader.ReadToEnd();
            }

            if (string.IsNullOrWhiteSpace(json)) {
                SendResponse(context, serializer, ErrorResponse("Aucune donnée reçue."));
                return;
            }

            ImportRequest requestData;
            try {
                requestData = serializer.Deserialize<ImportRequest>(json);
            } catch (Exception jsonEx) {
                SendResponse(context, serializer, ErrorResponse("JSON invalide : " + jsonEx.Message));
                return;
            }

            if (requestData == null || requestData.eleves == null || requestData.eleves.Count == 0) {
                SendResponse(context, serializer, ErrorResponse("Le tableau de données est vide."));
                return;
            }

            // ═══════════════════════════════════════════════════════
            // FIX : Vérification de la chaîne de connexion
            // ═══════════════════════════════════════════════════════
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting == null) {
                SendResponse(context, serializer, ErrorResponse(
                    "Chaîne de connexion \"MaConnexion\" introuvable dans Web.config. " +
                    "Clés disponibles : " + GetAvailableConnStrings()
                ));
                return;
            }

            string connString = connSetting.ConnectionString;
            if (string.IsNullOrWhiteSpace(connString)) {
                SendResponse(context, serializer, ErrorResponse(
                    "La chaîne de connexion \"MaConnexion\" est vide dans Web.config."));
                return;
            }

            var response = ProcessImport(requestData.eleves, connString, AuthHelper.GetUserId(context));
            SendResponse(context, serializer, response);

        } catch (Exception ex) {
            SendResponse(context, serializer, new ImportResponse {
                success    = false,
                message    = "Erreur serveur : " + ex.Message,
                inserted   = 0,
                updated    = 0,
                skipped    = 0,
                duplicates = new List<EleveDoublon>(),
                errors     = new List<EleveErreur> {
                    new EleveErreur {
                        MATRICULE = "—",
                        message   = string.Format("[{0}] {1} — Source: {2}",
                            ex.GetType().Name, ex.Message, ex.Source ?? "inconnue")
                    }
                }
            });
        }
    }

    // ─── Logique d'importation ───────────────────────────────────────
    private ImportResponse ProcessImport(List<Dictionary<string, string>> eleves, string connString, int? userId) {

        var response = new ImportResponse {
            success    = true,
            inserted   = 0,
            updated    = 0,
            skipped    = 0,
            duplicates = new List<EleveDoublon>(),
            errors     = new List<EleveErreur>()
        };

        // Test de connexion isolé pour message d'erreur clair
        try {
            using (var testConn = new SqlConnection(connString)) { testConn.Open(); }
        } catch (SqlException connEx) {
            return ErrorResponse("Connexion BDD impossible : " + connEx.Message);
        }

        using (SqlConnection conn = new SqlConnection(connString)) {
            conn.Open();

            const string sql = @"
                IF EXISTS (SELECT 1 FROM ELEVES WHERE MATRICULE = @Matricule)
                BEGIN
                    UPDATE ELEVES
                    SET ANNEE_ID = @AnneeId,
                        NOM = @Nom,
                        CLASSE = @Classe,
                        STATUT = @Statut,
                        EMAIL = @Email,
                        TELEPHONE = @Tel,
                        DATE_NAISSANCE = @DateN,
                        GENRE = @Genre,
                        ADRESSE = @Adresse,
                        PARENT = @Parent,
                        UPDATED_AT = GETDATE(),
                        UPDATED_BY = @UpdatedBy
                    WHERE MATRICULE = @Matricule;
                    SELECT 2;
                END
                ELSE
                BEGIN
                    INSERT INTO ELEVES (
                        ID, ANNEE_ID, MATRICULE, NOM, CLASSE, STATUT,
                        EMAIL, TELEPHONE, DATE_NAISSANCE, GENRE, ADRESSE, PARENT,
                        CREATED_AT, CREATED_BY, UPDATED_AT, UPDATED_BY
                    )
                    VALUES (
                        NEWID(), @AnneeId, @Matricule, @Nom, @Classe, @Statut,
                        @Email, @Tel, @DateN, @Genre, @Adresse, @Parent,
                        GETDATE(), @CreatedBy, GETDATE(), @UpdatedBy
                    );
                    SELECT 1;
                END;";

            foreach (var row in eleves) {
                string matricule = GetVal(row, "MATRICULE");
                string nom       = GetVal(row, "NOM");

                try {
                    // Validation des champs obligatoires
                    if (string.IsNullOrEmpty(matricule)) {
                        throw new ArgumentException("Le matricule est obligatoire.");
                    }
                    
                    if (string.IsNullOrEmpty(nom)) {
                        throw new ArgumentException("Le nom est obligatoire.");
                    }

                    using (SqlCommand cmd = new SqlCommand(sql, conn)) {

                        int anneeId = 0;
                        if (!int.TryParse(GetVal(row, "ANNEE_SCO"), out anneeId) || anneeId <= 0) {
                            throw new ArgumentException("L'année scolaire est invalide.");
                        }
                        cmd.Parameters.AddWithValue("@AnneeId", anneeId);

                        int classeId = 0;
                        if (!int.TryParse(GetVal(row, "CLASSE_ID"), out classeId) || classeId <= 0) {
                            throw new ArgumentException("La classe est invalide.");
                        }
                        cmd.Parameters.AddWithValue("@Classe", classeId);

                        cmd.Parameters.AddWithValue("@Matricule", matricule);
                        cmd.Parameters.AddWithValue("@Nom",       nom);
                        cmd.Parameters.AddWithValue("@Statut",    GetVal(row, "STATUT", "actif"));
                        cmd.Parameters.AddWithValue("@Genre",     GetVal(row, "GENRE",  "M"));

                        AddNullable(cmd, "@Email",   GetVal(row, "EMAIL"));
                        AddNullable(cmd, "@Tel",     GetVal(row, "TELEPHONE"));
                        AddNullable(cmd, "@Adresse", GetVal(row, "ADRESSE"));
                        AddNullable(cmd, "@Parent",  GetVal(row, "PARENT"));

                        DateTime dateN;
                        if (DateTime.TryParse(GetVal(row, "DATE_NAISS"), out dateN))
                            cmd.Parameters.AddWithValue("@DateN", dateN);
                        else
                            cmd.Parameters.AddWithValue("@DateN", DBNull.Value);

                        if (userId.HasValue && userId.Value > 0) {
                            cmd.Parameters.AddWithValue("@CreatedBy", userId.Value);
                            cmd.Parameters.AddWithValue("@UpdatedBy", userId.Value);
                        } else {
                            cmd.Parameters.AddWithValue("@CreatedBy", DBNull.Value);
                            cmd.Parameters.AddWithValue("@UpdatedBy", DBNull.Value);
                        }

                        int action = Convert.ToInt32(cmd.ExecuteScalar());
                        if (action == 2) {
                            response.updated++;
                        } else {
                            response.inserted++;
                        }
                    }
                } catch (SqlException sqlEx) {
                    response.skipped++;
                    response.errors.Add(new EleveErreur {
                        MATRICULE = matricule,
                        message   = string.Format("Erreur SQL #{0} : {1}", sqlEx.Number, sqlEx.Message)
                    });
                } catch (Exception rowEx) {
                    response.skipped++;
                    response.errors.Add(new EleveErreur {
                        MATRICULE = matricule,
                        message   = string.Format("[{0}] {1}", rowEx.GetType().Name, rowEx.Message)
                    });
                }
            }
        }

        response.message = string.Format(
            "{0} élève(s) ajouté(s), {1} mise(s) à jour, {2} ignoré(s) ({3} erreur(s)).",
            response.inserted, response.updated, response.skipped, response.errors.Count);

        return response;
    }

    // ─── Helpers ─────────────────────────────────────────────────────

    private static string GetAvailableConnStrings() {
        var keys = new List<string>();
        foreach (ConnectionStringSettings cs in ConfigurationManager.ConnectionStrings)
            keys.Add(cs.Name);
        return keys.Count > 0 ? string.Join(", ", keys.ToArray()) : "(aucune)";
    }

    private static int GetUserRole(HttpContext context)
    {
        if (context == null || context.Session == null)
            return -1;

        object roleValue = context.Session["USERROLE"];
        if (roleValue == null)
            return -1;

        int role;
        if (int.TryParse(roleValue.ToString(), out role))
            return role;

        return -1;
    }

    private static ImportResponse ErrorResponse(string msg) {
        return new ImportResponse {
            success    = false,
            message    = msg,
            inserted   = 0,
            updated    = 0,
            skipped    = 0,
            duplicates = new List<EleveDoublon>(),
            errors     = new List<EleveErreur> {
                new EleveErreur { MATRICULE = "—", message = msg }
            }
        };
    }

    private static string GetVal(Dictionary<string, string> row, string key, string def = "") {
        string v;
        return (row.TryGetValue(key, out v) && v != null) ? v.Trim() : def;
    }

    private static void AddNullable(SqlCommand cmd, string param, string val) {
        cmd.Parameters.AddWithValue(param,
            string.IsNullOrEmpty(val) ? (object)DBNull.Value : val);
    }

    private void SendResponse(HttpContext context, JavaScriptSerializer s, ImportResponse r) {
        context.Response.Write(s.Serialize(r));
    }

    public bool IsReusable { get { return false; } }
}