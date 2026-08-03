<%@ WebHandler Language="C#" Class="ModifierTarifEcolage" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierTarifEcolage : IHttpHandler, IRequiresSessionState
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

            Guid id = Guid.Parse(data["id"].ToString());
            int anneeId = Convert.ToInt32(data["anneeId"]);
            int classeId = Convert.ToInt32(data["classeId"]);
            decimal montant = Convert.ToDecimal(data["montant"]);
            string description = "";
            if (data.ContainsKey("description") && data["description"] != null)
                description = data["description"].ToString();
            bool statut = true;
            if (data.ContainsKey("statut") && data["statut"] != null)
                statut = Convert.ToBoolean(data["statut"]);

            string connStr = "";
            var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
            if (connSetting != null)
            {
                connStr = connSetting.ConnectionString;
            }

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(@"
                UPDATE TARIFS_ECOLAGE 
                SET ANNEE_ID = @anneeId,
                    CLASSE_ID = @classeId,
                    MONTANT = @montant,
                    DESCRIPTION = @description,
                    STATUT = @statut,
                    UPDATED_AT = GETDATE()
                WHERE ID = @id", conn))
            {
                cmd.Parameters.AddWithValue("@id", id);
                cmd.Parameters.AddWithValue("@anneeId", anneeId);
                cmd.Parameters.AddWithValue("@classeId", classeId);
                cmd.Parameters.AddWithValue("@montant", montant);
                cmd.Parameters.AddWithValue("@description", description);
                cmd.Parameters.AddWithValue("@statut", statut ? 1 : 0);
                conn.Open();
                cmd.ExecuteNonQuery();
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Tarif modifié avec succès\"}");
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