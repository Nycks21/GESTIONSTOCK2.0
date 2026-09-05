<%@ WebHandler Language="C#" Class="GetCategories" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetCategories : IHttpHandler, IRequiresSessionState
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
            // Lecture des paramètres
            int page = Math.Max(1, Convert.ToInt32(ctx.Request.QueryString["page"] ?? "1"));
            int pageSize = Convert.ToInt32(ctx.Request.QueryString["pageSize"] ?? "10");
            if (pageSize <= 0) pageSize = 10;
            string search = (ctx.Request.QueryString["search"] ?? "").Trim();
            string status = (ctx.Request.QueryString["status"] ?? "").Trim();
            string sortField = (ctx.Request.QueryString["sort"] ?? "NOM").Trim();
            string sortOrder = (ctx.Request.QueryString["order"] ?? "ASC").Trim();

            // Mappage sécurisé des colonnes de tri
            string orderByColumn;
            switch (sortField.ToUpper())
            {
                case "CODE": orderByColumn = "c.CODE"; break;
                case "NOM": orderByColumn = "c.NOM"; break;
                case "ACTIVE": orderByColumn = "c.ACTIVE"; break;
                case "PARENT_NOM": orderByColumn = "p.NOM"; break;
                default: orderByColumn = "c.NOM"; break;
            }
            string orderDir = (sortOrder.ToUpper() == "DESC") ? "DESC" : "ASC";

            string connStr = AuthHelper.ConnectionString;
            List<Dictionary<string, object>> categories = new List<Dictionary<string, object>>();
            int total = 0;

            // Construction de la clause WHERE
            string whereClause = "WHERE c.DELETION_AT IS NULL";
            if (!string.IsNullOrEmpty(search))
                whereClause += " AND (c.CODE LIKE @search OR c.NOM LIKE @search)";
            if (!string.IsNullOrEmpty(status))
                whereClause += " AND c.ACTIVE = @status";

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                // --- Requête COUNT ---
                string countSql = "SELECT COUNT(*) FROM SCATEGORIE c " + whereClause;
                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    if (!string.IsNullOrEmpty(search))
                        cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(status))
                        cmd.Parameters.AddWithValue("@status", Convert.ToInt32(status));
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                if (total == 0)
                {
                    var emptyResult = new { success = true, Categories = new List<object>(), total = 0, totalPages = 0, page = page, pageSize = pageSize };
                    ctx.Response.Write(new JavaScriptSerializer().Serialize(emptyResult));
                    return;
                }

                // --- Requête SELECT avec pagination ---
                int offset = (page - 1) * pageSize;
                string selectSql = @"
                    WITH CTE AS (
                        SELECT
                            c.ID,
                            c.CODE,
                            c.NOM,
                            c.DESCRIPTION,
                            c.PARENT_ID,
                            c.ACTIVE,
                            p.NOM AS PARENT_NOM,
                            ROW_NUMBER() OVER (ORDER BY " + orderByColumn + " " + orderDir + @") AS RowNum
                        FROM SCATEGORIE c
                        LEFT JOIN SCATEGORIE p ON c.PARENT_ID = p.ID
                        " + whereClause + @"
                    )
                    SELECT ID, CODE, NOM, DESCRIPTION, PARENT_ID, ACTIVE, PARENT_NOM
                    FROM CTE
                    WHERE RowNum BETWEEN @startRow AND @endRow
                    ORDER BY RowNum";

                using (SqlCommand cmd = new SqlCommand(selectSql, conn))
                {
                    if (!string.IsNullOrEmpty(search))
                        cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(status))
                        cmd.Parameters.AddWithValue("@status", Convert.ToInt32(status));
                    cmd.Parameters.AddWithValue("@startRow", offset + 1);
                    cmd.Parameters.AddWithValue("@endRow", offset + pageSize);

                    using (SqlDataReader reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            var dict = new Dictionary<string, object>();
                            dict["ID"] = reader["ID"].ToString();
                            dict["CODE"] = reader["CODE"];
                            dict["NOM"] = reader["NOM"];
                            dict["DESCRIPTION"] = reader["DESCRIPTION"] != DBNull.Value ? reader["DESCRIPTION"] : "";
                            dict["PARENT_ID"] = reader["PARENT_ID"] != DBNull.Value ? reader["PARENT_ID"].ToString() : null;
                            dict["ACTIVE"] = Convert.ToBoolean(reader["ACTIVE"]);
                            dict["PARENT_NOM"] = reader["PARENT_NOM"] != DBNull.Value ? reader["PARENT_NOM"].ToString() : "";
                            categories.Add(dict);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            var result = new
            {
                success = true,
                Categories = categories,
                total = total,
                totalPages = totalPages,
                page = page,
                pageSize = pageSize
            };

            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = "Erreur serveur : " + ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
