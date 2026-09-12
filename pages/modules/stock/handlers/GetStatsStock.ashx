<%@ WebHandler Language="C#" Class="GetStatsStock" %>

using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetStatsStock : IHttpHandler, IRequiresSessionState
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
            string connStr = AuthHelper.ConnectionString;
            int totalArticles = 0;
            decimal totalQuantite = 0;
            int sousSeuil = 0;
            int rupture = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string totalsFromMovements = @"
                    FROM MARTICLE a
                    INNER JOIN (
                        SELECT le.ARTICLE_ID, SUM(le.QUANTITE) AS ENTREE
                        FROM MLENTREE le
                        INNER JOIN SENTREE be ON be.ID = le.BON_ENTREE_ID
                        WHERE le.DELETION_AT IS NULL AND be.STATUT = 'VALIDE' AND be.DELETION_AT IS NULL
                        GROUP BY le.ARTICLE_ID
                    ) ent ON ent.ARTICLE_ID = a.ID
                    LEFT JOIN (
                        SELECT ls.ARTICLE_ID, SUM(ls.QUANTITE_R) AS SORTIE
                        FROM MLSORTIE ls
                        INNER JOIN SSORTIE bs ON bs.ID = ls.BON_SORTIE_ID
                        WHERE ls.DELETION_AT IS NULL AND bs.STATUT = 'VALIDE' AND bs.DELETION_AT IS NULL
                        GROUP BY ls.ARTICLE_ID
                    ) sor ON sor.ARTICLE_ID = a.ID
                    WHERE a.DELETION_AT IS NULL";

                // Les cartes utilisent la même formule que le tableau.
                string sqlTotalArticles = "SELECT COUNT(*) " + totalsFromMovements + " AND ent.ENTREE - ISNULL(sor.SORTIE, 0) > 0";
                using (var cmd = new SqlCommand(sqlTotalArticles, conn))
                    totalArticles = (int)cmd.ExecuteScalar();

                string sqlTotalQuantite = "SELECT ISNULL(SUM(ent.ENTREE - ISNULL(sor.SORTIE, 0)), 0) " + totalsFromMovements;
                using (var cmd = new SqlCommand(sqlTotalQuantite, conn))
                    totalQuantite = (decimal)cmd.ExecuteScalar();

                string sqlSousSeuil = "SELECT COUNT(*) " + totalsFromMovements + " AND ent.ENTREE - ISNULL(sor.SORTIE, 0) <= a.SEUIL_ALERTE AND ent.ENTREE - ISNULL(sor.SORTIE, 0) > 0";
                using (var cmd = new SqlCommand(sqlSousSeuil, conn))
                    sousSeuil = (int)cmd.ExecuteScalar();

                string sqlRupture = "SELECT COUNT(*) " + totalsFromMovements + " AND ent.ENTREE - ISNULL(sor.SORTIE, 0) = 0";
                using (var cmd = new SqlCommand(sqlRupture, conn))
                    rupture = (int)cmd.ExecuteScalar();
            }

            var result = new
            {
                success = true,
                totalArticles,
                totalQuantite,
                sousSeuil,
                rupture
            };
            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}
