<%@ WebHandler Language="C#" Class="GetReussite" %>
using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Collections.Generic;
using System.Web.SessionState;   // ✅ AJOUT

public class GetReussite : IHttpHandler, IRequiresSessionState   // ✅ AJOUT
{
    private static readonly string connStr;

    static GetReussite()
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

                string sql = @"
                    WITH Coeffs AS (
                        SELECT 
                            MATIERE_ID, 
                            CLASSE_ID, 
                            PERIODE,
                            ISNULL(COEFF1, 1) AS COEFF1,
                            ISNULL(COEFF2, 1) AS COEFF2,
                            ISNULL(COEFF_PROJET, 1) AS COEFF_PROJET
                        FROM BULLETINS_COEFFS
                    )
                    SELECT 
                        ISNULL(c.NOM, 'Non définie') AS CLASSE,
                        COUNT(b.ID) AS TOTAL,
                        SUM(CASE 
                            WHEN (ISNULL(b.NOTE1, 0) * ISNULL(co.COEFF1, 1) 
                                + ISNULL(b.NOTE2, 0) * ISNULL(co.COEFF2, 1) 
                                + ISNULL(b.NOTE_PROJET, 0) * ISNULL(co.COEFF_PROJET, 1)) 
                                / (ISNULL(co.COEFF1, 1) + ISNULL(co.COEFF2, 1) + ISNULL(co.COEFF_PROJET, 1)) >= 10 
                            THEN 1 ELSE 0 END) AS REUSSIS,
                        CASE 
                            WHEN COUNT(b.ID) > 0 THEN 
                                ROUND(CAST(SUM(CASE 
                                    WHEN (ISNULL(b.NOTE1, 0) * ISNULL(co.COEFF1, 1) 
                                        + ISNULL(b.NOTE2, 0) * ISNULL(co.COEFF2, 1) 
                                        + ISNULL(b.NOTE_PROJET, 0) * ISNULL(co.COEFF_PROJET, 1)) 
                                        / (ISNULL(co.COEFF1, 1) + ISNULL(co.COEFF2, 1) + ISNULL(co.COEFF_PROJET, 1)) >= 10 
                                    THEN 1 ELSE 0 END) AS FLOAT) / COUNT(b.ID) * 100, 1)
                            ELSE 0 
                        END AS TAUX
                    FROM BULLETINS b
                    INNER JOIN ELEVES e ON b.ELEVE_MATRICULE = e.MATRICULE
                    LEFT JOIN CLASSES c ON e.CLASSE = c.ID
                    LEFT JOIN Coeffs co ON b.MATIERE_ID = co.MATIERE_ID 
                                       AND c.ID = co.CLASSE_ID 
                                       AND b.PERIODE = co.PERIODE
                    WHERE b.STATUT IN ('Enregistré', 'Validé')
                    GROUP BY c.NOM
                    ORDER BY TAUX DESC";

                using (SqlCommand cmd = new SqlCommand(sql, conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        string classe = reader["CLASSE"] != DBNull.Value ? reader["CLASSE"].ToString() : "Non définie";
                        int total = Convert.ToInt32(reader["TOTAL"]);
                        int reussis = Convert.ToInt32(reader["REUSSIS"]);
                        double taux = reader["TAUX"] != DBNull.Value ? Math.Round(Convert.ToDouble(reader["TAUX"]), 1) : 0;

                        data.Add(new
                        {
                            classe = classe,
                            total = total,
                            reussis = reussis,
                            taux = taux
                        });
                    }
                }

                var result = new { success = true, data = data };
                context.Response.Write(new JavaScriptSerializer().Serialize(result));
            }
        }
        catch (Exception)
        {
            var result = new { success = false, message = "Erreur serveur", data = new List<object>() };
            context.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
    }

    public bool IsReusable { get { return false; } }
}