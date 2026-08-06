<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.Clear();
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);
    Response.Cache.SetNoStore();

    if (!AuthHelper.RequireApiAuth(Context, 0))
    {
        Response.StatusCode = 401;
        Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\",\"backups\":[]}");
        return;
    }
    
    try
    {
        string backupFolder = Server.MapPath("~/App_Data/Backups/");
        
        if (!Directory.Exists(backupFolder))
        {
            Directory.CreateDirectory(backupFolder);
            Response.Write("{\"success\":true,\"backups\":[],\"message\":\"Dossier créé\"}");
            return;
        }
        
        string[] backupFiles = Directory.GetFiles(backupFolder, "*.bak");
        var backups = new List<object>();
        
        foreach (string filePath in backupFiles)
        {
            FileInfo fileInfo = new FileInfo(filePath);
            
            string fileName = fileInfo.Name;
            string dateStr = fileInfo.LastWriteTime.ToString("dd/MM/yyyy HH:mm");
            
            try
            {
                string nameWithoutExt = Path.GetFileNameWithoutExtension(fileName);
                string datePart = nameWithoutExt.Replace("backup_", "");
                if (!string.IsNullOrEmpty(datePart))
                {
                    DateTime parsedDate = DateTime.ParseExact(datePart, "yyyyMMdd_HHmmss", System.Globalization.CultureInfo.InvariantCulture);
                    dateStr = parsedDate.ToString("dd/MM/yyyy HH:mm");
                }
            }
            catch { }
            
            // ✅ IMPORTANT: Remplacer les backslashes par des slashes ou les échapper
            string safePath = filePath.Replace("\\", "/");
            
            backups.Add(new
            {
                name = fileName,
                path = safePath, // ← Chemin avec des / au lieu de \
                size = fileInfo.Length,
                date = dateStr,
                status = "Disponible"
            });
        }
        
        backups.Sort((a, b) => 
        {
            dynamic aObj = a;
            dynamic bObj = b;
            return bObj.date.CompareTo(aObj.date);
        });
        
        var serializer = new JavaScriptSerializer();
        string json = serializer.Serialize(new
        {
            success = true,
            backups = backups,
            count = backups.Count
        });
        
        Response.Write(json);
    }
    catch (Exception ex)
    {
        string safeMessage = ex.Message.Replace("\"", "'").Replace("\r", " ").Replace("\n", " ").Replace("\t", " ");
        Response.Write("{\"success\":false,\"message\":\"" + safeMessage + "\",\"backups\":[]}");
    }
}
</script>