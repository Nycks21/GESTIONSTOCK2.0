using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

public partial class index : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        AuthHelper.VerifySession(this);
        LocalizationHelper.HandleLanguage();

        string action = Request.QueryString["action"];
        if (string.IsNullOrEmpty(action)) return;

        Response.Clear();
        Response.ContentType = "application/json";
        Response.Charset = "utf-8";
        Response.Cache.SetNoStore();

        try
        {
            switch (action)
            {
                case "kpi":                WriteKpi();                break;
                case "alerts":             WriteAlerts();             break;
                case "movements":          WriteMovementsChart();     break;
                case "stockByCategory":    WriteStockByCategory();    break;
                case "recentMovements":    WriteRecentMovements();    break;
                case "recentDocuments":    WriteRecentDocuments();    break;
                case "topArticles":        WriteTopArticles();        break;
                default:                   Response.Write("{\"success\":false,\"message\":\"Action inconnue\"}"); break;
            }
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message
            }));
        }
        Response.End();
    }

    // ============================================================
    // KPI GLOBAUX
    // ============================================================
    private void WriteKpi()
    {
        var result = new Dictionary<string, object>();
        using (SqlConnection conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();

            // Articles actifs
            using (SqlCommand cmd = new SqlCommand(
                "SELECT COUNT(*) FROM MARTICLE WHERE ACTIVE = 1 AND DELETION_AT IS NULL", conn))
                result["articlesActifs"] = Convert.ToInt32(cmd.ExecuteScalar());

            // Total articles (pour comparaison)
            using (SqlCommand cmd = new SqlCommand(
                "SELECT COUNT(*) FROM MARTICLE WHERE DELETION_AT IS NULL", conn))
                result["articlesTotal"] = Convert.ToInt32(cmd.ExecuteScalar());

            // Alertes stock
            using (SqlCommand cmd = new SqlCommand(
                "SELECT COUNT(*) FROM SSTOCK WHERE STATUT IN ('ALERTE','RUPTURE') AND DELETION_AT IS NULL", conn))
                result["alertesStock"] = Convert.ToInt32(cmd.ExecuteScalar());

            // Détail alertes
            using (SqlCommand cmd = new SqlCommand(
                @"SELECT
                    SUM(CASE WHEN STATUT='RUPTURE' THEN 1 ELSE 0 END) AS ruptures,
                    SUM(CASE WHEN STATUT='ALERTE' THEN 1 ELSE 0 END) AS alertes
                  FROM SSTOCK WHERE DELETION_AT IS NULL", conn))
            using (SqlDataReader r = cmd.ExecuteReader())
            {
                if (r.Read())
                {
                    result["ruptures"] = r["ruptures"] == DBNull.Value ? 0 : Convert.ToInt32(r["ruptures"]);
                    result["alertes"]  = r["alertes"]  == DBNull.Value ? 0 : Convert.ToInt32(r["alertes"]);
                }
                r.Close();
            }

            // Bons en attente
            int bonsEntree = 0, bonsSortie = 0;
            using (SqlCommand cmd = new SqlCommand(
                "SELECT COUNT(*) FROM SENTREE WHERE STATUT='BROUILLON' AND DELETION_AT IS NULL", conn))
                bonsEntree = Convert.ToInt32(cmd.ExecuteScalar());

            using (SqlCommand cmd = new SqlCommand(
                "SELECT COUNT(*) FROM SSORTIE WHERE STATUT='BROUILLON' AND DELETION_AT IS NULL", conn))
                bonsSortie = Convert.ToInt32(cmd.ExecuteScalar());

            result["bonsEntree"] = bonsEntree;
            result["bonsSortie"] = bonsSortie;
            result["bonsAttente"] = bonsEntree + bonsSortie;

            // Valeur du stock (dernier prix connu par article)
            string sqlValeur = @"
                WITH LastPrice AS (
                    SELECT ARTICLE_ID, PRIX_UNITAIRE,
                           ROW_NUMBER() OVER (PARTITION BY ARTICLE_ID ORDER BY CREATED_AT DESC) AS rn
                    FROM MSTOCK
                    WHERE PRIX_UNITAIRE IS NOT NULL AND DELETION_AT IS NULL
                )
                SELECT ISNULL(SUM(s.QUANTITE_ACTUELLE * ISNULL(lp.PRIX_UNITAIRE, 0)), 0)
                FROM SSTOCK s
                LEFT JOIN LastPrice lp ON lp.ARTICLE_ID = s.ARTICLE_ID AND lp.rn = 1
                WHERE s.DELETION_AT IS NULL";
            using (SqlCommand cmd = new SqlCommand(sqlValeur, conn))
                result["valeurStock"] = Convert.ToDecimal(cmd.ExecuteScalar());

            // Nombre d'articles en alerte par rapport au seuil
            using (SqlCommand cmd = new SqlCommand(
                @"SELECT COUNT(DISTINCT a.ID)
                  FROM MARTICLE a
                  INNER JOIN SSTOCK s ON s.ARTICLE_ID = a.ID
                  WHERE a.DELETION_AT IS NULL AND s.DELETION_AT IS NULL
                    AND s.QUANTITE_ACTUELLE <= a.SEUIL_ALERTE", conn))
                result["articlesSousSeuil"] = Convert.ToInt32(cmd.ExecuteScalar());
        }
        result["success"] = true;
        Response.Write(new JavaScriptSerializer().Serialize(result));
    }

    // ============================================================
    // ALERTES PRIORITAIRES (articles en RUPTURE ou ALERTE)
    // ============================================================
    private void WriteAlerts()
    {
        if (!AuthHelper.HasPermission("stock") && !AuthHelper.HasPermission("articles"))
        {
            Response.Write("{\"success\":true,\"data\":[]}");
            return;
        }

        var list = new List<Dictionary<string, object>>();
        using (SqlConnection conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();
            string sql = @"
                SELECT TOP 20
                    a.CODE       AS article_code,
                    a.NOM        AS article_nom,
                    c.NOM        AS categorie,
                    e.NOM        AS emplacement,
                    u.NOM        AS unite,
                    s.QUANTITE_ACTUELLE,
                    a.SEUIL_ALERTE,
                    a.SEUIL_MIN,
                    s.STATUT
                FROM SSTOCK s
                INNER JOIN MARTICLE a ON a.ID = s.ARTICLE_ID
                LEFT JOIN SCATEGORIE c ON c.ID = a.CATEGORIE_ID
                LEFT JOIN SEMPLACEMENT e ON e.ID = s.EMPLACEMENT_ID
                LEFT JOIN SUNITE u ON u.ID = a.UNITE_MESURE_ID
                WHERE s.DELETION_AT IS NULL
                  AND a.DELETION_AT IS NULL
                  AND s.STATUT IN ('ALERTE','RUPTURE')
                ORDER BY
                    CASE s.STATUT WHEN 'RUPTURE' THEN 0 ELSE 1 END,
                    s.QUANTITE_ACTUELLE ASC";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            using (SqlDataReader r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    list.Add(new Dictionary<string, object>
                    {
                        { "code",          r["article_code"].ToString() },
                        { "nom",           r["article_nom"].ToString() },
                        { "categorie",     r["categorie"] == DBNull.Value ? "" : r["categorie"].ToString() },
                        { "emplacement",   r["emplacement"] == DBNull.Value ? "" : r["emplacement"].ToString() },
                        { "unite",         r["unite"] == DBNull.Value ? "" : r["unite"].ToString() },
                        { "quantite",      Convert.ToDecimal(r["QUANTITE_ACTUELLE"]) },
                        { "seuilAlerte",   Convert.ToDecimal(r["SEUIL_ALERTE"]) },
                        { "seuilMin",      Convert.ToDecimal(r["SEUIL_MIN"]) },
                        { "statut",        r["STATUT"].ToString() }
                    });
                }
            }
        }
        Response.Write(new JavaScriptSerializer().Serialize(new { success = true, data = list }));
    }

    // ============================================================
    // MOUVEMENTS — Graphique 30 jours (entrées vs sorties)
    // ============================================================
    private void WriteMovementsChart()
    {
        if (!AuthHelper.HasPermission("stock"))
        {
            Response.Write("{\"success\":false,\"message\":\"Non autorisé\"}");
            return;
        }

        var labels = new List<string>();
        var entrees = new List<decimal>();
        var sorties = new List<decimal>();

        using (SqlConnection conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();
            string sql = @"
                SELECT
                    CAST(CREATED_AT AS DATE) AS jour,
                    SUM(CASE WHEN TYPE = 'ENTREE' THEN QUANTITE ELSE 0 END) AS total_entree,
                    SUM(CASE WHEN TYPE = 'SORTIE' THEN QUANTITE ELSE 0 END) AS total_sortie
                FROM MSTOCK
                WHERE CREATED_AT >= DATEADD(DAY, -29, CAST(GETDATE() AS DATE))
                  AND DELETION_AT IS NULL
                GROUP BY CAST(CREATED_AT AS DATE)
                ORDER BY jour";

            var dict = new Dictionary<DateTime, Tuple<decimal, decimal>>();
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            using (SqlDataReader r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    DateTime d = Convert.ToDateTime(r["jour"]);
                    decimal e = r["total_entree"] == DBNull.Value ? 0 : Convert.ToDecimal(r["total_entree"]);
                    decimal s = r["total_sortie"] == DBNull.Value ? 0 : Convert.ToDecimal(r["total_sortie"]);
                    dict[d] = Tuple.Create(e, s);
                }
            }

            // Remplir les 30 jours (avec 0 si absent)
            for (int i = 29; i >= 0; i--)
            {
                DateTime jour = DateTime.Today.AddDays(-i);
                labels.Add(jour.ToString("dd/MM"));
                if (dict.ContainsKey(jour))
                {
                    entrees.Add(dict[jour].Item1);
                    sorties.Add(dict[jour].Item2);
                }
                else
                {
                    entrees.Add(0);
                    sorties.Add(0);
                }
            }
        }

        Response.Write(new JavaScriptSerializer().Serialize(new
        {
            success = true,
            labels = labels,
            entrees = entrees,
            sorties = sorties
        }));
    }

    // ============================================================
    // RÉPARTITION STOCK PAR CATÉGORIE (donut)
    // ============================================================
    private void WriteStockByCategory()
    {
        if (!AuthHelper.HasPermission("stock") && !AuthHelper.HasPermission("categories"))
        {
            Response.Write("{\"success\":true,\"labels\":[],\"quantites\":[]}");
            return;
        }

        var labels = new List<string>();
        var quantites = new List<decimal>();

        using (SqlConnection conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();
            string sql = @"
                SELECT
                    ISNULL(c.NOM, 'Non classé') AS categorie,
                    SUM(s.QUANTITE_ACTUELLE) AS total
                FROM SSTOCK s
                INNER JOIN MARTICLE a ON a.ID = s.ARTICLE_ID
                LEFT JOIN SCATEGORIE c ON c.ID = a.CATEGORIE_ID
                WHERE s.DELETION_AT IS NULL AND a.DELETION_AT IS NULL
                GROUP BY c.NOM
                HAVING SUM(s.QUANTITE_ACTUELLE) > 0
                ORDER BY total DESC";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            using (SqlDataReader r = cmd.ExecuteReader())
            {
                int count = 0;
                while (r.Read() && count < 8)
                {
                    labels.Add(r["categorie"].ToString());
                    quantites.Add(Convert.ToDecimal(r["total"]));
                    count++;
                }
            }
        }

        Response.Write(new JavaScriptSerializer().Serialize(new
        {
            success = true,
            labels = labels,
            quantites = quantites
        }));
    }

    // ============================================================
    // DERNIERS MOUVEMENTS (activité récente)
    // ============================================================
    private void WriteRecentMovements()
    {
        if (!AuthHelper.HasPermission("stock"))
        {
            Response.Write("{\"success\":true,\"data\":[]}");
            return;
        }

        var list = new List<Dictionary<string, object>>();
        using (SqlConnection conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();
            string sql = @"
                SELECT TOP 10
                    m.TYPE,
                    m.QUANTITE,
                    m.QUANTITE_APRES,
                    m.CREATED_AT,
                    a.CODE AS article_code,
                    a.NOM  AS article_nom,
                    u.NOM  AS unite,
                    us.USERNAME AS utilisateur
                FROM MSTOCK m
                INNER JOIN MARTICLE a ON a.ID = m.ARTICLE_ID
                LEFT JOIN SUNITE u ON u.ID = a.UNITE_MESURE_ID
                LEFT JOIN USERS us ON us.IDUSER = m.CREATED_BY
                WHERE m.DELETION_AT IS NULL
                ORDER BY m.CREATED_AT DESC";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            using (SqlDataReader r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    list.Add(new Dictionary<string, object>
                    {
                        { "type",       r["TYPE"].ToString() },
                        { "quantite",   Convert.ToDecimal(r["QUANTITE"]) },
                        { "quantiteApres", Convert.ToDecimal(r["QUANTITE_APRES"]) },
                        { "date",       Convert.ToDateTime(r["CREATED_AT"]).ToString("o") },
                        { "code",       r["article_code"].ToString() },
                        { "nom",        r["article_nom"].ToString() },
                        { "unite",      r["unite"] == DBNull.Value ? "" : r["unite"].ToString() },
                        { "utilisateur", r["utilisateur"] == DBNull.Value ? "" : r["utilisateur"].ToString() }
                    });
                }
            }
        }
        Response.Write(new JavaScriptSerializer().Serialize(new { success = true, data = list }));
    }

    // ============================================================
    // DERNIERS DOCUMENTS (bons d'entrée + sortie)
    // ============================================================
    private void WriteRecentDocuments()
    {
        var list = new List<Dictionary<string, object>>();
        using (SqlConnection conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();

            // Bons d'entrée
            if (AuthHelper.HasPermission("entrees"))
            {
                using (SqlCommand cmd = new SqlCommand(
                    @"SELECT TOP 5 ID, NUMERO, DATE_ENTREE AS DATE_DOC, STATUT, TOTAL_TTC,
                             'ENTREE' AS TYPE_DOC
                      FROM SENTREE WHERE DELETION_AT IS NULL
                      ORDER BY CREATED_AT DESC", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        list.Add(new Dictionary<string, object>
                        {
                            { "type",     "ENTREE" },
                            { "numero",   r["NUMERO"].ToString() },
                            { "date",     Convert.ToDateTime(r["DATE_DOC"]).ToString("o") },
                            { "statut",   r["STATUT"].ToString() },
                            { "montant",  Convert.ToDecimal(r["TOTAL_TTC"]) }
                        });
                    }
                }
            }

            // Bons de sortie
            if (AuthHelper.HasPermission("sorties"))
            {
                using (SqlCommand cmd = new SqlCommand(
                    @"SELECT TOP 5 ID, NUMERO, DATE_SORTIE AS DATE_DOC, STATUT, DESTINATION,
                             'SORTIE' AS TYPE_DOC
                      FROM SSORTIE WHERE DELETION_AT IS NULL
                      ORDER BY CREATED_AT DESC", conn))
                using (SqlDataReader r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        list.Add(new Dictionary<string, object>
                        {
                            { "type",        "SORTIE" },
                            { "numero",      r["NUMERO"].ToString() },
                            { "date",        Convert.ToDateTime(r["DATE_DOC"]).ToString("o") },
                            { "statut",      r["STATUT"].ToString() },
                            { "destination", r["DESTINATION"] == DBNull.Value ? "" : r["DESTINATION"].ToString() }
                        });
                    }
                }
            }

            // Trier par date décroissante
            list.Sort((a, b) =>
                Convert.ToDateTime(b["date"]).CompareTo(Convert.ToDateTime(a["date"])));
        }
        Response.Write(new JavaScriptSerializer().Serialize(new
        {
            success = true,
            data = list.GetRange(0, Math.Min(10, list.Count))
        }));
    }

    // ============================================================
    // TOP ARTICLES (par volume de mouvements)
    // ============================================================
    private void WriteTopArticles()
    {
        if (!AuthHelper.HasPermission("stock") && !AuthHelper.HasPermission("articles"))
        {
            Response.Write("{\"success\":true,\"data\":[]}");
            return;
        }

        var list = new List<Dictionary<string, object>>();
        using (SqlConnection conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();
            string sql = @"
                SELECT TOP 5
                    a.CODE, a.NOM,
                    SUM(m.QUANTITE) AS volume_total,
                    u.NOM AS unite
                FROM MSTOCK m
                INNER JOIN MARTICLE a ON a.ID = m.ARTICLE_ID
                LEFT JOIN SUNITE u ON u.ID = a.UNITE_MESURE_ID
                WHERE m.CREATED_AT >= DATEADD(DAY, -30, GETDATE())
                  AND m.DELETION_AT IS NULL
                GROUP BY a.CODE, a.NOM, u.NOM
                ORDER BY volume_total DESC";

            using (SqlCommand cmd = new SqlCommand(sql, conn))
            using (SqlDataReader r = cmd.ExecuteReader())
            {
                while (r.Read())
                {
                    list.Add(new Dictionary<string, object>
                    {
                        { "code",   r["CODE"].ToString() },
                        { "nom",    r["NOM"].ToString() },
                        { "volume", Convert.ToDecimal(r["volume_total"]) },
                        { "unite",  r["unite"] == DBNull.Value ? "" : r["unite"].ToString() }
                    });
                }
            }
        }
        Response.Write(new JavaScriptSerializer().Serialize(new { success = true, data = list }));
    }
}
