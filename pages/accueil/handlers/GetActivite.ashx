<%@ WebHandler Language="C#" Class="GetActivite" %>
using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Collections.Generic;
using System.Web.SessionState;   // ✅ AJOUT

public class GetActivite : IHttpHandler, IRequiresSessionState   // ✅ AJOUT
{
    private static readonly string connStr;

    static GetActivite()
    {
        var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
        connStr = (connSetting != null) ? connSetting.ConnectionString : "";
    }

    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";

        if (!AuthHelper.IsAuthenticated(context))
        {
            context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
            return;
        }

        // ✅ Même vérification de rôle que les autres handlers du dashboard
        int role = AuthHelper.GetUserRole(context);
        if (role != 0 && role != 1)
        {
            context.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
            return;
        }

        try
        {
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                var data = new List<object>();

                // Dernières absences
                string sqlAbsences = @"
                    SELECT TOP 3
                        'Nouvelle absence' AS TEXTE,
                        ISNULL(e.NOM, 'Un élève') AS DETAIL,
                        FORMAT(a.CREATED_AT, 'HH:mm') AS TEMPS,
                        'danger' AS TYPE
                    FROM ABSENCES a
                    LEFT JOIN ELEVES e ON a.MATRICULE = e.MATRICULE
                    WHERE a.CREATED_AT >= DATEADD(day, -7, GETDATE())
                    ORDER BY a.CREATED_AT DESC";

                using (SqlCommand cmd = new SqlCommand(sqlAbsences, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        string texte = reader["TEXTE"].ToString();
                        string detail = reader["DETAIL"] != DBNull.Value ? reader["DETAIL"].ToString() : "Un élève";
                        string temps = reader["TEMPS"].ToString();
                        string type = reader["TYPE"].ToString();
                        data.Add(new { texte = texte, detail = detail, temps = temps, type = type });
                    }
                }

                // Derniers paiements
                string sqlPaiements = @"
                    SELECT TOP 2
                        'Paiement enregistré' AS TEXTE,
                        ISNULL(e.NOM, 'Un élève') AS DETAIL,
                        FORMAT(f.CREATED_AT, 'HH:mm') AS TEMPS,
                        'success' AS TYPE
                    FROM FRAIS f
                    LEFT JOIN ELEVES e ON f.MATRICULE = e.MATRICULE
                    WHERE f.CREATED_AT >= DATEADD(day, -7, GETDATE())
                    ORDER BY f.CREATED_AT DESC";

                using (SqlCommand cmd = new SqlCommand(sqlPaiements, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        string texte = reader["TEXTE"].ToString();
                        string detail = reader["DETAIL"] != DBNull.Value ? reader["DETAIL"].ToString() : "Un élève";
                        string temps = reader["TEMPS"].ToString();
                        string type = reader["TYPE"].ToString();
                        data.Add(new { texte = texte, detail = detail, temps = temps, type = type });
                    }
                }

                // Derniers bulletins
                string sqlBulletins = @"
                    SELECT TOP 2
                        'Bulletin ajouté' AS TEXTE,
                        ISNULL(e.NOM, 'Un élève') AS DETAIL,
                        FORMAT(b.CREATED_AT, 'HH:mm') AS TEMPS,
                        'info' AS TYPE
                    FROM BULLETINS b
                    LEFT JOIN ELEVES e ON b.MATRICULE = e.MATRICULE
                    WHERE b.CREATED_AT >= DATEADD(day, -7, GETDATE())
                    ORDER BY b.CREATED_AT DESC";

                using (SqlCommand cmd = new SqlCommand(sqlBulletins, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        string texte = reader["TEXTE"].ToString();
                        string detail = reader["DETAIL"] != DBNull.Value ? reader["DETAIL"].ToString() : "Un élève";
                        string temps = reader["TEMPS"].ToString();
                        string type = reader["TYPE"].ToString();
                        data.Add(new { texte = texte, detail = detail, temps = temps, type = type });
                    }
                }

                if (data.Count == 0)
                {
                    data.Add(new { texte = "Bienvenue", detail = "Tableau de bord chargé", temps = "maintenant", type = "info" });
                }

                var result = new { success = true, data = data };
                context.Response.Write(new JavaScriptSerializer().Serialize(result));
            }
        }
        catch (Exception)
        {
            var data = new List<object>();
            data.Add(new { texte = "Bienvenue", detail = "Tableau de bord chargé", temps = "maintenant", type = "info" });
            var result = new { success = true, data = data };
            context.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
    }

    public bool IsReusable { get { return false; } }
}