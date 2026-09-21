<%@ WebHandler Language="C#" Class="ArticlesImportHandler" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ArticlesImportHandler : IHttpHandler, IRequiresSessionState
{
    public bool IsReusable { get { return false; } }

    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        context.Response.ContentEncoding = System.Text.UTF8Encoding.UTF8;
        context.Response.Cache.SetNoStore();

        try
        {
            // ============================================================
            // Authentification : Session directement (pas d'AuthHelper)
            // ============================================================
            if (context.Session == null || context.Session["authenticated"] == null
                || !Convert.ToBoolean(context.Session["authenticated"]))
            {
                WriteJson(context, new { success = false, message = "Non authentifié" });
                return;
            }

            int currentRole = context.Session["USERROLE"] != null
                ? Convert.ToInt32(context.Session["USERROLE"]) : -1;

            // Seuls SuperAdmin (0) et Admin (1) peuvent importer
            if (currentRole != 0 && currentRole != 1)
            {
                WriteJson(context, new { success = false, message = "Accès non autorisé" });
                return;
            }

            int currentUserId = context.Session["IDUSER"] != null
                ? Convert.ToInt32(context.Session["IDUSER"]) : 0;

            // ============================================================
            // Lecture du corps JSON
            // ============================================================
            string body;
            using (var reader = new StreamReader(context.Request.InputStream))
            {
                body = reader.ReadToEnd();
            }

            if (string.IsNullOrEmpty(body))
            {
                WriteJson(context, new { success = false, message = "Corps de requête vide" });
                return;
            }

            var serializer = new JavaScriptSerializer();
            serializer.MaxJsonLength = int.MaxValue;

            List<Dictionary<string, object>> rows;
            try
            {
                rows = serializer.Deserialize<List<Dictionary<string, object>>>(body);
            }
            catch (Exception ex)
            {
                WriteJson(context, new { success = false, message = "JSON invalide : " + ex.Message });
                return;
            }

            if (rows == null || rows.Count == 0)
            {
                WriteJson(context, new { success = false, message = "Aucune ligne à importer" });
                return;
            }

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                WriteJson(context, new { success = false, message = "Chaîne de connexion non trouvée" });
                return;
            }

            int imported = 0;
            int skipped = 0;
            var errors = new List<string>();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                int defaultEmplacementId = GetFirstIdOrZero(conn, "EMPLACEMENTS");
                var categorieCache = LoadLookup(conn, "CATEGORIES", "NOM");
                var uniteCache     = LoadLookup(conn, "UNITES",     "NOM");

                int seq = 1;

                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        for (int i = 0; i < rows.Count; i++)
                        {
                            var row = rows[i];
                            int lineNum = i + 2;

                            try
                            {
                                string nom           = GetString(row, "nom");
                                string code          = GetString(row, "code");
                                string categorieName = GetString(row, "categorie");
                                string uniteName     = GetString(row, "unite");
                                decimal seuilAlerte  = GetDecimal(row, "seuilAlerte");
                                decimal stockInitial = GetDecimal(row, "stockInitial");

                                if (string.IsNullOrEmpty(nom))
                                {
                                    skipped++;
                                    errors.Add("Ligne " + lineNum + " : NOM manquant");
                                    continue;
                                }

                                if (string.IsNullOrEmpty(code))
                                {
                                    code = "ART-IMP-" + seq.ToString("D5");
                                    seq++;
                                }

                                int categorieId = 0;
                                if (!string.IsNullOrEmpty(categorieName))
                                {
                                    if (categorieCache.ContainsKey(categorieName))
                                        categorieId = categorieCache[categorieName];
                                    else
                                    {
                                        categorieId = InsertCategorie(conn, tx, categorieName);
                                        categorieCache[categorieName] = categorieId;
                                    }
                                }

                                int uniteId = 0;
                                if (!string.IsNullOrEmpty(uniteName))
                                {
                                    if (uniteCache.ContainsKey(uniteName))
                                        uniteId = uniteCache[uniteName];
                                    else
                                    {
                                        uniteId = InsertUnite(conn, tx, uniteName);
                                        uniteCache[uniteName] = uniteId;
                                    }
                                }

                                if (uniteId == 0)
                                {
                                    skipped++;
                                    errors.Add("Ligne " + lineNum + " : UNITÉ manquante ou vide");
                                    continue;
                                }

                                if (CodeExists(conn, tx, code))
                                {
                                    skipped++;
                                    errors.Add("Ligne " + lineNum + " : CODE déjà existant (" + code + ")");
                                    continue;
                                }

                                int newArticleId = InsertArticle(conn, tx,
                                    code, nom, categorieId, uniteId,
                                    defaultEmplacementId, seuilAlerte, currentUserId);

                                if (stockInitial > 0 && defaultEmplacementId > 0)
                                {
                                    try
                                    {
                                        InsertStockInitial(conn, tx, newArticleId,
                                            defaultEmplacementId, stockInitial,
                                            currentUserId, code);
                                    }
                                    catch (Exception exStock)
                                    {
                                        errors.Add("Ligne " + lineNum +
                                            " : article créé mais stock initial non enregistré (" +
                                            exStock.Message + ")");
                                    }
                                }

                                imported++;
                            }
                            catch (Exception exLine)
                            {
                                skipped++;
                                errors.Add("Ligne " + lineNum + " : " + exLine.Message);
                            }
                        }

                        tx.Commit();
                    }
                    catch
                    {
                        tx.Rollback();
                        throw;
                    }
                }
            }

            WriteJson(context, new
            {
                success  = true,
                imported = imported,
                skipped  = skipped,
                message  = imported + " article(s) importé(s)" +
                           (skipped > 0 ? ", " + skipped + " ignoré(s)" : ""),
                errors   = errors
            });
        }
        catch (Exception ex)
        {
            WriteJson(context, new { success = false, message = "Erreur serveur : " + ex.Message });
        }
    }

    // ============================================================
    // HELPERS
    // ============================================================

    private static void WriteJson(HttpContext context, object obj)
    {
        var ser = new JavaScriptSerializer();
        ser.MaxJsonLength = int.MaxValue;
        context.Response.Write(ser.Serialize(obj));
    }

    private static string GetString(Dictionary<string, object> row, string key)
    {
        if (row == null) return "";
        foreach (var k in row.Keys)
        {
            if (string.Equals(k, key, StringComparison.OrdinalIgnoreCase))
                return row[k] == null ? "" : row[k].ToString().Trim();
        }
        return "";
    }

    private static decimal GetDecimal(Dictionary<string, object> row, string key)
    {
        string s = GetString(row, key);
        if (string.IsNullOrEmpty(s)) return 0m;
        decimal d;
        if (decimal.TryParse(s, System.Globalization.NumberStyles.Any,
                             System.Globalization.CultureInfo.InvariantCulture, out d))
            return d;
        if (decimal.TryParse(s, System.Globalization.NumberStyles.Any,
                             System.Globalization.CultureInfo.GetCultureInfo("fr-FR"), out d))
            return d;
        return 0m;
    }

    private static int GetFirstIdOrZero(SqlConnection conn, string tableName)
    {
        try
        {
            using (var cmd = new SqlCommand("SELECT TOP 1 ID FROM [" + tableName + "] ORDER BY ID", conn))
            {
                object r = cmd.ExecuteScalar();
                return (r == null || r == DBNull.Value) ? 0 : Convert.ToInt32(r);
            }
        }
        catch { return 0; }
    }

    private static Dictionary<string, int> LoadLookup(SqlConnection conn, string tableName, string nameColumn)
    {
        var dict = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        try
        {
            using (var cmd = new SqlCommand(
                "SELECT ID, [" + nameColumn + "] FROM [" + tableName + "]", conn))
            using (var reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    if (reader[1] != DBNull.Value)
                    {
                        string k = reader[1].ToString().Trim();
                        if (!string.IsNullOrEmpty(k) && !dict.ContainsKey(k))
                            dict[k] = Convert.ToInt32(reader[0]);
                    }
                }
            }
        }
        catch { }
        return dict;
    }

    private static bool CodeExists(SqlConnection conn, SqlTransaction tx, string code)
    {
        using (var cmd = new SqlCommand("SELECT COUNT(*) FROM ARTICLES WHERE CODE = @code", conn, tx))
        {
            cmd.Parameters.AddWithValue("@code", code);
            return Convert.ToInt32(cmd.ExecuteScalar()) > 0;
        }
    }

    private static int InsertCategorie(SqlConnection conn, SqlTransaction tx, string nom)
    {
        using (var cmd = new SqlCommand(
            "INSERT INTO CATEGORIES (NOM) OUTPUT INSERTED.ID VALUES (@nom)", conn, tx))
        {
            cmd.Parameters.AddWithValue("@nom", nom);
            return Convert.ToInt32(cmd.ExecuteScalar());
        }
    }

    private static int InsertUnite(SqlConnection conn, SqlTransaction tx, string nom)
    {
        using (var cmd = new SqlCommand(
            "INSERT INTO UNITES (NOM, SYMBOLE) OUTPUT INSERTED.ID VALUES (@nom, @sym)", conn, tx))
        {
            cmd.Parameters.AddWithValue("@nom", nom);
            cmd.Parameters.AddWithValue("@sym", nom.Length > 5 ? nom.Substring(0, 5) : nom);
            return Convert.ToInt32(cmd.ExecuteScalar());
        }
    }

    private static int InsertArticle(SqlConnection conn, SqlTransaction tx,
        string code, string nom, int categorieId, int uniteId,
        int emplacementId, decimal seuilAlerte, int createdBy)
    {
        const string sql = @"
            INSERT INTO ARTICLES
                (CODE, NOM, CATEGORIE_ID, UNITE_MESURE_ID, EMPLACEMENT_ID,
                 SEUIL_ALERTE, ACTIVE, EST_SERVICE, CREATED_AT, CREATED_BY)
            OUTPUT INSERTED.ID
            VALUES
                (@Code, @Nom, @CategorieId, @UniteId, @EmplacementId,
                 @SeuilAlerte, 1, 0, GETDATE(), @CreatedBy)";

        using (var cmd = new SqlCommand(sql, conn, tx))
        {
            cmd.Parameters.AddWithValue("@Code", code);
            cmd.Parameters.AddWithValue("@Nom", nom);
            cmd.Parameters.AddWithValue("@CategorieId",
                categorieId > 0 ? (object)categorieId : DBNull.Value);
            cmd.Parameters.AddWithValue("@UniteId", uniteId);
            cmd.Parameters.AddWithValue("@EmplacementId",
                emplacementId > 0 ? (object)emplacementId : DBNull.Value);
            cmd.Parameters.AddWithValue("@SeuilAlerte", seuilAlerte);
            cmd.Parameters.AddWithValue("@CreatedBy", createdBy);
            return Convert.ToInt32(cmd.ExecuteScalar());
        }
    }

    private static void InsertStockInitial(SqlConnection conn, SqlTransaction tx,
        int articleId, int emplacementId, decimal quantite,
        int userId, string code)
    {
        const string sqlStock = @"
            IF EXISTS (SELECT 1 FROM STOCK WHERE ARTICLE_ID = @aid AND EMPLACEMENT_ID = @eid)
                UPDATE STOCK SET QUANTITE = QUANTITE + @qte
                WHERE ARTICLE_ID = @aid AND EMPLACEMENT_ID = @eid;
            ELSE
                INSERT INTO STOCK (ARTICLE_ID, EMPLACEMENT_ID, QUANTITE)
                VALUES (@aid, @eid, @qte);";

        using (var cmd = new SqlCommand(sqlStock, conn, tx))
        {
            cmd.Parameters.AddWithValue("@aid", articleId);
            cmd.Parameters.AddWithValue("@eid", emplacementId);
            cmd.Parameters.AddWithValue("@qte", quantite);
            cmd.ExecuteNonQuery();
        }

        const string sqlMvt = @"
            INSERT INTO MOUVEMENTS
                (ARTICLE_ID, EMPLACEMENT_ID, TYPE, QUANTITE,
                 QUANTITE_AVANT, QUANTITE_APRES, MOTIF,
                 REFERENCE_TYPE, REFERENCE_NUMERO, CREATED_AT, CREATED_BY)
            VALUES
                (@aid, @eid, 'ENTREE', @qte,
                 0, @qte, 'Stock initial (import)',
                 'IMPORT', @code, GETDATE(), @uid)";

        using (var cmd = new SqlCommand(sqlMvt, conn, tx))
        {
            cmd.Parameters.AddWithValue("@aid", articleId);
            cmd.Parameters.AddWithValue("@eid", emplacementId);
            cmd.Parameters.AddWithValue("@qte", quantite);
            cmd.Parameters.AddWithValue("@code", code);
            cmd.Parameters.AddWithValue("@uid", userId);
            cmd.ExecuteNonQuery();
        }
    }
}
