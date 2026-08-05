<%@ WebHandler Language="C#" Class="GetNiveaux" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetNiveaux : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        context.Response.Charset = "utf-8";
        context.Response.Cache.SetNoStore();

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

            string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                SendError(context, "Chaîne de connexion non définie");
                return;
            }

            List<object> niveaux = new List<object>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                SqlCommand cmd = new SqlCommand(
                    "SELECT ID, NOM, ORDRE, STATUT, CREATED_AT FROM [dbo].[NIVEAUX] ORDER BY ORDRE, NOM", conn);
                conn.Open();
                SqlDataReader reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    Dictionary<string, object> item = new Dictionary<string, object>();
                    item["ID"] = reader.GetGuid(0).ToString();
                    item["NOM"] = reader.GetString(1);
                    item["ORDRE"] = reader.GetInt32(2);
                    item["STATUT"] = reader.GetBoolean(3);
                    item["CREATED_AT"] = reader.IsDBNull(4) ? "" : reader.GetDateTime(4).ToString("yyyy-MM-dd HH:mm:ss");
                    niveaux.Add(item);
                }
                reader.Close();
            }

            Dictionary<string, object> result = new Dictionary<string, object>();
            result["success"] = true;
            result["niveaux"] = niveaux;
            context.Response.Write(new JavaScriptSerializer().Serialize(result));
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
}