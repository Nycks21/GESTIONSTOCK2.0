<%@ WebHandler Language="C#" Class="GetAbsences" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetAbsences : IHttpHandler, IRequiresSessionState
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

        var list = new List<object>();
        string connStr = AuthHelper.ConnectionString;

        if (string.IsNullOrEmpty(connStr))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
            return;
        }

        try
        {
            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(@"
                SELECT a.ID, a.MATRICULE, a.NOM, c.NOM AS CLASSE_NOM, 
                       a.DATE_DEBUT, a.DATE_FIN, a.MOTIF, a.JUSTIFIE, a.JUSTIFICATION,
                       DATEDIFF(day, a.DATE_DEBUT, a.DATE_FIN) + 1 AS DUREE,
                       ISNULL(a.MOTIF, '') AS MOTIF_AFFICHAGE
                FROM ABSENCES a
                LEFT JOIN CLASSES c ON a.CLASSE = c.ID
                WHERE a.DELETION_AT IS NULL
                ORDER BY a.DATE_DEBUT DESC", conn))
            {
                conn.Open();
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        list.Add(new
                        {
                            ID = rdr["ID"].ToString(),
                            MATRICULE = rdr["MATRICULE"].ToString(),
                            NOM = rdr["NOM"].ToString(),
                            CLASSE_NOM = rdr["CLASSE_NOM"].ToString(),
                            DATE_DEBUT = Convert.ToDateTime(rdr["DATE_DEBUT"]).ToString("yyyy-MM-dd"),
                            DATE_FIN = rdr["DATE_FIN"] != DBNull.Value ? Convert.ToDateTime(rdr["DATE_FIN"]).ToString("yyyy-MM-dd") : "",
                            DUREE = rdr["DUREE"].ToString(),
                            MOTIF = rdr["MOTIF_AFFICHAGE"].ToString(),
                            JUSTIFIE = Convert.ToBoolean(rdr["JUSTIFIE"]),
                            JUSTIFICATION = rdr["JUSTIFICATION"].ToString()
                        });
                    }
                }
            }
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, data = list }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}