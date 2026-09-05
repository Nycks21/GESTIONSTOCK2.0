<%@ Page Title="Articles" Language="C#" MasterPageFile="~/shell.Master" AutoEventWireup="true"
    CodeBehind="articles.aspx.cs" Inherits="GestionStock.Pages.ArticlesPage" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">

    <div id="spa-fragment" class="page-articles">

        <div class="page-header">
            <h2>Articles</h2>
            <button type="button" class="btn btn-primary" id="btnNouvelArticle">
                <i class="fa fa-plus"></i> Nouvel article
            </button>
        </div>

        <div class="filter-bar">
            <input type="text" id="txtRecherche" class="form-control" placeholder="Rechercher un article (code, nom, code-barre)..." />
            <button type="button" class="btn btn-outline-secondary" id="btnExportExcel"><i class="fa fa-file-excel"></i> Excel</button>
            <button type="button" class="btn btn-outline-secondary" id="btnExportPdf"><i class="fa fa-file-pdf"></i> PDF</button>
        </div>

        <div class="table-responsive">
            <table class="table table-striped table-hover" id="tblArticles">
                <thead>
                    <tr>
                        <th>Code</th>
                        <th>Nom</th>
                        <th>Categorie</th>
                        <th>Unite</th>
                        <th>Fournisseur</th>
                        <th>Emplacement</th>
                        <th>Stock</th>
                        <th>Seuil alerte</th>
                        <th>Statut</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody id="tblArticlesBody">
                    <!-- rempli dynamiquement par articles.js -->
                </tbody>
            </table>
        </div>

    </div>

    <!-- Modal Ajout / Modification -->
    <div class="modal" id="modalArticle" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <form id="frmArticle">
                    <input type="hidden" id="articleId" />

                    <div class="modal-header">
                        <h5 class="modal-title" id="modalArticleTitle">Nouvel article</h5>
                        <button type="button" class="btn-close" id="btnFermerModal"></button>
                    </div>

                    <div class="modal-body">
                        <div class="row">
                            <div class="col-md-4 form-group">
                                <label>Code *</label>
                                <input type="text" id="txtCode" class="form-control" required maxlength="50" />
                            </div>
                            <div class="col-md-4 form-group">
                                <label>Code-barre</label>
                                <input type="text" id="txtCodeBarre" class="form-control" maxlength="50" />
                            </div>
                            <div class="col-md-4 form-group">
                                <label>Nom *</label>
                                <input type="text" id="txtNom" class="form-control" required maxlength="200" />
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-12 form-group">
                                <label>Description</label>
                                <textarea id="txtDescription" class="form-control" rows="2" maxlength="500"></textarea>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-3 form-group">
                                <label>Categorie</label>
                                <select id="ddlCategorie" class="form-control"></select>
                            </div>
                            <div class="col-md-3 form-group">
                                <label>Unite de mesure</label>
                                <select id="ddlUnite" class="form-control"></select>
                            </div>
                            <div class="col-md-3 form-group">
                                <label>Fournisseur prefere</label>
                                <select id="ddlFournisseur" class="form-control"></select>
                            </div>
                            <div class="col-md-3 form-group">
                                <label>Emplacement</label>
                                <select id="ddlEmplacement" class="form-control"></select>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-3 form-group">
                                <label>Seuil min</label>
                                <input type="number" step="0.01" id="txtSeuilMin" class="form-control" value="0" />
                            </div>
                            <div class="col-md-3 form-group">
                                <label>Seuil max</label>
                                <input type="number" step="0.01" id="txtSeuilMax" class="form-control" value="0" />
                            </div>
                            <div class="col-md-3 form-group">
                                <label>Seuil alerte</label>
                                <input type="number" step="0.01" id="txtSeuilAlerte" class="form-control" value="0" />
                            </div>
                            <div class="col-md-3 form-group">
                                <label>Poids (kg)</label>
                                <input type="number" step="0.01" id="txtPoids" class="form-control" />
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-3 form-group">
                                <label>Volume</label>
                                <input type="number" step="0.01" id="txtVolume" class="form-control" />
                            </div>
                            <div class="col-md-3 form-check mt-4">
                                <input type="checkbox" id="chkActive" class="form-check-input" checked="checked" />
                                <label class="form-check-label">Actif</label>
                            </div>
                            <div class="col-md-3 form-check mt-4">
                                <input type="checkbox" id="chkEstService" class="form-check-input" />
                                <label class="form-check-label">Service (non stockable)</label>
                            </div>
                            <div class="col-md-3 form-check mt-4">
                                <input type="checkbox" id="chkEstPerissable" class="form-check-input" />
                                <label class="form-check-label">Perissable</label>
                            </div>
                        </div>
                    </div>

                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" id="btnAnnulerModal">Annuler</button>
                        <button type="submit" class="btn btn-primary" id="btnEnregistrerArticle">Enregistrer</button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <script src="/Scripts/pages/articles.js"></script>

</asp:Content>
