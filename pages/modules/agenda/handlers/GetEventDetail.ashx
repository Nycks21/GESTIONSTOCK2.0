<%@ WebHandler Language="C#" Class="GetEventDetail" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetEventDetail : IHttpHandler, IRequiresSessionState
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

        // ✅ Vérifier la permission agenda
        if (!AuthHelper.HasPermission("agenda"))
        {
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            if (string.IsNullOrEmpty(connStr))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Erreur de connexion\"}");
                return;
            }

            string id = ctx.Request.QueryString["id"];
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant\"}");
                return;
            }

            Dictionary<string, object> eventDetail = null;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                string sql = @"
                    SELECT 
                        ID, TEMPLATE_ID, IDUSER, TITRE, DATE_DEBUT, DATE_FIN,
                        COULEUR, HEURE_DEBUT, HEURE_FIN, DESCRIPTION,
                        TYPE, LIEU, PUBLIQUE, URL, CREATED_AT
                    FROM CALENDAREVENTS
                    WHERE ID = @id";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    using (var rdr = cmd.ExecuteReader())
                    {
                        if (rdr.Read())
                        {
                            eventDetail = new Dictionary<string, object>();
                            eventDetail["ID"] = rdr["ID"].ToString();
                            eventDetail["TEMPLATE_ID"] = rdr["TEMPLATE_ID"] != DBNull.Value ? Convert.ToInt32(rdr["TEMPLATE_ID"]) : (int?)null;
                            eventDetail["IDUSER"] = rdr["IDUSER"] != DBNull.Value ? Convert.ToInt32(rdr["IDUSER"]) : (int?)null;
                            eventDetail["TITRE"] = rdr["TITRE"] != DBNull.Value ? rdr["TITRE"].ToString() : "Sans titre";
                            eventDetail["DATE_DEBUT"] = rdr["DATE_DEBUT"] != DBNull.Value ? ((DateTime)rdr["DATE_DEBUT"]).ToString("yyyy-MM-ddTHH:mm:ss") : "";
                            eventDetail["DATE_FIN"] = rdr["DATE_FIN"] != DBNull.Value ? ((DateTime)rdr["DATE_FIN"]).ToString("yyyy-MM-ddTHH:mm:ss") : "";
                            eventDetail["COULEUR"] = rdr["COULEUR"] != DBNull.Value ? rdr["COULEUR"].ToString() : "#6f42c1";
                            eventDetail["HEURE_DEBUT"] = rdr["HEURE_DEBUT"] != DBNull.Value ? rdr["HEURE_DEBUT"].ToString() : "";
                            eventDetail["HEURE_FIN"] = rdr["HEURE_FIN"] != DBNull.Value ? rdr["HEURE_FIN"].ToString() : "";
                            eventDetail["DESCRIPTION"] = rdr["DESCRIPTION"] != DBNull.Value ? rdr["DESCRIPTION"].ToString() : "";
                            eventDetail["TYPE"] = rdr["TYPE"] != DBNull.Value ? rdr["TYPE"].ToString() : "autre";
                            eventDetail["LIEU"] = rdr["LIEU"] != DBNull.Value ? rdr["LIEU"].ToString() : "";
                            eventDetail["PUBLIQUE"] = rdr["PUBLIQUE"] != DBNull.Value ? rdr["PUBLIQUE"].ToString() : "all";
                            eventDetail["URL"] = rdr["URL"] != DBNull.Value ? rdr["URL"].ToString() : "";
                            eventDetail["CREATED_AT"] = rdr["CREATED_AT"] != DBNull.Value ? ((DateTime)rdr["CREATED_AT"]).ToString("yyyy-MM-dd HH:mm") : "";
                        }
                    }
                }
            }

            var result = new Dictionary<string, object>();
            if (eventDetail == null)
            {
                result["success"] = false;
                result["message"] = "Événement non trouvé";
            }
            else
            {
                result["success"] = true;
                result["event"] = eventDetail;
            }

            ctx.Response.Write(new JavaScriptSerializer().Serialize(result));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "\\\"") + "\"}");
        }
    }

    public bool IsReusable { get { return false; } }
}