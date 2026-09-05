<%@ WebHandler Language="C#" Class="GetEntrees" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEntrees : IHttpHandler, IRequiresSessionState
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
            int page = 1;
            int pageSize = 10;
            string search = "";
            string fournisseurId = "";
            string statut = "";
            string sort = "DATE_ENTREE";
            string order = "DESC";

            if (!string.IsNullOrEmpty(ctx.Request["page"])) int.TryParse(ctx.Request["page"], out page);
            if (!string.IsNullOrEmpty(ctx.Request["pageSize"])) int.TryParse(ctx.Request["pageSize"], out pageSize);
            if (!string.IsNullOrEmpty(ctx.Request["search"])) search = ctx.Request["search"].Trim();
            if (!string.IsNullOrEmpty(ctx.Request["fournisseur"])) fournisseurId = ctx.Request["fournisseur"];
            if (!string.IsNullOrEmpty(ctx.Request["statut"])) statut = ctx.Request["statut"];
            if (!string.IsNullOrEmpty(ctx.Request["sort"])) sort = ctx.Request["sort"];
            if (!string.IsNullOrEmpty(ctx.Request["order"])) order = ctx.Request["order"];

            string connStr = AuthHelper.ConnectionString;
            var resultList = new List<Dictionary<string, object>>();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Construction de la clause WHERE
                string where = "WHERE e.DELETION_AT IS NULL";
                if (!string.IsNullOrEmpty(search))
                    where += " AND (e.NUMERO LIKE @search OR f.NOM LIKE @search)";
                if (!string.IsNullOrEmpty(fournisseurId))
                    where += " AND e.FOURNISSEUR_ID = @fournisseurId";
                if (!string.IsNullOrEmpty(statut))
                    where += " AND e.STATUT = @statut";

                string orderBy = "ORDER BY " + sort + " " + order;

                // Récupération du nombre total
                string countSql = "SELECT COUNT(*) FROM SENTREE e LEFT JOIN SFOURNISSEUR f ON e.FOURNISSEUR_ID = f.ID " + where;
                int total = 0;
                using (var cmd = new SqlCommand(countSql, conn))
                {
                    if (!string.IsNullOrEmpty(search)) cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(fournisseurId)) cmd.Parameters.AddWithValue("@fournisseurId", fournisseurId);
                    if (!string.IsNullOrEmpty(statut)) cmd.Parameters.AddWithValue("@statut", statut);
                    total = (int)cmd.ExecuteScalar();
                }

                // Requête de données paginée
                string dataSql = @"
                    SELECT e.ID, e.NUMERO, e.DATE_ENTREE, e.STATUT, e.TOTAL_HT, e.TOTAL_TTC, e.REFERENCE, e.NOTES, e.CREATED_AT,
                           f.ID AS FOURNISSEUR_ID, f.NOM AS FOURNISSEUR
                    FROM SENTREE e
                    LEFT JOIN SFOURNISSEUR f ON e.FOURNISSEUR_ID = f.ID
                    " + where + @"
                    " + orderBy + @"
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                // Lire les bons dans une liste temporaire
                var tempList = new List<Dictionary<string, object>>();
                using (var cmd = new SqlCommand(dataSql, conn))
                {
                    if (!string.IsNullOrEmpty(search)) cmd.Parameters.AddWithValue("@search", "%" + search + "%");
                    if (!string.IsNullOrEmpty(fournisseurId)) cmd.Parameters.AddWithValue("@fournisseurId", fournisseurId);
                    if (!string.IsNullOrEmpty(statut)) cmd.Parameters.AddWithValue("@statut", statut);
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);

                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            var obj = new Dictionary<string, object>();
                            string entreeId = reader["ID"].ToString();
                            obj["ID"] = entreeId;
                            obj["NUMERO"] = reader["NUMERO"].ToString();
                            obj["DATE_ENTREE"] = reader["DATE_ENTREE"];
                            obj["STATUT"] = reader["STATUT"].ToString();
                            obj["TOTAL_HT"] = reader["TOTAL_HT"];
                            obj["TOTAL_TTC"] = reader["TOTAL_TTC"];
                            obj["REFERENCE"] = reader["REFERENCE"] != DBNull.Value ? reader["REFERENCE"].ToString() : "";
                            obj["NOTES"] = reader["NOTES"] != DBNull.Value ? reader["NOTES"].ToString() : "";
                            obj["CREATED_AT"] = reader["CREATED_AT"];
                            obj["FOURNISSEUR_ID"] = reader["FOURNISSEUR_ID"] != DBNull.Value ? reader["FOURNISSEUR_ID"].ToString() : null;
                            obj["FOURNISSEUR"] = reader["FOURNISSEUR"] != DBNull.Value ? reader["FOURNISSEUR"].ToString() : "";
                            // Lignes chargées plus tard
                            tempList.Add(obj);
                        }
                    }
                }

                // Maintenant, charger les lignes pour chaque bon (le DataReader précédent est fermé)
                foreach (var obj in tempList)
                {
                    string entreeId = obj["ID"].ToString();
                    obj["Lignes"] = GetLignesByBonId(conn, entreeId);
                    resultList.Add(obj);
                }

                int totalPages = (int)Math.Ceiling((double)total / pageSize);
                var response = new Dictionary<string, object>();
                response["success"] = true;
                response["Entrees"] = resultList;
                response["total"] = total;
                response["totalPages"] = totalPages;

                ctx.Response.Write(new JavaScriptSerializer().Serialize(response));
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
            }));
        }
    }

    private List<Dictionary<string, object>> GetLignesByBonId(SqlConnection conn, string bonEntreeId)
    {
        var lignes = new List<Dictionary<string, object>>();

        string sql = @"
            SELECT ARTICLE_ID, QUANTITE, PRIX_UNITAIRE_HT, TVA_TX, PRIX_UNITAIRE_TTC, TOTAL_HT, TOTAL_TVA, TOTAL_TTC
            FROM MLENTREE
            WHERE BON_ENTREE_ID = @bonEntreeId AND DELETION_AT IS NULL
            ORDER BY ARTICLE_ID";

        using (var cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@bonEntreeId", bonEntreeId);
            using (var reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    var ligne = new Dictionary<string, object>();
                    ligne["ARTICLE_ID"] = reader["ARTICLE_ID"] != DBNull.Value ? reader["ARTICLE_ID"].ToString() : null;
                    ligne["QUANTITE"] = reader["QUANTITE"];
                    ligne["PRIX_UNITAIRE_HT"] = reader["PRIX_UNITAIRE_HT"];
                    ligne["TVA_TX"] = reader["TVA_TX"];
                    ligne["PRIX_UNITAIRE_TTC"] = reader["PRIX_UNITAIRE_TTC"];
                    ligne["TOTAL_HT"] = reader["TOTAL_HT"];
                    ligne["TOTAL_TVA"] = reader["TOTAL_TVA"];
                    ligne["TOTAL_TTC"] = reader["TOTAL_TTC"];
                    lignes.Add(ligne);
                }
            }
        }

        return lignes;
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
