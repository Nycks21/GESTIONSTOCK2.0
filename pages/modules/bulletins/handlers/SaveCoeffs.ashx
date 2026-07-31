<%@ WebHandler Language="C#" Class="SaveCoeffs" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SaveCoeffs : IHttpHandler, IRequiresSessionState
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

            if (data == null || !data.ContainsKey("matiereId") || !data.ContainsKey("classeId") || !data.ContainsKey("periode"))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Paramètres manquants (matiereId, classeId, periode)\"}");
                return;
            }

            string matiereId = GetString(data, "matiereId");
            string classeIdStr = GetString(data, "classeId");
            string periode = GetString(data, "periode");

            decimal coeff1 = GetDecimal(data, "coeff1") ?? 1;
            decimal coeff2 = GetDecimal(data, "coeff2") ?? 2;
            decimal coeffProjet = GetDecimal(data, "coeffProjet") ?? 1;

            if (string.IsNullOrEmpty(matiereId) || string.IsNullOrEmpty(classeIdStr) || string.IsNullOrEmpty(periode))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Paramètres manquants\"}");
                return;
            }

            int classeId;
            if (!int.TryParse(classeIdStr, out classeId) || classeId <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"classeId invalide\"}");
                return;
            }

            Guid matiereGuid;
            if (!Guid.TryParse(matiereId, out matiereGuid))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"matiereId invalide (format GUID attendu)\"}");
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string sql = @"
                    IF EXISTS (SELECT 1 FROM BULLETINS_COEFFS 
                               WHERE MATIERE_ID = @matiereId AND CLASSE_ID = @classeId AND PERIODE = @periode)
                    BEGIN
                        UPDATE BULLETINS_COEFFS 
                        SET COEFF1 = @coeff1,
                            COEFF2 = @coeff2,
                            COEFF_PROJET = @coeffProjet,
                            UPDATED_AT = GETDATE()
                        WHERE MATIERE_ID = @matiereId AND CLASSE_ID = @classeId AND PERIODE = @periode
                    END
                    ELSE
                    BEGIN
                        INSERT INTO BULLETINS_COEFFS (ID, MATIERE_ID, CLASSE_ID, PERIODE, COEFF1, COEFF2, COEFF_PROJET, CREATED_AT, UPDATED_AT)
                        VALUES (NEWID(), @matiereId, @classeId, @periode, @coeff1, @coeff2, @coeffProjet, GETDATE(), GETDATE())
                    END";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@matiereId", matiereGuid);
                    cmd.Parameters.AddWithValue("@classeId", classeId);
                    cmd.Parameters.AddWithValue("@periode", periode);
                    cmd.Parameters.AddWithValue("@coeff1", coeff1);
                    cmd.Parameters.AddWithValue("@coeff2", coeff2);
                    cmd.Parameters.AddWithValue("@coeffProjet", coeffProjet);
                    cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Coefficients sauvegardés\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    private string GetString(Dictionary<string, object> dict, string key)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
            return dict[key].ToString();
        return "";
    }

    private decimal? GetDecimal(Dictionary<string, object> dict, string key)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
        {
            decimal val;
            if (decimal.TryParse(dict[key].ToString(), out val))
                return val;
        }
        return null;
    }

    public bool IsReusable { get { return false; } }
}