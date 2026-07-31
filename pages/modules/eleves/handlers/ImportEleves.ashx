public void ProcessRequest(HttpContext context) {
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
    var file = context.Request.Files[0];
    var mappingJson = context.Request.Form["mapping"];
    var mapping = JsonConvert.DeserializeObject<Dictionary<string, string>>(mappingJson);
    
    List<string> errors = new List<string>();
    int successCount = 0;

    using (var reader = ExcelReaderFactory.CreateReader(file.InputStream)) {
        var data = reader.AsDataSet().Tables[0];
        
        for (int i = 1; i < data.Rows.Count; i++) { // Saute l'entête
            try {
                var row = data.Rows[i];
                string matricule = row[mapping["MATRICULE"]].ToString();
                string classe = row[mapping["CLASSE"]].ToString();
                
                // Validation : Vérifier si la classe existe dans votre BD
                if (!DbHelper.Exists("SELECT 1 FROM Classes WHERE NOM = @nom", classe)) {
                    errors.Add($"Ligne {i+1}: La classe '{classe}' n'existe pas dans le système.");
                    continue;
                }

                // Insertion...
                successCount++;
            } catch {
                errors.Add($"Ligne {i+1}: Format de donnée invalide.");
            }
        }
    }

    var response = new { 
        success = errors.Count == 0, 
        count = successCount, 
        errors = errors 
    };
    context.Response.Write(JsonConvert.SerializeObject(response));
}