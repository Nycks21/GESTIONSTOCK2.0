<%@ WebHandler Language="C#" Class="GetHistoriquePaiements" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetHistoriquePaiements : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        string matricule = ctx.Request.QueryString["matricule"];
        if (string.IsNullOrEmpty(matricule))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Matricule manquant\"}");
            return;
        }

        var list = new List<object>();
        string connStr = "";
        var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
        if (connSetting != null)
        {
            connStr = connSetting.ConnectionString;
        }

        try
        {
            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                
                string query = @"
                    SELECT 
                        h.ID, 
                        h.MATRICULE, 
                        h.NOM, 
                        ISNULL(c.NOM, 'Non défini') AS CLASSE_NOM,
                        h.MONTANT, 
                        h.DATE_PAIEMENT, 
                        h.MODE_PAIEMENT, 
                        ISNULL(h.REFERENCE, '') AS REFERENCE, 
                        ISNULL(h.COMMENTAIRE, '') AS COMMENTAIRE, 
                        ISNULL(h.USERNAME, 'Système') AS USERNAME,
                        ISNULL(h.ANCIEN_PAYE, 0) AS ANCIEN_PAYE, 
                        ISNULL(h.NOUVEAU_PAYE, 0) AS NOUVEAU_PAYE,
                        ISNULL(h.ANCIEN_RESTE, 0) AS ANCIEN_RESTE, 
                        ISNULL(h.NOUVEAU_RESTE, 0) AS NOUVEAU_RESTE,
                        h.MOIS,
                        h.ANNEE,
                        h.CREATED_AT
                    FROM HISTORIQUE_PAIEMENTS h
                    LEFT JOIN CLASSES c ON h.CLASSE = c.ID
                    WHERE h.MATRICULE = @matricule
                    ORDER BY h.DATE_PAIEMENT DESC";
                
                using (var cmd = new SqlCommand(query, conn))
                {
                    cmd.Parameters.AddWithValue("@matricule", matricule);
                    using (var rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            var item = new Dictionary<string, object>();
                            item["ID"] = rdr["ID"].ToString();
                            item["MATRICULE"] = rdr["MATRICULE"].ToString();
                            item["NOM"] = rdr["NOM"].ToString();
                            item["CLASSE_NOM"] = rdr["CLASSE_NOM"].ToString();
                            item["MONTANT"] = Convert.ToDecimal(rdr["MONTANT"]);
                            item["DATE_PAIEMENT"] = Convert.ToDateTime(rdr["DATE_PAIEMENT"]).ToString("yyyy-MM-dd HH:mm:ss");
                            item["MODE_PAIEMENT"] = rdr["MODE_PAIEMENT"].ToString();
                            item["REFERENCE"] = rdr["REFERENCE"].ToString();
                            item["COMMENTAIRE"] = rdr["COMMENTAIRE"].ToString();
                            item["USERNAME"] = rdr["USERNAME"].ToString();
                            item["ANCIEN_PAYE"] = Convert.ToDecimal(rdr["ANCIEN_PAYE"]);
                            item["NOUVEAU_PAYE"] = Convert.ToDecimal(rdr["NOUVEAU_PAYE"]);
                            item["ANCIEN_RESTE"] = Convert.ToDecimal(rdr["ANCIEN_RESTE"]);
                            item["NOUVEAU_RESTE"] = Convert.ToDecimal(rdr["NOUVEAU_RESTE"]);
                            item["MOIS"] = rdr["MOIS"].ToString();
                            item["ANNEE"] = rdr["ANNEE"].ToString();
                            item["CREATED_AT"] = Convert.ToDateTime(rdr["CREATED_AT"]).ToString("yyyy-MM-dd HH:mm:ss");
                            list.Add(item);
                        }
                    }
                }
            }
            
            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["data"] = list;
            
            var serializer = new JavaScriptSerializer();
            ctx.Response.Write(serializer.Serialize(result));
        }
        catch (Exception)
        {
            ctx.Response.Write("{\"success\":true,\"data\":[]}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}