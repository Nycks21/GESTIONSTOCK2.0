<%@ WebHandler Language="C#" Class="GetEmploi" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEmploi : IHttpHandler, IRequiresSessionState
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

        string mode = ctx.Request.QueryString["mode"];
        string classeId = ctx.Request.QueryString["classe"];
        string professeurValue = ctx.Request.QueryString["professeur"];
        int userRole = AuthHelper.GetUserRole(ctx);
        int userId = AuthHelper.GetUserId(ctx);
        string userName = AuthHelper.GetUsername(ctx);

        string connStr = AuthHelper.ConnectionString;
        if (string.IsNullOrEmpty(connStr))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
            return;
        }

        try
        {
            string sql;
            SqlCommand cmd = new SqlCommand();

            if (!string.IsNullOrEmpty(mode) && mode == "specific_prof" && !string.IsNullOrWhiteSpace(professeurValue))
            {
                sql = @"
                    SELECT 
                        e.JOUR, 
                        e.HEURE_DEBUT, 
                        e.HEURE_FIN, 
                        e.MATIERE_ID, 
                        m.NOM AS MATIERE_NOM,
                        e.PROFESSEUR, 
                        e.SALLE, 
                        e.COULEUR, 
                        e.TYPE, 
                        e.URL, 
                        e.DESCRIPTION 
                    FROM EMPLOI_TEMPS e
                    LEFT JOIN MATIERES m ON e.MATIERE_ID = m.ID
                    WHERE e.PROFESSEUR = @professeurValue
                    ORDER BY e.JOUR, e.HEURE_DEBUT";
                cmd = new SqlCommand(sql);
                cmd.Parameters.AddWithValue("@professeurValue", professeurValue.Trim());
            }
            else if (!string.IsNullOrEmpty(mode) && (mode == "my_all" || mode == "my_in_class"))
            {
                if (userRole == 3 && !string.IsNullOrWhiteSpace(userName))
                {
                    sql = @"
                        SELECT 
                            e.JOUR, 
                            e.HEURE_DEBUT, 
                            e.HEURE_FIN, 
                            e.MATIERE_ID, 
                            m.NOM AS MATIERE_NOM,
                            e.PROFESSEUR, 
                            e.SALLE, 
                            e.COULEUR, 
                            e.TYPE, 
                            e.URL, 
                            e.DESCRIPTION 
                        FROM EMPLOI_TEMPS e
                        LEFT JOIN MATIERES m ON e.MATIERE_ID = m.ID
                        WHERE e.PROFESSEUR = @userName";

                    if (!string.IsNullOrEmpty(classeId))
                    {
                        sql += " AND e.CLASSE_ID = @classeId";
                    }

                    sql += " ORDER BY e.JOUR, e.HEURE_DEBUT";

                    cmd = new SqlCommand(sql);
                    cmd.Parameters.AddWithValue("@userName", userName.Trim());
                    if (!string.IsNullOrEmpty(classeId))
                    {
                        cmd.Parameters.AddWithValue("@classeId", classeId);
                    }
                }
                else
                {
                    ctx.Response.Write("{\"success\":false,\"message\":\"Ce mode n’est pas disponible pour cet utilisateur\"}");
                    return;
                }
            }
            else if (!string.IsNullOrEmpty(classeId))
            {
                sql = @"
                    SELECT 
                        e.JOUR, 
                        e.HEURE_DEBUT, 
                        e.HEURE_FIN, 
                        e.MATIERE_ID, 
                        m.NOM AS MATIERE_NOM,
                        e.PROFESSEUR, 
                        e.SALLE, 
                        e.COULEUR, 
                        e.TYPE, 
                        e.URL, 
                        e.DESCRIPTION 
                    FROM EMPLOI_TEMPS e
                    LEFT JOIN MATIERES m ON e.MATIERE_ID = m.ID
                    WHERE e.CLASSE_ID = @classeId
                    ORDER BY e.JOUR, e.HEURE_DEBUT";
                cmd = new SqlCommand(sql);
                cmd.Parameters.AddWithValue("@classeId", classeId);
            }
            else
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Paramètre classe ou professeur manquant\"}");
                return;
            }

            var dict = new Dictionary<string, object>();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                cmd.Connection = conn;

                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        string heureDebut = rdr["HEURE_DEBUT"].ToString();
                        string key = rdr["JOUR"] + "_" + heureDebut;

                        string matiereId = rdr["MATIERE_ID"] != DBNull.Value ? rdr["MATIERE_ID"].ToString() : "";
                        string matiereNom = rdr["MATIERE_NOM"] != DBNull.Value ? rdr["MATIERE_NOM"].ToString() : matiereId;
                        string prof = rdr["PROFESSEUR"] != DBNull.Value ? rdr["PROFESSEUR"].ToString() : "";
                        string salle = rdr["SALLE"] != DBNull.Value ? rdr["SALLE"].ToString() : "";
                        string heureFin = rdr["HEURE_FIN"] != DBNull.Value ? rdr["HEURE_FIN"].ToString() : heureDebut;
                        string couleur = rdr["COULEUR"] != DBNull.Value ? rdr["COULEUR"].ToString() : "#007bff";
                        string type = rdr["TYPE"] != DBNull.Value ? rdr["TYPE"].ToString() : "cours";
                        string url = rdr["URL"] != DBNull.Value ? rdr["URL"].ToString() : "";
                        string description = rdr["DESCRIPTION"] != DBNull.Value ? rdr["DESCRIPTION"].ToString() : "";

                        dict[key] = new
                        {
                            matiere = matiereId,
                            matiere_nom = matiereNom,
                            prof,
                            salle,
                            heureFin,
                            couleur,
                            type,
                            url,
                            description
                        };
                    }
                }
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = true, data = dict }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}