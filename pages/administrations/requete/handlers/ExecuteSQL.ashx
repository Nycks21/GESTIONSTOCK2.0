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
        // ✅ Sécurité : 4 vérifications essentielles
    
    // 1. Authentification
    if (context.Session == null || context.Session["authenticated"] == null || !(bool)context.Session["authenticated"])
    {
        context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
        return;
    }
    
    // 2. Token de session valide
    if (!AuthHelper.RequireApiAuth(context))
    {
        context.Response.Write("{\"success\":false,\"message\":\"Session invalide\"}");
        return;
    }
    
    // 3. Permission (SuperAdmin = 0, Admin = 1, etc.)
    int role = AuthHelper.GetUserRole(context);
    if (role < 0 || role > 1) // Permissions minimales selon le handler
    {
        context.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
        return;
    }
    
    // 4. CSRF pour les méthodes POST/PUT/DELETE
    string method = context.Request.HttpMethod.ToUpper();
    if (method == "POST" || method == "PUT" || method == "DELETE")
    {
        string token = context.Request.Headers["X-CSRF-Token"];
        string sessionToken = context.Session["CSRF_TOKEN"] != null ? context.Session["CSRF_TOKEN"].ToString() : null;
        if (string.IsNullOrEmpty(token) || token != sessionToken)
        {
            context.Response.Write("{\"success\":false,\"message\":\"Token CSRF invalide\"}");
            return;
        }
    }
        context.Response.ContentType = "application/json";
        context.Response.Headers["Cache-Control"] = "no-cache";

        // ✅ Vérification d'authentification
        if (!AuthHelper.RequireApiAuth(context, 0)) // SuperAdmin uniquement
        {
            SendResponse(context, false, "Accès non autorisé.");
            return;
        }

        string sqlQuery = context.Request.Form["query"];

        if (string.IsNullOrEmpty(sqlQuery))
        {
            SendResponse(context, false, "La requête SQL est vide.");
            return;
        }

        // ✅ Vérifier que la requête est dans la liste blanche
        bool isAllowed = false;
        foreach (string allowed in AllowedQueries)
        {
            if (sqlQuery.Trim().Equals(allowed, StringComparison.OrdinalIgnoreCase))
            {
                isAllowed = true;
                break;
            }
        }

        if (!isAllowed)
        {
            SendResponse(context, false, "Requête non autorisée.");
            return;
        }

        // ✅ Vérifier que c'est bien un SELECT (sécurité supplémentaire)
        if (!sqlQuery.Trim().StartsWith("SELECT", StringComparison.OrdinalIgnoreCase))
        {
            SendResponse(context, false, "Seules les requêtes SELECT sont autorisées.");
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
                // ✅ Log sécurisé sans exposer les détails
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
            string entry = $"[{DateTime.Now}] SQL Error: {ex.Message}\n" +
                           $"IP: {context.Request.UserHostAddress}\n" +
                           $"---\n";
            System.IO.File.AppendAllText(logFile, entry);
        }
        catch { /* Ne pas échouer si le log échoue */ }
    }

    public bool IsReusable
    {
        get { return false; }
    }
}