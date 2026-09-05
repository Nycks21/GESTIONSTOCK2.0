<%@ WebHandler Language="C#" Class="GetEvents" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEvents : IHttpHandler, IRequiresSessionState
{
    private static readonly string connStr;

    static GetEvents()
    {
        var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
        connStr = (connSetting != null) ? connSetting.ConnectionString : "";
    }

    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        context.Response.Charset = "utf-8";

        if (!AuthHelper.IsAuthenticated(context))
        {
            context.Response.StatusCode = 401;
            context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        // ✅ Vérification de rôle (pour le dashboard, Admin ou SuperAdmin)
        int role = AuthHelper.GetUserRole(context);
        if (role != 0 && role != 1)
        {
            context.Response.StatusCode = 403;
            context.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
            return;
        }

        if (string.IsNullOrEmpty(connStr))
        {
            context.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
            return;
        }

        try
        {
            int userId = AuthHelper.GetUserId(context);
            var events = new List<Dictionary<string, object>>();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string checkTable = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CALENDAREVENTS'";
                using (var checkCmd = new SqlCommand(checkTable, conn))
                {
                    int exists = (int)checkCmd.ExecuteScalar();
                    if (exists == 0)
                    {
                        context.Response.Write("{\"success\":true,\"events\":[]}");
                        return;
                    }
                }

                string sql = @"
                    SELECT 
                        ID, TEMPLATE_ID, IDUSER, TITRE, DATE_DEBUT, DATE_FIN,
                        COULEUR, HEURE_DEBUT, HEURE_FIN, DESCRIPTION,
                        TYPE, LIEU, PUBLIQUE, URL, CREATED_AT
                    FROM CALENDAREVENTS
                    ORDER BY DATE_DEBUT ASC";

                using (var cmd = new SqlCommand(sql, conn))
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        var e = new Dictionary<string, object>();
                        e["id"] = rdr["ID"].ToString();
                        e["templateId"] = rdr["TEMPLATE_ID"] != DBNull.Value ? Convert.ToInt32(rdr["TEMPLATE_ID"]) : (int?)null;
                        e["userId"] = rdr["IDUSER"] != DBNull.Value ? Convert.ToInt32(rdr["IDUSER"]) : (int?)null;
                        e["title"] = rdr["TITRE"] != DBNull.Value ? rdr["TITRE"].ToString() : "Sans titre";
                        e["start"] = rdr["DATE_DEBUT"] != DBNull.Value ? ((DateTime)rdr["DATE_DEBUT"]).ToString("yyyy-MM-ddTHH:mm:ss") : "";
                        e["end"] = rdr["DATE_FIN"] != DBNull.Value ? ((DateTime)rdr["DATE_FIN"]).ToString("yyyy-MM-ddTHH:mm:ss") : "";
                        e["color"] = rdr["COULEUR"] != DBNull.Value ? rdr["COULEUR"].ToString() : "#007bff";
                        e["heureDebut"] = rdr["HEURE_DEBUT"] != DBNull.Value ? rdr["HEURE_DEBUT"].ToString() : "";
                        e["heureFin"] = rdr["HEURE_FIN"] != DBNull.Value ? rdr["HEURE_FIN"].ToString() : "";
                        e["description"] = rdr["DESCRIPTION"] != DBNull.Value ? rdr["DESCRIPTION"].ToString() : "";
                        e["type"] = rdr["TYPE"] != DBNull.Value ? rdr["TYPE"].ToString() : "autre";
                        e["location"] = rdr["LIEU"] != DBNull.Value ? rdr["LIEU"].ToString() : "";
                        e["publique"] = rdr["PUBLIQUE"] != DBNull.Value ? rdr["PUBLIQUE"].ToString() : "all";
                        e["url"] = rdr["URL"] != DBNull.Value ? rdr["URL"].ToString() : "";
                        e["created_at"] = rdr["CREATED_AT"] != DBNull.Value ? ((DateTime)rdr["CREATED_AT"]).ToString("yyyy-MM-dd HH:mm") : "";
                        events.Add(e);
                    }
                }
            }

            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["events"] = events;
            context.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception)
        {
            context.Response.StatusCode = 500;
            context.Response.Write("{\"success\":false,\"message\":\"Erreur serveur\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}