<%@ WebHandler Language="C#" Class="GetTarifsEcolage" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetTarifsEcolage : IHttpHandler, IRequiresSessionState
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

            string anneeId = ctx.Request.QueryString["anneeId"];
            string classeId = ctx.Request.QueryString["classeId"];

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
                    SELECT t.ID, t.ANNEE_ID, ISNULL(r.ANNEE, '') AS ANNEE_TEXTE, 
                           t.CLASSE_ID, ISNULL(c.NOM, '') AS CLASSE_NOM,
                           t.MONTANT, ISNULL(t.DESCRIPTION, '') AS DESCRIPTION, t.STATUT, 
                           CONVERT(VARCHAR(19), t.CREATED_AT, 120) AS CREATED_AT
                    FROM TARIFS_ECOLAGE t
                    LEFT JOIN RANNEE r ON t.ANNEE_ID = r.ID
                    LEFT JOIN CLASSES c ON t.CLASSE_ID = c.ID
                    WHERE 1=1";
                
                if (!string.IsNullOrEmpty(anneeId))
                    query += " AND t.ANNEE_ID = @anneeId";
                if (!string.IsNullOrEmpty(classeId))
                    query += " AND t.CLASSE_ID = @classeId";
                
                query += " ORDER BY r.ANNEE DESC, c.NOM ASC";
                
                using (var cmd = new SqlCommand(query, conn))
                {
                    if (!string.IsNullOrEmpty(anneeId))
                        cmd.Parameters.AddWithValue("@anneeId", anneeId);
                    if (!string.IsNullOrEmpty(classeId))
                        cmd.Parameters.AddWithValue("@classeId", classeId);
                    
                    using (var rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            var item = new Dictionary<string, object>();
                            item["ID"] = rdr["ID"].ToString();
                            item["ANNEE_ID"] = Convert.ToInt32(rdr["ANNEE_ID"]);
                            item["ANNEE_TEXTE"] = rdr["ANNEE_TEXTE"].ToString();
                            item["CLASSE_ID"] = Convert.ToInt32(rdr["CLASSE_ID"]);
                            item["CLASSE_NOM"] = rdr["CLASSE_NOM"].ToString();
                            item["MONTANT"] = Convert.ToDecimal(rdr["MONTANT"]);
                            item["DESCRIPTION"] = rdr["DESCRIPTION"].ToString();
                            item["STATUT"] = Convert.ToBoolean(rdr["STATUT"]);
                            item["CREATED_AT"] = rdr["CREATED_AT"].ToString();
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