<%@ WebHandler Language="C#" Class="GetAnnee" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetAnnee : IHttpHandler, IRequiresSessionState
{
    private static readonly string connStr;

    static GetAnnee()
    {
        var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
        connStr = (connSetting != null) ? connSetting.ConnectionString : "";
    }

    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ✅ Vérification d'authentification simplifiée
        if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        // ✅ Vérification du rôle (SuperAdmin ou Admin)
        object roleObj = ctx.Session["USERROLE"];
        int role = (roleObj != null) ? Convert.ToInt32(roleObj) : -1;
        if (role != 0 && role != 1)
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
            return;
        }

        try
        {
            var list = new List<object>();

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand("SELECT ID, ANNEE, DATE_DEBUT, DATE_FIN, CLOTURE, DATE_CLOTURE, CREATED_AT FROM [dbo].[RANNEE] ORDER BY DATE_DEBUT DESC", conn))
            {
                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        list.Add(new
                        {
                            ID = reader.GetInt32(0),
                            ANNEE = reader.GetString(1),
                            DATE_DEBUT = reader.GetDateTime(2),
                            DATE_FIN = reader.GetDateTime(3),
                            CLOTURE = reader.GetBoolean(4),
                            DATE_CLOTURE = reader.IsDBNull(5) ? null : (DateTime?)reader.GetDateTime(5),
                            CREATED_AT = reader.GetDateTime(6)
                        });
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, Annees = list }));
        }
        catch (Exception)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur serveur\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}