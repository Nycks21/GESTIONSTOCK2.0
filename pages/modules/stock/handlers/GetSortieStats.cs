<%@ WebHandler Language="C#" Class="GetSortieStats" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetSortieStats : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                // Récupérer les totaux par statut
                string sql = @"
                    SELECT
                        COUNT(*) AS Total,
                        SUM(CASE WHEN STATUT = 'VALIDE' THEN 1 ELSE 0 END) AS Valide,
                        SUM(CASE WHEN STATUT = 'BROUILLON' THEN 1 ELSE 0 END) AS Brouillon,
                        SUM(CASE WHEN STATUT = 'ANNULE' THEN 1 ELSE 0 END) AS Annule,
                        SUM(CASE WHEN ISNULL(STATUT, '') <> 'VALIDE' THEN 1 ELSE 0 END) AS Pending
                    FROM SSORTIE
                    WHERE DELETION_AT IS NULL";
                // ✅ Ajout de la colonne Pending (non validés)
                int total = 0, valide = 0, brouillon = 0, annule = 0, pending = 0;
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    using (SqlDataReader rdr = cmd.ExecuteReader())
                    {
                        if (rdr.Read())
                        {
                            total = Convert.ToInt32(rdr["Total"]);
                            valide = Convert.ToInt32(rdr["Valide"]);
                            brouillon = Convert.ToInt32(rdr["Brouillon"]);
                            annule = Convert.ToInt32(rdr["Annule"]);
                            pending = Convert.ToInt32(rdr["Pending"]);
                        }
                    }
                }
                ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                {
                    success = true,
                    total,
                    valide,
                    brouillon,
                    annule,
                    pending // ✅ nouveau champ
                }));
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable => false;
}
