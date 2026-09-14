<%@ WebHandler Language="C#" Class="GetAccuseStats" %>
using System;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetAccuseStats : IHttpHandler, IRequiresSessionState
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
      ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
      return;
    }

    try
    {
      // ✅ Récupération de l'utilisateur connecté
      int userId = AuthHelper.GetUserId(ctx);

      string connStr = AuthHelper.ConnectionString;

      // ✅ UNE SEULE requête : retourne les 3 compteurs + le total
      int total = 0, valide = 0, termine = 0, pending = 0;
      int brouillon = 0, annule = 0; // non applicables sur la page ACCUSÉS

      using (var conn = new SqlConnection(connStr))
      {
        conn.Open();

        // ✅ FIX : une seule requête agrégée.
        //    - Total   = VALIDE + TERMINE (bons visibles sur la page ACCUSÉS)
        //    - Valide  = bons VALIDE (en attente de réception)
        //    - Termine = bons TERMINE (réceptionnés)
        //    - Pending = alias de Valide (à traiter)
        string sql = @"
          SELECT
            ISNULL(SUM(CASE WHEN STATUT IN ('VALIDE','TERMINE') THEN 1 ELSE 0 END), 0) AS Total,
            ISNULL(SUM(CASE WHEN STATUT = 'VALIDE'             THEN 1 ELSE 0 END), 0) AS Valide,
            ISNULL(SUM(CASE WHEN STATUT = 'TERMINE'            THEN 1 ELSE 0 END), 0) AS Termine,
            ISNULL(SUM(CASE WHEN STATUT = 'VALIDE'             THEN 1 ELSE 0 END), 0) AS Pending
          FROM SSORTIE
          WHERE CREATED_BY = @userId
            AND DELETION_AT IS NULL
            AND STATUT IN ('VALIDE','TERMINE')";

        using (var cmd = new SqlCommand(sql, conn))
        {
          cmd.Parameters.AddWithValue("@userId", userId);

          using (var reader = cmd.ExecuteReader())
          {
            if (reader.Read())
            {
              total   = ToInt32(reader["Total"]);
              valide  = ToInt32(reader["Valide"]);
              termine = ToInt32(reader["Termine"]);
              pending = ToInt32(reader["Pending"]);
            }
          }
        }
      }

      // ✅ Réponse JSON complète (toutes les clés attendues par loaders.js)
      var response = new
      {
        success = true,
        total = total,
        valide = valide,
        termine = termine,
        brouillon = brouillon,
        annule = annule,
        pending = pending
      };

      ctx.Response.Write(new JavaScriptSerializer().Serialize(response));
    }
    catch (Exception ex)
    {
      ctx.Response.StatusCode = 500;
      ctx.Response.Write(new JavaScriptSerializer().Serialize(
        new { success = false, message = ex.Message.Replace("\"", "\\\"") }));
    }
  }

  private static int ToInt32(object value)
  {
    return value == DBNull.Value || value == null ? 0 : Convert.ToInt32(value);
  }

  public bool IsReusable { get { return false; } }
}
