using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Web;
using System.Data.SqlClient;
using System.Configuration;
using System.Security.Cryptography;
using System.Drawing;
using System.Globalization;
using System.Web.UI;
using System.Collections.Generic;

public partial class Login : Page
{
    string connStr = "";

    const int MAX_ATTEMPTS = 5;
    const int LOCKOUT_SECONDS = 60;
    const string SK_ATTEMPTS = "login_attempts";
    const string SK_LOCKOUT_END = "login_lockout_end";

    protected void Page_Load(object sender, EventArgs e)
    {
        connStr = AuthHelper.ConnectionString;

        if (!IsPostBack && AuthHelper.IsAuthenticated(Context))
        {
            Response.Redirect("~/pages/accueil/index.aspx", true);
            return;
        }

        if (!IsPostBack)
        {
            HideMessages();

            if (!TestDatabaseConnection())
            {
                ShowError("Connexion à la base de données impossible. Veuillez contacter l'administrateur.");
                return;
            }

            var licenceInfo = AuthHelper.GetLicenceInfo();

            if (!licenceInfo.IsValid)
            {
                lblLicenceInfo.Text = licenceInfo.IsExpired
                    ? "❌ Licence expirée depuis le " + licenceInfo.ExpirationDate.ToString("dd/MM/yyyy")
                    : "❌ Licence invalide.";
                lblLicenceInfo.ForeColor = Color.Red;
                lblLicenceInfo.Font.Bold = true;
                lblLicenceInfo.Visible = true;
                return;
            }

            int daysLeft = licenceInfo.DaysLeft;
            int[] alertDays = { 45, 15, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 };

            if (alertDays.Contains(daysLeft))
            {
                if (daysLeft == 0)
                    lblLicenceInfo.Text = "⚠️ La licence expire aujourd'hui.";
                else if (daysLeft == 1)
                    lblLicenceInfo.Text = "⚠️ La licence expire demain.";
                else
                    lblLicenceInfo.Text = "⚠️ La licence expirera dans " + daysLeft + " jours.";

                lblLicenceInfo.ForeColor = Color.OrangeRed;
                lblLicenceInfo.Visible = true;
            }

            if (AuthHelper.IsMaxUsersReached())
            {
                lblUserLimitInfo.Text = "❌ Nombre maximum d'utilisateurs atteint (" + licenceInfo.MaxUsers + ").";
                lblUserLimitInfo.ForeColor = Color.Red;
                lblUserLimitInfo.Font.Bold = true;
                lblUserLimitInfo.Visible = true;
            }

            string msg = Request.QueryString["msg"];
            if (msg == "maintenance") ShowNotification("Vous avez été déconnecté pour cause de maintenance.", "warning");
            else if (msg == "disconnected") ShowNotification("Vous avez été déconnecté par l'administrateur.", "info");
            else if (msg == "session_expired") ShowNotification("Votre session a expiré. Veuillez vous reconnecter.", "warning");
            else if (msg == "session_error") ShowNotification("Erreur de session. Veuillez vous reconnecter.", "error");
            else if (msg == "blocked") ShowNotification("Compte bloqué temporairement. Réessayez dans 1 minute.", "error");
            else if (msg == "other_pc") ShowNotification("Déconnecté car une autre session a été ouverte.", "warning");
        }
    }

    private bool TestDatabaseConnection()
    {
        try
        {
            if (string.IsNullOrEmpty(connStr))
            {
                System.Diagnostics.Debug.WriteLine("❌ Chaîne de connexion vide");
                return false;
            }

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                conn.Close();
                return true;
            }
        }
        catch (SqlException sqlEx)
        {
            System.Diagnostics.Debug.WriteLine("❌ Erreur SQL: " + sqlEx.Message);
            if (sqlEx.Number == 53) ShowError("❌ Serveur SQL introuvable.");
            else if (sqlEx.Number == 18456) ShowError("❌ Identifiants invalides.");
            else if (sqlEx.Number == 4060) ShowError("❌ Base de données inaccessible.");
            else ShowError("❌ Erreur de connexion: " + sqlEx.Message);
            return false;
        }
        catch (Exception ex)
        {
            ShowError("❌ Erreur de connexion: " + ex.Message);
            return false;
        }
    }

    // ============================================================
    // NOTIFICATIONS
    // ============================================================
    private void ShowNotification(string message, string type = "info")
    {
        string script = "showNotification('" + EscapeForJs(message) + "', '" + type + "');";
        ScriptManager.RegisterStartupScript(this, GetType(), "toast_" + Guid.NewGuid().ToString(), script, true);
    }

    private void ShowSuccessNotification(string message)
    {
        string script = "showLoginSuccessNotification('" + EscapeForJs(message) + "');";
        ScriptManager.RegisterStartupScript(this, GetType(), "successToast_" + Guid.NewGuid().ToString(), script, true);
    }

    private string EscapeForJs(string text)
    {
        if (string.IsNullOrEmpty(text)) return "";
        return text.Replace("\\", "\\\\").Replace("'", "\\'").Replace("\r", "").Replace("\n", " ");
    }

    // ============================================================
    // M7 — JOURNALISATION DES TENTATIVES DE CONNEXION
    // ------------------------------------------------------------
    // Chaque tentative (succès ou échec) est enregistrée dans LOGIN_LOG
    // avec l'IP, le User-Agent et la raison.
    // Ne casse jamais la connexion en cas d'échec d'insertion.
    // ============================================================
    private void LogLoginAttempt(string username, bool success, string reason = null)
    {
        try
        {
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                string sql = @"INSERT INTO LOGIN_LOG (USERNAME, IP_ADDRESS, SUCCESS, ATTEMPTED_AT, USER_AGENT, REASON)
                               VALUES (@Username, @IP, @Success, GETDATE(), @UA, @Reason)";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@Username",
                        string.IsNullOrEmpty(username) ? (object)DBNull.Value : username);

                    string ip = Request.UserHostAddress ?? "";
                    cmd.Parameters.AddWithValue("@IP", ip.Length > 45 ? ip.Substring(0, 45) : ip);

                    cmd.Parameters.AddWithValue("@Success", success ? 1 : 0);

                    string ua = Request.UserAgent ?? "";
                    cmd.Parameters.AddWithValue("@UA", ua.Length > 500 ? ua.Substring(0, 500) : ua);

                    cmd.Parameters.AddWithValue("@Reason",
                        string.IsNullOrEmpty(reason) ? (object)DBNull.Value : reason);

                    conn.Open();
                    cmd.ExecuteNonQuery();
                }
            }
        }
        catch
        {
            // Le log ne doit jamais casser la connexion
        }
    }

    // ============================================================
    // CONNEXION
    // ============================================================
    protected void btnLogin_Click(object sender, EventArgs e)
    {
        if (!TestDatabaseConnection())
        {
            ShowError("Connexion à la base de données impossible.");
            return;
        }

        DateTime lockoutEnd = Session[SK_LOCKOUT_END] as DateTime? ?? DateTime.MinValue;
        if (DateTime.Now < lockoutEnd)
        {
            int secondsLeft = (int)Math.Ceiling((lockoutEnd - DateTime.Now).TotalSeconds);
            ShowError("⛔ Trop de tentatives. Réessayez dans " + secondsLeft + "s.");
            StartCountdownScript(secondsLeft);
            return;
        }
        else if (lockoutEnd != DateTime.MinValue)
        {
            Session.Remove(SK_ATTEMPTS);
            Session.Remove(SK_LOCKOUT_END);
        }

        var licenceInfo = AuthHelper.GetLicenceInfo();
        if (!licenceInfo.IsValid)
        {
            ShowError("Licence non valide.");
            return;
        }

        if (AuthHelper.IsMaxUsersReached())
        {
            ShowError("Nombre maximum d'utilisateurs atteint (" + licenceInfo.MaxUsers + ").");
            return;
        }

        string usernameOrEmail = txtUsername.Text.Trim();
        string password = txtPassword.Text.Trim();

        int idUser, roleId;
        string nomComplet, errorMessage;
        int minutesLeft = 0;
        bool accountNotFound = false;
        bool accountDeleted = false;
        bool accountInactive = false;

        if (!AuthenticateUser(usernameOrEmail, password,
                              out idUser, out roleId, out nomComplet,
                              out errorMessage, out minutesLeft,
                              out accountNotFound, out accountDeleted, out accountInactive))
        {
            // ============================================================
            // CAS 1 : COMPTE INEXISTANT
            // ============================================================
            if (accountNotFound)
            {
                LogLoginAttempt(usernameOrEmail, false, "Compte inexistant - CX2100");
                ShowError("Nom d'utilisateur ou mot de passe incorrect - ERROR CX2100");
                return;
            }

            // ============================================================
            // CAS 2 : COMPTE SUPPRIMÉ
            // ============================================================
            if (accountDeleted)
            {
                LogLoginAttempt(usernameOrEmail, false, "Compte supprimé - CX7898");
                ShowError("Nom d'utilisateur ou mot de passe incorrect - ERROR CX7898");
                return;
            }

            // ============================================================
            // CAS 3 : COMPTE INACTIF
            // ============================================================
            if (accountInactive)
            {
                LogLoginAttempt(usernameOrEmail, false, "Compte inactif - CX4561");
                ShowError("Nom d'utilisateur ou mot de passe incorrect - ERROR CX4561");
                return;
            }

            // ============================================================
            // CAS 4 : MOT DE PASSE INCORRECT (SEUL CAS AVEC COMPTEUR)
            // ============================================================
            int attempts = (Session[SK_ATTEMPTS] as int? ?? 0) + 1;
            Session[SK_ATTEMPTS] = attempts;

            if (attempts >= MAX_ATTEMPTS)
            {
                Session[SK_LOCKOUT_END] = DateTime.Now.AddSeconds(LOCKOUT_SECONDS);
                Session[SK_ATTEMPTS] = 0;
                LogLoginAttempt(usernameOrEmail, false, "Verrouillage après " + MAX_ATTEMPTS + " échecs");
                ShowError("⛔ Compte bloqué après " + MAX_ATTEMPTS + " échecs. Réessayez dans " + LOCKOUT_SECONDS + "s.");
                StartCountdownScript(LOCKOUT_SECONDS);
            }
            else
            {
                if (errorMessage.Contains("bloqué") && minutesLeft > 0)
                {
                    LogLoginAttempt(usernameOrEmail, false, "Bloqué maintenance: " + minutesLeft + " min");
                    ShowError("⚠️ Compte bloqué. Maintenance en cours. Réessayez dans " + minutesLeft + " min.");
                }
                else
                {
                    LogLoginAttempt(usernameOrEmail, false, "Mot de passe incorrect (tentative " + attempts + ")");
                    ShowError(errorMessage + " — " + (MAX_ATTEMPTS - attempts) + " tentative(s) restante(s).");
                }
            }
            return;
        }

        // ════════════════════════════════════════════════════════════
        // ✅ AUTHENTIFICATION RÉUSSIE
        // ════════════════════════════════════════════════════════════

        // M7 — Log succès
        LogLoginAttempt(usernameOrEmail, true, "Connexion réussie");

        ShowSuccessNotification("Bienvenue " + nomComplet + " !");
        Session.Remove(SK_ATTEMPTS);
        Session.Remove(SK_LOCKOUT_END);

        string newToken = Guid.NewGuid().ToString();
        string currentPC = Environment.MachineName;

        try
        {
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                string sql = @"UPDATE USERS
                               SET SESSION_TOKEN = @token,
                                   LAST_LOGIN    = GETDATE(),
                                   LAST_PC       = @pc
                               WHERE IDUSER = @id";
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@token", newToken);
                    cmd.Parameters.AddWithValue("@pc", currentPC);
                    cmd.Parameters.AddWithValue("@id", idUser);
                    conn.Open();
                    cmd.ExecuteNonQuery();
                }
            }
        }
        catch (Exception ex)
        {
            ShowError("❌ Erreur lors de la connexion: " + ex.Message);
            return;
        }

        // Préparer les données de session à transférer
        var classesAutorisees = "[]";
        var matieresAutorisees = "[]";

        if (roleId == 3)
        {
            var serializer = new System.Web.Script.Serialization.JavaScriptSerializer();
            classesAutorisees  = serializer.Serialize(GetClassesForProfessor(idUser));
            matieresAutorisees = serializer.Serialize(GetMatieresForProfessor(idUser));
        }

        var authData = new Dictionary<string, object>
        {
            { "authenticated", true },
            { "IDUSER", idUser },
            { "username", nomComplet },
            { "USERROLE", roleId },
            { "SESSION_TOKEN", newToken },
            { "PC", currentPC },
            { "ClassesAutorisees", classesAutorisees },
            { "MatieresAutorisees", matieresAutorisees }
        };

        // ════════════════════════════════════════════════════════════
        // C4 — RÉGÉNÉRATION DE SESSION (ANTI SESSION FIXATION)
        // ------------------------------------------------------------
        // 1. Stocker les données d'auth dans le Cache serveur (60s)
        // 2. Abandonner la session actuelle (détruit l'ancien SessionId)
        // 3. Supprimer le cookie côté client
        // 4. Rediriger vers EstablishSession.aspx qui reconstruit la session
        //    → nouvelle session, nouveau SessionId, mêmes données
        // ════════════════════════════════════════════════════════════

        string transferToken = AuthHelper.StorePendingAuth(authData);

        Session.Clear();
        Session.RemoveAll();
        Session.Abandon();

        if (Request.Cookies["ASP.NET_SessionId"] != null)
        {
            var expiredCookie = new HttpCookie("ASP.NET_SessionId", "");
            expiredCookie.Expires = DateTime.Now.AddYears(-1);
            expiredCookie.HttpOnly = true;
            expiredCookie.Secure = Request.IsSecureConnection;
            Response.Cookies.Set(expiredCookie);
        }

        string redirectScript = @"
            sessionStorage.setItem('loginToast', 'success|Authentification réussie - Bienvenue !');
            setTimeout(function() {
                window.isRedirecting = true;
                window.location.href = '/pages/accueil/EstablishSession.aspx?t=" + transferToken + @"';
            }, 1500);";
        ScriptManager.RegisterStartupScript(this, GetType(), "redirectAfterLogin", redirectScript, true);
    }

    // ============================================================
    // COMPTES À REBOURS
    // ============================================================
    private void StartLoginCountdown(int seconds)
    {
        string script = @"
            (function() {
                var btn = document.getElementById('" + btnLogin.ClientID + @"');
                if (!btn) return;
                var remaining = " + seconds + @";
                var originalText = btn.value;
                btn.disabled = true;
                btn.style.opacity = '0.6';
                btn.style.cursor = 'not-allowed';
                btn.style.backgroundColor = '#6c757d';
                var interval = setInterval(function() {
                    remaining--;
                    if (remaining <= 0) {
                        clearInterval(interval);
                        btn.disabled = false;
                        btn.style.opacity = '1';
                        btn.style.cursor = 'pointer';
                        btn.style.backgroundColor = '#28a745';
                        btn.style.animation = 'pulse-green 1.5s infinite';
                        btn.value = originalText;
                        if (typeof showNotification === 'function') {
                            showNotification('Vous pouvez maintenant vous connecter', 'success', 3000);
                        }
                    } else {
                        var minutes = Math.floor(remaining / 60);
                        var secs = remaining % 60;
                        if (minutes > 0) {
                            btn.value = '⏳ Patientez ' + minutes + ' min ' + secs + 's';
                        } else {
                            btn.value = '⏳ Patientez ' + secs + 's';
                        }
                    }
                }, 1000);
            })();";
        ScriptManager.RegisterStartupScript(this, GetType(), "loginCountdown", script, true);
    }

    private void StartCountdownScript(int secondsLeft)
    {
        string script = @"
            (function() {
                var btn = document.getElementById('" + btnLogin.ClientID + @"');
                if (!btn) return;
                btn.disabled = true;
                btn.style.opacity = '0.6';
                btn.style.cursor = 'not-allowed';
                var remaining = " + secondsLeft + @";
                var orig = btn.value;
                btn.value = '⏳ Patienter ' + remaining + 's';
                var iv = setInterval(function() {
                    remaining--;
                    if (remaining <= 0) {
                        clearInterval(iv);
                        btn.disabled = false;
                        btn.style.opacity = '1';
                        btn.style.cursor = 'pointer';
                        btn.value = orig;
                    } else {
                        btn.value = '⏳ Patienter ' + remaining + 's';
                    }
                }, 1000);
            })();";
        ScriptManager.RegisterStartupScript(this, GetType(), "lockoutCountdown", script, true);
    }

    // ============================================================
    // AUTHENTIFICATION LOCALE
    // ============================================================
    private bool AuthenticateUser(string usernameOrEmail, string password,
                                  out int idUser, out int roleId, out string nomComplet,
                                  out string errorMessage, out int minutesLeft,
                                  out bool accountNotFound, out bool accountDeleted, out bool accountInactive)
    {
        idUser = 0;
        roleId = 0;
        nomComplet = "";
        errorMessage = "";
        minutesLeft = 0;
        accountNotFound = false;
        accountDeleted = false;
        accountInactive = false;

        try
        {
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                bool hasBlockedUntilColumn = false;
                string checkColumnSql = @"
                    SELECT COUNT(*)
                    FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'BLOCKED_UNTIL'";
                using (SqlCommand checkCmd = new SqlCommand(checkColumnSql, conn))
                {
                    conn.Open();
                    hasBlockedUntilColumn = (int)checkCmd.ExecuteScalar() > 0;
                    conn.Close();
                }

                string sql = @"SELECT IDUSER, ROLEID, ACTIVE, NOM, PWD, DELETION_AT";
                if (hasBlockedUntilColumn) sql += ", BLOCKED_UNTIL";
                sql += " FROM USERS WHERE USERNAME = @u OR EMAIL = @u";

                SqlCommand cmd = new SqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@u", usernameOrEmail);

                conn.Open();
                using (SqlDataReader rd = cmd.ExecuteReader())
                {
                    if (!rd.Read())
                    {
                        accountNotFound = true;
                        errorMessage = "Nom d'utilisateur ou mot de passe incorrect - ERROR CX2100";
                        return false;
                    }

                    if (rd["DELETION_AT"] != DBNull.Value)
                    {
                        accountDeleted = true;
                        errorMessage = "Nom d'utilisateur ou mot de passe incorrect - ERROR CX7898";
                        return false;
                    }

                    bool isActive = Convert.ToInt32(rd["ACTIVE"]) == 1;
                    if (!isActive)
                    {
                        accountInactive = true;
                        errorMessage = "Nom d'utilisateur ou mot de passe incorrect - ERROR CX4561";
                        return false;
                    }

                    string storedPwd = rd["PWD"] != DBNull.Value ? rd["PWD"].ToString() : "";
                    bool needsRehash;
                    if (!PasswordHelper.VerifyPassword(storedPwd, password, out needsRehash))
                    {
                        errorMessage = "Nom d'utilisateur ou mot de passe incorrect";
                        return false;
                    }

                    idUser = Convert.ToInt32(rd["IDUSER"]);
                    roleId = Convert.ToInt32(rd["ROLEID"]);
                    nomComplet = rd["NOM"].ToString();

                    if (needsRehash)
                    {
                        UpgradePasswordHash(idUser, password);
                    }

                    if (roleId != 0 && hasBlockedUntilColumn && rd["BLOCKED_UNTIL"] != DBNull.Value)
                    {
                        DateTime blockedUntil = Convert.ToDateTime(rd["BLOCKED_UNTIL"]);
                        if (blockedUntil > DateTime.Now)
                        {
                            minutesLeft = (int)Math.Ceiling((blockedUntil - DateTime.Now).TotalMinutes);
                            errorMessage = "⚠️ Compte bloqué. Maintenance en cours. Réessayez dans " + minutesLeft + " min.";
                            return false;
                        }
                    }
                    return true;
                }
            }
        }
        catch (SqlException sqlEx)
        {
            errorMessage = "❌ Erreur SQL: " + sqlEx.Message;
            return false;
        }
        catch (Exception ex)
        {
            errorMessage = "❌ Erreur: " + ex.Message;
            return false;
        }
    }

    private void UpgradePasswordHash(int userId, string plainPassword)
    {
        try
        {
            string hashed = PasswordHelper.HashPassword(plainPassword);
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                using (SqlCommand cmd = new SqlCommand("UPDATE USERS SET PWD = @p WHERE IDUSER = @id", conn))
                {
                    cmd.Parameters.AddWithValue("@p", hashed);
                    cmd.Parameters.AddWithValue("@id", userId);
                    conn.Open();
                    cmd.ExecuteNonQuery();
                }
            }
        }
        catch { }
    }

    // ============================================================
    // MÉTHODES PROFESSEUR
    // ============================================================
    private List<object> GetClassesForProfessor(int professeurId)
    {
        var classes = new List<object>();
        try
        {
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                string sql = @"SELECT DISTINCT c.ID, c.NOM
                            FROM CLASSES c
                            INNER JOIN MATIERES m ON m.CLASSE_ID = c.ID
                            WHERE m.ENSEIGNANT = @professeurId
                            ORDER BY c.NOM";
                SqlCommand cmd = new SqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@professeurId", professeurId);
                conn.Open();
                SqlDataReader reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    classes.Add(new { ID = reader["ID"].ToString(), NOM = reader["NOM"].ToString() });
                }
            }
        }
        catch { }
        return classes;
    }

    private List<object> GetMatieresForProfessor(int professeurId)
    {
        var matieres = new List<object>();
        try
        {
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                string sql = @"SELECT m.ID, m.NOM, m.COEFFICIENT, m.CLASSE_ID, c.NOM AS CLASSE_NOM
                            FROM MATIERES m
                            INNER JOIN CLASSES c ON m.CLASSE_ID = c.ID
                            WHERE m.ENSEIGNANT = @professeurId
                            ORDER BY c.NOM, m.NOM";
                SqlCommand cmd = new SqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@professeurId", professeurId);
                conn.Open();
                SqlDataReader reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    matieres.Add(new
                    {
                        ID = reader["ID"].ToString(),
                        NOM = reader["NOM"].ToString(),
                        COEFFICIENT = reader["COEFFICIENT"] != DBNull.Value ? Convert.ToDecimal(reader["COEFFICIENT"]) : 1,
                        CLASSE_ID = reader["CLASSE_ID"] != DBNull.Value ? Convert.ToInt32(reader["CLASSE_ID"]) : 0,
                        CLASSE_NOM = reader["CLASSE_NOM"] != DBNull.Value ? reader["CLASSE_NOM"].ToString() : ""
                    });
                }
            }
        }
        catch { }
        return matieres;
    }

    // ============================================================
    // UTILITAIRES
    // ============================================================
    private void HideMessages()
    {
        lblLicenceInfo.Visible = false;
        lblUserLimitInfo.Visible = false;
        lblMessage.Visible = false;
    }

    private void ShowError(string msg)
    {
        lblMessage.Text = msg;
        lblMessage.ForeColor = Color.Red;
        lblMessage.Visible = true;
    }
}
