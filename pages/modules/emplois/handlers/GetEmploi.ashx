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

        string mode = ctx.Request.QueryString["mode"] ?? "class_all";
        string classeId = ctx.Request.QueryString["classe"];
        string requestedProfId = ctx.Request.QueryString["professeur"];

        var dict = new Dictionary<string, object>();
        string connStr = AuthHelper.ConnectionString;

        if (string.IsNullOrEmpty(connStr))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
            return;
        }

        try
        {
            int userRole = AuthHelper.GetUserRole(ctx);
            bool isProfessor = userRole == 3;
            int currentUserId = AuthHelper.GetUserId(ctx);
            int selectedProfId;
            int.TryParse(requestedProfId, out selectedProfId);
            if (!string.IsNullOrEmpty(mode))
            {
                mode = mode.ToLowerInvariant();
            }
            else
            {
                mode = "class_all";
            }

            if (!isProfessor)
            {
                if (mode == "my_in_class" || mode == "my_all")
                {
                    mode = "class_all";
                }
            }

            if ((mode == "my_in_class" || mode == "class_all") && string.IsNullOrEmpty(classeId))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Paramètre classe manquant\"}");
                return;
            }

            if (mode == "specific_prof" && selectedProfId <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Paramètre professeur manquant\"}");
                return;
            }

            using (var conn = new SqlConnection(connStr))
            using (var cmd = new SqlCommand())
            {
                cmd.Connection = conn;
                cmd.CommandText = @"SELECT 
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
                  WHERE 1=1";

                if (!string.IsNullOrEmpty(classeId))
                {
                    cmd.CommandText += " AND e.CLASSE_ID = @classeId";
                    cmd.Parameters.AddWithValue("@classeId", classeId);
                }

                if (mode == "my_in_class" || mode == "my_all")
                {
                    cmd.CommandText += " AND e.PROFESSEUR = @professeurId";
                    cmd.Parameters.AddWithValue("@professeurId", currentUserId);
                }
                else if (mode == "specific_prof")
                {
                    cmd.CommandText += " AND e.PROFESSEUR = @professeurId";
                    cmd.Parameters.AddWithValue("@professeurId", selectedProfId);
                }
                else if (isProfessor && mode == "class_all")
                {
                    cmd.CommandText += " AND EXISTS(SELECT 1 FROM MATIERES mt WHERE mt.CLASSE_ID = e.CLASSE_ID AND mt.ENSEIGNANT = @professeurId)";
                    cmd.Parameters.AddWithValue("@professeurId", currentUserId);
                }

                cmd.CommandText += " ORDER BY e.JOUR, e.HEURE_DEBUT";

                conn.Open();
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        string heureDebut = rdr["HEURE_DEBUT"].ToString();
                        string key = rdr["JOUR"] + "_" + heureDebut;

                        string matiereId = rdr["MATIERE_ID"].ToString();
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