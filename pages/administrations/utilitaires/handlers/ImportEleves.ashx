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
        public int                skipped    { get; set; }
        public List<EleveDoublon> duplicates { get; set; }
        public List<EleveErreur>  errors     { get; set; }
    }

    // ─── Point d'entrée ──────────────────────────────────────────────
    public void ProcessRequest(HttpContext context) {
        // ✅ Sécurité : 4 vérifications essentielles
    
    // 1. Authentification
    if (context.Session == null || context.Session["authenticated"] == null || !(bool)context.Session["authenticated"])
    {
        context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
        return;
    }
    
    // 2. Token de session valide
    if (!AuthHelper.RequireApiAuth(context))
    {
        context.Response.Write("{\"success\":false,\"message\":\"Session invalide\"}");
        return;
    }
    
    // 3. Permission (SuperAdmin = 0, Admin = 1, etc.)
    int role = AuthHelper.GetUserRole(context);
    if (role < 0 || role > 1) // Permissions minimales selon le handler
    {
        context.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
        return;
    }
    
    // 4. CSRF pour les méthodes POST/PUT/DELETE
    string method = context.Request.HttpMethod.ToUpper();
    if (method == "POST" || method == "PUT" || method == "DELETE")
    {
        string token = context.Request.Headers["X-CSRF-Token"];
        string sessionToken = context.Session["CSRF_TOKEN"]?.ToString();
        if (string.IsNullOrEmpty(token) || token != sessionToken)
        {
            context.Response.Write("{\"success\":false,\"message\":\"Token CSRF invalide\"}");
            return;
        }
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
            // FIX PRINCIPAL : NullReferenceException si la clé de
            // connexion est absente du Web.config
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

            var response = ProcessImport(requestData.eleves, connString);
            SendResponse(context, serializer, response);

        } catch (Exception ex) {
            SendResponse(context, serializer, new ImportResponse {
                success    = false,
                message    = "Erreur serveur : " + ex.Message,
                inserted   = 0,
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
    private ImportResponse ProcessImport(List<Dictionary<string, string>> eleves, string connString) {

        var response = new ImportResponse {
            success    = true,
            inserted   = 0,
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

            // ID = UNIQUEIDENTIFIER généré par NEWID() — pas envoyé depuis le JS
            // CLASSE = int  ← nom réel dans la BDD (pas CLASSE_ID)
            const string sql = @"
                INSERT INTO ELEVES (
                    ID, ANNEE_ID, MATRICULE, NOM, CLASSE, STATUT,
                    EMAIL, TELEPHONE, DATE_NAISSANCE, GENRE, ADRESSE, PARENT
                )
                SELECT NEWID(), @AnneeId, @Matricule, @Nom, @Classe, @Statut,
                       @Email, @Tel, @DateN, @Genre, @Adresse, @Parent
                WHERE NOT EXISTS (
                    SELECT 1 FROM ELEVES WHERE MATRICULE = @Matricule
                );";

            foreach (var row in eleves) {
                string matricule = GetVal(row, "MATRICULE");
                string nom       = GetVal(row, "NOM");

                try {
                    using (SqlCommand cmd = new SqlCommand(sql, conn)) {

                        int anneeId = 0;
                        int.TryParse(GetVal(row, "ANNEE_SCO"), out anneeId);
                        cmd.Parameters.AddWithValue("@AnneeId",
                            anneeId > 0 ? (object)anneeId : DBNull.Value);

                        int classeId = 0;
                        int.TryParse(GetVal(row, "CLASSE_ID"), out classeId);
                        cmd.Parameters.AddWithValue("@Classe",
                            classeId > 0 ? (object)classeId : DBNull.Value);

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

                        int result = cmd.ExecuteNonQuery();

                        if (result > 0) {
                            response.inserted++;
                        } else {
                            response.skipped++;
                            response.duplicates.Add(new EleveDoublon {
                                MATRICULE = matricule,
                                NOM       = nom,
                                raison    = "Matricule déjà existant"
                            });
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
            "{0} élève(s) importé(s), {1} ignoré(s) ({2} doublon(s), {3} erreur(s)).",
            response.inserted, response.skipped,
            response.duplicates.Count, response.errors.Count);

        return response;
    }

    // ─── Helpers ─────────────────────────────────────────────────────

    private static string GetAvailableConnStrings() {
        var keys = new List<string>();
        foreach (ConnectionStringSettings cs in ConfigurationManager.ConnectionStrings)
            keys.Add(cs.Name);
        return keys.Count > 0 ? string.Join(", ", keys.ToArray()) : "(aucune)";
    }

    private static ImportResponse ErrorResponse(string msg) {
        return new ImportResponse {
            success    = false,
            message    = msg,
            inserted   = 0,
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
