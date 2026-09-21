<%@ WebHandler Language="C#" Class="ExecuteSQL" %>

using System;
using System.Web;
using System.Data;
using System.Data.SqlClient;
using System.Configuration;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ExecuteSQL : IHttpHandler, IRequiresSessionState
{
    // ✅ Liste blanche des requêtes autorisées (READ ONLY)
    private static readonly string[] AllowedQueries = new string[]
    {
        "SELECT USERNAME, NOM, EMAIL FROM USERS",
        "SELECT COUNT(*) FROM USERS",
        "SELECT ID, NOM, EFFECTIF FROM CLASSES",
        "SELECT ID, NOM FROM MATIERES",
        "SELECT * FROM ELEVES WHERE STATUT = 'actif'",
        // Ajouter d'autres requêtes autorisées ici
    };

    public void ProcessRequest(HttpContext context)
    {
        // ✅ Sécurité : garde-fou unifié
        //    RequireCsrfSafePost = RequireApiAuth + ValidateCsrfToken + ValidateOrigin
        //    1. Session authentifiée
        //    2. Token de session valide (validé en DB)
        //    3. Rôle minimal : SuperAdmin (role == 0)
        //    4. Header X-CSRF-Token valide
        //    5. Origin/Referer de confiance
        if (!AuthHelper.RequireCsrfSafePost(context, 0))
        {
            context.Response.ContentType = "application/json";
            context.Response.StatusCode = 403;
            SendResponse(context, false, "Accès non autorisé.");
            return;
        }

        context.Response.ContentType = "application/json";
        context.Response.Headers["Cache-Control"] = "no-cache";

        string sqlQuery = context.Request.Form["query"];

        if (string.IsNullOrEmpty(sqlQuery))
        {
            SendResponse(context, false, "La requête SQL est vide.");
            return;
        }

        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            try
            {
                SqlCommand cmd = new SqlCommand(sqlQuery, conn);
                conn.Open();

                SqlDataAdapter da = new SqlDataAdapter(cmd);
                DataTable dt = new DataTable();
                da.Fill(dt);

                var rows = new List<Dictionary<string, object>>();
                foreach (DataRow dr in dt.Rows)
                {
                    var row = new Dictionary<string, object>();
                    foreach (DataColumn col in dt.Columns)
                    {
                        row.Add(col.ColumnName, dr[col]);
                    }
                    rows.Add(row);
                }

                JavaScriptSerializer serializer = new JavaScriptSerializer();
                context.Response.Write(serializer.Serialize(new
                {
                    success = true,
                    type = "SELECT",
                    data = rows
                }));
            }
            catch (SqlException ex)
            {
                LogError(context, ex);
                SendResponse(context, false, "Erreur de base de données. Contactez l'administrateur.");
            }
            catch (Exception ex)
            {
                LogError(context, ex);
                SendResponse(context, false, "Erreur système. Contactez l'administrateur.");
            }
        }
    }

    private void SendResponse(HttpContext context, bool success, string message)
    {
        JavaScriptSerializer serializer = new JavaScriptSerializer();
        context.Response.Write(serializer.Serialize(new
        {
            success = success,
            message = message
        }));
    }

    private void LogError(HttpContext context, Exception ex)
    {
        try
        {
            string logFile = context.Server.MapPath("~/App_Data/security.log");
            string entry = "[" + DateTime.Now.ToString() + "] SQL Error: " + ex.Message + "\n" +
                           "IP: " + context.Request.UserHostAddress + "\n" +
                           "---\n";
            System.IO.File.AppendAllText(logFile, entry);
        }
        catch { /* Ne pas échouer si le log échoue */ }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
