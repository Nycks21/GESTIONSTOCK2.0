<%@ WebHandler Language="C#" Class="SortieAdd" %>
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SortieAdd : IHttpHandler, IRequiresSessionState
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

            string numero = GetString(data, "numero");
            string dateSortieStr = GetString(data, "dateSortie");
            DateTime dateSortie;
            if (string.IsNullOrEmpty(dateSortieStr) || !DateTime.TryParse(dateSortieStr, out dateSortie))
                dateSortie = DateTime.Now;

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
                        string id = Guid.NewGuid().ToString();

                        string sqlEntete = @"
                            INSERT INTO SSORTIE (ID, NUMERO, DATE_SORTIE, DESTINATION, NOM, FONCTION, NOTES, STATUT, CREATED_BY, CREATED_AT)
                            VALUES (@id, @numero, @date, @dest, @nom, @fonction, @notes, 'BROUILLON', @userId, GETDATE())";
                        using (var cmd = new SqlCommand(sqlEntete, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@numero", numero);
                            cmd.Parameters.AddWithValue("@date", dateSortie);
                            cmd.Parameters.AddWithValue("@dest", destination);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@fonction", fonction);
                            cmd.Parameters.AddWithValue("@notes", notes);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        foreach (Dictionary<string, object> ligne in lignes)
                        {
                            string articleId = null;
                            if (ligne.ContainsKey("articleId") && ligne["articleId"] != null)
                                articleId = ligne["articleId"].ToString();
                            if (string.IsNullOrEmpty(articleId)) continue;

                            decimal qteD = 0;
                            if (ligne.ContainsKey("quantiteD") && ligne["quantiteD"] != null)
                                decimal.TryParse(ligne["quantiteD"].ToString(), out qteD);

                            decimal qteR = 0;
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

                        trans.Commit();
                        ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, id = id, message = "Bon de sortie créé avec succès." }));
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

    private string GetString(Dictionary<string, object> data, string key)
    {
        return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null;
    }

    public bool IsReusable { get { return false; } }
}
