<%@ WebHandler Language="C#" Class="SortieEdit" %>
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SortieEdit : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ✅ Authentification : tous les rôles authentifiés (0 à 4)
        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            string id = GetString(data, "id");
            if (string.IsNullOrEmpty(id))
                throw new Exception("ID manquant");

            // Vérifier si le bon est modifiable (statut = BROUILLON)
            if (!CanEdit(ctx, id))
                throw new Exception("Impossible de modifier un bon validé ou annulé.");

            string numero = GetString(data, "numero");
            string dateSortieStr = GetString(data, "dateSortie");
            DateTime dateSortie;
            bool hasNewDate = DateTime.TryParse(dateSortieStr, out dateSortie);

            string destination = GetString(data, "destination") ?? "";
            string nom = GetString(data, "nom") ?? "";
            string fonction = GetString(data, "fonction") ?? "";
            string notes = GetString(data, "notes") ?? "";

            ArrayList lignes = data.ContainsKey("lignes") ? (ArrayList)data["lignes"] : new ArrayList();

            if (string.IsNullOrEmpty(numero) || string.IsNullOrEmpty(destination) || lignes.Count == 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Numéro, destination et au moins une ligne sont requis.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var trans = conn.BeginTransaction())
                {
                    try
                    {
                        // 1. Mise à jour de l'entête (statut non modifié)
                        string sqlEntete = @"
                            UPDATE SSORTIE SET NUMERO = @numero, DATE_SORTIE = CASE WHEN @date IS NULL THEN DATE_SORTIE ELSE @date END, DESTINATION = @dest, NOM = @nom, FONCTION = @fonction, NOTES = @notes,
                                UPDATED_BY = @userId, UPDATED_AT = GETDATE()
                            WHERE ID = @id AND STATUT = 'BROUILLON' AND DELETION_AT IS NULL";
                        using (var cmd = new SqlCommand(sqlEntete, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@numero", numero);
                            cmd.Parameters.Add("@date", SqlDbType.DateTime).Value = hasNewDate ? (object)dateSortie : DBNull.Value;
                            cmd.Parameters.AddWithValue("@dest", destination);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@fonction", fonction);
                            cmd.Parameters.AddWithValue("@notes", notes);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            if (cmd.ExecuteNonQuery() != 1)
                                throw new Exception("Impossible de modifier un bon validé ou annulé.");
                        }

                        // 2. Supprimer les anciennes lignes
                        string sqlDelete = "DELETE FROM MLSORTIE WHERE BON_SORTIE_ID = @id";
                        using (var cmd = new SqlCommand(sqlDelete, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.ExecuteNonQuery();
                        }

                        // 3. Réinsérer les nouvelles lignes
                        foreach (Dictionary<string, object> ligne in lignes)
                        {
                            string articleId = null;
                            if (ligne.ContainsKey("articleId") && ligne["articleId"] != null)
                                articleId = ligne["articleId"].ToString();
                            if (string.IsNullOrEmpty(articleId)) continue;

                            decimal qteD = 0, qteR = 0;
                            if (ligne.ContainsKey("quantiteD") && ligne["quantiteD"] != null)
                                decimal.TryParse(ligne["quantiteD"].ToString(), out qteD);
                            if (ligne.ContainsKey("quantiteR") && ligne["quantiteR"] != null)
                                decimal.TryParse(ligne["quantiteR"].ToString(), out qteR);

                            string observations = "";
                            if (ligne.ContainsKey("observations") && ligne["observations"] != null)
                                observations = ligne["observations"].ToString();

                            string sqlLigne = @"
                                INSERT INTO MLSORTIE (ID, BON_SORTIE_ID, ARTICLE_ID, QUANTITE_D, QUANTITE_R, OBSERVATIONS, CREATED_BY, CREATED_AT)
                                VALUES (NEWID(), @bonId, @articleId, @qteD, @qteR, @obs, @userId, GETDATE())";
                            using (var cmd = new SqlCommand(sqlLigne, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@bonId", id);
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                cmd.Parameters.AddWithValue("@qteD", qteD);
                                cmd.Parameters.AddWithValue("@qteR", qteR);
                                cmd.Parameters.AddWithValue("@obs", observations);
                                cmd.Parameters.AddWithValue("@userId", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        // 4. Pas de mise à jour du statut (reste 'BROUILLON')
                        trans.Commit();
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, message = "Bon de sortie modifié avec succès." }));
                    }
                    catch
                    {
                        trans.Rollback();
                        throw;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    private bool CanEdit(HttpContext ctx, string bonId)
    {
        string connStr = AuthHelper.ConnectionString;
        using (var conn = new SqlConnection(connStr))
        {
            conn.Open();
            string sql = "SELECT STATUT FROM SSORTIE WHERE ID = @id";
            using (var cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@id", bonId);
                var obj = cmd.ExecuteScalar();
                return obj != null && obj.ToString() == "BROUILLON";
            }
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null;
    }

    public bool IsReusable { get { return false; } }
}
