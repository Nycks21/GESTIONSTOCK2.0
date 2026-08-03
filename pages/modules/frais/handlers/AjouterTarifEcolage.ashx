<%@ WebHandler Language="C#" Class="AjouterTarifEcolage" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterTarifEcolage : IHttpHandler, IRequiresSessionState
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

            int anneeId = Convert.ToInt32(data["anneeId"]);
            int classeId = Convert.ToInt32(data["classeId"]);
            decimal montant = Convert.ToDecimal(data["montant"]);
            string description = "";
            if (data.ContainsKey("description") && data["description"] != null)
                description = data["description"].ToString();
            bool statut = true;
            if (data.ContainsKey("statut") && data["statut"] != null)
                statut = Convert.ToBoolean(data["statut"]);

            if (anneeId <= 0 || classeId <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Année et classe obligatoires\"}");
                return;
            }
            if (montant <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Montant invalide\"}");
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

                // Vérification doublon
                string checkSql = "SELECT COUNT(*) FROM TARIFS_ECOLAGE WHERE ANNEE_ID = @anneeId AND CLASSE_ID = @classeId";
                using (var checkCmd = new SqlCommand(checkSql, conn))
                {
                    checkCmd.Parameters.AddWithValue("@anneeId", anneeId);
                    checkCmd.Parameters.AddWithValue("@classeId", classeId);
                    int existing = (int)checkCmd.ExecuteScalar();
                    if (existing > 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Un tarif existe déjà pour cette classe et cette année scolaire\"}");
                        return;
                    }
                }

                using (var cmd = new SqlCommand(@"
                    INSERT INTO TARIFS_ECOLAGE (ID, ANNEE_ID, CLASSE_ID, MONTANT, DESCRIPTION, STATUT, CREATED_AT)
                    VALUES (NEWID(), @anneeId, @classeId, @montant, @description, @statut, GETDATE())", conn))
                {
                    cmd.Parameters.AddWithValue("@anneeId", anneeId);
                    cmd.Parameters.AddWithValue("@classeId", classeId);
                    cmd.Parameters.AddWithValue("@montant", montant);
                    cmd.Parameters.AddWithValue("@description", description);
                    cmd.Parameters.AddWithValue("@statut", statut ? 1 : 0);
                    cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Tarif ajouté avec succès\"}");
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