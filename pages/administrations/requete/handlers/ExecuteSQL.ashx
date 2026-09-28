﻿<%@ WebHandler Language="C#" Class="ExecuteSQL" %>

using System;
using System.Web;
using System.Data;
using System.Data.SqlClient;
using System.Configuration;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ExecuteSQL : IHttpHandler, IRequiresSessionState
{
    // ✅ Liste blanche STRICTE des requêtes autorisées.
    //    Comparaison insensible à la casse + espaces normalisés.
    //    ⚠️ Adapter cette liste à VOS besoins métier réels (GESTION STOCK).
    private static readonly HashSet<string> AllowedQueries = new HashSet<string>(
        new string[]
        {
            // ── Exemples à adapter ──────────────────────────────────
            "SELECT USERNAME, NOM, EMAIL FROM USERS",
            "SELECT COUNT(*) FROM USERS",
            "SELECT ID, CODE, NOM FROM SCATEGORIE WHERE DELETION_AT IS NULL",
            "SELECT ID, CODE, NOM FROM SUNITE WHERE DELETION_AT IS NULL",
            "SELECT ID, CODE, NOM FROM SFOURNISSEUR WHERE DELETION_AT IS NULL",
            "SELECT ID, CODE, NOM FROM SEMPLACEMENT WHERE DELETION_AT IS NULL",
            "SELECT ID, CODE, NOM FROM MARTICLE WHERE DELETION_AT IS NULL",
            // ── Ajouter d'autres requêtes autorisées ici ───────────
        },
        StringComparer.OrdinalIgnoreCase);

    public void ProcessRequest(HttpContext context)
    {
        // ✅ Sécurité renforcée : Session + Token session + Rôle SuperAdmin + CSRF + Origin/Referer
        if (!AuthHelper.RequireCsrfSafePost(context, 0))
        {
            context.Response.ContentType = "application/json";
            context.Response.StatusCode = 403;
            SendResponse(context, false, "Accès non autorisé.");
            return;
        }

        // ✅ POST uniquement
        if (!string.Equals(context.Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase))
        {
            context.Response.StatusCode = 405;
            SendResponse(context, false, "Méthode non autorisée.");
            return;
        }

        context.Response.ContentType = "application/json";
        context.Response.Headers["Cache-Control"] = "no-cache";

        string sqlQuery = context.Request.Form["query"];

        if (string.IsNullOrWhiteSpace(sqlQuery))
        {
            SendResponse(context, false, "La requête SQL est vide.");
            return;
        }

        // ✅ Normalisation : trim + espaces multiples → 1 espace
        //    Permet une comparaison fiable avec la liste blanche.
        string normalized = Regex.Replace(sqlQuery.Trim(), @"\s+", " ");

        // ═══════════════════════════════════════════════════════════
        // ✅ CONTRÔLE CRITIQUE : vérification contre la liste blanche
        // ═══════════════════════════════════════════════════════════
        if (!AllowedQueries.Contains(normalized))
        {
            LogSecurityViolation(context, sqlQuery);
            SendResponse(context, false,
                "Requête non autorisée. Seules les requêtes de la liste blanche sont permises.");
            return;
        }

        string connStr = ConfigurationManager.ConnectionStrings["MaConnexion"].ConnectionString;

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            try
            {
                SqlCommand cmd = new SqlCommand(normalized, conn);
                conn.Open();

                SqlDataAdapter da = new SqlDataAdapter(cmd);
                DataTable dt = new DataTable();
                da.Fill(dt);

                var rows = new List<Dictionary<string, object>>();
                foreach (DataRow dr in dt.Rows)
                {
                    var row = new Dictionary<string, object>();
                    foreach (DataColumn col in dt.Columns)
                    {
                        object val = dr[col];
                        if (val == DBNull.Value) val = null;
                        row.Add(col.ColumnName, val);
                    }
                    rows.Add(row);
                }

                var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
                context.Response.Write(serializer.Serialize(new
                {
                    success = true,
                    type = "SELECT",
                    data = rows
                }));
            }
            catch (SqlException ex)
            {
                LogError(context, ex);
                SendResponse(context, false, "Erreur de base de données. Contactez l'administrateur.");
            }
            catch (Exception ex)
            {
                LogError(context, ex);
                SendResponse(context, false, "Erreur système. Contactez l'administrateur.");
            }
        }
    }

    private void SendResponse(HttpContext context, bool success, string message)
    {
        var serializer = new JavaScriptSerializer();
        context.Response.Write(serializer.Serialize(new
        {
            success = success,
            message = message
        }));
    }

    // Log des erreurs SQL/système
    private void LogError(HttpContext context, Exception ex)
    {
        try
        {
            string logFile = context.Server.MapPath("~/App_Data/security.log");
            string entry = "[" + DateTime.Now.ToString() + "] SQL Error: " + ex.Message + "\n" +
                           "IP: " + context.Request.UserHostAddress + "\n" +
                           "---\n";
            System.IO.File.AppendAllText(logFile, entry);
        }
        catch { /* Ne pas échouer si le log échoue */ }
    }

    // Log spécifique aux tentatives de requêtes non autorisées
    private void LogSecurityViolation(HttpContext context, string attemptedQuery)
    {
        try
        {
            string logFile = context.Server.MapPath("~/App_Data/security.log");
            string entry = "[" + DateTime.Now.ToString() + "] ⚠️ SQL WHITELIST VIOLATION\n" +
                           "IP: " + context.Request.UserHostAddress + "\n" +
                           "Query: " + (attemptedQuery ?? "").Substring(0, Math.Min(500, (attemptedQuery ?? "").Length)) + "\n" +
                           "---\n";
            System.IO.File.AppendAllText(logFile, entry);
        }
        catch { }
    }

    public bool IsReusable { get { return false; } }
}
