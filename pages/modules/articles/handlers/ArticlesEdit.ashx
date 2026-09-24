﻿<%@ WebHandler Language="C#" Class="ArticlesEdit" %>
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ArticlesEdit : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Cache.SetNoStore();

        // ✅ Sécurité renforcée : Session + Token CSRF + Origin/Referer
        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            WriteJson(ctx, new {
                success = false,
                messageKey = "articles.server.unauthorized",
                message = "Accès non autorisé"
            });
            return;
        }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            string id = GetString(data, "id");
            if (string.IsNullOrEmpty(id))
            {
                WriteJson(ctx, new {
                    success = false,
                    messageKey = "articles.server.id_missing",
                    message = "ID manquant."
                });
                return;
            }

            string nom = GetString(data, "nom");
            string description = GetString(data, "description") ?? "";
            string categorieId = GetString(data, "categorieId");
            string fournisseurId = GetString(data, "fournisseurId");
            string uniteId = GetString(data, "uniteId");
            string emplacementId = GetString(data, "emplacementId");
            bool actif = GetBool(data, "actif", true);
            bool estService = GetBool(data, "estService", false);
            bool estPerissable = GetBool(data, "estPerissable", false);
            string datePeremptionStr = GetString(data, "datePeremption");

            var missing = new List<string>();
            if (string.IsNullOrWhiteSpace(nom))             missing.Add("NOM");
            if (string.IsNullOrWhiteSpace(categorieId))     missing.Add("CATÉGORIE");
            if (string.IsNullOrWhiteSpace(fournisseurId))   missing.Add("FOURNISSEUR");
            if (string.IsNullOrWhiteSpace(uniteId))         missing.Add("UNITÉ DE MESURE");
            if (string.IsNullOrWhiteSpace(emplacementId))   missing.Add("EMPLACEMENT PAR DÉFAUT");

            bool hasSeuil = data.ContainsKey("seuilAlerte")
                            && data["seuilAlerte"] != null
                            && !string.IsNullOrWhiteSpace(data["seuilAlerte"].ToString());
            decimal seuilAlerte = 0m;
            bool seuilNumeric = false;
            if (hasSeuil)
            {
                string seuilStr = data["seuilAlerte"].ToString().Trim();
                seuilNumeric =
                    decimal.TryParse(seuilStr, System.Globalization.NumberStyles.Any,
                        System.Globalization.CultureInfo.InvariantCulture, out seuilAlerte)
                    ||
                    decimal.TryParse(seuilStr, System.Globalization.NumberStyles.Any,
                        System.Globalization.CultureInfo.GetCultureInfo("fr-FR"), out seuilAlerte);
            }
            if (!hasSeuil) missing.Add("SEUIL D'ALERTE");
            else if (!seuilNumeric) missing.Add("SEUIL D'ALERTE (valeur numérique invalide)");

            DateTime? datePeremption = null;
            if (estPerissable)
            {
                if (string.IsNullOrWhiteSpace(datePeremptionStr))
                {
                    missing.Add("DATE DE PÉREMEPTION (obligatoire pour un article périssable)");
                }
                else
                {
                    datePeremption = TryParseDateFlexible(datePeremptionStr.Trim());
                    if (!datePeremption.HasValue)
                        missing.Add("DATE DE PÉREMEPTION (format invalide — jj/mm/aaaa attendu)");
                }
            }
            else
            {
                datePeremption = null;
            }

            if (missing.Count > 0)
            {
                WriteJson(ctx, new {
                    success = false,
                    messageKey = "articles.server.required_fields_prefix",
                    messageParams = new { fields = string.Join(", ", missing.ToArray()) },
                    message = "Veuillez renseigner tous les champs obligatoires : "
                              + string.Join(", ", missing.ToArray()) + "."
                });
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = @"
                    UPDATE MARTICLE SET
                        NOM = @nom,
                        DESCRIPTION = @desc,
                        CATEGORIE_ID = @cat,
                        FOURNISSEUR_PREFERE_ID = @four,
                        UNITE_MESURE_ID = @unite,
                        EMPLACEMENT_ID = @empl,
                        SEUIL_ALERTE = @seuilAlerte,
                        ACTIVE = @active,
                        EST_SERVICE = @service,
                        EST_PERISSABLE = @perissable,
                        DATE_PEREMPTION = @dper,
                        UPDATED_BY = @userId,
                        UPDATED_AT = GETDATE()
                    WHERE ID = @id AND DELETION_AT IS NULL";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@desc", description ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@cat", categorieId);
                    cmd.Parameters.AddWithValue("@four", fournisseurId);
                    cmd.Parameters.AddWithValue("@unite", uniteId);
                    cmd.Parameters.AddWithValue("@empl", emplacementId);
                    cmd.Parameters.AddWithValue("@seuilAlerte", seuilAlerte);
                    cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                    cmd.Parameters.AddWithValue("@service", estService ? 1 : 0);
                    cmd.Parameters.AddWithValue("@perissable", estPerissable ? 1 : 0);
                    var pDate = cmd.Parameters.Add("@dper", SqlDbType.Date);
                    pDate.Value = datePeremption.HasValue
                        ? (object)datePeremption.Value.Date : DBNull.Value;
                    cmd.Parameters.AddWithValue("@userId", userId);

                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        WriteJson(ctx, new {
                            success = false,
                            messageKey = "articles.server.not_found",
                            message = "Article introuvable ou déjà supprimé."
                        });
                        return;
                    }
                }

                WriteJson(ctx, new {
                    success = true,
                    messageKey = "articles.server.updated",
                    message = "Article modifié avec succès."
                });
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            WriteJson(ctx, new {
                success = false,
                messageKey = "message.error",
                message = ex.Message.Replace("\"", "\\\"")
            });
        }
    }

    private static DateTime? TryParseDateFlexible(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        string s = raw.Trim();
        DateTime d;
        if (DateTime.TryParseExact(s, "yyyy-MM-dd",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out d)) return d.Date;
        if (DateTime.TryParseExact(s, "dd/MM/yyyy",
                System.Globalization.CultureInfo.GetCultureInfo("fr-FR"),
                System.Globalization.DateTimeStyles.None, out d)) return d.Date;
        string[] formatsFr = { "d/M/yyyy", "dd/MM/yyyy", "d-M-yyyy", "dd-MM-yyyy", "d.M.yyyy", "dd.MM.yyyy" };
        if (DateTime.TryParseExact(s, formatsFr,
                System.Globalization.CultureInfo.GetCultureInfo("fr-FR"),
                System.Globalization.DateTimeStyles.None, out d)) return d.Date;
        if (DateTime.TryParse(s,
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out d)) return d.Date;
        return null;
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null;
    }

    private bool GetBool(Dictionary<string, object> data, string key, bool defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool val;
            if (bool.TryParse(data[key].ToString(), out val)) return val;
            string s = data[key].ToString().Trim();
            if (s == "1") return true;
            if (s == "0") return false;
        }
        return defaultValue;
    }

    private void WriteJson(HttpContext ctx, object obj)
    {
        var ser = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        ctx.Response.Write(ser.Serialize(obj));
    }

    public bool IsReusable { get { return false; } }
}
