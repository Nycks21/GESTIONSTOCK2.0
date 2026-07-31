<%@ WebHandler Language="C#" Class="AjouterAnnee" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterAnnee : IHttpHandler, IRequiresSessionState
{
    private static readonly string connStr;

    static AjouterAnnee()
    {
        var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
        connStr = (connSetting != null) ? connSetting.ConnectionString : "";
    }

    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        JavaScriptSerializer ser = new JavaScriptSerializer();

        // ✅ Vérification d'authentification simplifiée
        if (ctx.Session == null || ctx.Session["authenticated"] == null || !(bool)ctx.Session["authenticated"])
        {
            ctx.Response.StatusCode = 401;
            ctx.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        // ✅ Vérification du rôle (SuperAdmin ou Admin)
        object roleObj = ctx.Session["USERROLE"];
        int role = (roleObj != null) ? Convert.ToInt32(roleObj) : -1;
        if (role != 0 && role != 1)
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
            return;
        }

        if (ctx.Request.HttpMethod != "POST")
        {
            ctx.Response.StatusCode = 405;
            ctx.Response.Write("{\"success\":false,\"message\":\"Méthode non autorisée\"}");
            return;
        }

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var payload = ser.Deserialize<AnneePayload>(body);

            if (payload == null)
                throw new ArgumentException("Les données envoyées sont vides ou invalides.");

            if (string.IsNullOrWhiteSpace(payload.ANNEE))
                throw new ArgumentException("L'année scolaire est obligatoire.");

            DateTime dateDebut, dateFin;
            if (!DateTime.TryParse(payload.DATE_DEBUT, out dateDebut))
                throw new ArgumentException("La date de début est invalide.");
            if (!DateTime.TryParse(payload.DATE_FIN, out dateFin))
                throw new ArgumentException("La date de fin est invalide.");
            if (dateFin <= dateDebut)
                throw new ArgumentException("La date de fin doit être postérieure à la date de début.");

            bool cloture = (payload.CLOTURE == "Inactif" || payload.CLOTURE == "1" || payload.CLOTURE == "true");

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(
                @"INSERT INTO [dbo].[RANNEE]
                    (ANNEE, DATE_DEBUT, DATE_FIN, CLOTURE, CREATED_AT)
                  VALUES
                    (@annee, @dateDebut, @dateFin, @cloture, GETDATE())", conn))
            {
                cmd.Parameters.Add("@annee", System.Data.SqlDbType.NVarChar, 50).Value = payload.ANNEE.Trim();
                cmd.Parameters.Add("@dateDebut", System.Data.SqlDbType.Date).Value = dateDebut;
                cmd.Parameters.Add("@dateFin", System.Data.SqlDbType.Date).Value = dateFin;
                cmd.Parameters.Add("@cloture", System.Data.SqlDbType.Bit).Value = cloture;

                conn.Open();
                cmd.ExecuteNonQuery();
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Année scolaire ajoutée avec succès.\"}");
        }
        catch (ArgumentException ex)
        {
            ctx.Response.StatusCode = 400;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(ex.Message) + "}");
        }
        catch (SqlException ex)
        {
            ctx.Response.StatusCode = 500;
            string msg = (ex.Number == 2627) ? "Cette année scolaire existe déjà." : "Erreur de base de données.";
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize(msg) + "}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":" + ser.Serialize("Erreur serveur") + "}");
        }
    }

    public bool IsReusable { get { return false; } }

    private class AnneePayload
    {
        public string ANNEE { get; set; }
        public string DATE_DEBUT { get; set; }
        public string DATE_FIN { get; set; }
        public string CLOTURE { get; set; }
    }
}