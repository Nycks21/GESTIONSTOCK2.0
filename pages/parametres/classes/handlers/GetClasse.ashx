<%@ WebHandler Language="C#" Class="GetClasse" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetClasse : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            // 1. Authentification
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            // 2. Token de session valide
            if (!AuthHelper.RequireApiAuth(ctx))
            {
                ctx.Response.StatusCode = 403;
                ctx.Response.Write("{\"success\":false,\"message\":\"Session invalide\"}");
                return;
            }

            // 3. Permission (SuperAdmin = 0, Admin = 1, etc.)
            int role = AuthHelper.GetUserRole(ctx);
            if (role < 0 || role > 1)
            {
                ctx.Response.StatusCode = 403;
                ctx.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
                return;
            }

            // 4. CSRF pour les méthodes POST/PUT/DELETE
            string method = ctx.Request.HttpMethod.ToUpper();
            if (method == "POST" || method == "PUT" || method == "DELETE")
            {
                string token = ctx.Request.Headers["X-CSRF-Token"];
                string sessionToken = ctx.Session["CSRF_TOKEN"] != null ? ctx.Session["CSRF_TOKEN"].ToString() : null;
                if (string.IsNullOrEmpty(token) || token != sessionToken)
                {
                    ctx.Response.StatusCode = 403;
                    ctx.Response.Write("{\"success\":false,\"message\":\"Token CSRF invalide\"}");
                    return;
                }
            }

            // Récupération de la chaîne de connexion
            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }

            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.StatusCode = 500;
                ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée\"}");
                return;
            }

            // Récupération de l'ID de la classe (optionnel)
            string classeId = ctx.Request.QueryString["id"];
            
            // Si un ID est fourni, retourner une seule classe
            if (!string.IsNullOrEmpty(classeId))
            {
                GetClasseById(ctx, connStr, classeId);
            }
            else
            {
                // Sinon, retourner toutes les classes
                GetAllClasses(ctx, connStr);
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "'") + "\"}");
        }
    }

    private void GetClasseById(HttpContext ctx, string connStr, string classeId)
    {
        var result = new Dictionary<string, object>();

        using (var conn = new SqlConnection(connStr))
        using (var cmd = new SqlCommand(@"
            SELECT 
                c.ID,
                c.NOM,
                c.NIVEAU_ID,
                n.NOM AS NIVEAU_NOM,
                c.EFFECTIF,
                c.TITULAIRE_ID,
                u.NOM AS TITULAIRE_NOM,
                c.SALLE_ID,
                s.NUMERO AS SALLE_NUMERO,
                c.STATUT,
                c.CREATED_AT
            FROM [dbo].[CLASSES] c
            LEFT JOIN [dbo].[NIVEAUX] n ON n.ID = c.NIVEAU_ID
            LEFT JOIN [dbo].[USERS] u ON u.IDUSER = c.TITULAIRE_ID
            LEFT JOIN [dbo].[SALLES] s ON s.ID = c.SALLE_ID
            WHERE c.ID = @id", conn))
        {
            cmd.Parameters.AddWithValue("@id", classeId);
            conn.Open();
            
            using (var reader = cmd.ExecuteReader())
            {
                if (reader.Read())
                {
                    result["ID"] = reader.IsDBNull(0) ? "" : reader.GetInt32(0).ToString();
                    result["NOM"] = reader.IsDBNull(1) ? "" : reader.GetString(1);
                    result["NIVEAU_ID"] = reader.IsDBNull(2) ? "" : reader.GetGuid(2).ToString();
                    result["NIVEAU_NOM"] = reader.IsDBNull(3) ? "" : reader.GetString(3);
                    result["EFFECTIF"] = reader.IsDBNull(4) ? 0 : reader.GetInt32(4);
                    result["TITULAIRE_ID"] = reader.IsDBNull(5) ? 0 : reader.GetInt32(5);
                    result["TITULAIRE_NOM"] = reader.IsDBNull(6) ? "" : reader.GetString(6);
                    result["SALLE_ID"] = reader.IsDBNull(7) ? "" : reader.GetGuid(7).ToString();
                    result["SALLE_NUMERO"] = reader.IsDBNull(8) ? "" : reader.GetString(8);
                    result["STATUT"] = !reader.IsDBNull(9) && reader.GetBoolean(9);
                    result["CREATED_AT"] = reader.IsDBNull(10) ? "" : reader.GetDateTime(10).ToString("yyyy-MM-dd HH:mm:ss");
                }
                else
                {
                    ctx.Response.Write("{\"success\":false,\"message\":\"Classe non trouvée\"}");
                    return;
                }
            }
        }

        var response = new Dictionary<string, object>();
        response["success"] = true;
        response["data"] = result;

        var serializer = new JavaScriptSerializer();
        ctx.Response.Write(serializer.Serialize(response));
    }

    private void GetAllClasses(HttpContext ctx, string connStr)
    {
        var classes = new List<object>();

        using (var conn = new SqlConnection(connStr))
        using (var cmd = new SqlCommand(@"
            SELECT 
                c.ID,
                c.NOM,
                n.NOM AS NIVEAU,
                c.EFFECTIF,
                u.NOM AS TITULAIRE,
                s.NUMERO AS SALLE,
                c.STATUT,
                c.NIVEAU_ID,
                c.TITULAIRE_ID,
                c.SALLE_ID
            FROM [dbo].[CLASSES] c
            LEFT JOIN [dbo].[NIVEAUX] n ON n.ID = c.NIVEAU_ID
            LEFT JOIN [dbo].[USERS] u ON u.IDUSER = c.TITULAIRE_ID
            LEFT JOIN [dbo].[SALLES] s ON s.ID = c.SALLE_ID
            ORDER BY c.NOM", conn))
        {
            conn.Open();
            
            using (var reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    var item = new Dictionary<string, object>();
                    item["ID"] = reader.IsDBNull(0) ? "" : reader.GetInt32(0).ToString();
                    item["NOM"] = reader.IsDBNull(1) ? "" : reader.GetString(1);
                    item["NIVEAU"] = reader.IsDBNull(2) ? "" : reader.GetString(2);
                    item["EFFECTIF"] = reader.IsDBNull(3) ? 0 : reader.GetInt32(3);
                    item["TITULAIRE"] = reader.IsDBNull(4) ? "" : reader.GetString(4);
                    item["SALLE"] = reader.IsDBNull(5) ? "" : reader.GetString(5);
                    item["STATUT"] = !reader.IsDBNull(6) && reader.GetBoolean(6);
                    item["NIVEAU_ID"] = reader.IsDBNull(7) ? "" : reader.GetGuid(7).ToString();
                    item["TITULAIRE_ID"] = reader.IsDBNull(8) ? 0 : reader.GetInt32(8);
                    item["SALLE_ID"] = reader.IsDBNull(9) ? "" : reader.GetGuid(9).ToString();
                    classes.Add(item);
                }
            }
        }

        var response = new Dictionary<string, object>();
        response["success"] = true;
        response["Classes"] = classes;

        var serializer = new JavaScriptSerializer();
        ctx.Response.Write(serializer.Serialize(response));
    }

    public bool IsReusable
    {
        get { return false; }
    }
}