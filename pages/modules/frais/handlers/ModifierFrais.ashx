<%@ WebHandler Language="C#" Class="ModifierFrais" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierFrais : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var ser = new JavaScriptSerializer();
            var data = ser.Deserialize<Dictionary<string, object>>(body);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données invalides\"}");
                return;
            }

            Guid id = Guid.Parse(data["id"].ToString());
            decimal total = Convert.ToDecimal(data["total"]);

            if (total < 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le montant total ne peut pas être négatif\"}");
                return;
            }

            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string sql = @"
                    UPDATE FRAIS
                    SET TOTAL       = @total,
                        RESTE       = CASE WHEN @total - PAYE < 0 THEN 0 ELSE @total - PAYE END,
                        PROGRESSION = CASE WHEN @total > 0 THEN ROUND((PAYE / @total) * 100, 2) ELSE 0 END,
                        STATUT      = CASE
                                        WHEN @total <= PAYE THEN N'Terminé'
                                        WHEN PAYE > 0       THEN N'En cours'
                                        ELSE N'Non payé'
                                      END,
                        UPDATED_AT  = GETDATE()
                    WHERE ID = @id";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@total", total);
                    cmd.Parameters.AddWithValue("@id", id);
                    int affected = cmd.ExecuteNonQuery();

                    if (affected == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Enregistrement introuvable\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Frais modifié avec succès\"}");
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