<%@ WebHandler Language="C#" Class="GetEleve" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEleve : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
                throw new Exception("Chaîne de connexion non trouvée.");

            var list = new List<object>();

            using (var conn = new SqlConnection(connStr))
            {
                string sql = @"SELECT e.ID,
                                      a.ANNEE, 
                                      e.MATRICULE, 
                                      e.NOM, 
                                      e.CLASSE, 
                                      c.NOM AS CLASSE_NOM, 
                                      e.EMAIL, 
                                      e.TELEPHONE, 
                                      e.STATUT,
                                      e.GENRE,
                                      e.DATE_NAISSANCE,
                                      e.ADRESSE,
                                      e.PARENT
                               FROM [dbo].[ELEVES] e
                               LEFT JOIN [dbo].[CLASSES] c ON e.CLASSE = c.ID
                               LEFT JOIN [dbo].[RANNEE] a ON e.ANNEE_ID = a.ID
                               WHERE e.DELETION_AT IS NULL
                               ORDER BY e.MATRICULE ASC";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    conn.Open();
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            list.Add(new
                            {
                                ID             = reader.IsDBNull(0) ? "" : reader.GetGuid(0).ToString(),
                                ANNEE_TEXTE    = reader.IsDBNull(1) ? "" : reader.GetString(1),
                                MATRICULE      = reader.IsDBNull(2) ? "" : reader.GetString(2),
                                NOM            = reader.IsDBNull(3) ? "" : reader.GetString(3),
                                ID_CLASSE      = reader.IsDBNull(4) ? 0 : reader.GetInt32(4),
                                CLASSE_NOM     = reader.IsDBNull(5) ? "N/A" : reader.GetString(5),
                                EMAIL          = reader.IsDBNull(6) ? "" : reader.GetString(6),
                                TELEPHONE      = reader.IsDBNull(7) ? "" : reader.GetString(7),
                                STATUT         = reader.IsDBNull(8) ? "inactif" : reader.GetString(8),
                                GENRE          = reader.IsDBNull(9) ? "M" : reader.GetString(9),
                                DATE_NAISSANCE = reader.IsDBNull(10) ? "" : reader.GetDateTime(10).ToString("yyyy-MM-dd"),
                                ADRESSE        = reader.IsDBNull(11) ? "" : reader.GetString(11),
                                PARENT         = reader.IsDBNull(12) ? "" : reader.GetString(12)
                            });
                        }
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, Eleves = list }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}