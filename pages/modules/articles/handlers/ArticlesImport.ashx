<%@ WebHandler Language="C#" Class="ArticlesImport" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class ArticlesImport : IHttpHandler, IRequiresSessionState
{
    // ─── Modèles ─────────────────────────────────────────────
    // NOTE : plus de STOCK_INITIAL, SEUIL_MIN ni SEUIL_MAX.
    //   - Le stock est alimenté uniquement par les mouvements.
    //   - Seul SEUIL_ALERTE est importé (utile pour les alertes).
    //   - Cohérence stricte EST_PERISSABLE ↔ DATE_PEREMPTION.
    //   - Toutes les erreurs portent une clé i18n (messageKey).
    //   - DATE_PEREMPTION acceptée en jj/mm/aaaa (ou ISO aaaa-mm-jj).
    public class ArticleImport
    {
        public string CODE { get; set; }
        public string NOM { get; set; }
        public string DESCRIPTION { get; set; }
        public string CODE_BARRE { get; set; }
        public string CATEGORIE_ID { get; set; }
        public string UNITE_MESURE_ID { get; set; }
        public string FOURNISSEUR_PREFERE_ID { get; set; }
        public string EMPLACEMENT_ID { get; set; }
        public decimal SEUIL_ALERTE { get; set; }
        public decimal POIDS { get; set; }
        public decimal VOLUME { get; set; }
        public bool ACTIVE { get; set; }
        public bool EST_SERVICE { get; set; }
        public bool EST_PERISSABLE { get; set; }
        public string DATE_PEREMPTION { get; set; }
    }

    public class ImportRequest
    {
        public List<ArticleImport> articles { get; set; }
    }

    public class ArticleDoublon
    {
        public string CODE { get; set; }
        public string NOM { get; set; }
        public string raison { get; set; }       // libellé FR (fallback)
        public string raisonKey { get; set; }    // clé i18n
    }

    public class ArticleErreur
    {
        public string CODE { get; set; }
        public string message { get; set; }      // libellé FR (fallback)
        public string messageKey { get; set; }   // clé i18n
    }

    public class ImportResponse
    {
        public bool success { get; set; }
        public string message { get; set; }        // libellé FR (fallback)
        public string messageKey { get; set; }     // clé i18n
        public object messageParams { get; set; }  // valeurs pour interpolation
        public int inserted { get; set; }
        public int updated { get; set; }
        public int skipped { get; set; }
        public List<ArticleDoublon> duplicates { get; set; }
        public List<ArticleErreur> errors { get; set; }
    }

    public bool IsReusable { get { return false; } }

    // ─── Point d'entrée ───────────────────────────────────────
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        context.Response.ContentEncoding = System.Text.UTF8Encoding.UTF8;
        context.Response.Cache.SetNoStore();

        // SuperAdmin (0) ou Admin (1)
        if (!AuthHelper.RequireApiAuth(context, 1))
        {
            context.Response.StatusCode = 403;
            WriteJson(context, ErrorResponse(
                "articles.server.unauthorized",
                "Accès non autorisé"));
            return;
        }

        try
        {
            string json;
            using (var reader = new StreamReader(context.Request.InputStream))
                json = reader.ReadToEnd();

            if (string.IsNullOrWhiteSpace(json))
            {
                WriteJson(context, ErrorResponse(
                    "articles.server.empty_body",
                    "Aucune donnée reçue."));
                return;
            }

            var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
            ImportRequest req;
            try { req = serializer.Deserialize<ImportRequest>(json); }
            catch (Exception jex)
            {
                WriteJson(context, ErrorResponse(
                    "articles.server.invalid_json",
                    "JSON invalide : " + jex.Message));
                return;
            }

            if (req == null || req.articles == null || req.articles.Count == 0)
            {
                WriteJson(context, ErrorResponse(
                    "articles.server.empty_array",
                    "Le tableau d'articles est vide."));
                return;
            }

            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                var cs = ConfigurationManager.ConnectionStrings["MaConnexion"];
                if (cs != null) connStr = cs.ConnectionString;
            }
            if (string.IsNullOrEmpty(connStr))
            {
                WriteJson(context, ErrorResponse(
                    "articles.server.no_connection",
                    "Chaîne de connexion introuvable."));
                return;
            }

            int userId = AuthHelper.GetUserId(context);
            string projetCode = AuthHelper.GetProjectCode(context);
            if (string.IsNullOrEmpty(projetCode)) projetCode = "TALIM";
            projetCode = projetCode.Trim().ToUpperInvariant().Replace(" ", "");

            var response = ProcessImport(req.articles, connStr, userId, projetCode);
            WriteJson(context, response);
        }
        catch (Exception ex)
        {
            WriteJson(context, new ImportResponse
            {
                success = false,
                messageKey = "message.error",
                message = "Erreur serveur : " + ex.Message,
                duplicates = new List<ArticleDoublon>(),
                errors = new List<ArticleErreur> {
                    new ArticleErreur {
                        CODE = "—",
                        message = ex.Message,
                        messageKey = "message.error"
                    }
                }
            });
        }
    }

    // ─── Logique d'importation ────────────────────────────────
    // Aucune écriture dans SSTOCK ni MSTOCK.
    // SEUIL_MIN et SEUIL_MAX ne sont plus touchés : ils restent
    // inchangés en base lors d'un UPDATE (valeur par défaut 0 pour INSERT).
    private ImportResponse ProcessImport(List<ArticleImport> articles, string connStr, int userId, string projetCode)
    {
        var response = new ImportResponse
        {
            success = true,
            duplicates = new List<ArticleDoublon>(),
            errors = new List<ArticleErreur>()
        };

        using (var conn = new SqlConnection(connStr))
        {
            conn.Open();

            // Chargement des FK valides
            var catLookup   = LoadGuidLookup(conn, "SCATEGORIE",   "NOM");
            var uniteLookup = LoadGuidLookup(conn, "SUNITE",       "NOM");
            var fourLookup  = LoadGuidLookup(conn, "SFOURNISSEUR", "NOM");
            var emplLookup  = LoadGuidLookup(conn, "SEMPLACEMENT", "NOM");

            var catIds   = new HashSet<Guid>(catLookup.Values);
            var uniteIds = new HashSet<Guid>(uniteLookup.Values);
            var fourIds  = new HashSet<Guid>(fourLookup.Values);
            var emplIds  = new HashSet<Guid>(emplLookup.Values);

            using (var tx = conn.BeginTransaction())
            {
                try
                {
                    int currentSeq = GetCurrentSequence(conn, tx, projetCode);
                    bool seqDirty = false;
                    var codesInFile = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                    foreach (var a in articles)
                    {
                        string code = (a.CODE ?? "").Trim();
                        try
                        {
                            // ─── 1) Validation du NOM ───
                            string nom = (a.NOM ?? "").Trim();
                            if (string.IsNullOrEmpty(nom))
                                throw new ArgumentException(
                                    "articles.msg.name_required|Le NOM est obligatoire.");

                            // ─── 2) Résolution des FK ───
                            Guid? catId   = ResolveGuid(a.CATEGORIE_ID,           catLookup,   catIds,   "articles.import.field.categorie",   "Catégorie");
                            Guid? uniteId = ResolveGuid(a.UNITE_MESURE_ID,        uniteLookup, uniteIds, "articles.import.field.unite",       "Unité");
                            Guid? fourId  = ResolveGuid(a.FOURNISSEUR_PREFERE_ID, fourLookup,  fourIds,  "articles.import.field.fournisseur", "Fournisseur");
                            Guid? emplId  = ResolveGuid(a.EMPLACEMENT_ID,         emplLookup,  emplIds,  "articles.import.field.emplacement", "Emplacement");

                            if (uniteId == null)
                                throw new ArgumentException(
                                    "articles.msg.unit_required|Unité obligatoire (introuvable).");

                            // ─── 3) Parsing explicite de la DATE_PEREMPTION ───
                            // Accepte ISO (yyyy-MM-dd) ET format FR (jj/mm/aaaa).
                            DateTime? datePeremption = null;
                            if (!string.IsNullOrWhiteSpace(a.DATE_PEREMPTION))
                            {
                                datePeremption = TryParseDateFlexible(a.DATE_PEREMPTION.Trim());
                                if (!datePeremption.HasValue)
                                {
                                    throw new ArgumentException(
                                        "articles.msg.date_peremption_invalid|Date de péremption invalide (format attendu : jj/mm/aaaa).");
                                }
                            }

                            // ─── 4) COHÉRENCE PÉRISSABLE ↔ DATE DE PÉREMEPTION ───
                            if (!a.EST_PERISSABLE && datePeremption.HasValue)
                            {
                                throw new ArgumentException(
                                    "articles.msg.date_peremption_forbidden|Date de péremption fournie pour un article non périssable.");
                            }
                            if (a.EST_PERISSABLE && !datePeremption.HasValue)
                            {
                                throw new ArgumentException(
                                    "articles.msg.date_peremption_required|Date de péremption obligatoire pour un article périssable.");
                            }
                            // Si non périssable, on force NULL même si une valeur résiduelle existe
                            if (!a.EST_PERISSABLE)
                            {
                                datePeremption = null;
                            }

                            // ─── 5) Détection doublons dans le fichier ───
                            if (!string.IsNullOrEmpty(code))
                            {
                                if (codesInFile.Contains(code))
                                {
                                    response.skipped++;
                                    response.duplicates.Add(new ArticleDoublon
                                    {
                                        CODE = code,
                                        NOM = nom,
                                        raison = "Code en doublon dans le fichier",
                                        raisonKey = "articles.import.duplicate_in_file"
                                    });
                                    continue;
                                }
                                codesInFile.Add(code);
                            }

                            // ─── 6) Recherche d'un article existant par CODE ───
                            Guid? existingId = string.IsNullOrEmpty(code)
                                ? (Guid?)null
                                : FindArticleByCode(conn, tx, code);

                            Guid articleId;
                            bool isUpdate = false;

                            if (existingId.HasValue)
                            {
                                articleId = existingId.Value;
                                isUpdate = true;
                                UpdateArticle(conn, tx, articleId, nom, a, catId, uniteId, fourId, emplId,
                                              datePeremption, userId);
                            }
                            else
                            {
                                if (string.IsNullOrEmpty(code))
                                {
                                    do
                                    {
                                        currentSeq++;
                                        code = string.Format("ART-{0}-{1:D5}", projetCode, currentSeq);
                                    } while (FindArticleByCode(conn, tx, code) != null);
                                    seqDirty = true;
                                }

                                articleId = Guid.NewGuid();
                                InsertArticle(conn, tx, articleId, code, nom, a, catId, uniteId, fourId, emplId,
                                              datePeremption, userId);
                            }

                            if (isUpdate) response.updated++;
                            else response.inserted++;
                        }
                        catch (SqlException sqlex)
                        {
                            response.skipped++;
                            response.errors.Add(new ArticleErreur
                            {
                                CODE = a.CODE ?? "—",
                                message = "SQL #" + sqlex.Number + " : " + sqlex.Message,
                                messageKey = "articles.server.sql_error"
                            });
                        }
                        catch (Exception exRow)
                        {
                            response.skipped++;
                            var parsed = ParseKeyedMessage(exRow.Message);
                            response.errors.Add(new ArticleErreur
                            {
                                CODE = a.CODE ?? "—",
                                message = parsed.Value,
                                messageKey = parsed.Key
                            });
                        }
                    }

                    if (seqDirty)
                        UpdateSequence(conn, tx, projetCode, currentSeq);

                    tx.Commit();
                }
                catch
                {
                    try { tx.Rollback(); } catch { /* ignore */ }
                    throw;
                }
            }
        }

        response.messageKey = "articles.server.import_summary";
        response.messageParams = new
        {
            inserted = response.inserted,
            updated = response.updated,
            skipped = response.skipped,
            errors = response.errors.Count
        };
        response.message = string.Format(
            "{0} article(s) ajouté(s), {1} mise(s) à jour, {2} ignoré(s) ({3} erreur(s)).",
            response.inserted, response.updated, response.skipped, response.errors.Count);

        return response;
    }

    // ─── Parsing de date flexible ─────────────────────────────
    // Accepte (par ordre de priorité) :
    //   1) ISO strict                : yyyy-MM-dd
    //   2) Format français strict    : dd/MM/yyyy
    //   3) Format français variantes : dd-MM-yyyy, dd.MM.yyyy
    //   4) Fallback invariant        : DateTime.TryParse
    private static DateTime? TryParseDateFlexible(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        string s = raw.Trim();

        // 1) ISO yyyy-MM-dd (envoyé par le client après normalisation)
        DateTime d;
        if (DateTime.TryParseExact(
                s, "yyyy-MM-dd",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None,
                out d))
            return d.Date;

        // 2) FR jj/mm/aaaa
        if (DateTime.TryParseExact(
                s, "dd/MM/yyyy",
                System.Globalization.CultureInfo.GetCultureInfo("fr-FR"),
                System.Globalization.DateTimeStyles.None,
                out d))
            return d.Date;

        // 3) Variantes FR avec -, .
        string[] formatsFr = { "d/M/yyyy", "dd/MM/yyyy", "d-M-yyyy", "dd-MM-yyyy",
                                "d.M.yyyy", "dd.MM.yyyy" };
        if (DateTime.TryParseExact(
                s, formatsFr,
                System.Globalization.CultureInfo.GetCultureInfo("fr-FR"),
                System.Globalization.DateTimeStyles.None,
                out d))
            return d.Date;

        // 4) Dernier recours : parsing invariant (accepte ISO 8601 complet)
        if (DateTime.TryParse(
                s,
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None,
                out d))
            return d.Date;

        return null;
    }

    // ─── Helpers FK / séquence ────────────────────────────────
    private static Guid? ResolveGuid(string value, Dictionary<string, Guid> lookup,
                                     HashSet<Guid> valid, string labelKey, string labelFr)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        value = value.Trim();

        Guid g;
        if (Guid.TryParse(value, out g))
        {
            if (!valid.Contains(g))
                throw new ArgumentException(
                    "articles.server.fk_guid_not_found|" + labelFr + " introuvable (GUID).");
            return g;
        }

        Guid found;
        if (lookup.TryGetValue(value, out found)) return found;
        throw new ArgumentException(
            "articles.server.fk_not_found|" + labelFr + " introuvable : \"" + value + "\"");
    }

    private static Dictionary<string, Guid> LoadGuidLookup(SqlConnection conn, string table, string nameCol)
    {
        var dict = new Dictionary<string, Guid>(StringComparer.OrdinalIgnoreCase);
        string sql = "SELECT ID, [" + nameCol + "], [CODE] FROM [" + table + "] WHERE DELETION_AT IS NULL";
        try
        {
            using (var cmd = new SqlCommand(sql, conn))
            using (var rdr = cmd.ExecuteReader())
            {
                while (rdr.Read())
                {
                    if (rdr[0] == DBNull.Value) continue;
                    Guid id = (Guid)rdr[0];
                    if (rdr[1] != DBNull.Value)
                    {
                        string k = rdr[1].ToString().Trim();
                        if (!string.IsNullOrEmpty(k) && !dict.ContainsKey(k)) dict[k] = id;
                    }
                    if (rdr[2] != DBNull.Value)
                    {
                        string kc = rdr[2].ToString().Trim();
                        if (!string.IsNullOrEmpty(kc) && !dict.ContainsKey(kc)) dict[kc] = id;
                    }
                }
            }
        }
        catch { /* table/colonne absente : on ignore, la résolution rejettera */ }
        return dict;
    }

    private static int GetCurrentSequence(SqlConnection conn, SqlTransaction tx, string projetCode)
    {
        const string sql = @"
            IF NOT EXISTS (SELECT 1 FROM MARTICLE_SEQUENCE WITH (UPDLOCK, HOLDLOCK) WHERE PROJET_CODE = @p)
                INSERT INTO MARTICLE_SEQUENCE (PROJET_CODE, DERNIER_NUMERO) VALUES (@p, 0);
            SELECT DERNIER_NUMERO FROM MARTICLE_SEQUENCE WITH (UPDLOCK, HOLDLOCK) WHERE PROJET_CODE = @p;";
        using (var cmd = new SqlCommand(sql, conn, tx))
        {
            cmd.Parameters.AddWithValue("@p", projetCode);
            object r = cmd.ExecuteScalar();
            return (r == null || r == DBNull.Value) ? 0 : Convert.ToInt32(r);
        }
    }

    private static void UpdateSequence(SqlConnection conn, SqlTransaction tx, string projetCode, int value)
    {
        using (var cmd = new SqlCommand(
            "UPDATE MARTICLE_SEQUENCE SET DERNIER_NUMERO = @n WHERE PROJET_CODE = @p", conn, tx))
        {
            cmd.Parameters.AddWithValue("@n", value);
            cmd.Parameters.AddWithValue("@p", projetCode);
            cmd.ExecuteNonQuery();
        }
    }

    private static Guid? FindArticleByCode(SqlConnection conn, SqlTransaction tx, string code)
    {
        using (var cmd = new SqlCommand(
            "SELECT ID FROM MARTICLE WHERE CODE = @c AND DELETION_AT IS NULL", conn, tx))
        {
            cmd.Parameters.AddWithValue("@c", code);
            object r = cmd.ExecuteScalar();
            return (r == null || r == DBNull.Value) ? (Guid?)null : (Guid)r;
        }
    }

    // ─── CRUD article ─────────────────────────────────────────
    // La DATE_PEREMPTION est passée en DateTime? (déjà parsée) pour
    // garantir un enregistrement propre dans la colonne DATE.
    private static void InsertArticle(SqlConnection conn, SqlTransaction tx,
        Guid id, string code, string nom, ArticleImport a,
        Guid? catId, Guid? uniteId, Guid? fourId, Guid? emplId,
        DateTime? datePeremption, int userId)
    {
        const string sql = @"
            INSERT INTO MARTICLE (
                ID, CODE, CODE_BARRE, NOM, DESCRIPTION,
                CATEGORIE_ID, UNITE_MESURE_ID, FOURNISSEUR_PREFERE_ID, EMPLACEMENT_ID,
                SEUIL_ALERTE, POIDS, VOLUME,
                ACTIVE, EST_SERVICE, EST_PERISSABLE, DATE_PEREMPTION,
                CREATED_BY, CREATED_AT
            ) VALUES (
                @id, @code, @cb, @nom, @desc,
                @cat, @unite, @four, @empl,
                @salt, @poids, @vol,
                @active, @service, @perissable, @dper,
                @uid, GETDATE()
            )";
        using (var cmd = new SqlCommand(sql, conn, tx))
        {
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@code", code);
            cmd.Parameters.Add("@cb", SqlDbType.VarChar, 50).Value =
                string.IsNullOrEmpty(a.CODE_BARRE) ? (object)DBNull.Value : a.CODE_BARRE;
            cmd.Parameters.AddWithValue("@nom", nom);
            cmd.Parameters.Add("@desc", SqlDbType.NVarChar, 500).Value =
                string.IsNullOrEmpty(a.DESCRIPTION) ? (object)DBNull.Value : a.DESCRIPTION;
            AddGuidOrNull(cmd, "@cat",   catId);
            AddGuidOrNull(cmd, "@unite", uniteId);
            AddGuidOrNull(cmd, "@four",  fourId);
            AddGuidOrNull(cmd, "@empl",  emplId);
            cmd.Parameters.AddWithValue("@salt", a.SEUIL_ALERTE);
            cmd.Parameters.AddWithValue("@poids", a.POIDS);
            cmd.Parameters.AddWithValue("@vol", a.VOLUME);
            cmd.Parameters.AddWithValue("@active", a.ACTIVE ? 1 : 0);
            cmd.Parameters.AddWithValue("@service", a.EST_SERVICE ? 1 : 0);
            cmd.Parameters.AddWithValue("@perissable", a.EST_PERISSABLE ? 1 : 0);
            AddDateOrNull(cmd, "@dper", datePeremption);
            cmd.Parameters.AddWithValue("@uid", userId);
            cmd.ExecuteNonQuery();
        }
    }

    private static void UpdateArticle(SqlConnection conn, SqlTransaction tx,
        Guid id, string nom, ArticleImport a,
        Guid? catId, Guid? uniteId, Guid? fourId, Guid? emplId,
        DateTime? datePeremption, int userId)
    {
        const string sql = @"
            UPDATE MARTICLE SET
                NOM = @nom,
                DESCRIPTION = @desc,
                CODE_BARRE = @cb,
                CATEGORIE_ID = @cat,
                UNITE_MESURE_ID = @unite,
                FOURNISSEUR_PREFERE_ID = @four,
                EMPLACEMENT_ID = @empl,
                SEUIL_ALERTE = @salt,
                POIDS = @poids,
                VOLUME = @vol,
                ACTIVE = @active,
                EST_SERVICE = @service,
                EST_PERISSABLE = @perissable,
                DATE_PEREMPTION = @dper,
                UPDATED_BY = @uid,
                UPDATED_AT = GETDATE()
            WHERE ID = @id";
        using (var cmd = new SqlCommand(sql, conn, tx))
        {
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@nom", nom);
            cmd.Parameters.Add("@desc", SqlDbType.NVarChar, 500).Value =
                string.IsNullOrEmpty(a.DESCRIPTION) ? (object)DBNull.Value : a.DESCRIPTION;
            cmd.Parameters.Add("@cb", SqlDbType.VarChar, 50).Value =
                string.IsNullOrEmpty(a.CODE_BARRE) ? (object)DBNull.Value : a.CODE_BARRE;
            AddGuidOrNull(cmd, "@cat",   catId);
            AddGuidOrNull(cmd, "@unite", uniteId);
            AddGuidOrNull(cmd, "@four",  fourId);
            AddGuidOrNull(cmd, "@empl",  emplId);
            cmd.Parameters.AddWithValue("@salt", a.SEUIL_ALERTE);
            cmd.Parameters.AddWithValue("@poids", a.POIDS);
            cmd.Parameters.AddWithValue("@vol", a.VOLUME);
            cmd.Parameters.AddWithValue("@active", a.ACTIVE ? 1 : 0);
            cmd.Parameters.AddWithValue("@service", a.EST_SERVICE ? 1 : 0);
            cmd.Parameters.AddWithValue("@perissable", a.EST_PERISSABLE ? 1 : 0);
            AddDateOrNull(cmd, "@dper", datePeremption);
            cmd.Parameters.AddWithValue("@uid", userId);
            cmd.ExecuteNonQuery();
        }
    }

    // ─── Utilitaires ──────────────────────────────────────────
    private static void AddGuidOrNull(SqlCommand cmd, string name, Guid? value)
    {
        var p = cmd.Parameters.Add(name, SqlDbType.UniqueIdentifier);
        p.Value = value.HasValue ? (object)value.Value : DBNull.Value;
    }

    // Enregistre une date déjà parsée. Plus de parsing implicite côté SQL :
    // on aiguille directement sur la valeur DateTime? issue de TryParseDateFlexible.
    private static void AddDateOrNull(SqlCommand cmd, string name, DateTime? value)
    {
        var p = cmd.Parameters.Add(name, SqlDbType.Date);
        p.Value = value.HasValue ? (object)value.Value.Date : DBNull.Value;
    }

    // Parse une chaîne "clé|message" en paire (Key, Value)
    // Si la chaîne ne contient pas de pipe, Key = null et Value = message.
    private static KeyValuePair<string, string> ParseKeyedMessage(string raw)
    {
        if (string.IsNullOrEmpty(raw))
            return new KeyValuePair<string, string>(null, "");

        int idx = raw.IndexOf('|');
        if (idx <= 0 || idx >= raw.Length - 1)
            return new KeyValuePair<string, string>(null, raw);

        string key = raw.Substring(0, idx).Trim();
        string val = raw.Substring(idx + 1).Trim();
        return new KeyValuePair<string, string>(key, val);
    }

    private static ImportResponse ErrorResponse(string msgKey, string fallbackMsg = null)
    {
        string msg = fallbackMsg ?? msgKey;
        return new ImportResponse
        {
            success = false,
            messageKey = msgKey,
            message = msg,
            duplicates = new List<ArticleDoublon>(),
            errors = new List<ArticleErreur> {
                new ArticleErreur {
                    CODE = "—",
                    message = msg,
                    messageKey = msgKey
                }
            }
        };
    }

    private void WriteJson(HttpContext context, object obj)
    {
        var ser = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        context.Response.Write(ser.Serialize(obj));
    }
}
