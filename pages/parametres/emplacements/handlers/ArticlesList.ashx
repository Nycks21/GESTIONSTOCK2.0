using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;

public class ArticlesList : IHttpHandler
{
    public void ProcessRequest(HttpContext context)
    {
        if (!AuthHelper.RequireApiAuth(context))
        {
            context.Response.StatusCode = 401;
            context.Response.Write("{\"success\":false,\"message\":\"Non autorisé\"}");
            return;
        }

        string action = context.Request.QueryString["action"] ?? "list";
        var serializer = new JavaScriptSerializer();

        if (action == "stats")
        {
            var stats = GetStats();
            context.Response.ContentType = "application/json";
            context.Response.Write(serializer.Serialize(new { success = true, total = stats.Total, normal = stats.Normal, alerte = stats.Alerte, rupture = stats.Rupture }));
            return;
        }

        // List action
        int page = int.Parse(context.Request.QueryString["page"] ?? "1");
        int pageSize = int.Parse(context.Request.QueryString["pageSize"] ?? "10");
        string search = context.Request.QueryString["search"] ?? "";
        string category = context.Request.QueryString["category"] ?? "";
        string status = context.Request.QueryString["status"] ?? "";
        string sortField = context.Request.QueryString["sort"] ?? "CODE";
        string sortOrder = context.Request.QueryString["order"] ?? "ASC";

        var result = GetArticles(page, pageSize, search, category, status, sortField, sortOrder);
        context.Response.ContentType = "application/json";
        context.Response.Write(serializer.Serialize(result));
    }

    private dynamic GetArticles(int page, int pageSize, string search, string category, string status, string sortField, string sortOrder)
    {
        var list = new List<object>();
        int total = 0;

        string connStr = AuthHelper.ConnectionString;
        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            // Sous-requête pour le stock total par article
            string stockSubquery = @"(SELECT ISNULL(SUM(QUANTITE_ACTUELLE), 0) FROM SSTOCK WHERE ARTICLE_ID = a.ID AND DELETION_AT IS NULL)";

            string where = "a.DELETION_AT IS NULL";
            if (!string.IsNullOrEmpty(search))
                where += $" AND (a.CODE LIKE '%{search}%' OR a.NOM LIKE '%{search}%' OR a.DESCRIPTION LIKE '%{search}%')";
            if (!string.IsNullOrEmpty(category))
                where += $" AND a.CATEGORIE_ID = '{category}'";
            if (!string.IsNullOrEmpty(status))
            {
                where += $" AND (CASE WHEN {stockSubquery} <= 0 THEN 'rupture' WHEN {stockSubquery} <= a.SEUIL_ALERTE THEN 'alerte' ELSE 'normal' END) = '{status}'";
            }

            // Count
            string countSql = $"SELECT COUNT(*) FROM MARTICLE a WHERE {where}";
            using (SqlCommand cmd = new SqlCommand(countSql, conn))
            {
                total = (int)cmd.ExecuteScalar();
            }

            string[] allowedSort = { "CODE", "NOM", "CATEGORIE_NOM", "FOURNISSEUR_NOM", "UNITE_SYMBOLE", "STOCK_DISPONIBLE", "SEUIL_ALERTE", "STATUT_STOCK" };
            string sort = Array.Exists(allowedSort, s => s == sortField) ? sortField : "CODE";
            string order = sortOrder.ToUpper() == "DESC" ? "DESC" : "ASC";

            string sql = $@"
                SELECT
                    a.ID,
                    a.CODE,
                    a.NOM,
                    a.DESCRIPTION,
                    a.SEUIL_ALERTE,
                    a.SEUIL_MIN,
                    a.ACTIVE AS ACTIF,
                    a.EST_SERVICE,
                    a.CATEGORIE_ID,
                    c.NOM AS CATEGORIE_NOM,
                    a.FOURNISSEUR_PREFERE_ID AS FOURNISSEUR_ID,
                    f.NOM AS FOURNISSEUR_NOM,
                    a.UNITE_MESURE_ID AS UNITE_ID,
                    u.NOM AS UNITE_SYMBOLE,
                    ({stockSubquery}) AS STOCK_DISPONIBLE,
                    CASE
                        WHEN ({stockSubquery}) <= 0 THEN 'rupture'
                        WHEN ({stockSubquery}) <= a.SEUIL_ALERTE THEN 'alerte'
                        ELSE 'normal'
                    END AS STATUT_STOCK
                FROM MARTICLE a
                LEFT JOIN SCATEGORIE c ON a.CATEGORIE_ID = c.ID
                LEFT JOIN SFOURNISSEUR f ON a.FOURNISSEUR_PREFERE_ID = f.ID
                LEFT JOIN SUNITE u ON a.UNITE_MESURE_ID = u.ID
                WHERE {where}
                ORDER BY {sort} {order}
                OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                cmd.Parameters.AddWithValue("@pageSize", pageSize);

                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        list.Add(new
                        {
                            ID = reader["ID"].ToString(),
                            CODE = reader["CODE"],
                            NOM = reader["NOM"],
                            DESCRIPTION = reader["DESCRIPTION"],
                            STOCK_DISPONIBLE = reader["STOCK_DISPONIBLE"],
                            SEUIL_ALERTE = reader["SEUIL_ALERTE"],
                            SEUIL_MIN = reader["SEUIL_MIN"],
                            ACTIF = reader["ACTIF"],
                            EST_SERVICE = reader["EST_SERVICE"],
                            CATEGORIE_ID = reader["CATEGORIE_ID"]?.ToString(),
                            CATEGORIE_NOM = reader["CATEGORIE_NOM"],
                            FOURNISSEUR_ID = reader["FOURNISSEUR_ID"]?.ToString(),
                            FOURNISSEUR_NOM = reader["FOURNISSEUR_NOM"],
                            UNITE_ID = reader["UNITE_ID"]?.ToString(),
                            UNITE_NOM = reader["UNITE_NOM"],
                            STATUT_STOCK = reader["STATUT_STOCK"]
                        });
                    }
                }
            }
        }

        return new { success = true, data = list, total = total, page = page, totalPages = (int)Math.Ceiling((double)total / pageSize) };
    }

    private (int Total, int Normal, int Alerte, int Rupture) GetStats()
    {
        int total = 0, normal = 0, alerte = 0, rupture = 0;
        string connStr = AuthHelper.ConnectionString;
        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();
            string sql = @"
                WITH StockTotal AS (
                    SELECT ARTICLE_ID, ISNULL(SUM(QUANTITE_ACTUELLE), 0) AS STOCK
                    FROM SSTOCK WHERE DELETION_AT IS NULL
                    GROUP BY ARTICLE_ID
                )
                SELECT
                    COUNT(a.ID) AS Total,
                    SUM(CASE WHEN ISNULL(st.STOCK,0) > a.SEUIL_ALERTE THEN 1 ELSE 0 END) AS Normal,
                    SUM(CASE WHEN ISNULL(st.STOCK,0) > 0 AND ISNULL(st.STOCK,0) <= a.SEUIL_ALERTE THEN 1 ELSE 0 END) AS Alerte,
                    SUM(CASE WHEN ISNULL(st.STOCK,0) <= 0 THEN 1 ELSE 0 END) AS Rupture
                FROM MARTICLE a
                LEFT JOIN StockTotal st ON a.ID = st.ARTICLE_ID
                WHERE a.DELETION_AT IS NULL AND a.ACTIVE = 1";
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        total = ReadInt(reader, "Total");
                        normal = ReadInt(reader, "Normal");
                        alerte = ReadInt(reader, "Alerte");
                        rupture = ReadInt(reader, "Rupture");
                    }
                }
            }
        }
        return (total, normal, alerte, rupture);
    }

    private static int ReadInt(SqlDataReader reader, string columnName)
    {
        object value = reader[columnName];
        if (value == null || value == DBNull.Value)
            return 0;

        try
        {
            return Convert.ToInt32(value);
        }
        catch
        {
            return 0;
        }
    }

    public bool IsReusable => false;
}
