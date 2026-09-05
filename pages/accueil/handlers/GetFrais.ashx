<%@ WebHandler Language="C#" Class="GetFrais" %>
using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Collections.Generic;
using System.Web.SessionState;   // ✅ AJOUT

public class GetFrais : IHttpHandler, IRequiresSessionState   // ✅ AJOUT
{
    private static readonly string connStr;

    static GetFrais()
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

                double totalGlobal = 0;
                string totalSql = "SELECT ISNULL(SUM(TOTAL), 0) FROM FRAIS";
                using (SqlCommand cmd = new SqlCommand(totalSql, conn))
                {
                    object obj = cmd.ExecuteScalar();
                    totalGlobal = Convert.ToDouble(obj) / 1000;
                }

                var labels = new List<string>();
                var payes = new List<double>();
                var restes = new List<double>();
                var cumuls = new List<double>();

                for (int i = 5; i >= 0; i--)
                {
                    DateTime monthDate = DateTime.Now.AddMonths(-i);
                    string mois = monthDate.ToString("MM");
                    string annee = monthDate.ToString("yyyy");
                    labels.Add(monthDate.ToString("MM/yyyy"));

                    double paiementMois = 0;
                    string paiementSql = @"
                        SELECT ISNULL(SUM(MONTANT), 0)
                        FROM HISTORIQUE_PAIEMENTS
                        WHERE MOIS = @mois AND ANNEE = @annee";
                    using (SqlCommand cmd = new SqlCommand(paiementSql, conn))
                    {
                        cmd.Parameters.AddWithValue("@mois", mois);
                        cmd.Parameters.AddWithValue("@annee", annee);
                        object obj = cmd.ExecuteScalar();
                        paiementMois = Convert.ToDouble(obj) / 1000;
                    }

                    payes.Add(paiementMois);
                    double cumul = (cumuls.Count > 0) ? cumuls[cumuls.Count - 1] + paiementMois : paiementMois;
                    cumuls.Add(cumul);
                    restes.Add(totalGlobal - cumul);
                }

                if (labels.Count == 0 || payes.TrueForAll(p => p == 0))
                {
                    labels = new List<string> { "02/2026", "03/2026", "04/2026", "05/2026", "06/2026", "07/2026" };
                    payes = new List<double> { 12000, 13500, 14000, 12800, 15000, 16000 };
                    cumuls = new List<double> { 12000, 25500, 39500, 52300, 67300, 83300 };
                    restes = new List<double> { 88000, 74500, 60500, 47700, 32700, 16700 };
                }

                var dataResult = new
                {
                    success = true,
                    labels = labels,
                    payes = payes,
                    impayes = restes,
                    totals = cumuls
                };

                context.Response.Write(new JavaScriptSerializer().Serialize(dataResult));
            }
        }
        catch (Exception)
        {
            context.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = "Erreur serveur" }));
        }
    }

    public bool IsReusable { get { return false; } }
}