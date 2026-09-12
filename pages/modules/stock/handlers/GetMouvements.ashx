<%@ WebHandler Language="C#" Class="GetMouvements" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetMouvements : IHttpHandler, IRequiresSessionState
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
            string articleId = ctx.Request.QueryString["articleId"] ?? "";
            string emplacementId = ctx.Request.QueryString["emplacementId"] ?? "";
            int page = 1, pageSize = 50;
            int.TryParse(ctx.Request.QueryString["page"], out page);
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 50;

            if (string.IsNullOrEmpty(articleId) || string.IsNullOrEmpty(emplacementId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Article et emplacement requis.\"}");
                return;
            }

            var connStr = AuthHelper.ConnectionString;
            var list = new List<Dictionary<string, object>>();
            int total = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string whereClause = "WHERE ARTICLE_ID = @articleId AND EMPLACEMENT_ID = @emplacementId AND DELETION_AT IS NULL";

                string countSql = "SELECT COUNT(*) FROM MSTOCK " + whereClause;
                using (var cmd = new SqlCommand(countSql, conn))
                {
                    cmd.Parameters.AddWithValue("@articleId", articleId);
                    cmd.Parameters.AddWithValue("@emplacementId", emplacementId);
                    total = (int)cmd.ExecuteScalar();
                }

                string selectSql = @"
                    SELECT ID, TYPE, QUANTITE, QUANTITE_AVANT, QUANTITE_APRES,
                           MOTIF, REFERENCE_TYPE, REFERENCE_NUMERO,
                           CREATED_BY, CREATED_AT
                    FROM MSTOCK
                    " + whereClause + @"
                    ORDER BY CREATED_AT DESC
                    OFFSET @offset ROWS FETCH NEXT @fetch ROWS ONLY";

                int offset = (page - 1) * pageSize;
                using (var cmd = new SqlCommand(selectSql, conn))
                {
                    cmd.Parameters.AddWithValue("@articleId", articleId);
                    cmd.Parameters.AddWithValue("@emplacementId", emplacementId);
                    cmd.Parameters.AddWithValue("@offset", offset);
                    cmd.Parameters.AddWithValue("@fetch", pageSize);
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            var d = new Dictionary<string, object>();
                            d["ID"] = reader["ID"].ToString();
                            d["TYPE"] = reader["TYPE"].ToString();
                            d["QUANTITE"] = reader["QUANTITE"];
                            d["QUANTITE_AVANT"] = reader["QUANTITE_AVANT"];
                            d["QUANTITE_APRES"] = reader["QUANTITE_APRES"];
                            d["MOTIF"] = reader["MOTIF"] ?? "";
                            d["REFERENCE_TYPE"] = reader["REFERENCE_TYPE"] ?? "";
                            d["REFERENCE_NUMERO"] = reader["REFERENCE_NUMERO"] ?? "";
                            d["CREATED_BY"] = reader["CREATED_BY"];
                            d["CREATED_AT"] = reader["CREATED_AT"] != DBNull.Value ? Convert.ToDateTime(reader["CREATED_AT"]).ToString("dd/MM/yyyy HH:mm") : "";
                            list.Add(d);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["Mouvements"] = list;
            result["total"] = total;
            result["totalPages"] = totalPages;
            result["page"] = page;
            result["pageSize"] = pageSize;

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
