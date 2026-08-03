<%@ WebHandler Language="C#" Class="GetFrais" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetFrais : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        try
        {
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            var list = new List<object>();
            
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            string connStr = connSetting != null ? connSetting.ConnectionString : "";
            
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée\"}");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                
                string query = @"
                    SELECT 
                        f.ID, 
                        f.MATRICULE, 
                        f.NOM, 
                        ISNULL(c.NOM, 'Non defini') AS CLASSE_NOM,
                        ISNULL(f.TOTAL, 0) AS TOTAL,
                        ISNULL(f.PAYE, 0) AS PAYE,
                        ISNULL(f.RESTE, 0) AS RESTE,
                        ISNULL(f.PROGRESSION, 0) AS PROGRESSION,
                        ISNULL(f.STATUT, 'Non paye') AS STATUT,
                        CONVERT(VARCHAR(10), f.DERNIER_PAIEMENT, 103) AS DERNIER_PAIEMENT,
                        ISNULL(r.ANNEE, '') AS ANNEE_TEXTE
                    FROM FRAIS f
                    INNER JOIN ELEVES e ON f.MATRICULE = e.MATRICULE
                    LEFT JOIN CLASSES c ON f.CLASSE = c.ID
                    LEFT JOIN RANNEE r ON f.ANNEE_ID = r.ID
                    WHERE e.STATUT = 'actif'
                    ORDER BY f.NOM ASC";
                
                using (var cmd = new SqlCommand(query, conn))
                {
                    using (var rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            var item = new Dictionary<string, object>();
                            item["ID"] = rdr["ID"].ToString();
                            item["MATRICULE"] = rdr["MATRICULE"].ToString();
                            item["NOM"] = rdr["NOM"].ToString();
                            item["CLASSE_NOM"] = rdr["CLASSE_NOM"].ToString();
                            item["TOTAL"] = Convert.ToDecimal(rdr["TOTAL"]);
                            item["PAYE"] = Convert.ToDecimal(rdr["PAYE"]);
                            item["RESTE"] = Convert.ToDecimal(rdr["RESTE"]);
                            item["PROGRESSION"] = Convert.ToDecimal(rdr["PROGRESSION"]);
                            item["STATUT"] = rdr["STATUT"].ToString();
                            item["DERNIER_PAIEMENT"] = rdr["DERNIER_PAIEMENT"].ToString();
                            item["ANNEE_TEXTE"] = rdr["ANNEE_TEXTE"].ToString();
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
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "'") + "\"}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}