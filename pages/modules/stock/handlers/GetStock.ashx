<%@ WebHandler Language="C#" Class="GetStock" %>

using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetStock : IHttpHandler, IRequiresSessionState
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
            int page = 1, pageSize = 10;
            string search = ctx.Request.QueryString["search"] ?? "";
            string article = ctx.Request.QueryString["article"] ?? "";
            string emplacement = ctx.Request.QueryString["emplacement"] ?? "";
            string sortField = ctx.Request.QueryString["sort"] ?? "ARTICLE_NOM";
            string sortOrder = ctx.Request.QueryString["order"] ?? "ASC";

            int.TryParse(ctx.Request.QueryString["page"], out page);
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            bool getAll = (pageSize == 999999);

            var connStr = AuthHelper.ConnectionString;
            var list = new List<Dictionary<string, object>>();
            int total = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ✅ Filtre : tous les articles ayant du stock réel (SSTOCK)
                string whereClause = @"
                    WHERE a.DELETION_AT IS NULL
                      AND EXISTS (
                          SELECT 1 FROM SSTOCK s
                          WHERE s.ARTICLE_ID = a.ID
                            AND s.DELETION_AT IS NULL
                      )";
                if (!string.IsNullOrEmpty(search))
                    whereClause += " AND (a.CODE LIKE @search OR a.NOM LIKE @search)";
                if (!string.IsNullOrEmpty(article))
                    whereClause += " AND a.ID = @article";
                if (!string.IsNullOrEmpty(emplacement))
                    whereClause += @" AND EXISTS (
                        SELECT 1 FROM SSTOCK sf
                        WHERE sf.ARTICLE_ID = a.ID
                          AND sf.EMPLACEMENT_ID = @emplacement
                          AND sf.DELETION_AT IS NULL)";

                string sortColumn = "ARTICLE_NOM";
                switch (sortField.ToUpperInvariant())
                {
                    case "ARTICLE_CODE": sortColumn = "ARTICLE_CODE"; break;
                    case "ENTREE": sortColumn = "ENTREE"; break;
                    case "SORTIE": sortColumn = "SORTIE"; break;
                    case "DISPONIBLE": sortColumn = "DISPONIBLE"; break;
                    case "STATUT": sortColumn = "STATUT"; break;
                }
                string orderBy = "ORDER BY " + sortColumn + " " + (sortOrder.ToUpperInvariant() == "DESC" ? "DESC" : "ASC");

                // ✅ FIX :
                //   - ENTREE / SORTIE : lus depuis MSTOCK (tous mouvements : bons + ajustements)
                //   - DISPONIBLE : lu directement depuis SSTOCK (source de vérité)
                //   - Emplacement : le plus grand porteur de stock (OUTER APPLY)
                string fromSql = @"
                    FROM MARTICLE a
                    LEFT JOIN (
                        SELECT
                            ARTICLE_ID,
                            SUM(CASE WHEN TYPE = 'ENTREE' THEN QUANTITE ELSE 0 END) AS ENTREE,
                            SUM(CASE WHEN TYPE = 'SORTIE' THEN QUANTITE ELSE 0 END) AS SORTIE
                        FROM MSTOCK
                        WHERE DELETION_AT IS NULL
                        GROUP BY ARTICLE_ID
                    ) mvt ON mvt.ARTICLE_ID = a.ID
                    OUTER APPLY (
                        SELECT TOP 1 s.EMPLACEMENT_ID, e.NOM AS EMPLACEMENT_NOM, s.STATUT
                        FROM SSTOCK s
                        INNER JOIN SEMPLACEMENT e ON e.ID = s.EMPLACEMENT_ID
                        WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                        ORDER BY s.QUANTITE_ACTUELLE DESC
                    ) emp";

                string calculatedColumns = @"
                    a.ID AS ARTICLE_ID,
                    a.CODE AS ARTICLE_CODE,
                    a.NOM AS ARTICLE_NOM,
                    emp.EMPLACEMENT_ID,
                    emp.EMPLACEMENT_NOM,
                    a.SEUIL_ALERTE,
                    ISNULL(mvt.ENTREE, 0) AS ENTREE,
                    ISNULL(mvt.SORTIE, 0) AS SORTIE,
                    ISNULL((SELECT SUM(s.QUANTITE_ACTUELLE)
                            FROM SSTOCK s
                            WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL), 0) AS DISPONIBLE,
                    emp.STATUT AS STATUT";

                string countSql = "SELECT COUNT(*) " + fromSql + " " + whereClause;

                string selectSql = "SELECT " + calculatedColumns + " " + fromSql + " " + whereClause + @"
                    " + orderBy + @"
                    OFFSET @offset ROWS FETCH NEXT @fetch ROWS ONLY";

                using (var cmd = new SqlCommand(countSql, conn))
                {
                    AddParameters(cmd, search, article, emplacement);
                    total = (int)cmd.ExecuteScalar();
                }

                if (!getAll && pageSize > 0)
                {
                    int offset = (page - 1) * pageSize;
                    using (var cmd = new SqlCommand(selectSql, conn))
                    {
                        AddParameters(cmd, search, article, emplacement);
                        cmd.Parameters.AddWithValue("@offset", offset);
                        cmd.Parameters.AddWithValue("@fetch", pageSize);
                        using (var reader = cmd.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                var d = new Dictionary<string, object>();
                                d["ARTICLE_ID"] = reader["ARTICLE_ID"].ToString();
                                d["EMPLACEMENT_ID"] = reader["EMPLACEMENT_ID"] == DBNull.Value ? null : reader["EMPLACEMENT_ID"].ToString();
                                d["ARTICLE_CODE"] = reader["ARTICLE_CODE"];
                                d["ARTICLE_NOM"] = reader["ARTICLE_NOM"];
                                d["SEUIL_ALERTE"] = reader["SEUIL_ALERTE"];
                                d["EMPLACEMENT_NOM"] = reader["EMPLACEMENT_NOM"];
                                d["ENTREE"] = reader["ENTREE"];
                                d["SORTIE"] = reader["SORTIE"];
                                d["DISPONIBLE"] = reader["DISPONIBLE"];
                                d["STATUT"] = reader["STATUT"] == DBNull.Value ? "NORMALE" : reader["STATUT"].ToString();
                                list.Add(d);
                            }
                        }
                    }
                }
                else
                {
                    string allSql = "SELECT " + calculatedColumns + " " + fromSql + " " + whereClause + " " + orderBy;
                    using (var cmd = new SqlCommand(allSql, conn))
                    {
                        AddParameters(cmd, search, article, emplacement);
                        using (var reader = cmd.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                var d = new Dictionary<string, object>();
                                d["ARTICLE_ID"] = reader["ARTICLE_ID"].ToString();
                                d["EMPLACEMENT_ID"] = reader["EMPLACEMENT_ID"] == DBNull.Value ? null : reader["EMPLACEMENT_ID"].ToString();
                                d["ARTICLE_CODE"] = reader["ARTICLE_CODE"];
                                d["ARTICLE_NOM"] = reader["ARTICLE_NOM"];
                                d["SEUIL_ALERTE"] = reader["SEUIL_ALERTE"];
                                d["EMPLACEMENT_NOM"] = reader["EMPLACEMENT_NOM"];
                                d["ENTREE"] = reader["ENTREE"];
                                d["SORTIE"] = reader["SORTIE"];
                                d["DISPONIBLE"] = reader["DISPONIBLE"];
                                d["STATUT"] = reader["STATUT"] == DBNull.Value ? "NORMALE" : reader["STATUT"].ToString();
                                list.Add(d);
                            }
                        }
                    }
                }
            }

            int totalPages = (pageSize > 0 && pageSize < 999999) ? (int)Math.Ceiling((double)total / pageSize) : 1;
            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["Stock"] = list;
            result["total"] = total;
            result["totalPages"] = totalPages;

            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    private void AddParameters(SqlCommand cmd, string search, string article, string emplacement)
    {
        if (!string.IsNullOrEmpty(search))
            cmd.Parameters.AddWithValue("@search", "%" + search + "%");
        if (!string.IsNullOrEmpty(article))
            cmd.Parameters.AddWithValue("@article", article);
        if (!string.IsNullOrEmpty(emplacement))
            cmd.Parameters.AddWithValue("@emplacement", emplacement);
    }

    public bool IsReusable { get { return false; } }
}
