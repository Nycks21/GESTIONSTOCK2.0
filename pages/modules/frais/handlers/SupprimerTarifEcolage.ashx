<%@ WebHandler Language="C#" Class="SupprimerTarifEcolage" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SupprimerTarifEcolage : IHttpHandler, IRequiresSessionState
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

            if (data == null || !data.ContainsKey("id"))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Données invalides\"}");
                return;
            }

            Guid id = Guid.Parse(data["id"].ToString());
            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Vérifier si des élèves sont liés à ce tarif
                string checkSql = "SELECT COUNT(*) FROM FRAIS WHERE TARIF_ID = @id";
                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.AddWithValue("@id", id);
                    int linked = (int)checkCmd.ExecuteScalar();
                    if (linked > 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Ce tarif est utilisé par " + linked + " élève(s). Supprimez d'abord les frais associés.\"}");
                        return;
                    }
                }

                using (var cmd = new SqlCommand("DELETE FROM TARIFS_ECOLAGE WHERE ID = @id", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    int affected = cmd.ExecuteNonQuery();
                    if (affected == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Tarif introuvable\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Tarif supprimé avec succès\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}