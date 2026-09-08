using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;

public class DataHelper : IHttpHandler
{
    public void ProcessRequest(HttpContext context)
    {
        if (!AuthHelper.RequireApiAuth(context))
        {
            context.Response.StatusCode = 401;
            context.Response.Write("{\"success\":false,\"message\":\"Non autorisé\"}");
            return;
        }

        string type = context.Request.QueryString["type"];
        var serializer = new JavaScriptSerializer();
        context.Response.ContentType = "application/json";

        if (string.IsNullOrEmpty(type))
        {
            context.Response.Write("{\"success\":false,\"message\":\"Type manquant\"}");
            return;
        }

        try
        {
            string connStr = AuthHelper.ConnectionString;
            var list = new List<object>();

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                string sql = "";
                switch (type.ToLower())
                {
                    case "categories":
                        sql = "SELECT ID, NOM FROM SCATEGORIE WHERE ACTIVE = 1 AND DELETION_AT IS NULL ORDER BY NOM";
                        break;
                    case "fournisseurs":
                        sql = "SELECT ID, NOM FROM SFOURNISSEUR WHERE ACTIVE = 1 AND DELETION_AT IS NULL ORDER BY NOM";
                        break;
                    case "unites":
                        sql = "SELECT ID, NOM FROM SUNITE WHERE ACTIVE = 1 AND DELETION_AT IS NULL ORDER BY NOM";
                        break;
                    default:
                        context.Response.Write("{\"success\":false,\"message\":\"Type non supporté\"}");
                        return;
                }

                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    using (SqlDataReader reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            list.Add(new { ID = reader["ID"].ToString(), NOM = reader["NOM"].ToString() });
                        }
                    }
                }
            }

            context.Response.Write(serializer.Serialize(new { success = true, data = list }));
        }
        catch (Exception ex)
        {
            context.Response.StatusCode = 500;
            context.Response.Write($"{{\"success\":false,\"message\":\"{ex.Message.Replace("\"", "'")}\"}}");
        }
    }

    public bool IsReusable => false;
}
