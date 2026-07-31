<%@ WebHandler Language="C#" Class="GetStatistics" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetStatistics : IHttpHandler, IRequiresSessionState
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

            int monthEvents = 0;
            int upcoming = 0;
            int past = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérifier si la table existe
                string checkTable = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CALENDAREVENTS'";
                using (var checkCmd = new SqlCommand(checkTable, conn))
                {
                    int exists = (int)checkCmd.ExecuteScalar();
                    if (exists == 0)
                    {
                        ctx.Response.Write("{\"success\":true,\"monthEvents\":0,\"upcoming\":0,\"past\":0}");
                        return;
                    }
                }

                // Statistiques du mois en cours
                string sqlMonth = @"
                    SELECT COUNT(*) 
                    FROM CALENDAREVENTS 
                    WHERE MONTH(DATE_DEBUT) = MONTH(GETDATE())
                      AND YEAR(DATE_DEBUT) = YEAR(GETDATE())";
                using (var cmd = new SqlCommand(sqlMonth, conn))
                {
                    monthEvents = (int)cmd.ExecuteScalar();
                }

                // Événements à venir
                string sqlUpcoming = @"
                    SELECT COUNT(*) 
                    FROM CALENDAREVENTS 
                    WHERE DATE_DEBUT >= GETDATE()";
                using (var cmd = new SqlCommand(sqlUpcoming, conn))
                {
                    upcoming = (int)cmd.ExecuteScalar();
                }

                // Événements terminés
                string sqlPast = @"
                    SELECT COUNT(*) 
                    FROM CALENDAREVENTS 
                    WHERE DATE_FIN < GETDATE()";
                using (var cmd = new SqlCommand(sqlPast, conn))
                {
                    past = (int)cmd.ExecuteScalar();
                }
            }

            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["monthEvents"] = monthEvents;
            result["upcoming"] = upcoming;
            result["past"] = past;

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