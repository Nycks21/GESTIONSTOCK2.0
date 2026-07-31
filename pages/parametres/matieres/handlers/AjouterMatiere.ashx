<%@ WebHandler Language="C#" Class="AjouterMatiere" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class AjouterMatiere : IHttpHandler, IRequiresSessionState
{
    private static readonly string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

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
        string sessionToken = context.Session["CSRF_TOKEN"]?.ToString();
        if (string.IsNullOrEmpty(token) || token != sessionToken)
        {
            context.Response.Write("{\"success\":false,\"message\":\"Token CSRF invalide\"}");
            return;
        }
    }
        context.Response.ContentType = "application/json";
        context.Response.Charset = "utf-8";

        try
        {
            string jsonBody = new System.IO.StreamReader(context.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<dynamic>(jsonBody);

            string nom = Convert.ToString(data["NOM"]);
            int enseignantId = Convert.ToInt32(data["ENSEIGNANT_ID"]);
            decimal coefficient = Convert.ToDecimal(data["COEFFICIENT"]);
            int heuresSemaine = Convert.ToInt32(data["HEURES_SEMAINE"]);
            int classeId = Convert.ToInt32(data["CLASSE_ID"]);

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string sql = @"INSERT INTO MATIERES (ID, NOM, ENSEIGNANT, COEFFICIENT, HEURES_SEMAINE, CLASSE_ID, CREATED_AT) 
                               VALUES (NEWID(), @nom, @enseignantId, @coefficient, @heuresSemaine, @classeId, GETDATE())";

                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@enseignantId", enseignantId);
                    cmd.Parameters.AddWithValue("@coefficient", coefficient);
                    cmd.Parameters.AddWithValue("@heuresSemaine", heuresSemaine);
                    cmd.Parameters.AddWithValue("@classeId", classeId);

                    int rowsAffected = cmd.ExecuteNonQuery();
                    
                    context.Response.Write(new JavaScriptSerializer().Serialize(new
                    {
                        success = rowsAffected > 0,
                        message = rowsAffected > 0 ? "Matière ajoutée avec succès" : "Erreur lors de l'insertion"
                    }));
                }
            }
        }
        catch (Exception ex)
        {
            context.Response.StatusCode = 500;
            context.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = "Erreur: " + ex.Message
            }));
        }
    }

    public bool IsReusable { get { return false; } }
}