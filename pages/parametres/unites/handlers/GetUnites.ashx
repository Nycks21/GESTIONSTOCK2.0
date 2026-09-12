<%@ WebHandler Language="C#" Class="GetUnites" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetUnites : IHttpHandler, IRequiresSessionState
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
            int page = Math.Max(1, Convert.ToInt32(ctx.Request.QueryString["page"] ?? "1"));
            int pageSize = Convert.ToInt32(ctx.Request.QueryString["pageSize"] ?? "10");
            if (pageSize <= 0) pageSize = 10;
            string search = (ctx.Request.QueryString["search"] ?? "").Trim();
            string status = (ctx.Request.QueryString["status"] ?? "").Trim();
            string sortField = (ctx.Request.QueryString["sort"] ?? "NOM").Trim();
            string sortOrder = (ctx.Request.QueryString["order"] ?? "ASC").Trim();

            string connStr = AuthHelper.ConnectionString;
            List<Dictionary<string, object>> unites = new List<Dictionary<string, object>>();
            int total = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string countSql = "SELECT COUNT(*) FROM SUNITE WHERE DELETION_AT IS NULL";
                string whereClause = "";
                List<SqlParameter> parameters = new List<SqlParameter>();

                if (!string.IsNullOrEmpty(search))
                {
                    whereClause += " AND (CODE LIKE @search OR NOM LIKE @search)";
                    parameters.Add(new SqlParameter("@search", "%" + search + "%"));
                }
                if (!string.IsNullOrEmpty(status))
                {
                    int active = Convert.ToInt32(status);
                    whereClause += " AND ACTIVE = @status";
                    parameters.Add(new SqlParameter("@status", active));
                }

                if (!string.IsNullOrEmpty(whereClause))
                    countSql += whereClause;

                using (SqlCommand cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                string orderBy = "ORDER BY " + SqlSafeSort(sortField) + " " + (sortOrder.ToUpper() == "DESC" ? "DESC" : "ASC");
                string selectSql = @"
                    SELECT ID, CODE, NOM, ACTIVE, CREATED_BY, CREATED_AT
                    FROM SUNITE
                    WHERE DELETION_AT IS NULL" + whereClause + @"
                    " + orderBy + @"
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                using (SqlCommand cmd = new SqlCommand(selectSql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);

                    using (SqlDataReader reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            Dictionary<string, object> dict = new Dictionary<string, object>();
                            dict["ID"] = reader["ID"].ToString();
                            dict["CODE"] = reader["CODE"];
                            dict["NOM"] = reader["NOM"];
                            dict["ACTIVE"] = Convert.ToBoolean(reader["ACTIVE"]);
                            unites.Add(dict);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            var result = new
            {
                success = true,
                Unites = unites,
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
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    private string SqlSafeSort(string field)
    {
        string upper = field.ToUpper();
        if (upper == "CODE" || upper == "NOM" || upper == "ACTIVE")
            return field;
        return "NOM";
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
