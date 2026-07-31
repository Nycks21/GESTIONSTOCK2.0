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

        // ✅ Sécurité centralisée (Admin ou SuperAdmin)
        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        string classeId = ctx.Request.QueryString["classe"];
        if (string.IsNullOrEmpty(classeId))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Paramètre classe manquant\"}");
            return;
        }

        string connStr = AuthHelper.ConnectionString;
        if (string.IsNullOrEmpty(connStr))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
            return;
        }

        var list = new List<object>();

        try
        {
            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                int userRole = AuthHelper.GetUserRole(ctx);
                bool isProfessor = userRole == 3;
                string sql = @"
                    SELECT 
                        m.ID, 
                        m.NOM, 
                        m.ENSEIGNANT, 
                        u.NOM AS ENSEIGNANT_NOM
                    FROM MATIERES m
                    LEFT JOIN USERS u ON m.ENSEIGNANT = u.IDUSER
                    WHERE m.CLASSE_ID = @classe";

                if (isProfessor)
                {
                    sql += " AND m.ENSEIGNANT = @professeurId";
                }

                sql += " ORDER BY m.NOM";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@classe", classeId);
                    if (isProfessor)
                    {
                        cmd.Parameters.AddWithValue("@professeurId", AuthHelper.GetUserId(ctx));
                    }
                    using (var rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            list.Add(new
                            {
                                ID = rdr["ID"].ToString(),
                                NOM = rdr["NOM"].ToString(),
                                ENSEIGNANT_ID = rdr["ENSEIGNANT"] != DBNull.Value ? rdr["ENSEIGNANT"].ToString() : "",
                                ENSEIGNANT_NOM = rdr["ENSEIGNANT_NOM"] != DBNull.Value ? rdr["ENSEIGNANT_NOM"].ToString() : ""
                            });
                        }
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, data = list }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}