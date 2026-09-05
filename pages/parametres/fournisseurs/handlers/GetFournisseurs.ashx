<%@ WebHandler Language="C#" Class="GetFournisseurs" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetFournisseurs : IHttpHandler, IRequiresSessionState
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
            int page = Math.Max(1, int.Parse(ctx.Request.QueryString["page"] ?? "1"));
            int pageSize = int.Parse(ctx.Request.QueryString["pageSize"] ?? "10");
            string search = (ctx.Request.QueryString["search"] ?? "").Trim();
            string actifFilter = ctx.Request.QueryString["actif"] ?? "";
            string sortField = ctx.Request.QueryString["sort"] ?? "NOM";
            string sortOrder = ctx.Request.QueryString["order"] ?? "ASC";

            string[] allowedSortFields = { "CODE", "NOM", "ADRESSE", "TELEPHONE", "EMAIL", "CONTACT_NOM", "SIRET", "ACTIVE" };
            if (!Array.Exists(allowedSortFields, f => f.Equals(sortField, StringComparison.OrdinalIgnoreCase)))
                sortField = "NOM";

            string connStr = AuthHelper.ConnectionString;
            var fournisseurs = new List<Dictionary<string, object>>();
            int total = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string countSql = "SELECT COUNT(*) FROM SFOURNISSEUR WHERE DELETION_AT IS NULL";
                string whereClause = "";
                if (!string.IsNullOrEmpty(search))
                {
                    whereClause = " AND (CODE LIKE @search OR NOM LIKE @search OR ADRESSE LIKE @search OR EMAIL LIKE @search OR CONTACT_NOM LIKE @search)";
                }
                if (!string.IsNullOrEmpty(actifFilter))
                {
                    whereClause += " AND ACTIVE = @actif";
                }
                countSql += whereClause;
                using (var cmd = new SqlCommand(countSql, conn))
                {
                    if (!string.IsNullOrEmpty(search))
                        cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(actifFilter))
                        cmd.Parameters.AddWithValue("@actif", int.Parse(actifFilter));
                    total = Convert.ToInt32(cmd.ExecuteScalar());
                }

                string sql = @"
                    SELECT ID, CODE, NOM, ADRESSE, TELEPHONE, EMAIL, CONTACT_NOM, CONTACT_TELEPHONE, SIRET, ACTIVE
                    FROM SFOURNISSEUR
                    WHERE DELETION_AT IS NULL " + whereClause + @"
                    ORDER BY " + sortField + " " + sortOrder + @"
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);
                    if (!string.IsNullOrEmpty(search))
                        cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(actifFilter))
                        cmd.Parameters.AddWithValue("@actif", int.Parse(actifFilter));

                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            // Syntaxe compatible .NET 4.0 (C# 4)
                            var dict = new Dictionary<string, object>();
                            dict.Add("ID", reader["ID"].ToString());
                            dict.Add("CODE", reader["CODE"]);
                            dict.Add("NOM", reader["NOM"]);
                            dict.Add("ADRESSE", reader["ADRESSE"]);
                            dict.Add("TELEPHONE", reader["TELEPHONE"]);
                            dict.Add("EMAIL", reader["EMAIL"]);
                            dict.Add("CONTACT_NOM", reader["CONTACT_NOM"]);
                            dict.Add("CONTACT_TELEPHONE", reader["CONTACT_TELEPHONE"]);
                            dict.Add("SIRET", reader["SIRET"]);
                            dict.Add("ACTIVE", Convert.ToBoolean(reader["ACTIVE"]));
                            fournisseurs.Add(dict);
                        }
                    }
                }
            }

            int totalPages = pageSize > 0 ? (int)Math.Ceiling((double)total / pageSize) : 0;
            var result = new
            {
                success = true,
                Fournisseurs = fournisseurs,
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

    public bool IsReusable
    {
        get { return false; }
    }
}
