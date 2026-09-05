<%@ WebHandler Language="C#" Class="GetSorties" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetSorties : IHttpHandler, IRequiresSessionState
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
            string search = "", destination = "", statut = "", sort = "DATE_SORTIE", order = "DESC";

            if (!string.IsNullOrEmpty(ctx.Request["page"])) int.TryParse(ctx.Request["page"], out page);
            if (!string.IsNullOrEmpty(ctx.Request["pageSize"])) int.TryParse(ctx.Request["pageSize"], out pageSize);
            if (!string.IsNullOrEmpty(ctx.Request["search"])) search = ctx.Request["search"].Trim();
            if (!string.IsNullOrEmpty(ctx.Request["destination"])) destination = ctx.Request["destination"];
            if (!string.IsNullOrEmpty(ctx.Request["statut"])) statut = ctx.Request["statut"];
            if (!string.IsNullOrEmpty(ctx.Request["sort"])) sort = ctx.Request["sort"];
            if (!string.IsNullOrEmpty(ctx.Request["order"])) order = ctx.Request["order"];

            string connStr = AuthHelper.ConnectionString;
            var resultList = new List<Dictionary<string, object>>();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string where = "WHERE s.DELETION_AT IS NULL";
                if (!string.IsNullOrEmpty(search))
                    where += " AND (s.NUMERO LIKE @search OR s.DESTINATION LIKE @search OR s.NOM LIKE @search)";
                if (!string.IsNullOrEmpty(destination))
                    where += " AND s.DESTINATION LIKE @destination";
                if (!string.IsNullOrEmpty(statut))
                    where += " AND s.STATUT = @statut";

                string orderBy = "ORDER BY " + sort + " " + order;

                string countSql = "SELECT COUNT(*) FROM SSORTIE s " + where;
                int total = 0;
                using (var cmd = new SqlCommand(countSql, conn))
                {
                    if (!string.IsNullOrEmpty(search)) cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(destination)) cmd.Parameters.AddWithValue("@destination", "%" + destination + "%");
                    if (!string.IsNullOrEmpty(statut)) cmd.Parameters.AddWithValue("@statut", statut);
                    total = (int)cmd.ExecuteScalar();
                }

                string dataSql = @"
                    SELECT s.ID, s.NUMERO, s.DATE_SORTIE, s.STATUT, s.DESTINATION, s.NOM, s.FONCTION, s.NOTES, s.CREATED_AT
                    FROM SSORTIE s
                    " + where + @"
                    " + orderBy + @"
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                var tempList = new List<Dictionary<string, object>>();
                using (var cmd = new SqlCommand(dataSql, conn))
                {
                    if (!string.IsNullOrEmpty(search)) cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(destination)) cmd.Parameters.AddWithValue("@destination", "%" + destination + "%");
                    if (!string.IsNullOrEmpty(statut)) cmd.Parameters.AddWithValue("@statut", statut);
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);

                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            var obj = new Dictionary<string, object>();
                            string id = reader["ID"].ToString();
                            obj["ID"] = id;
                            obj["NUMERO"] = reader["NUMERO"].ToString();
                            obj["DATE_SORTIE"] = reader["DATE_SORTIE"] == DBNull.Value ? null : reader["DATE_SORTIE"];
                            obj["STATUT"] = reader["STATUT"].ToString();
                            obj["DESTINATION"] = reader["DESTINATION"] == DBNull.Value ? "" : reader["DESTINATION"].ToString();
                            obj["NOM"] = reader["NOM"] == DBNull.Value ? "" : reader["NOM"].ToString();
                            obj["FONCTION"] = reader["FONCTION"] == DBNull.Value ? "" : reader["FONCTION"].ToString();
                            obj["NOTES"] = reader["NOTES"] == DBNull.Value ? "" : reader["NOTES"].ToString();
                            obj["CREATED_AT"] = reader["CREATED_AT"] == DBNull.Value ? null : reader["CREATED_AT"];
                            tempList.Add(obj);
                        }
                    }
                }

                foreach (var obj in tempList)
                {
                    string id = obj["ID"].ToString();
                    obj["Lignes"] = GetLignesByBonId(conn, id);
                    resultList.Add(obj);
                }

                int totalPages = (int)Math.Ceiling((double)total / pageSize);
                var response = new Dictionary<string, object>();
                response.Add("success", true);
                response.Add("Sorties", resultList);
                response.Add("total", total);
                response.Add("totalPages", totalPages);
                ctx.Response.Write(new JavaScriptSerializer().Serialize(response));
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    private List<Dictionary<string, object>> GetLignesByBonId(SqlConnection conn, string bonSortieId)
    {
        var lignes = new List<Dictionary<string, object>>();
        string sql = @"
            SELECT ARTICLE_ID, QUANTITE_D, QUANTITE_R, OBSERVATIONS
            FROM MLSORTIE
            WHERE BON_SORTIE_ID = @bonSortieId AND DELETION_AT IS NULL
            ORDER BY ARTICLE_ID";
        using (var cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@bonSortieId", bonSortieId);
            using (var reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    var ligne = new Dictionary<string, object>();
                    ligne["ARTICLE_ID"] = reader["ARTICLE_ID"] == DBNull.Value ? null : reader["ARTICLE_ID"].ToString();
                    ligne["QUANTITE_D"] = reader["QUANTITE_D"] == DBNull.Value ? 0m : Convert.ToDecimal(reader["QUANTITE_D"]);
                    ligne["QUANTITE_R"] = reader["QUANTITE_R"] == DBNull.Value ? 0m : Convert.ToDecimal(reader["QUANTITE_R"]);
                    ligne["OBSERVATIONS"] = reader["OBSERVATIONS"] == DBNull.Value ? "" : reader["OBSERVATIONS"].ToString();
                    lignes.Add(ligne);
                }
            }
        }
        return lignes;
    }

    public bool IsReusable { get { return false; } }
}
