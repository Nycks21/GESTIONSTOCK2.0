<%@ WebHandler Language="C#" Class="JustifierAbsence" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class JustifierAbsence : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            var ser = new JavaScriptSerializer();
            var data = ser.Deserialize<Dictionary<string, object>>(body);

            if (data == null || !data.ContainsKey("id") || data["id"] == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant\"}");
                return;
            }

            Guid absenceId;
            if (!Guid.TryParse(data["id"].ToString(), out absenceId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide\"}");
                return;
            }

            string justification = data.ContainsKey("justification") ? data["justification"].ToString() : "";
            if (string.IsNullOrEmpty(justification))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"La justification est requise\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand(@"
                UPDATE ABSENCES 
                SET JUSTIFIE = 1, 
                    JUSTIFICATION = @justification,
                    MOTIF = @justification,
                    UPDATED_AT = GETDATE() 
                WHERE ID = @id", conn))
            {
                cmd.Parameters.AddWithValue("@id", absenceId);
                cmd.Parameters.AddWithValue("@justification", justification);
                conn.Open();
                cmd.ExecuteNonQuery();
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Absence justifiée avec succès\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}