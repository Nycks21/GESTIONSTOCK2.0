<%@ WebHandler Language="C#" Class="MoveEmploi" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class MoveEmploi : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";

        // ✅ Sécurité centralisée (Admin ou SuperAdmin)
        if (!AuthHelper.RequireApiAuth(ctx, 1))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        string classe = ctx.Request.QueryString["classe"];
        string sourceDay = ctx.Request.QueryString["sourceDay"];
        string sourceHour = ctx.Request.QueryString["sourceHour"];
        string targetDay = ctx.Request.QueryString["targetDay"];
        string targetHour = ctx.Request.QueryString["targetHour"];
        string swapParam = ctx.Request.QueryString["swap"] ?? "false";
        bool swap = swapParam.ToLower() == "true";

        if (string.IsNullOrEmpty(classe) || string.IsNullOrEmpty(sourceDay) || string.IsNullOrEmpty(sourceHour) ||
            string.IsNullOrEmpty(targetDay) || string.IsNullOrEmpty(targetHour))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Paramètres manquants\"}");
            return;
        }

        string connStr = AuthHelper.ConnectionString;
        if (string.IsNullOrEmpty(connStr))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
            return;
        }

        try
        {
            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                if (swap)
                {
                    var source = GetCell(conn, classe, sourceDay, sourceHour);
                    var target = GetCell(conn, classe, targetDay, targetHour);
                    UpdateCell(conn, classe, sourceDay, sourceHour, target);
                    UpdateCell(conn, classe, targetDay, targetHour, source);
                }
                else
                {
                    DeleteCell(conn, classe, targetDay, targetHour);
                    MoveCell(conn, classe, sourceDay, sourceHour, targetDay, targetHour);
                }
            }

            ctx.Response.Write("{\"success\":true,\"message\":\"Emploi déplacé avec succès\"}");
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    private dynamic GetCell(SqlConnection conn, string classe, string jour, string heureDebut)
    {
        string sql = "SELECT HEURE_FIN, MATIERE_ID, PROFESSEUR, SALLE, COULEUR, TYPE, URL, DESCRIPTION FROM EMPLOI_TEMPS WHERE CLASSE_ID = @classe AND JOUR = @jour AND HEURE_DEBUT = @heureDebut";
        using (var cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@classe", classe);
            cmd.Parameters.AddWithValue("@jour", jour);
            cmd.Parameters.AddWithValue("@heureDebut", heureDebut);
            using (var rdr = cmd.ExecuteReader())
            {
                if (rdr.Read())
                {
                    return new
                    {
                        heureFin = rdr["HEURE_FIN"] == DBNull.Value ? null : rdr["HEURE_FIN"].ToString(),
                        matiere = rdr["MATIERE_ID"].ToString(),
                        prof = rdr["PROFESSEUR"] == DBNull.Value ? "" : rdr["PROFESSEUR"].ToString(),
                        salle = rdr["SALLE"] == DBNull.Value ? "" : rdr["SALLE"].ToString(),
                        couleur = rdr["COULEUR"] == DBNull.Value ? "#007bff" : rdr["COULEUR"].ToString(),
                        type = rdr["TYPE"] == DBNull.Value ? "cours" : rdr["TYPE"].ToString(),
                        url = rdr["URL"] == DBNull.Value ? "" : rdr["URL"].ToString(),
                        description = rdr["DESCRIPTION"] == DBNull.Value ? "" : rdr["DESCRIPTION"].ToString()
                    };
                }
                return null;
            }
        }
    }

    private void UpdateCell(SqlConnection conn, string classe, string jour, string heureDebut, dynamic cell)
    {
        if (cell == null)
        {
            DeleteCell(conn, classe, jour, heureDebut);
            return;
        }

        string sql = @"
            UPDATE EMPLOI_TEMPS SET
                HEURE_FIN = @heureFin,
                MATIERE_ID = @matiere,
                PROFESSEUR = @prof,
                SALLE = @salle,
                COULEUR = @couleur,
                TYPE = @type,
                URL = @url,
                DESCRIPTION = @description,
                UPDATED_AT = GETDATE()
            WHERE CLASSE_ID = @classe AND JOUR = @jour AND HEURE_DEBUT = @heureDebut";
        using (var cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@heureFin", (object)cell.heureFin ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@matiere", cell.matiere);
            cmd.Parameters.AddWithValue("@prof", (object)cell.prof ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@salle", (object)cell.salle ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@couleur", (object)cell.couleur ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@type", (object)cell.type ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@url", (object)cell.url ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@description", (object)cell.description ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@classe", classe);
            cmd.Parameters.AddWithValue("@jour", jour);
            cmd.Parameters.AddWithValue("@heureDebut", heureDebut);
            cmd.ExecuteNonQuery();
        }
    }

    private void DeleteCell(SqlConnection conn, string classe, string jour, string heureDebut)
    {
        string sql = "DELETE FROM EMPLOI_TEMPS WHERE CLASSE_ID = @classe AND JOUR = @jour AND HEURE_DEBUT = @heureDebut";
        using (var cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@classe", classe);
            cmd.Parameters.AddWithValue("@jour", jour);
            cmd.Parameters.AddWithValue("@heureDebut", heureDebut);
            cmd.ExecuteNonQuery();
        }
    }

    private void MoveCell(SqlConnection conn, string classe, string sourceJour, string sourceHeure, string targetJour, string targetHeure)
    {
        var source = GetCell(conn, classe, sourceJour, sourceHeure);
        if (source == null) return;

        DeleteCell(conn, classe, sourceJour, sourceHeure);

        string sql = @"
            INSERT INTO EMPLOI_TEMPS (CLASSE_ID, JOUR, HEURE_DEBUT, HEURE_FIN, MATIERE_ID, PROFESSEUR, SALLE, COULEUR, TYPE, URL, DESCRIPTION, CREATED_AT)
            VALUES (@classe, @jour, @heureDebut, @heureFin, @matiere, @prof, @salle, @couleur, @type, @url, @description, GETDATE())";
        using (var cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@classe", classe);
            cmd.Parameters.AddWithValue("@jour", targetJour);
            cmd.Parameters.AddWithValue("@heureDebut", targetHeure);
            cmd.Parameters.AddWithValue("@heureFin", (object)source.heureFin ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@matiere", source.matiere);
            cmd.Parameters.AddWithValue("@prof", (object)source.prof ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@salle", (object)source.salle ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@couleur", (object)source.couleur ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@type", (object)source.type ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@url", (object)source.url ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@description", (object)source.description ?? DBNull.Value);
            cmd.ExecuteNonQuery();
        }
    }

    public bool IsReusable { get { return false; } }
}