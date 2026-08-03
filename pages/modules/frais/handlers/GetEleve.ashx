<%@ WebHandler Language="C#" Class="GetEleve" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEleve : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        
        try
        {
            if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
            {
                ctx.Response.StatusCode = 401;
                ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
                return;
            }

            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }
            
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Chaîne de connexion non trouvée\"}");
                return;
            }

            var eleves = new List<object>();
            
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                
                string sql = @"
                    SELECT 
                        e.MATRICULE,
                        e.NOM,
                        e.CLASSE,
                        c.NOM as CLASSE_NOM,
                        e.STATUT,
                        e.EMAIL,
                        e.TELEPHONE
                    FROM ELEVES e
                    LEFT JOIN CLASSES c ON e.CLASSE = c.ID
                    WHERE e.STATUT = 'actif'
                    ORDER BY e.NOM ASC
                ";
                
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var item = new Dictionary<string, object>();
                        item["MATRICULE"] = reader["MATRICULE"].ToString();
                        item["NOM"] = reader["NOM"].ToString();
                        if (reader["CLASSE"] != DBNull.Value)
                            item["CLASSE"] = Convert.ToInt32(reader["CLASSE"]);
                        else
                            item["CLASSE"] = 0;
                        if (reader["CLASSE_NOM"] != DBNull.Value)
                            item["CLASSE_NOM"] = reader["CLASSE_NOM"].ToString();
                        else
                            item["CLASSE_NOM"] = "";
                        item["STATUT"] = reader["STATUT"].ToString();
                        if (reader["EMAIL"] != DBNull.Value)
                            item["EMAIL"] = reader["EMAIL"].ToString();
                        else
                            item["EMAIL"] = "";
                        if (reader["TELEPHONE"] != DBNull.Value)
                            item["TELEPHONE"] = reader["TELEPHONE"].ToString();
                        else
                            item["TELEPHONE"] = "";
                        eleves.Add(item);
                    }
                }
            }
            
            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["Eleves"] = eleves;
            result["Total"] = eleves.Count;
            
            JavaScriptSerializer serializer = new JavaScriptSerializer();
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