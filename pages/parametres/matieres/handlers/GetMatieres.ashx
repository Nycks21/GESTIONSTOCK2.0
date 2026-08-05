<%@ WebHandler Language="C#" Class="GetMatieres" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetMatieres : IHttpHandler, IRequiresSessionState
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
                // ✅ CORRECTION : WHERE après les JOIN
                string sql = @"
                    SELECT 
                        m.ID,
                        m.NOM,
                        m.ENSEIGNANT AS ENSEIGNANT_ID,
                        u.NOM AS ENSEIGNANT,
                        m.COEFFICIENT,
                        m.HEURES_SEMAINE,
                        m.CLASSE_ID,
                        c.NOM AS CLASSE_NOM,
                        m.CREATED_AT,
                        m.DELETION_AT
                    FROM [dbo].[MATIERES] m
                    LEFT JOIN [dbo].[USERS] u ON m.ENSEIGNANT = u.IDUSER
                    LEFT JOIN [dbo].[CLASSES] c ON m.CLASSE_ID = c.ID
                    WHERE m.DELETION_AT IS NULL
                    ORDER BY m.NOM ASC";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    conn.Open();
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            list.Add(new
                            {
                                ID = reader.IsDBNull(0) ? "" : reader.GetGuid(0).ToString(),
                                NOM = reader.IsDBNull(1) ? "" : reader.GetString(1),
                                ENSEIGNANT_ID = reader.IsDBNull(2) ? 0 : reader.GetInt32(2),
                                ENSEIGNANT = reader.IsDBNull(3) ? "" : reader.GetString(3),
                                COEFFICIENT = reader.IsDBNull(4) ? 1.0m : reader.GetDecimal(4),
                                HEURES_SEMAINE = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                                CLASSE_ID = reader.IsDBNull(6) ? 0 : reader.GetInt32(6),
                                CLASSE_NOM = reader.IsDBNull(7) ? "" : reader.GetString(7),
                                CREATED_AT = reader.IsDBNull(8) ? "" : reader.GetDateTime(8).ToString("yyyy-MM-dd HH:mm:ss")
                            });
                        }
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, matieres = list }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}