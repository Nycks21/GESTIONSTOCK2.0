<%@ WebHandler Language="C#" Class="GetClasse" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetClasse : IHttpHandler, IRequiresSessionState
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

            string classeId = ctx.Request.QueryString["id"];

            var list = new List<object>();

            using (var conn = new SqlConnection(connStr))
            {
                string sql = @"
                    SELECT 
                        c.ID,
                        c.NOM,
                        n.NOM AS NIVEAU,
                        c.EFFECTIF,
                        u.NOM AS TITULAIRE,
                        s.NUMERO AS SALLE,
                        c.STATUT,
                        c.NIVEAU_ID,
                        c.TITULAIRE_ID,
                        c.SALLE_ID
                    FROM [dbo].[CLASSES] c
                    LEFT JOIN [dbo].[NIVEAUX] n ON n.ID = c.NIVEAU_ID
                    LEFT JOIN [dbo].[USERS] u ON u.IDUSER = c.TITULAIRE_ID
                    LEFT JOIN [dbo].[SALLES] s ON s.ID = c.SALLE_ID
                ";

                if (!string.IsNullOrEmpty(classeId))
                {
                    sql += " WHERE c.ID = @id";
                }

                sql += " ORDER BY c.NOM";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    if (!string.IsNullOrEmpty(classeId))
                    {
                        cmd.Parameters.AddWithValue("@id", classeId);
                    }

                    conn.Open();
                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            list.Add(new
                            {
                                ID = reader.IsDBNull(0) ? "" : reader.GetInt32(0).ToString(),
                                NOM = reader.IsDBNull(1) ? "" : reader.GetString(1),
                                NIVEAU = reader.IsDBNull(2) ? "" : reader.GetString(2),
                                EFFECTIF = reader.IsDBNull(3) ? 0 : reader.GetInt32(3),
                                TITULAIRE = reader.IsDBNull(4) ? "" : reader.GetString(4),
                                SALLE = reader.IsDBNull(5) ? "" : reader.GetString(5),
                                STATUT = !reader.IsDBNull(6) && reader.GetBoolean(6),
                                NIVEAU_ID = reader.IsDBNull(7) ? "" : reader.GetGuid(7).ToString(),
                                TITULAIRE_ID = reader.IsDBNull(8) ? 0 : reader.GetInt32(8),
                                SALLE_ID = reader.IsDBNull(9) ? "" : reader.GetGuid(9).ToString()
                            });
                        }
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, Classes = list }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
        }
    }

    public bool IsReusable { get { return false; } }
}