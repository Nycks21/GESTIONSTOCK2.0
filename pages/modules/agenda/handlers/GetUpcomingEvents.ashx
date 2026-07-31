<%@ WebHandler Language="C#" Class="GetUpcomingEvents" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetUpcomingEvents : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        if (!AuthHelper.HasPermission("agenda"))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

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
                        ctx.Response.Write("{\"success\":true,\"events\":[]}");
                        return;
                    }
                }

                string sql = @"
                    SELECT TOP 10
                        ce.ID, ce.TEMPLATE_ID, ce.IDUSER, ce.TITRE,
                        ce.DATE_DEBUT, ce.DATE_FIN, ce.COULEUR,
                        ce.HEURE_DEBUT, ce.HEURE_FIN, ce.DESCRIPTION,
                        ce.TYPE, ce.LIEU, ce.PUBLIQUE, ce.URL, ce.CREATED_AT,
                        CASE 
                            WHEN ce.TEMPLATE_ID IS NOT NULL THEN (SELECT NOM FROM EVENTTEMPLATES WHERE ID = ce.TEMPLATE_ID)
                            ELSE 'Personnalisé'
                        END AS TEMPLATE_NOM
                    FROM CALENDAREVENTS ce
                    WHERE ce.DATE_DEBUT >= GETDATE()
                    ORDER BY ce.DATE_DEBUT ASC, ce.HEURE_DEBUT ASC";

                using (var cmd = new SqlCommand(sql, conn))
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        var e = new Dictionary<string, object>();
                        e["ID"] = rdr["ID"].ToString();
                        e["TEMPLATE_ID"] = rdr["TEMPLATE_ID"] != DBNull.Value ? Convert.ToInt32(rdr["TEMPLATE_ID"]) : (int?)null;
                        e["IDUSER"] = rdr["IDUSER"] != DBNull.Value ? Convert.ToInt32(rdr["IDUSER"]) : (int?)null;
                        e["TITRE"] = rdr["TITRE"] != DBNull.Value ? rdr["TITRE"].ToString() : "Sans titre";
                        e["DATE_DEBUT"] = rdr["DATE_DEBUT"] != DBNull.Value ? ((DateTime)rdr["DATE_DEBUT"]).ToString("yyyy-MM-dd") : "";
                        e["DATE_FIN"] = rdr["DATE_FIN"] != DBNull.Value ? ((DateTime)rdr["DATE_FIN"]).ToString("yyyy-MM-dd") : "";
                        e["COULEUR"] = rdr["COULEUR"] != DBNull.Value ? rdr["COULEUR"].ToString() : "#007bff";
                        e["HEURE_DEBUT"] = rdr["HEURE_DEBUT"] != DBNull.Value ? rdr["HEURE_DEBUT"].ToString() : "";
                        e["HEURE_FIN"] = rdr["HEURE_FIN"] != DBNull.Value ? rdr["HEURE_FIN"].ToString() : "";
                        e["DESCRIPTION"] = rdr["DESCRIPTION"] != DBNull.Value ? rdr["DESCRIPTION"].ToString() : "";
                        e["TYPE"] = rdr["TYPE"] != DBNull.Value ? rdr["TYPE"].ToString() : "autre";
                        e["LIEU"] = rdr["LIEU"] != DBNull.Value ? rdr["LIEU"].ToString() : "";
                        e["PUBLIQUE"] = rdr["PUBLIQUE"] != DBNull.Value ? rdr["PUBLIQUE"].ToString() : "all";
                        e["URL"] = rdr["URL"] != DBNull.Value ? rdr["URL"].ToString() : "";
                        e["TEMPLATE_NOM"] = rdr["TEMPLATE_NOM"] != DBNull.Value ? rdr["TEMPLATE_NOM"].ToString() : "Événement";
                        e["CREATED_AT"] = rdr["CREATED_AT"] != DBNull.Value ? ((DateTime)rdr["CREATED_AT"]).ToString("yyyy-MM-dd HH:mm") : "";
                        events.Add(e);
                    }
                }
            }

            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["events"] = events;

            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}