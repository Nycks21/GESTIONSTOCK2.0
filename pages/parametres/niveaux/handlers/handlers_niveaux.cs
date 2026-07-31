// =========================================================
// GetNiveaux.ashx
// Retourne tous les niveaux depuis [NIVEAUX] en JSON
// =========================================================
/*
<%@ WebHandler Language="C#" Class="GetNiveaux" %>

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Web;

public class GetNiveaux : IHttpHandler
{
    public void ProcessRequest(HttpContext context)
    {
    // ✅ Sécurité : 4 vérifications essentielles
    
    // 1. Authentification
    if (context.Session == null || context.Session["authenticated"] == null || !(bool)context.Session["authenticated"])
    {
        context.Response.Write("{\"success\":false,\"message\":\"Non authentifié\"}");
        return;
    }
    
    // 2. Token de session valide
    if (!AuthHelper.RequireApiAuth(context))
    {
        context.Response.Write("{\"success\":false,\"message\":\"Session invalide\"}");
        return;
    }
    
    // 3. Permission (SuperAdmin = 0, Admin = 1, etc.)
    int role = AuthHelper.GetUserRole(context);
    if (role < 0 || role > 1) // Permissions minimales selon le handler
    {
        context.Response.Write("{\"success\":false,\"message\":\"Permissions insuffisantes\"}");
        return;
    }
    
    // 4. CSRF pour les méthodes POST/PUT/DELETE
    string method = context.Request.HttpMethod.ToUpper();
    if (method == "POST" || method == "PUT" || method == "DELETE")
    {
        string token = context.Request.Headers["X-CSRF-Token"];
        string sessionToken = context.Session["CSRF_TOKEN"]?.ToString();
        if (string.IsNullOrEmpty(token) || token != sessionToken)
        {
            context.Response.Write("{\"success\":false,\"message\":\"Token CSRF invalide\"}");
            return;
        }
    }
        context.Response.ContentType    = "application/json";
        context.Response.ContentEncoding = System.Text.Encoding.UTF8;

        string cs = ConfigurationManager.ConnectionStrings["MONAPPECOLE2"].ConnectionString;

        try
        {
            var list = new List<string>();

            using (var conn = new SqlConnection(cs))
            using (var cmd  = new SqlCommand(
                "SELECT ID, NOM, ORDRE, STATUT, CREATED_AT FROM NIVEAUX ORDER BY ORDRE, NOM", conn))
            {
                conn.Open();
                using (var rdr = cmd.ExecuteReader())
                {
                    while (rdr.Read())
                    {
                        list.Add(string.Format(
                            "{{\"ID\":{0},\"NOM\":{1},\"ORDRE\":{2},\"STATUT\":{3},\"CREATED_AT\":{4}}}",
                            rdr["ID"],
                            JsonStr(rdr["NOM"]),
                            rdr["ORDRE"],
                            ((bool)rdr["STATUT"]) ? "true" : "false",
                            rdr["CREATED_AT"] == DBNull.Value ? "null" : "\"" + ((DateTime)rdr["CREATED_AT"]).ToString("yyyy-MM-ddTHH:mm:ss") + "\""
                        ));
                    }
                }
            }

            context.Response.Write("{\"success\":true,\"niveaux\":[" + string.Join(",", list) + "]}");
        }
        catch (Exception ex)
        {
            context.Response.Write("{\"success\":false,\"message\":" + JsonStr(ex.Message) + "}");
        }
    }

    private string JsonStr(object v)
    {
        if (v == null || v == DBNull.Value) return "null";
        return "\"" + v.ToString().Replace("\\","\\\\").Replace("\"","\\\"").Replace("\n","\\n").Replace("\r","\\r") + "\"";
    }

    public bool IsReusable { get { return false; } }
}
*/

// =========================================================
// AjouterNiveau.ashx
// Insère un nouveau niveau dans [NIVEAUX]
// =========================================================
/*
<%@ WebHandler Language="C#" Class="AjouterNiveau" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;

public class AjouterNiveau : IHttpHandler
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType    = "application/json";
        context.Response.ContentEncoding = System.Text.Encoding.UTF8;

        try
        {
            string body    = new StreamReader(context.Request.InputStream).ReadToEnd();
            var    serial  = new JavaScriptSerializer();
            dynamic data   = serial.DeserializeObject(body);

            string nom    = (string)data["nom"];
            int    ordre  = Convert.ToInt32(data["ordre"]);
            bool   statut = Convert.ToBoolean(data["statut"]);

            if (string.IsNullOrWhiteSpace(nom))
                throw new Exception("Le nom est obligatoire.");

            string cs = ConfigurationManager.ConnectionStrings["MONAPPECOLE2"].ConnectionString;
            using (var conn = new SqlConnection(cs))
            using (var cmd  = new SqlCommand(
                "INSERT INTO NIVEAUX (NOM, ORDRE, STATUT) VALUES (@nom, @ordre, @statut)", conn))
            {
                cmd.Parameters.AddWithValue("@nom",    nom.Trim());
                cmd.Parameters.AddWithValue("@ordre",  ordre);
                cmd.Parameters.AddWithValue("@statut", statut);
                conn.Open();
                cmd.ExecuteNonQuery();
            }

            context.Response.Write("{\"success\":true}");
        }
        catch (Exception ex)
        {
            string msg = ex.Message.Contains("UNIQUE") || ex.Message.Contains("UQ_")
                ? "Ce nom de niveau existe déjà."
                : ex.Message;
            context.Response.Write("{\"success\":false,\"message\":\"" + msg.Replace("\"","'") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}
*/

// =========================================================
// ModifierNiveau.ashx
// Met à jour un niveau existant dans [NIVEAUX]
// =========================================================
/*
<%@ WebHandler Language="C#" Class="ModifierNiveau" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;

public class ModifierNiveau : IHttpHandler
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType    = "application/json";
        context.Response.ContentEncoding = System.Text.Encoding.UTF8;

        try
        {
            string  body   = new StreamReader(context.Request.InputStream).ReadToEnd();
            var     serial = new JavaScriptSerializer();
            dynamic data   = serial.DeserializeObject(body);

            int    id     = Convert.ToInt32(data["id"]);
            string nom    = (string)data["nom"];
            int    ordre  = Convert.ToInt32(data["ordre"]);
            bool   statut = Convert.ToBoolean(data["statut"]);

            if (string.IsNullOrWhiteSpace(nom))
                throw new Exception("Le nom est obligatoire.");

            string cs = ConfigurationManager.ConnectionStrings["MONAPPECOLE2"].ConnectionString;
            using (var conn = new SqlConnection(cs))
            using (var cmd  = new SqlCommand(
                "UPDATE NIVEAUX SET NOM=@nom, ORDRE=@ordre, STATUT=@statut WHERE ID=@id", conn))
            {
                cmd.Parameters.AddWithValue("@id",     id);
                cmd.Parameters.AddWithValue("@nom",    nom.Trim());
                cmd.Parameters.AddWithValue("@ordre",  ordre);
                cmd.Parameters.AddWithValue("@statut", statut);
                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0) throw new Exception("Niveau introuvable.");
            }

            context.Response.Write("{\"success\":true}");
        }
        catch (Exception ex)
        {
            string msg = ex.Message.Contains("UNIQUE") || ex.Message.Contains("UQ_")
                ? "Ce nom de niveau existe déjà."
                : ex.Message;
            context.Response.Write("{\"success\":false,\"message\":\"" + msg.Replace("\"","'") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}
*/

// =========================================================
// SupprimerNiveau.ashx
// Supprime un niveau de [NIVEAUX]
// =========================================================
/*
<%@ WebHandler Language="C#" Class="SupprimerNiveau" %>

using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Script.Serialization;

public class SupprimerNiveau : IHttpHandler
{
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType    = "application/json";
        context.Response.ContentEncoding = System.Text.Encoding.UTF8;

        try
        {
            string  body   = new StreamReader(context.Request.InputStream).ReadToEnd();
            var     serial = new JavaScriptSerializer();
            dynamic data   = serial.DeserializeObject(body);

            int id = Convert.ToInt32(data["id"]);

            string cs = ConfigurationManager.ConnectionStrings["MONAPPECOLE2"].ConnectionString;
            using (var conn = new SqlConnection(cs))
            using (var cmd  = new SqlCommand("DELETE FROM NIVEAUX WHERE ID=@id", conn))
            {
                cmd.Parameters.AddWithValue("@id", id);
                conn.Open();
                int rows = cmd.ExecuteNonQuery();
                if (rows == 0) throw new Exception("Niveau introuvable.");
            }

            context.Response.Write("{\"success\":true}");
        }
        catch (Exception ex)
        {
            context.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"","'") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}
*/
