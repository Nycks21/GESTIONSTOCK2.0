<%@ WebHandler Language="C#" Class="GetBulletins" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetBulletins : IHttpHandler, IRequiresSessionState
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

        var ser = new JavaScriptSerializer();

        try
        {
            string body;
            using (var reader = new StreamReader(ctx.Request.InputStream))
                body = reader.ReadToEnd();

            if (string.IsNullOrEmpty(body))
            {
                ctx.Response.StatusCode = 400;
                ctx.Response.Write("{\"success\":false,\"message\":\"Corps de requête vide\"}");
                return;
            }

            var data = ser.Deserialize<Dictionary<string, object>>(body);
            if (data == null)
            {
                ctx.Response.StatusCode = 400;
                ctx.Response.Write("{\"success\":false,\"message\":\"Données JSON invalides\"}");
                return;
            }

            // Récupérer les paramètres
            int classeId = GetInt(data, "classeId");
            string matiereId = GetString(data, "matiereId");
            string periode = GetString(data, "periodeId");

            if (classeId <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"classeId invalide\"}");
                return;
            }
            if (string.IsNullOrEmpty(matiereId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"matiereId manquant\"}");
                return;
            }
            if (string.IsNullOrEmpty(periode))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"periodeId manquant\"}");
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
                ctx.Response.StatusCode = 500;
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            var eleves = new List<Dictionary<string, object>>();
            Dictionary<string, object> coefficients = null;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // 1. Récupérer les coefficients
                string coeffSql = @"
                    SELECT COEFF1, COEFF2, COEFF_PROJET
                    FROM BULLETINS_COEFFS
                    WHERE MATIERE_ID = @matiereId 
                      AND CLASSE_ID = @classeId 
                      AND PERIODE = @periode";

                using (var cmd = new SqlCommand(coeffSql, conn))
                {
                    cmd.Parameters.AddWithValue("@classeId", classeId);
                    cmd.Parameters.AddWithValue("@matiereId", matiereGuid);
                    cmd.Parameters.AddWithValue("@periode", periode);

                    using (var rdr = cmd.ExecuteReader())
                    {
                        if (rdr.Read())
                        {
                            coefficients = new Dictionary<string, object>();
                            coefficients["coeff1"] = Convert.ToDecimal(rdr["COEFF1"]);
                            coefficients["coeff2"] = Convert.ToDecimal(rdr["COEFF2"]);
                            coefficients["coeffProjet"] = Convert.ToDecimal(rdr["COEFF_PROJET"]);
                        }
                    }
                }

                // 2. Récupérer les élèves avec leurs notes
                string sql = @"
                    SELECT
                        e.MATRICULE,
                        e.NOM,
                        b.ID,
                        b.NOTE1,
                        b.NOTE2,
                        b.NOTE_PROJET,
                        b.TOTAL_NOTE,
                        b.APPRECIATION,
                        b.STATUT
                    FROM ELEVES e
                    LEFT JOIN BULLETINS b
                        ON b.ELEVE_MATRICULE = e.MATRICULE
                       AND b.MATIERE_ID = @matiereId
                       AND b.PERIODE = @periode
                    WHERE e.CLASSE = @classeId
                      AND e.STATUT = 'actif'
                    ORDER BY e.NOM ASC";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@classeId", classeId);
                    cmd.Parameters.AddWithValue("@matiereId", matiereGuid);
                    cmd.Parameters.AddWithValue("@periode", periode);

                    using (var rdr = cmd.ExecuteReader())
                    {
                        while (rdr.Read())
                        {
                            var eleve = new Dictionary<string, object>();
                            eleve["EleveId"] = rdr["MATRICULE"].ToString();
                            eleve["Nom"] = rdr["NOM"].ToString();
                            eleve["BulletinId"] = rdr["ID"] is DBNull ? null : rdr["ID"].ToString();
                            eleve["Note1"] = rdr["NOTE1"] is DBNull ? null : (object)Convert.ToDecimal(rdr["NOTE1"]);
                            eleve["Note2"] = rdr["NOTE2"] is DBNull ? null : (object)Convert.ToDecimal(rdr["NOTE2"]);
                            eleve["NoteProjet"] = rdr["NOTE_PROJET"] is DBNull ? null : (object)Convert.ToDecimal(rdr["NOTE_PROJET"]);
                            eleve["TotalNote"] = rdr["TOTAL_NOTE"] is DBNull ? null : (object)Convert.ToDecimal(rdr["TOTAL_NOTE"]);
                            eleve["Appreciation"] = rdr["APPRECIATION"] is DBNull ? "" : rdr["APPRECIATION"].ToString();
                            eleve["Statut"] = rdr["STATUT"] is DBNull ? "Non saisi" : rdr["STATUT"].ToString();
                            eleves.Add(eleve);
                        }
                    }
                }
            }

            if (coefficients == null)
            {
                coefficients = new Dictionary<string, object>();
                coefficients["coeff1"] = 1.0m;
                coefficients["coeff2"] = 2.0m;
                coefficients["coeffProjet"] = 1.0m;
            }

            var result = new Dictionary<string, object>();
            result["success"] = true;
            result["eleves"] = eleves;
            result["coefficients"] = coefficients;

            ctx.Response.Write(ser.Serialize(result));
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

    private int GetInt(Dictionary<string, object> dict, string key)
    {
        if (dict.ContainsKey(key) && dict[key] != null)
        {
            int val;
            if (int.TryParse(dict[key].ToString(), out val))
                return val;
        }
        return 0;
    }

    public bool IsReusable { get { return false; } }
}