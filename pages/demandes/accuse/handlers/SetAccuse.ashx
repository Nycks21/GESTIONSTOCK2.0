﻿<%@ WebHandler Language="C#" Class="SetAccuse" %>
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

        // ✅ Authentification : tous les rôles authentifiés (0 à 4)
        if (!AuthHelper.RequireApiAuth(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            WriteJson(ctx, false, "Accès non autorisé");
            return;
        }

        // ✅ Méthode : uniquement POST
        if (!string.Equals(ctx.Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase))
        {
            ctx.Response.StatusCode = 405;
            WriteJson(ctx, false, "Méthode non autorisée");
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
            if (!DateTime.TryParse(dateReceptionStr, out dateReception))
            {
                WriteJson(ctx, false, "Date de réception invalide");
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

                // ✅ 3) Mise à jour du statut + date de réception
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
                    cmd.Parameters.AddWithValue("@dateReception", dateReception);
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
