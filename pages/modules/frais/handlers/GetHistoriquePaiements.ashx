<%@ WebHandler Language="C#" Class="GetHistoriquePaiements" %>
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetHistoriquePaiements : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
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
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        string matricule = ctx.Request.QueryString["matricule"];
        if (string.IsNullOrEmpty(matricule))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Matricule manquant\"}");
            return;
        }

        var list = new List<object>();
        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        try
        {
            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                
                string query = @"
                    SELECT 
                        h.ID, 
                        h.MATRICULE, 
                        h.NOM, 
                        ISNULL(c.NOM, 'Non défini') AS CLASSE_NOM,
                        h.MONTANT, 
                        h.DATE_PAIEMENT, 
                        h.MODE_PAIEMENT, 
                        ISNULL(h.REFERENCE, '') AS REFERENCE, 
                        ISNULL(h.COMMENTAIRE, '') AS COMMENTAIRE, 
                        ISNULL(h.USERNAME, 'Système') AS USERNAME,
                        ISNULL(h.ANCIEN_PAYE, 0) AS ANCIEN_PAYE, 
                        ISNULL(h.NOUVEAU_PAYE, 0) AS NOUVEAU_PAYE,
                        ISNULL(h.ANCIEN_RESTE, 0) AS ANCIEN_RESTE, 
                        ISNULL(h.NOUVEAU_RESTE, 0) AS NOUVEAU_RESTE,
                        h.MOIS,
                        h.ANNEE,
                        h.CREATED_AT
                    FROM HISTORIQUE_PAIEMENTS h
                    LEFT JOIN CLASSES c ON h.CLASSE = c.ID
                    WHERE h.MATRICULE = @matricule
                    ORDER BY h.DATE_PAIEMENT DESC";
                
                using (var cmd = new SqlCommand(query, conn))
                {
                    cmd.Parameters.AddWithValue("@matricule", matricule);
                    using (var rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            list.Add(new {
                                ID = rdr["ID"].ToString(),
                                MATRICULE = rdr["MATRICULE"].ToString(),
                                NOM = rdr["NOM"].ToString(),
                                CLASSE_NOM = rdr["CLASSE_NOM"].ToString(),
                                MONTANT = Convert.ToDecimal(rdr["MONTANT"]),
                                DATE_PAIEMENT = Convert.ToDateTime(rdr["DATE_PAIEMENT"]).ToString("yyyy-MM-dd HH:mm:ss"),
                                MODE_PAIEMENT = rdr["MODE_PAIEMENT"].ToString(),
                                REFERENCE = rdr["REFERENCE"].ToString(),
                                COMMENTAIRE = rdr["COMMENTAIRE"].ToString(),
                                USERNAME = rdr["USERNAME"].ToString(),
                                ANCIEN_PAYE = Convert.ToDecimal(rdr["ANCIEN_PAYE"]),
                                NOUVEAU_PAYE = Convert.ToDecimal(rdr["NOUVEAU_PAYE"]),
                                ANCIEN_RESTE = Convert.ToDecimal(rdr["ANCIEN_RESTE"]),
                                NOUVEAU_RESTE = Convert.ToDecimal(rdr["NOUVEAU_RESTE"]),
                                MOIS = rdr["MOIS"].ToString(),
                                ANNEE = rdr["ANNEE"].ToString(),
                                CREATED_AT = Convert.ToDateTime(rdr["CREATED_AT"]).ToString("yyyy-MM-dd HH:mm:ss")
                            });
                        }
                    }
                }
            }
            
            var serializer = new JavaScriptSerializer();
            ctx.Response.Write(serializer.Serialize(new { success = true, data = list }));
        }
        catch (Exception ex)
        {
            ctx.Response.Write("{\"success\":true,\"data\":[]}");
        }
    }

    public bool IsReusable { get { return false; } }
}