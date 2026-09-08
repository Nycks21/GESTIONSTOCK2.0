using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;

namespace GestionStock.Handlers
{
    /// <summary>
    /// Handler AJAX pour le module Articles (MARTICLE).
    /// Suit le meme schema que les handlers .ashx de MONAPPECOLE2 :
    /// - GET  ?action=list|get|dropdowns
    /// - POST ?action=save|delete
    /// - Reponses JSON { success, message, data }
    /// </summary>
    public class ArticleHandler : IHttpHandler, System.Web.SessionState.IRequiresSessionState
    {
        private static readonly string ConnStr =
            ConfigurationManager.ConnectionStrings["GestionStockConnection"].ConnectionString;

        public bool IsReusable => false;

        public void ProcessRequest(HttpContext context)
        {
            context.Response.ContentType = "application/json";

            // Meme garde de session que sur MONAPPECOLE2
            if (context.Session["IDUser"] == null)
            {
                context.Response.StatusCode = 401;
                Write(context, new { success = false, message = "Session expiree, veuillez vous reconnecter." });
                return;
            }

            string action = context.Request["action"] ?? "";

            try
            {
                switch (action.ToLower())
                {
                    case "list":
                        GetList(context);
                        break;
                    case "get":
                        GetById(context);
                        break;
                    case "dropdowns":
                        GetDropdowns(context);
                        break;
                    case "save":
                        Save(context);
                        break;
                    case "delete":
                        Delete(context);
                        break;
                    default:
                        context.Response.StatusCode = 400;
                        Write(context, new { success = false, message = "Action inconnue." });
                        break;
                }
            }
            catch (Exception ex)
            {
                context.Response.StatusCode = 500;
                Write(context, new { success = false, message = "Erreur serveur : " + ex.Message });
            }
        }

        // ---------------------------------------------------------
        // LISTE DES ARTICLES (avec libelles joints + stock total)
        // ---------------------------------------------------------
        private void GetList(HttpContext context)
        {
            string search = context.Request["search"] ?? "";
            var articles = new List<Dictionary<string, object>>();

            const string sql = @"
                SELECT
                    a.ID, a.CODE, a.CODE_BARRE, a.NOM, a.DESCRIPTION,
                    a.CATEGORIE_ID, c.NOM AS CATEGORIE_NOM,
                    a.UNITE_MESURE_ID, u.NOM AS UNITE_NOM, u.CODE AS UNITE_CODE,
                    a.FOURNISSEUR_PREFERE_ID, f.NOM AS FOURNISSEUR_NOM,
                    a.EMPLACEMENT_ID, e.NOM AS EMPLACEMENT_NOM,
                    a.SEUIL_MIN, a.SEUIL_MAX, a.SEUIL_ALERTE,
                    a.POIDS, a.VOLUME,
                    a.ACTIVE, a.EST_SERVICE, a.EST_PERISSABLE,
                    ISNULL(s.STOCK_TOTAL, 0) AS STOCK_TOTAL
                FROM MARTICLE a
                LEFT JOIN SCATEGORIE c   ON c.ID = a.CATEGORIE_ID
                LEFT JOIN SUNITE u       ON u.ID = a.UNITE_MESURE_ID
                LEFT JOIN SFOURNISSEUR f ON f.ID = a.FOURNISSEUR_PREFERE_ID
                LEFT JOIN SEMPLACEMENT e ON e.ID = a.EMPLACEMENT_ID
                OUTER APPLY (
                    SELECT SUM(QUANTITE_ACTUELLE) AS STOCK_TOTAL
                    FROM SSTOCK st
                    WHERE st.ARTICLE_ID = a.ID AND st.DELETION_AT IS NULL
                ) s
                WHERE a.DELETION_AT IS NULL
                  AND (@search = '' OR a.CODE LIKE '%' + @search + '%'
                                     OR a.NOM LIKE '%' + @search + '%'
                                     OR a.CODE_BARRE LIKE '%' + @search + '%')
                ORDER BY a.NOM;";

            using (var conn = new SqlConnection(ConnStr))
            using (var cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@search", search);
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        articles.Add(new Dictionary<string, object>
                        {
                            ["id"] = reader["ID"].ToString(),
                            ["code"] = reader["CODE"],
                            ["codeBarre"] = reader["CODE_BARRE"] as string,
                            ["nom"] = reader["NOM"],
                            ["description"] = reader["DESCRIPTION"] as string,
                            ["categorieId"] = reader["CATEGORIE_ID"] == DBNull.Value ? null : reader["CATEGORIE_ID"].ToString(),
                            ["categorieNom"] = reader["CATEGORIE_NOM"] as string,
                            ["uniteId"] = reader["UNITE_MESURE_ID"] == DBNull.Value ? null : reader["UNITE_MESURE_ID"].ToString(),
                            ["uniteNom"] = reader["UNITE_NOM"] as string,
                            ["uniteCode"] = reader["UNITE_CODE"] as string,
                            ["fournisseurId"] = reader["FOURNISSEUR_PREFERE_ID"] == DBNull.Value ? null : reader["FOURNISSEUR_PREFERE_ID"].ToString(),
                            ["fournisseurNom"] = reader["FOURNISSEUR_NOM"] as string,
                            ["emplacementId"] = reader["EMPLACEMENT_ID"] == DBNull.Value ? null : reader["EMPLACEMENT_ID"].ToString(),
                            ["emplacementNom"] = reader["EMPLACEMENT_NOM"] as string,
                            ["seuilMin"] = reader["SEUIL_MIN"],
                            ["seuilMax"] = reader["SEUIL_MAX"],
                            ["seuilAlerte"] = reader["SEUIL_ALERTE"],
                            ["poids"] = reader["POIDS"] == DBNull.Value ? null : reader["POIDS"],
                            ["volume"] = reader["VOLUME"] == DBNull.Value ? null : reader["VOLUME"],
                            ["active"] = reader["ACTIVE"],
                            ["estService"] = reader["EST_SERVICE"],
                            ["estPerissable"] = reader["EST_PERISSABLE"],
                            ["stockTotal"] = reader["STOCK_TOTAL"],
                        });
                    }
                }
            }

            Write(context, new { success = true, data = articles });
        }

        // ---------------------------------------------------------
        // UN SEUL ARTICLE (pour ouverture du formulaire en modification)
        // ---------------------------------------------------------
        private void GetById(HttpContext context)
        {
            Guid id;
            if (!Guid.TryParse(context.Request["id"], out id))
            {
                Write(context, new { success = false, message = "Identifiant invalide." });
                return;
            }

            const string sql = @"SELECT * FROM MARTICLE WHERE ID = @id AND DELETION_AT IS NULL;";

            using (var conn = new SqlConnection(ConnStr))
            using (var cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@id", id);
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    if (!reader.Read())
                    {
                        Write(context, new { success = false, message = "Article introuvable." });
                        return;
                    }

                    var article = new Dictionary<string, object>
                    {
                        ["id"] = reader["ID"].ToString(),
                        ["code"] = reader["CODE"],
                        ["codeBarre"] = reader["CODE_BARRE"] as string,
                        ["nom"] = reader["NOM"],
                        ["description"] = reader["DESCRIPTION"] as string,
                        ["categorieId"] = reader["CATEGORIE_ID"] == DBNull.Value ? null : reader["CATEGORIE_ID"].ToString(),
                        ["uniteId"] = reader["UNITE_MESURE_ID"] == DBNull.Value ? null : reader["UNITE_MESURE_ID"].ToString(),
                        ["fournisseurId"] = reader["FOURNISSEUR_PREFERE_ID"] == DBNull.Value ? null : reader["FOURNISSEUR_PREFERE_ID"].ToString(),
                        ["emplacementId"] = reader["EMPLACEMENT_ID"] == DBNull.Value ? null : reader["EMPLACEMENT_ID"].ToString(),
                        ["seuilMin"] = reader["SEUIL_MIN"],
                        ["seuilMax"] = reader["SEUIL_MAX"],
                        ["seuilAlerte"] = reader["SEUIL_ALERTE"],
                        ["poids"] = reader["POIDS"] == DBNull.Value ? null : reader["POIDS"],
                        ["volume"] = reader["VOLUME"] == DBNull.Value ? null : reader["VOLUME"],
                        ["active"] = reader["ACTIVE"],
                        ["estService"] = reader["EST_SERVICE"],
                        ["estPerissable"] = reader["EST_PERISSABLE"],
                    };
                    Write(context, new { success = true, data = article });
                }
            }
        }

        // ---------------------------------------------------------
        // LISTES POUR LES DROPDOWNS DU FORMULAIRE
        // ---------------------------------------------------------
        private void GetDropdowns(HttpContext context)
        {
            var result = new Dictionary<string, object>
            {
                ["categories"] = GetLookup("SELECT ID, NOM FROM SCATEGORIE WHERE ACTIVE = 1 AND DELETION_AT IS NULL ORDER BY NOM"),
                ["unites"] = GetLookup("SELECT ID, NOM, CODE FROM SUNITE WHERE ACTIVE = 1 AND DELETION_AT IS NULL ORDER BY NOM"),
                ["fournisseurs"] = GetLookup("SELECT ID, NOM FROM SFOURNISSEUR WHERE ACTIVE = 1 AND DELETION_AT IS NULL ORDER BY NOM"),
                ["emplacements"] = GetLookup("SELECT ID, NOM FROM SEMPLACEMENT WHERE ACTIVE = 1 AND DELETION_AT IS NULL ORDER BY NOM"),
            };
            Write(context, new { success = true, data = result });
        }

        private List<Dictionary<string, object>> GetLookup(string sql)
        {
            var list = new List<Dictionary<string, object>>();
            using (var conn = new SqlConnection(ConnStr))
            using (var cmd = new SqlCommand(sql, conn))
            {
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var row = new Dictionary<string, object>
                        {
                            ["id"] = reader["ID"].ToString(),
                            ["nom"] = reader["NOM"],
                        };
                        // colonne CODE optionnelle (presente pour SUNITE)
                        for (int i = 0; i < reader.FieldCount; i++)
                        {
                            if (reader.GetName(i) == "CODE")
                                row["code"] = reader["CODE"];
                        }
                        list.Add(row);
                    }
                }
            }
            return list;
        }

        // ---------------------------------------------------------
        // CREATION / MODIFICATION (upsert selon presence de l'ID)
        // ---------------------------------------------------------
        private void Save(HttpContext context)
        {
            string body = new System.IO.StreamReader(context.Request.InputStream).ReadToEnd();
            var js = new JavaScriptSerializer();
            var input = js.Deserialize<Dictionary<string, object>>(body);

            string id = input.ContainsKey("id") ? input["id"] as string : null;
            string code = (input["code"] as string ?? "").Trim();
            string nom = (input["nom"] as string ?? "").Trim();

            if (string.IsNullOrEmpty(code) || string.IsNullOrEmpty(nom))
            {
                Write(context, new { success = false, message = "Le code et le nom de l'article sont obligatoires." });
                return;
            }

            int idUser = Convert.ToInt32(context.Session["IDUser"]);

            using (var conn = new SqlConnection(ConnStr))
            {
                conn.Open();

                // Verifie l'unicite du code (hors article courant)
                using (var checkCmd = new SqlCommand(
                    "SELECT COUNT(1) FROM MARTICLE WHERE CODE = @code AND DELETION_AT IS NULL AND (@id IS NULL OR ID <> @id)", conn))
                {
                    checkCmd.Parameters.AddWithValue("@code", code);
                    checkCmd.Parameters.AddWithValue("@id", (object)id ?? DBNull.Value);
                    if ((int)checkCmd.ExecuteScalar() > 0)
                    {
                        Write(context, new { success = false, message = "Ce code article existe deja." });
                        return;
                    }
                }

                bool isUpdate = !string.IsNullOrEmpty(id);
                string sql = isUpdate ? @"
                    UPDATE MARTICLE SET
                        CODE = @code, CODE_BARRE = @codeBarre, NOM = @nom, DESCRIPTION = @description,
                        CATEGORIE_ID = @categorieId, UNITE_MESURE_ID = @uniteId,
                        FOURNISSEUR_PREFERE_ID = @fournisseurId, EMPLACEMENT_ID = @emplacementId,
                        SEUIL_MIN = @seuilMin, SEUIL_MAX = @seuilMax, SEUIL_ALERTE = @seuilAlerte,
                        POIDS = @poids, VOLUME = @volume,
                        ACTIVE = @active, EST_SERVICE = @estService, EST_PERISSABLE = @estPerissable,
                        UPDATED_AT = GETDATE(), UPDATED_BY = @idUser
                    WHERE ID = @id;"
                    : @"
                    INSERT INTO MARTICLE
                        (CODE, CODE_BARRE, NOM, DESCRIPTION, CATEGORIE_ID, UNITE_MESURE_ID,
                         FOURNISSEUR_PREFERE_ID, EMPLACEMENT_ID, SEUIL_MIN, SEUIL_MAX, SEUIL_ALERTE,
                         POIDS, VOLUME, ACTIVE, EST_SERVICE, EST_PERISSABLE, CREATED_BY)
                    OUTPUT INSERTED.ID
                    VALUES
                        (@code, @codeBarre, @nom, @description, @categorieId, @uniteId,
                         @fournisseurId, @emplacementId, @seuilMin, @seuilMax, @seuilAlerte,
                         @poids, @volume, @active, @estService, @estPerissable, @idUser);";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    if (isUpdate) cmd.Parameters.AddWithValue("@id", Guid.Parse(id));
                    cmd.Parameters.AddWithValue("@code", code);
                    cmd.Parameters.AddWithValue("@codeBarre", (object)(input.ContainsKey("codeBarre") ? input["codeBarre"] : null) ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@description", (object)(input.ContainsKey("description") ? input["description"] : null) ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@categorieId", ParseGuidOrNull(input, "categorieId"));
                    cmd.Parameters.AddWithValue("@uniteId", ParseGuidOrNull(input, "uniteId"));
                    cmd.Parameters.AddWithValue("@fournisseurId", ParseGuidOrNull(input, "fournisseurId"));
                    cmd.Parameters.AddWithValue("@emplacementId", ParseGuidOrNull(input, "emplacementId"));
                    cmd.Parameters.AddWithValue("@seuilMin", ParseDecimalOrZero(input, "seuilMin"));
                    cmd.Parameters.AddWithValue("@seuilMax", ParseDecimalOrZero(input, "seuilMax"));
                    cmd.Parameters.AddWithValue("@seuilAlerte", ParseDecimalOrZero(input, "seuilAlerte"));
                    cmd.Parameters.AddWithValue("@poids", (object)ParseDecimalOrNull(input, "poids") ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@volume", (object)ParseDecimalOrNull(input, "volume") ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@active", input.ContainsKey("active") ? (bool)input["active"] : true);
                    cmd.Parameters.AddWithValue("@estService", input.ContainsKey("estService") && (bool)input["estService"]);
                    cmd.Parameters.AddWithValue("@estPerissable", input.ContainsKey("estPerissable") && (bool)input["estPerissable"]);
                    cmd.Parameters.AddWithValue("@idUser", idUser);

                    if (isUpdate)
                    {
                        cmd.ExecuteNonQuery();
                        Write(context, new { success = true, message = "Article modifie avec succes.", data = new { id } });
                    }
                    else
                    {
                        var newId = cmd.ExecuteScalar();
                        Write(context, new { success = true, message = "Article cree avec succes.", data = new { id = newId.ToString() } });
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // SUPPRESSION LOGIQUE (soft delete, meme convention que MONAPPECOLE2)
        // ---------------------------------------------------------
        private void Delete(HttpContext context)
        {
            Guid id;
            if (!Guid.TryParse(context.Request["id"], out id))
            {
                Write(context, new { success = false, message = "Identifiant invalide." });
                return;
            }

            int idUser = Convert.ToInt32(context.Session["IDUser"]);

            const string sql = @"
                UPDATE MARTICLE
                SET DELETION_AT = GETDATE(), DELETION_BY = @idUser, ACTIVE = 0
                WHERE ID = @id;";

            using (var conn = new SqlConnection(ConnStr))
            using (var cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@id", id);
                cmd.Parameters.AddWithValue("@idUser", idUser);
                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                Write(context, rows > 0
                    ? new { success = true, message = "Article supprime avec succes." }
                    : new { success = false, message = "Article introuvable." });
            }
        }

        // ---------------------------------------------------------
        // Helpers
        // ---------------------------------------------------------
        private object ParseGuidOrNull(Dictionary<string, object> input, string key)
        {
            if (input.ContainsKey(key) && input[key] != null && Guid.TryParse(input[key].ToString(), out var g))
                return g;
            return DBNull.Value;
        }

        private decimal ParseDecimalOrZero(Dictionary<string, object> input, string key)
        {
            if (input.ContainsKey(key) && input[key] != null && decimal.TryParse(input[key].ToString(), out var d))
                return d;
            return 0;
        }

        private decimal? ParseDecimalOrNull(Dictionary<string, object> input, string key)
        {
            if (input.ContainsKey(key) && input[key] != null && decimal.TryParse(input[key].ToString(), out var d))
                return d;
            return null;
        }

        private void Write(HttpContext context, object obj)
        {
            var js = new JavaScriptSerializer();
            context.Response.Write(js.Serialize(obj));
        }
    }
}
