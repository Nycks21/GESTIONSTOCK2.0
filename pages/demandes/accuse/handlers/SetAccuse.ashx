﻿﻿﻿<%@ WebHandler Language="C#" Class="SetAccuse" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SetAccuse : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        // ✅ 1. Méthode : uniquement POST
        if (!string.Equals(ctx.Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase))
        {
            ctx.Response.StatusCode = 405;
            WriteJson(ctx, false, "Méthode non autorisée");
            return;
        }

        // ✅ 2. Sécurité CRITIQUE : Session + Token CSRF + Origin/Referer
        //    Cette action clôture une sortie (statut VALIDE → TERMINE).
        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            WriteJson(ctx, false, "Accès non autorisé");
            return;
        }

        try
        {
            // ✅ Récupération de l'ID du bon
            string id = ctx.Request["id"];
            if (string.IsNullOrEmpty(id))
            {
                WriteJson(ctx, false, "Identifiant du bon manquant");
                return;
            }

            Guid bonId;
            if (!Guid.TryParse(id, out bonId))
            {
                WriteJson(ctx, false, "Identifiant invalide");
                return;
            }

            // ✅ Récupération de la date de réception (obligatoire)
            string dateReceptionStr = ctx.Request["dateReception"];
            if (string.IsNullOrEmpty(dateReceptionStr))
            {
                WriteJson(ctx, false, "La date de réception est obligatoire");
                return;
            }

            DateTime dateReception;
            if (!TryParseDateFlexible(dateReceptionStr.Trim(), out dateReception))
            {
                WriteJson(ctx, false, "Date de réception invalide (format attendu : jj/mm/aaaa)");
                return;
            }

            // ✅ Contrôle métier : la date ne peut pas être dans le futur
            if (dateReception.Date > DateTime.Now.Date)
            {
                WriteJson(ctx, false, "La date de réception ne peut pas être dans le futur");
                return;
            }

            int currentUserId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // ✅ 1) Vérifier que le bon existe et récupérer son statut actuel
                string statutActuel = null;
                using (var cmd = new SqlCommand(
                    "SELECT STATUT FROM SSORTIE WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmd.Parameters.AddWithValue("@id", bonId);
                    object result = cmd.ExecuteScalar();

                    if (result == null || result == DBNull.Value)
                    {
                        WriteJson(ctx, false, "Bon de sortie introuvable");
                        return;
                    }
                    statutActuel = result.ToString();
                }

                // ✅ 2) Vérifier la transition autorisée
                if (statutActuel == "TERMINE")
                {
                    WriteJson(ctx, false, "Ce bon a déjà été marqué comme terminé");
                    return;
                }
                if (statutActuel != "VALIDE")
                {
                    WriteJson(ctx, false,
                        "Seul un bon au statut VALIDE peut être marqué comme TERMINE (statut actuel : " + statutActuel + ")");
                    return;
                }

                // ✅ 3) Mise à jour du statut + date de réception (atomique)
                using (var cmd = new SqlCommand(
                    @"UPDATE SSORTIE
                      SET STATUT = 'TERMINE',
                          DATE_RECEPTION = @dateReception,
                          UPDATED_AT = GETDATE(),
                          UPDATED_BY = @updatedBy
                      WHERE ID = @id
                        AND DELETION_AT IS NULL
                        AND STATUT = 'VALIDE'", conn))
                {
                    cmd.Parameters.AddWithValue("@id", bonId);
                    cmd.Parameters.AddWithValue("@dateReception", dateReception.Date);
                    cmd.Parameters.AddWithValue("@updatedBy",
                        currentUserId == 0 ? (object)DBNull.Value : currentUserId);

                    int rows = cmd.ExecuteNonQuery();

                    if (rows == 0)
                    {
                        WriteJson(ctx, false, "Le bon a été modifié entre-temps. Veuillez rafraîchir.");
                        return;
                    }
                }

                WriteJson(ctx, true, "Réception confirmée le " + dateReception.ToString("dd/MM/yyyy"));
            }
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            WriteJson(ctx, false, "Erreur base de données : " + sqlEx.Message.Replace("\"", "\\\""));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            WriteJson(ctx, false, "Erreur système : " + ex.Message.Replace("\"", "\\\""));
        }
    }

    // Parse flexible : ISO yyyy-MM-dd + FR dd/MM/yyyy + variantes
    private static bool TryParseDateFlexible(string raw, out DateTime result)
    {
        result = DateTime.MinValue;
        if (string.IsNullOrWhiteSpace(raw)) return false;

        // 1) ISO
        if (DateTime.TryParseExact(raw, "yyyy-MM-dd",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out result)) return true;

        // 2) FR strict
        if (DateTime.TryParseExact(raw, "dd/MM/yyyy",
                System.Globalization.CultureInfo.GetCultureInfo("fr-FR"),
                System.Globalization.DateTimeStyles.None, out result)) return true;

        // 3) FR variantes
        string[] formatsFr = { "d/M/yyyy", "dd/MM/yyyy", "d-M-yyyy", "dd-MM-yyyy", "d.M.yyyy", "dd.MM.yyyy" };
        if (DateTime.TryParseExact(raw, formatsFr,
                System.Globalization.CultureInfo.GetCultureInfo("fr-FR"),
                System.Globalization.DateTimeStyles.None, out result)) return true;

        // 4) Invariant fallback
        return DateTime.TryParse(raw,
            System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.None, out result);
    }

    private void WriteJson(HttpContext ctx, bool success, string message)
    {
        var serializer = new JavaScriptSerializer();
        var payload = new System.Collections.Generic.Dictionary<string, object>
        {
            { "success", success },
            { "message", message }
        };
        ctx.Response.Write(serializer.Serialize(payload));
    }

    public bool IsReusable { get { return false; } }
}
