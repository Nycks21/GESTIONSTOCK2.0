<%@ WebHandler Language="C#" Class="FournisseurAdd" %>

using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class FournisseurAdd : IHttpHandler, IRequiresSessionState
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
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            // ⚠️ Le CODE n'est plus envoyé par le client : il est généré côté serveur.
            string nom = GetString(data, "nom");
            string adresse = GetString(data, "adresse");
            string telephone = GetString(data, "telephone");
            string email = GetString(data, "email");
            string contactNom = GetString(data, "contactNom");
            string contactTelephone = GetString(data, "contactTelephone");
            string siret = GetString(data, "siret");
            bool actif = GetBool(data, "actif", true);

            if (string.IsNullOrEmpty(nom))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le nom est obligatoire.\"}");
                return;
            }

            // 🔑 Récupération du code projet (Web.config : ProjectCode)
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

                using (SqlTransaction tx = conn.BeginTransaction())
                {
                    try
                    {
                        // -----------------------------------------------------------
                        // 1) Génération atomique du numéro de séquence pour le projet
                        //    UPDLOCK + HOLDLOCK verrouillent la ligne jusqu'au COMMIT
                        // -----------------------------------------------------------
                        string sqlSeq = @"
                            IF NOT EXISTS (
                                SELECT 1 FROM SFOURNISSEUR_SEQUENCE WITH (UPDLOCK, HOLDLOCK)
                                WHERE PROJET_CODE = @projet
                            )
                            BEGIN
                                INSERT INTO SFOURNISSEUR_SEQUENCE (PROJET_CODE, DERNIER_NUMERO)
                                VALUES (@projet, 0);
                            END

                            UPDATE SFOURNISSEUR_SEQUENCE
                            SET DERNIER_NUMERO = DERNIER_NUMERO + 1
                            OUTPUT INSERTED.DERNIER_NUMERO
                            WHERE PROJET_CODE = @projet;";

                        int numero;
                        using (var cmdSeq = new SqlCommand(sqlSeq, conn, tx))
                        {
                            cmdSeq.Parameters.AddWithValue("@projet", projetCode);
                            object scalar = cmdSeq.ExecuteScalar();
                            numero = Convert.ToInt32(scalar);
                        }

                        // -----------------------------------------------------------
                        // 2) Construction du code : FO-{PROJET}-{00001}
                        // -----------------------------------------------------------
                        code = string.Format("FRS-{0}-{1:D5}", projetCode, numero);

                        // -----------------------------------------------------------
                        // 3) Vérification anti-doublon (ceinture + bretelles)
                        // -----------------------------------------------------------
                        using (var cmdCheck = new SqlCommand(
                            "SELECT COUNT(1) FROM SFOURNISSEUR WHERE CODE = @code", conn, tx))
                        {
                            cmdCheck.Parameters.AddWithValue("@code", code);
                            int exists = Convert.ToInt32(cmdCheck.ExecuteScalar());
                            if (exists > 0)
                                throw new Exception("Le code généré existe déjà, veuillez réessayer.");
                        }

                        // -----------------------------------------------------------
                        // 4) Insertion du fournisseur
                        // -----------------------------------------------------------
                        string sqlInsert = @"
                            INSERT INTO SFOURNISSEUR
                                (ID, CODE, NOM, ADRESSE, TELEPHONE, EMAIL, CONTACT_NOM, CONTACT_TELEPHONE, SIRET, ACTIVE, CREATED_BY, CREATED_AT)
                            VALUES
                                (@id, @code, @nom, @adresse, @telephone, @email, @contactNom, @contactTelephone, @siret, @actif, @userId, GETDATE())";

                        using (var cmd = new SqlCommand(sqlInsert, conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", newId);
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@nom", nom);
                            cmd.Parameters.AddWithValue("@adresse", (object)adresse ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@telephone", (object)telephone ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@email", (object)email ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@contactNom", (object)contactNom ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@contactTelephone", (object)contactTelephone ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@siret", (object)siret ?? DBNull.Value);
                            cmd.Parameters.AddWithValue("@actif", actif ? 1 : 0);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            cmd.ExecuteNonQuery();
                        }

                        tx.Commit();
                    }
                    catch
                    {
                        try { tx.Rollback(); } catch { /* ignore */ }
                        throw;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new
            {
                success = true,
                id = newId,
                code = code,
                message = "Fournisseur ajouté avec succès (" + code + ")."
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
            }));
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        if (data.ContainsKey(key) && data[key] != null)
            return data[key].ToString();
        return null;
    }

    private bool GetBool(Dictionary<string, object> data, string key, bool defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool val;
            if (bool.TryParse(data[key].ToString(), out val))
                return val;
        }
        return defaultValue;
    }

    public bool IsReusable
    {
        get { return false; }
    }
}
