<%@ WebHandler Language="C#" Class="GetArticles" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetArticles : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            int page = 1;
            int pageSize = 10;
            int.TryParse(ctx.Request.QueryString["page"], out page);
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 10;
            if (pageSize > 100 && pageSize != 999999) pageSize = 100;

            string search = (ctx.Request.QueryString["search"] ?? "").Trim();
            string category = (ctx.Request.QueryString["category"] ?? "").Trim();
            string status = (ctx.Request.QueryString["status"] ?? "").Trim();
            string sort = (ctx.Request.QueryString["sort"] ?? "NOM").Trim();
            string order = (ctx.Request.QueryString["order"] ?? "ASC").Trim();

            var articles = new List<object>();

                        string whereClause = @"
                                WHERE a.DELETION_AT IS NULL
                                    AND EXISTS (
                                            SELECT 1
                                            FROM MLENTREE le
                                            INNER JOIN SENTREE be ON be.ID = le.BON_ENTREE_ID
                                            WHERE le.ARTICLE_ID = a.ID
                                                AND le.DELETION_AT IS NULL
                                                AND be.STATUT = 'VALIDE'
                                                AND be.DELETION_AT IS NULL
                                    )
                                    AND ISNULL((
                                            SELECT SUM(s.QUANTITE_ACTUELLE)
                                            FROM SSTOCK s
                                            WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                                    ), 0) > 0 ";
            if (!string.IsNullOrEmpty(search))
            {
                whereClause += " AND (LOWER(a.CODE) LIKE @search OR LOWER(a.NOM) LIKE @search OR LOWER(a.DESCRIPTION) LIKE @search) ";
            }
            if (!string.IsNullOrEmpty(category))
            {
                whereClause += " AND a.CATEGORIE_ID = @category ";
            }
            if (!string.IsNullOrEmpty(status))
            {
                whereClause += " AND CASE WHEN ISNULL((SELECT SUM(QUANTITE_ACTUELLE) FROM SSTOCK s WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL), 0) <= 0 THEN 'RUPTURE' WHEN ISNULL((SELECT SUM(QUANTITE_ACTUELLE) FROM SSTOCK s WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL), 0) <= a.SEUIL_ALERTE THEN 'ALERTE' ELSE 'NORMAL' END = @status ";
            }

            string sortField = "a.NOM";
            switch ((sort ?? "NOM").ToUpperInvariant())
            {
                case "CODE": sortField = "a.CODE"; break;
                case "CATEGORIE": sortField = "c.NOM"; break;
                case "FOURNISSEUR": sortField = "f.NOM"; break;
                case "UNITE": sortField = "u.NOM"; break;
                case "STOCK_DISPONIBLE": sortField = "STOCK_DISPONIBLE"; break;
                case "SEUIL_ALERTE": sortField = "a.SEUIL_ALERTE"; break;
                case "STATUT_STOCK": sortField = "STATUT_STOCK"; break;
                default: sortField = "a.NOM"; break;
            }

            string sqlCount = @"
                SELECT COUNT(*)
                FROM MARTICLE a
                LEFT JOIN SCATEGORIE c ON c.ID = a.CATEGORIE_ID
                LEFT JOIN SUNITE u ON u.ID = a.UNITE_MESURE_ID
                LEFT JOIN SFOURNISSEUR f ON f.ID = a.FOURNISSEUR_PREFERE_ID
                " + whereClause;

            string sqlList = @"
                SELECT
                    a.ID, a.CODE, a.CODE_BARRE, a.NOM, a.DESCRIPTION,
                    a.CATEGORIE_ID, c.NOM AS CATEGORIE,
                    a.UNITE_MESURE_ID, u.NOM AS UNITE,
                    a.FOURNISSEUR_PREFERE_ID, f.NOM AS FOURNISSEUR,
                    a.EMPLACEMENT_ID,
                    a.SEUIL_MIN, a.SEUIL_ALERTE, a.POIDS, a.VOLUME,
                    a.ACTIVE, a.EST_SERVICE, a.EST_PERISSABLE,
                    ISNULL((SELECT SUM(QUANTITE_ACTUELLE) FROM SSTOCK s WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL), 0) AS STOCK_DISPONIBLE,
                    CASE
                        WHEN ISNULL((SELECT SUM(QUANTITE_ACTUELLE) FROM SSTOCK s WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL), 0) <= 0 THEN 'RUPTURE'
                        WHEN ISNULL((SELECT SUM(QUANTITE_ACTUELLE) FROM SSTOCK s WHERE s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL), 0) <= a.SEUIL_ALERTE THEN 'ALERTE'
                        ELSE 'NORMAL'
                    END AS STATUT_STOCK
                FROM MARTICLE a
                LEFT JOIN SCATEGORIE c ON c.ID = a.CATEGORIE_ID
                LEFT JOIN SUNITE u ON u.ID = a.UNITE_MESURE_ID
                LEFT JOIN SFOURNISSEUR f ON f.ID = a.FOURNISSEUR_PREFERE_ID
                " + whereClause + @"
                ORDER BY " + sortField + " " + (string.Equals(order, "DESC", StringComparison.OrdinalIgnoreCase) ? "DESC" : "ASC") + @"
                OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

            int total = 0;
            using (var conn = new SqlConnection(connStr))
            using (var countCmd = new SqlCommand(sqlCount, conn))
            {
                conn.Open();
                if (!string.IsNullOrEmpty(search)) countCmd.Parameters.AddWithValue("@search", "%" + search.ToLowerInvariant() + "%");
                if (!string.IsNullOrEmpty(category)) countCmd.Parameters.AddWithValue("@category", category);
                if (!string.IsNullOrEmpty(status)) countCmd.Parameters.AddWithValue("@status", status.ToUpperInvariant());
                total = (int)countCmd.ExecuteScalar();
            }

            int totalPages = total > 0 ? (int)Math.Ceiling((double)total / pageSize) : 0;
            if (page > totalPages && totalPages > 0) page = totalPages;
            int offset = (page - 1) * pageSize;

            var pageArticles = new List<object>();
            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(sqlList, conn))
            {
                if (!string.IsNullOrEmpty(search)) cmd.Parameters.AddWithValue("@search", "%" + search.ToLowerInvariant() + "%");
                if (!string.IsNullOrEmpty(category)) cmd.Parameters.AddWithValue("@category", category);
                if (!string.IsNullOrEmpty(status)) cmd.Parameters.AddWithValue("@status", status.ToUpperInvariant());
                cmd.Parameters.AddWithValue("@offset", offset);
                cmd.Parameters.AddWithValue("@pageSize", pageSize);

                conn.Open();
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        pageArticles.Add(new
                        {
                            ID = reader["ID"].ToString(),
                            CODE = reader["CODE"].ToString(),
                            CODE_BARRE = reader["CODE_BARRE"] == DBNull.Value ? "" : reader["CODE_BARRE"].ToString(),
                            NOM = reader["NOM"].ToString(),
                            DESCRIPTION = reader["DESCRIPTION"] == DBNull.Value ? "" : reader["DESCRIPTION"].ToString(),
                            CATEGORIE_ID = reader["CATEGORIE_ID"] == DBNull.Value ? null : reader["CATEGORIE_ID"].ToString(),
                            CATEGORIE = reader["CATEGORIE"] == DBNull.Value ? "" : reader["CATEGORIE"].ToString(),
                            UNITE_MESURE_ID = reader["UNITE_MESURE_ID"] == DBNull.Value ? null : reader["UNITE_MESURE_ID"].ToString(),
                            UNITE = reader["UNITE"] == DBNull.Value ? "" : reader["UNITE"].ToString(),
                            FOURNISSEUR_PREFERE_ID = reader["FOURNISSEUR_PREFERE_ID"] == DBNull.Value ? null : reader["FOURNISSEUR_PREFERE_ID"].ToString(),
                            FOURNISSEUR = reader["FOURNISSEUR"] == DBNull.Value ? "" : reader["FOURNISSEUR"].ToString(),
                            EMPLACEMENT_ID = reader["EMPLACEMENT_ID"] == DBNull.Value ? null : reader["EMPLACEMENT_ID"].ToString(),
                            SEUIL_MIN = Convert.ToDecimal(reader["SEUIL_MIN"]),
                            SEUIL_ALERTE = Convert.ToDecimal(reader["SEUIL_ALERTE"]),
                            POIDS = reader["POIDS"] == DBNull.Value ? (decimal?)null : Convert.ToDecimal(reader["POIDS"]),
                            VOLUME = reader["VOLUME"] == DBNull.Value ? (decimal?)null : Convert.ToDecimal(reader["VOLUME"]),
                            ACTIVE = Convert.ToBoolean(reader["ACTIVE"]),
                            EST_SERVICE = Convert.ToBoolean(reader["EST_SERVICE"]),
                            EST_PERISSABLE = Convert.ToBoolean(reader["EST_PERISSABLE"]),
                            STOCK_DISPONIBLE = Convert.ToDecimal(reader["STOCK_DISPONIBLE"]),
                            STATUT_STOCK = reader["STATUT_STOCK"].ToString()
                        });
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true,
                Articles = pageArticles,
                total = total,
                page = page,
                totalPages = totalPages
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
