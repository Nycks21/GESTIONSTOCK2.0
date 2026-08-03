<%@ WebHandler Language="C#" Class="GetTarifByClasse" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetTarifByClasse : IHttpHandler, IRequiresSessionState
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

            string classeNom = ctx.Request.QueryString["classeNom"];
            string anneeIdStr = ctx.Request.QueryString["anneeId"];
            
            int anneeId = 1;
            if (!string.IsNullOrEmpty(anneeIdStr))
                int.TryParse(anneeIdStr, out anneeId);

            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            string connStr = connSetting != null ? connSetting.ConnectionString : "";
            
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            decimal montant = 500000; // Valeur par défaut

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                
                string query = @"
                    SELECT TOP 1 t.MONTANT
                    FROM TARIFS_ECOLAGE t
                    INNER JOIN CLASSES c ON t.CLASSE_ID = c.ID
                    WHERE c.NOM = @classeNom AND t.ANNEE_ID = @anneeId AND t.STATUT = 1";
                
                using (var cmd = new SqlCommand(query, conn))
                {
                    cmd.Parameters.AddWithValue("@classeNom", classeNom);
                    cmd.Parameters.AddWithValue("@anneeId", anneeId);
                    var result = cmd.ExecuteScalar();
                    if (result != null && result != DBNull.Value)
                    {
                        montant = Convert.ToDecimal(result);
                    }
                }
            }
            
            var resultDict = new Dictionary<string, object>();
            resultDict["success"] = true;
            resultDict["montant"] = montant;
            
            var serializer = new JavaScriptSerializer();
            ctx.Response.Write(serializer.Serialize(resultDict));
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