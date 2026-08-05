<%@ WebHandler Language="C#" Class="ModifierNiveau" %>

using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ModifierNiveau : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        context.Response.Charset = "utf-8";

        try
        {
            if (context.Session == null || context.Session["authenticated"] == null || !(bool)context.Session["authenticated"])
            {
                SendError(context, "Non authentifié");
                return;
            }
            if (!AuthHelper.RequireApiAuth(context))
            {
                SendError(context, "Session invalide");
                return;
            }
            int role = AuthHelper.GetUserRole(context);
            if (role < 0 || role > 1)
            {
                SendError(context, "Permissions insuffisantes");
                return;
            }

            string tokenHeader = context.Request.Headers["X-CSRF-Token"];
            string sessionToken = context.Session["CSRF_TOKEN"] as string;
            if (string.IsNullOrEmpty(tokenHeader) || tokenHeader != sessionToken)
            {
                SendError(context, "Token CSRF invalide");
                return;
            }

            string body = new StreamReader(context.Request.InputStream).ReadToEnd();
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            NiveauPayload payload = serializer.Deserialize<NiveauPayload>(body);

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                SendError(context, "Chaîne de connexion non définie");
                return;
            }

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                SqlCommand cmd = new SqlCommand(
                    "UPDATE [dbo].[NIVEAUX] SET NOM = @nom, ORDRE = @ordre, STATUT = @statut WHERE ID = @id", conn);
                cmd.Parameters.AddWithValue("@id", new Guid(payload.id));
                cmd.Parameters.AddWithValue("@nom", payload.nom ?? "");
                cmd.Parameters.AddWithValue("@ordre", payload.ordre);
                cmd.Parameters.AddWithValue("@statut", payload.statut);
                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0)
                {
                    SendError(context, "Aucun niveau trouvé avec cet ID");
                    return;
                }
            }

            context.Response.Write("{\"success\":true}");
        }
        catch (Exception ex)
        {
            SendError(context, "Erreur : " + ex.Message);
        }
    }

    private void SendError(HttpContext context, string message)
    {
        context.Response.StatusCode = 500;
        context.Response.Write("{\"success\":false,\"message\":\"" + message.Replace("\"", "\\\"") + "\"}");
    }

    public bool IsReusable
    {
        get { return false; }
    }

    public class NiveauPayload
    {
        public string id { get; set; }
        public string nom { get; set; }
        public int ordre { get; set; }
        public bool statut { get; set; }
    }
}