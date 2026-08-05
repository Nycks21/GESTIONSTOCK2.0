<%@ WebHandler Language="C#" Class="GetRetards" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetRetards : IHttpHandler, IRequiresSessionState
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
                SELECT r.ID, r.MATRICULE, r.NOM, c.NOM AS CLASSE_NOM, 
                       r.DATE_RETARD, r.HEURE_ARRIVEE, r.HEURE_PREVUE, r.DUREE, 
                       r.MOTIF, r.JUSTIFIE, r.JUSTIFICATION,
                       ISNULL(r.MOTIF, '') AS MOTIF_AFFICHAGE
                FROM RETARDS r
                LEFT JOIN CLASSES c ON r.CLASSE = c.ID
                WHERE r.DELETION_AT IS NULL
                ORDER BY r.DATE_RETARD DESC", conn))
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
                            DATE_RETARD = Convert.ToDateTime(rdr["DATE_RETARD"]).ToString("yyyy-MM-dd"),
                            HEURE_ARRIVEE = rdr["HEURE_ARRIVEE"].ToString(),
                            HEURE_PREVUE = rdr["HEURE_PREVUE"].ToString(),
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