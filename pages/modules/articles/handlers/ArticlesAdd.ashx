﻿<%@ WebHandler Language="C#" Class="ArticlesAdd" %>
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ArticlesAdd : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
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

            if (data == null)
            {
                WriteJson(ctx, new {
                    success = false,
                    messageKey = "articles.server.invalid_body",
                    message = "Corps de requête invalide."
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

            // ─── Validation des 6 champs obligatoires ───
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

            string projetCode = AuthHelper.GetProjectCode(ctx);
            if (string.IsNullOrEmpty(projetCode)) projetCode = "TALIM";
            projetCode = projetCode.Trim().ToUpperInvariant().Replace(" ", "");

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string newId = Guid.NewGuid().ToString();
            string code;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var trans = conn.BeginTransaction())
                {
                    try
                    {
                        string sqlSeq = @"
                            IF NOT EXISTS (SELECT 1 FROM MARTICLE_SEQUENCE WITH (UPDLOCK, HOLDLOCK) WHERE PROJET_CODE = @projet)
                            BEGIN
                                INSERT INTO MARTICLE_SEQUENCE (PROJET_CODE, DERNIER_NUMERO) VALUES (@projet, 0);
                            END
                            UPDATE MARTICLE_SEQUENCE
                            SET DERNIER_NUMERO = DERNIER_NUMERO + 1
                            OUTPUT INSERTED.DERNIER_NUMERO
                            WHERE PROJET_CODE = @projet;";
                        int numero;
                        using (var cmdSeq = new SqlCommand(sqlSeq, conn, trans))
                        {
                            cmdSeq.Parameters.AddWithValue("@projet", projetCode);
                            numero = Convert.ToInt32(cmdSeq.ExecuteScalar());
                        }

                        code = string.Format("ART-{0}-{1:D5}", projetCode, numero);

                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM MARTICLE WHERE CODE = @code", conn, trans))
                        {
                            cmdCheck.Parameters.AddWithValue("@code", code);
                            if (Convert.ToInt32(cmdCheck.ExecuteScalar()) > 0)
                                throw new Exception("CodeExists");
                        }

                        string articleSql = @"
                            INSERT INTO MARTICLE (
                                ID, CODE, NOM, DESCRIPTION,
                                CATEGORIE_ID, FOURNISSEUR_PREFERE_ID, UNITE_MESURE_ID, EMPLACEMENT_ID,
                                SEUIL_ALERTE, ACTIVE, EST_SERVICE,
                                EST_PERISSABLE, DATE_PEREMPTION,
                                CREATED_BY, CREATED_AT)
                            VALUES (
                                @id, @code, @nom, @desc,
                                @cat, @four, @unite, @empl,
                                @seuil, @active, @service,
                                @perissable, @dper,
                                @userId, GETDATE())";
                        using (var cmd = new SqlCommand(articleSql, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", newId);
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@desc", description ?? (object)DBNull.Value);
                            cmd.Parameters.AddWithValue("@cat", categorieId);
                            cmd.Parameters.AddWithValue("@four", fournisseurId);
                            cmd.Parameters.AddWithValue("@unite", uniteId);
                            cmd.Parameters.AddWithValue("@empl", emplacementId);
                            cmd.Parameters.AddWithValue("@seuil", seuilAlerte);
                            cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                            cmd.Parameters.AddWithValue("@service", estService ? 1 : 0);
                            cmd.Parameters.AddWithValue("@perissable", estPerissable ? 1 : 0);
                            var pDate = cmd.Parameters.Add("@dper", SqlDbType.Date);
                            pDate.Value = datePeremption.HasValue
                                ? (object)datePeremption.Value.Date : DBNull.Value;
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        trans.Commit();

                        WriteJson(ctx, new {
                            success = true,
                            id = newId,
                            code = code,
                            messageKey = "articles.server.added_with_code",
                            messageParams = new { code = code },
                            message = "Article ajouté avec succès (" + code + ")."
                        });
                    }
                    catch (Exception tex)
                    {
                        try { trans.Rollback(); } catch { /* ignore */ }
                        if (tex.Message == "CodeExists")
                        {
                            WriteJson(ctx, new {
                                success = false,
                                messageKey = "articles.server.code_exists",
                                message = "Le code généré existe déjà, veuillez réessayer."
                            });
                            return;
                        }
                        throw;
                    }
                }
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
