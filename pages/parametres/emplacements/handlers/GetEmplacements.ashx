<%@ WebHandler Language="C#" Class="GetEmplacements" %>

using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEmplacements : IHttpHandler, IRequiresSessionState
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
            string type = ctx.Request.QueryString["type"] ?? "";
            string parent = ctx.Request.QueryString["parent"] ?? "";
            string sortField = ctx.Request.QueryString["sort"] ?? "NOM";
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
                // Construction de la requête avec jointure pour le parent
                string whereClause = "WHERE e.DELETION_AT IS NULL";
                if (!string.IsNullOrEmpty(search))
                    whereClause += " AND (e.CODE LIKE @search OR e.NOM LIKE @search)";
                if (!string.IsNullOrEmpty(type))
                    whereClause += " AND e.TYPE = @type";
                if (!string.IsNullOrEmpty(parent))
                    whereClause += " AND e.PARENT_ID = @parent";

                // Utilisation de string.Format au lieu de l'interpolation
                string orderBy = string.Format("ORDER BY e.{0} {1}", sortField, sortOrder);
                string countSql = string.Format("SELECT COUNT(*) FROM SEMPLACEMENT e {0}", whereClause);

                string selectSql = string.Format(@"
                    SELECT
                        e.ID, e.CODE, e.NOM, e.TYPE,
                        e.PARENT_ID,
                        p.NOM AS PARENT_NOM,
                        e.ACTIVE
                    FROM SEMPLACEMENT e
                    LEFT JOIN SEMPLACEMENT p ON e.PARENT_ID = p.ID AND p.DELETION_AT IS NULL
                    {0}
                    {1}
                    OFFSET @offset ROWS FETCH NEXT @fetch ROWS ONLY", whereClause, orderBy);

                using (var cmd = new SqlCommand(countSql, conn))
                {
                    AddParameters(cmd, search, type, parent);
                    total = (int)cmd.ExecuteScalar();
                }

                if (!getAll && pageSize > 0)
                {
                    int offset = (page - 1) * pageSize;
                    using (var cmd = new SqlCommand(selectSql, conn))
                    {
                        AddParameters(cmd, search, type, parent);
                        cmd.Parameters.AddWithValue("@offset", offset);
                        cmd.Parameters.AddWithValue("@fetch", pageSize);
                        using (var reader = cmd.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                var d = new Dictionary<string, object>();
                                d["ID"] = reader["ID"].ToString();
                                d["CODE"] = reader["CODE"];
                                d["NOM"] = reader["NOM"];
                                d["TYPE"] = reader["TYPE"];
                                d["PARENT_ID"] = reader["PARENT_ID"] == DBNull.Value ? null : reader["PARENT_ID"].ToString();
                                d["PARENT_NOM"] = reader["PARENT_NOM"];
                                d["ACTIVE"] = Convert.ToBoolean(reader["ACTIVE"]);
                                list.Add(d);
                            }
                        }
                    }
                }
                else
                {
                    // Cas "Tous" : on prend tout sans OFFSET/FETCH
                    string allSql = string.Format(@"
                        SELECT
                            e.ID, e.CODE, e.NOM, e.TYPE,
                            e.PARENT_ID,
                            p.NOM AS PARENT_NOM,
                            e.ACTIVE
                        FROM SEMPLACEMENT e
                        LEFT JOIN SEMPLACEMENT p ON e.PARENT_ID = p.ID AND p.DELETION_AT IS NULL
                        {0}
                        {1}", whereClause, orderBy);
                    using (var cmd = new SqlCommand(allSql, conn))
                    {
                        AddParameters(cmd, search, type, parent);
                        using (var reader = cmd.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                var d = new Dictionary<string, object>();
                                d["ID"] = reader["ID"].ToString();
                                d["CODE"] = reader["CODE"];
                                d["NOM"] = reader["NOM"];
                                d["TYPE"] = reader["TYPE"];
                                d["PARENT_ID"] = reader["PARENT_ID"] == DBNull.Value ? null : reader["PARENT_ID"].ToString();
                                d["PARENT_NOM"] = reader["PARENT_NOM"];
                                d["ACTIVE"] = Convert.ToBoolean(reader["ACTIVE"]);
                                list.Add(d);
                            }
                        }
                    }
                }
            }

            int totalPages = (pageSize > 0 && pageSize < 999999) ? (int)Math.Ceiling((double)total / pageSize) : 1;
            // Utilisation de l'initialisation classique de dictionnaire compatible C# 4.0
            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["Emplacements"] = list;
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

    private void AddParameters(SqlCommand cmd, string search, string type, string parent)
    {
        if (!string.IsNullOrEmpty(search))
            cmd.Parameters.AddWithValue("@search", "%" + search + "%");
        if (!string.IsNullOrEmpty(type))
            cmd.Parameters.AddWithValue("@type", type);
        if (!string.IsNullOrEmpty(parent))
            cmd.Parameters.AddWithValue("@parent", parent);
    }

    public bool IsReusable { get { return false; } }
}
