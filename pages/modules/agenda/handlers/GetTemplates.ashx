<%@ WebHandler Language="C#" Class="GetTemplates" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetTemplates : IHttpHandler, IRequiresSessionState
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

            var templates = new List<Dictionary<string, object>>();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string checkTable = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'EVENTTEMPLATES'";
                using (var checkCmd = new SqlCommand(checkTable, conn))
                {
                    int exists = (int)checkCmd.ExecuteScalar();
                    if (exists == 0)
                    {
                        ctx.Response.Write("{\"success\":true,\"templates\":[]}");
                        return;
                    }
                }

                string sql = @"
                    SELECT 
                        ID, NOM, COULEUR, HEURE_DEBUT, HEURE_FIN,
                        DESCRIPTION, TYPE, LIEU, PUBLIQUE, URL, CREATED_AT
                    FROM EVENTTEMPLATES
                    ORDER BY NOM ASC";

                using (var cmd = new SqlCommand(sql, conn))
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        var t = new Dictionary<string, object>();
                        t["ID"] = rdr["ID"];
                        t["NOM"] = rdr["NOM"].ToString();
                        t["COULEUR"] = rdr["COULEUR"] != DBNull.Value ? rdr["COULEUR"].ToString() : "#007bff";
                        t["HEURE_DEBUT"] = rdr["HEURE_DEBUT"] != DBNull.Value ? rdr["HEURE_DEBUT"].ToString() : "";
                        t["HEURE_FIN"] = rdr["HEURE_FIN"] != DBNull.Value ? rdr["HEURE_FIN"].ToString() : "";
                        t["DESCRIPTION"] = rdr["DESCRIPTION"] != DBNull.Value ? rdr["DESCRIPTION"].ToString() : "";
                        t["TYPE"] = rdr["TYPE"] != DBNull.Value ? rdr["TYPE"].ToString() : "autre";
                        t["LIEU"] = rdr["LIEU"] != DBNull.Value ? rdr["LIEU"].ToString() : "";
                        t["PUBLIQUE"] = rdr["PUBLIQUE"] != DBNull.Value ? rdr["PUBLIQUE"].ToString() : "all";
                        t["URL"] = rdr["URL"] != DBNull.Value ? rdr["URL"].ToString() : "";
                        t["CREATED_AT"] = rdr["CREATED_AT"] != DBNull.Value ? ((DateTime)rdr["CREATED_AT"]).ToString("yyyy-MM-dd HH:mm") : "";
                        templates.Add(t);
                    }
                }
            }

            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["templates"] = templates;

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