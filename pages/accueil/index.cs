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
        case "kpi": WriteKpi(); break;
        case "alerts": WriteAlerts(); break;
        case "stockAlerts": WriteStockAlerts(); break;
        case "movements": WriteMovementsChart(); break;
        case "stockByCategory": WriteStockByCategory(); break;
        case "recentMovements": WriteRecentMovements(); break;
        case "recentDocuments": WriteRecentDocuments(); break;
        case "topArticles": WriteTopArticles(); break;
        default: Response.Write("{\"success\":false,\"message\":\"Action inconnue\"}"); break;
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

      // ── Articles actifs ──
      using (SqlCommand cmd = new SqlCommand(
          "SELECT COUNT(*) FROM MARTICLE WHERE ACTIVE = 1 AND DELETION_AT IS NULL", conn))
        result["articlesActifs"] = Convert.ToInt32(cmd.ExecuteScalar());

      // ── Total articles ──
      using (SqlCommand cmd = new SqlCommand(
          "SELECT COUNT(*) FROM MARTICLE WHERE DELETION_AT IS NULL", conn))
        result["articlesTotal"] = Convert.ToInt32(cmd.ExecuteScalar());

      // ────────────────────────────────────────────────────────
      // ✅ FIX : Alertes / Ruptures calculées par article
      //    MÊME LOGIQUE QUE GetStockAlerts.ashx / page STOCK :
      //      DISPONIBLE  = SUM(SSTOCK.QUANTITE_ACTUELLE) par article
      //      ALERTE      : SEUIL_ALERTE > 0
      //                    AND DISPONIBLE > 0
      //                    AND DISPONIBLE <= SEUIL_ALERTE
      //      RUPTURE     : DISPONIBLE <= 0
      //    (On ne se fie PLUS à SSTOCK.STATUT qui n'est pas fiable.)
      // ────────────────────────────────────────────────────────
      string sqlAlertes = @"
                WITH StockAgg AS (
                    SELECT
                        a.ID AS ARTICLE_ID,
                        ISNULL(a.SEUIL_ALERTE, 0) AS SEUIL_ALERTE,
                        SUM(s.QUANTITE_ACTUELLE)  AS DISPONIBLE
                    FROM MARTICLE a
                    INNER JOIN SSTOCK s ON s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                    WHERE a.DELETION_AT IS NULL
                    GROUP BY a.ID, a.SEUIL_ALERTE
                )
                SELECT
                    SUM(CASE WHEN SEUIL_ALERTE > 0
                              AND DISPONIBLE > 0
                              AND DISPONIBLE <= SEUIL_ALERTE
                             THEN 1 ELSE 0 END) AS alertes,
                    SUM(CASE WHEN DISPONIBLE <= 0
                             THEN 1 ELSE 0 END) AS ruptures
                FROM StockAgg";

      int alertes = 0, ruptures = 0;
      using (SqlCommand cmd = new SqlCommand(sqlAlertes, conn))
      using (SqlDataReader r = cmd.ExecuteReader())
      {
        if (r.Read())
        {
          alertes = r["alertes"] == DBNull.Value ? 0 : Convert.ToInt32(r["alertes"]);
          ruptures = r["ruptures"] == DBNull.Value ? 0 : Convert.ToInt32(r["ruptures"]);
        }
        r.Close();
      }
      result["alertes"] = alertes;
      result["ruptures"] = ruptures;
      result["alertesStock"] = alertes + ruptures;  // total utilisé par valAlertes

      // ────────────────────────────────────────────────────────
      // Bons en attente (BROUILLON) → conservé pour valBons
      // ────────────────────────────────────────────────────────
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

      // ────────────────────────────────────────────────────────
      // ✅ NOUVEAU : Total des MOUVEMENTS dans MSTOCK
      //    (utilisé par pillEntree / pillSortie)
      // ────────────────────────────────────────────────────────
      string sqlMvt = @"
                SELECT
                    COUNT(CASE WHEN TYPE = 'ENTREE' THEN 1 END) AS entrees,
                    COUNT(CASE WHEN TYPE = 'SORTIE' THEN 1 END) AS sorties
                FROM MSTOCK
                WHERE DELETION_AT IS NULL";
      using (SqlCommand cmd = new SqlCommand(sqlMvt, conn))
      using (SqlDataReader r = cmd.ExecuteReader())
      {
        if (r.Read())
        {
          result["entrees"] = r["entrees"] == DBNull.Value ? 0 : Convert.ToInt32(r["entrees"]);
          result["sorties"] = r["sorties"] == DBNull.Value ? 0 : Convert.ToInt32(r["sorties"]);
        }
        r.Close();
      }

      // ────────────────────────────────────────────────────────
      // ✅ FIX : Valeur totale TTC de toutes les entrées MLENTREE
      //    Source exclusive : MLENTREE.TOTAL_TTC
      //    - SUM géré via ISNULL pour retourner 0 si aucune entrée
      //    - DELETION_AT IS NULL pour exclure les entrées supprimées
      // ────────────────────────────────────────────────────────
      string sqlValeur = @"
    SELECT ISNULL(SUM(TOTAL_TTC), 0)
    FROM MLENTREE
    WHERE DELETION_AT IS NULL";
      using (SqlCommand cmd = new SqlCommand(sqlValeur, conn))
        result["valeurStock"] = Convert.ToDecimal(cmd.ExecuteScalar());

      // ── Articles sous seuil (même logique que les alertes) ──
      string sqlSousSeuil = @"
                WITH StockAgg AS (
                    SELECT
                        a.ID AS ARTICLE_ID,
                        ISNULL(a.SEUIL_ALERTE, 0) AS SEUIL_ALERTE,
                        SUM(s.QUANTITE_ACTUELLE)  AS DISPONIBLE
                    FROM MARTICLE a
                    INNER JOIN SSTOCK s ON s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                    WHERE a.DELETION_AT IS NULL
                    GROUP BY a.ID, a.SEUIL_ALERTE
                )
                SELECT COUNT(*)
                FROM StockAgg
                WHERE SEUIL_ALERTE > 0
                  AND DISPONIBLE > 0
                  AND DISPONIBLE <= SEUIL_ALERTE";
      using (SqlCommand cmd = new SqlCommand(sqlSousSeuil, conn))
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

      // ────────────────────────────────────────────────────────
      // ✅ FIX : on ne renvoie QUE les articles en RUPTURE
      //    Règle (identique STOCK / WriteKpi) :
      //       RUPTURE  : DISPONIBLE <= 0
      //    Les articles en ALERTE sont gérés par la carte
      //    « Stock en alerte » (loadStockAlerts / GetStockAlerts.ashx).
      // ────────────────────────────────────────────────────────
      string sql = @"
            WITH StockAgg AS (
                SELECT
                    a.ID, a.CODE, a.NOM, a.SEUIL_ALERTE, a.SEUIL_MIN,
                    a.CATEGORIE_ID, a.UNITE_MESURE_ID,
                    SUM(s.QUANTITE_ACTUELLE) AS DISPONIBLE,
                    (SELECT TOP 1 s2.EMPLACEMENT_ID
                       FROM SSTOCK s2
                      WHERE s2.ARTICLE_ID = a.ID AND s2.DELETION_AT IS NULL
                      ORDER BY s2.QUANTITE_ACTUELLE DESC) AS EMPLACEMENT_ID
                FROM MARTICLE a
                INNER JOIN SSTOCK s ON s.ARTICLE_ID = a.ID AND s.DELETION_AT IS NULL
                WHERE a.DELETION_AT IS NULL
                GROUP BY a.ID, a.CODE, a.NOM, a.SEUIL_ALERTE, a.SEUIL_MIN,
                         a.CATEGORIE_ID, a.UNITE_MESURE_ID
            )
            SELECT TOP 20
                sa.CODE       AS article_code,
                sa.NOM        AS article_nom,
                c.NOM         AS categorie,
                e.NOM         AS emplacement,
                u.NOM         AS unite,
                sa.DISPONIBLE AS QUANTITE_ACTUELLE,
                ISNULL(sa.SEUIL_ALERTE, 0) AS SEUIL_ALERTE,
                ISNULL(sa.SEUIL_MIN, 0)    AS SEUIL_MIN,
                'RUPTURE'     AS STATUT
            FROM StockAgg sa
            LEFT JOIN SCATEGORIE   c ON c.ID = sa.CATEGORIE_ID
            LEFT JOIN SEMPLACEMENT e ON e.ID = sa.EMPLACEMENT_ID
            LEFT JOIN SUNITE       u ON u.ID = sa.UNITE_MESURE_ID
            WHERE sa.DISPONIBLE <= 0
            ORDER BY sa.DISPONIBLE ASC, sa.NOM ASC";

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
  // STOCK EN ALERTE (règle métier identique à la page STOCK)
  // ============================================================
  private void WriteStockAlerts()
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
                SELECT
                    a.CODE              AS ARTICLE_CODE,
                    a.NOM               AS ARTICLE_NOM,
                    c.NOM               AS CATEGORIE_NOM,
                    e.NOM               AS EMPLACEMENT_NOM,
                    u.NOM               AS UNITE_NOM,
                    s.QUANTITE_ACTUELLE AS DISPONIBLE,
                    a.SEUIL_ALERTE      AS SEUIL_ALERTE
                FROM SSTOCK s
                INNER JOIN MARTICLE a ON a.ID = s.ARTICLE_ID
                LEFT JOIN SCATEGORIE c ON c.ID = a.CATEGORIE_ID
                LEFT JOIN SEMPLACEMENT e ON e.ID = s.EMPLACEMENT_ID
                LEFT JOIN SUNITE u ON u.ID = a.UNITE_MESURE_ID
                WHERE s.DELETION_AT IS NULL
                  AND a.DELETION_AT IS NULL
                  AND a.SEUIL_ALERTE IS NOT NULL
                  AND a.SEUIL_ALERTE > 0
                  AND s.QUANTITE_ACTUELLE > 0
                  AND s.QUANTITE_ACTUELLE <= a.SEUIL_ALERTE
                ORDER BY s.QUANTITE_ACTUELLE ASC";

      using (SqlCommand cmd = new SqlCommand(sql, conn))
      using (SqlDataReader r = cmd.ExecuteReader())
      {
        while (r.Read())
        {
          list.Add(new Dictionary<string, object>
                    {
                        { "ARTICLE_CODE",    r["ARTICLE_CODE"].ToString() },
                        { "ARTICLE_NOM",     r["ARTICLE_NOM"].ToString() },
                        { "CATEGORIE_NOM",   r["CATEGORIE_NOM"]    == DBNull.Value ? "" : r["CATEGORIE_NOM"].ToString() },
                        { "EMPLACEMENT_NOM", r["EMPLACEMENT_NOM"]  == DBNull.Value ? "" : r["EMPLACEMENT_NOM"].ToString() },
                        { "UNITE_NOM",       r["UNITE_NOM"]        == DBNull.Value ? "" : r["UNITE_NOM"].ToString() },
                        { "DISPONIBLE",      Convert.ToDecimal(r["DISPONIBLE"]) },
                        { "SEUIL_ALERTE",    Convert.ToDecimal(r["SEUIL_ALERTE"]) }
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
