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

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
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

                // Construction de la requête avec jointures
                string whereClause = "WHERE s.DELETION_AT IS NULL AND a.DELETION_AT IS NULL AND e.DELETION_AT IS NULL";
                if (!string.IsNullOrEmpty(search))
                    whereClause += " AND (a.CODE LIKE @search OR a.NOM LIKE @search)";
                if (!string.IsNullOrEmpty(article))
                    whereClause += " AND a.ID = @article";
                if (!string.IsNullOrEmpty(emplacement))
                    whereClause += " AND e.ID = @emplacement";

                string orderBy = "ORDER BY " + sortField + " " + sortOrder;

                string countSql = @"
                    SELECT COUNT(*)
                    FROM SSTOCK s
                    INNER JOIN MARTICLE a ON s.ARTICLE_ID = a.ID
                    INNER JOIN SEMPLACEMENT e ON s.EMPLACEMENT_ID = e.ID
                    " + whereClause;

                string selectSql = @"
                    SELECT
                        s.ARTICLE_ID,
                        s.EMPLACEMENT_ID,
                        a.CODE AS ARTICLE_CODE,
                        a.NOM AS ARTICLE_NOM,
                        a.SEUIL_ALERTE,
                        e.NOM AS EMPLACEMENT_NOM,
                        s.QUANTITE_ACTUELLE
                    FROM SSTOCK s
                    INNER JOIN MARTICLE a ON s.ARTICLE_ID = a.ID
                    INNER JOIN SEMPLACEMENT e ON s.EMPLACEMENT_ID = e.ID
                    " + whereClause + @"
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
                                d["EMPLACEMENT_ID"] = reader["EMPLACEMENT_ID"].ToString();
                                d["ARTICLE_CODE"] = reader["ARTICLE_CODE"];
                                d["ARTICLE_NOM"] = reader["ARTICLE_NOM"];
                                d["SEUIL_ALERTE"] = reader["SEUIL_ALERTE"];
                                d["EMPLACEMENT_NOM"] = reader["EMPLACEMENT_NOM"];
                                d["QUANTITE_ACTUELLE"] = reader["QUANTITE_ACTUELLE"];
                                list.Add(d);
                            }
                        }
                    }
                }
                else
                {
                    string allSql = @"
                        SELECT
                            s.ARTICLE_ID,
                            s.EMPLACEMENT_ID,
                            a.CODE AS ARTICLE_CODE,
                            a.NOM AS ARTICLE_NOM,
                            a.SEUIL_ALERTE,
                            e.NOM AS EMPLACEMENT_NOM,
                            s.QUANTITE_ACTUELLE
                        FROM SSTOCK s
                        INNER JOIN MARTICLE a ON s.ARTICLE_ID = a.ID
                        INNER JOIN SEMPLACEMENT e ON s.EMPLACEMENT_ID = e.ID
                        " + whereClause + @"
                        " + orderBy;
                    using (var cmd = new SqlCommand(allSql, conn))
                    {
                        AddParameters(cmd, search, article, emplacement);
                        using (var reader = cmd.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                var d = new Dictionary<string, object>();
                                d["ARTICLE_ID"] = reader["ARTICLE_ID"].ToString();
                                d["EMPLACEMENT_ID"] = reader["EMPLACEMENT_ID"].ToString();
                                d["ARTICLE_CODE"] = reader["ARTICLE_CODE"];
                                d["ARTICLE_NOM"] = reader["ARTICLE_NOM"];
                                d["SEUIL_ALERTE"] = reader["SEUIL_ALERTE"];
                                d["EMPLACEMENT_NOM"] = reader["EMPLACEMENT_NOM"];
                                d["QUANTITE_ACTUELLE"] = reader["QUANTITE_ACTUELLE"];
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
