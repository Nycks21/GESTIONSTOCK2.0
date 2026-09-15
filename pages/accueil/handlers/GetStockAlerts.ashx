<%@ WebHandler Language="C#" Class="GetStockAlerts" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetStockAlerts : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequirePermission(ctx, "stock") &&
            !AuthHelper.RequirePermission(ctx, "articles"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            var list = new List<Dictionary<string, object>>();

            // ✅ MÊME LOGIQUE QUE GetStock.ashx :
            //   - DISPONIBLE  = SUM(SSTOCK.QUANTITE_ACTUELLE)
            //   - SEUIL_ALERTE = MARTICLE.SEUIL_ALERTE
            //   - STATUT ALERTE : DISPONIBLE > 0 ET SEUIL_ALERTE > 0 ET DISPONIBLE <= SEUIL_ALERTE
            string sql = @"
                SELECT
                    a.ID           AS ARTICLE_ID,
                    a.CODE         AS ARTICLE_CODE,
                    a.NOM          AS ARTICLE_NOM,
                    a.SEUIL_ALERTE,
                    c.NOM          AS CATEGORIE_NOM,
                    u.NOM          AS UNITE_NOM,
                    emp.EMPLACEMENT_ID,
                    emp.EMPLACEMENT_NOM,
                    ISNULL((
                        SELECT SUM(s.QUANTITE_ACTUELLE)
                        FROM SSTOCK s
                        WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                    ), 0) AS DISPONIBLE
                FROM MARTICLE a
                LEFT JOIN SCATEGORIE c ON c.ID = a.CATEGORIE_ID
                LEFT JOIN SUNITE u     ON u.ID = a.UNITE_MESURE_ID
                OUTER APPLY (
                    SELECT TOP 1 s.EMPLACEMENT_ID, e.NOM AS EMPLACEMENT_NOM
                    FROM SSTOCK s
                    INNER JOIN SEMPLACEMENT e ON e.ID = s.EMPLACEMENT_ID
                    WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                    ORDER BY s.QUANTITE_ACTUELLE DESC
                ) emp
                WHERE a.DELETION_AT IS NULL
                  AND EXISTS (
                      SELECT 1 FROM SSTOCK s
                      WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                  )
                  AND a.SEUIL_ALERTE > 0
                  AND ISNULL((
                      SELECT SUM(s.QUANTITE_ACTUELLE)
                      FROM SSTOCK s
                      WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                  ), 0) > 0
                  AND ISNULL((
                      SELECT SUM(s.QUANTITE_ACTUELLE)
                      FROM SSTOCK s
                      WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                  ), 0) <= a.SEUIL_ALERTE
                ORDER BY DISPONIBLE ASC, a.NOM ASC";

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var cmd = new SqlCommand(sql, conn))
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        var d = new Dictionary<string, object>();
                        d["ARTICLE_ID"]      = rdr["ARTICLE_ID"].ToString();
                        d["ARTICLE_CODE"]    = SafeStr(rdr["ARTICLE_CODE"]);
                        d["ARTICLE_NOM"]     = SafeStr(rdr["ARTICLE_NOM"]);
                        d["SEUIL_ALERTE"]    = rdr["SEUIL_ALERTE"] == DBNull.Value ? 0m : Convert.ToDecimal(rdr["SEUIL_ALERTE"]);
                        d["CATEGORIE_NOM"]   = SafeStr(rdr["CATEGORIE_NOM"]);
                        d["UNITE_NOM"]       = SafeStr(rdr["UNITE_NOM"]);
                        d["EMPLACEMENT_ID"]  = SafeStr(rdr["EMPLACEMENT_ID"]);
                        d["EMPLACEMENT_NOM"] = SafeStr(rdr["EMPLACEMENT_NOM"]);
                        d["DISPONIBLE"]      = rdr["DISPONIBLE"] == DBNull.Value ? 0m : Convert.ToDecimal(rdr["DISPONIBLE"]);
                        d["STATUT"]          = "ALERTE";
                        list.Add(d);
                    }
                }
            }

            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["data"] = list;
            result["total"] = list.Count;

            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(
                new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    private static string SafeStr(object v)
    {
        return v == null || v == DBNull.Value ? "" : v.ToString();
    }

    public bool IsReusable { get { return false; } }
}
