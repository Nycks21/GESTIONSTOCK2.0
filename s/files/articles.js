// =====================================================
// articles.js - Module Articles (Gestion de Stock)
// Suit les memes conventions vanilla JS que MONAPPECOLE2
// (fetch natif, pas de framework, delegation d'evenements)
// =====================================================
(function () {
    "use strict";

    var HANDLER_URL = "/Handlers/ArticleHandler.ashx";
    var dropdownsCache = null;

    // ---------------------------------------------------
    // INITIALISATION
    // ---------------------------------------------------
    function init() {
        chargerDropdowns(function () {
            chargerArticles();
        });

        document.getElementById("btnNouvelArticle").addEventListener("click", ouvrirModalCreation);
        document.getElementById("btnFermerModal").addEventListener("click", fermerModal);
        document.getElementById("btnAnnulerModal").addEventListener("click", fermerModal);
        document.getElementById("frmArticle").addEventListener("submit", enregistrerArticle);

        var timer = null;
        document.getElementById("txtRecherche").addEventListener("input", function () {
            clearTimeout(timer);
            timer = setTimeout(chargerArticles, 350); // debounce recherche
        });

        document.getElementById("btnExportExcel").addEventListener("click", function () {
            window.open(HANDLER_URL + "?action=export&format=excel", "_blank");
        });
        document.getElementById("btnExportPdf").addEventListener("click", function () {
            window.open(HANDLER_URL + "?action=export&format=pdf", "_blank");
        });

        // Delegation pour les boutons Modifier / Supprimer generes dynamiquement
        document.getElementById("tblArticlesBody").addEventListener("click", function (e) {
            var btn = e.target.closest("button[data-action]");
            if (!btn) return;
            var id = btn.getAttribute("data-id");
            if (btn.getAttribute("data-action") === "edit") ouvrirModalModification(id);
            if (btn.getAttribute("data-action") === "delete") supprimerArticle(id);
        });
    }

    // ---------------------------------------------------
    // CHARGEMENT DES LISTES DEROULANTES
    // ---------------------------------------------------
    function chargerDropdowns(callback) {
        fetch(HANDLER_URL + "?action=dropdowns")
            .then(function (r) { return r.json(); })
            .then(function (res) {
                if (!res.success) { afficherErreur(res.message); return; }
                dropdownsCache = res.data;
                remplirSelect("ddlCategorie", res.data.categories, "-- Aucune categorie --");
                remplirSelect("ddlUnite", res.data.unites, "-- Aucune unite --");
                remplirSelect("ddlFournisseur", res.data.fournisseurs, "-- Aucun fournisseur --");
                remplirSelect("ddlEmplacement", res.data.emplacements, "-- Aucun emplacement --");
                if (callback) callback();
            })
            .catch(function (err) { afficherErreur("Impossible de charger les listes : " + err.message); });
    }

    function remplirSelect(selectId, items, placeholder) {
        var select = document.getElementById(selectId);
        select.innerHTML = "";
        var optVide = document.createElement("option");
        optVide.value = "";
        optVide.textContent = placeholder;
        select.appendChild(optVide);

        items.forEach(function (item) {
            var opt = document.createElement("option");
            opt.value = item.id;
            opt.textContent = item.code ? item.nom + " (" + item.code + ")" : item.nom;
            select.appendChild(opt);
        });
    }

    // ---------------------------------------------------
    // CHARGEMENT / AFFICHAGE DE LA GRILLE
    // ---------------------------------------------------
    function chargerArticles() {
        var search = encodeURIComponent(document.getElementById("txtRecherche").value.trim());
        fetch(HANDLER_URL + "?action=list&search=" + search)
            .then(function (r) { return r.json(); })
            .then(function (res) {
                if (!res.success) { afficherErreur(res.message); return; }
                afficherArticles(res.data);
            })
            .catch(function (err) { afficherErreur("Impossible de charger les articles : " + err.message); });
    }

    function afficherArticles(articles) {
        var tbody = document.getElementById("tblArticlesBody");
        tbody.innerHTML = "";

        if (articles.length === 0) {
            tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted">Aucun article trouve.</td></tr>';
            return;
        }

        articles.forEach(function (a) {
            var enAlerte = parseFloat(a.stockTotal) <= parseFloat(a.seuilAlerte) && parseFloat(a.seuilAlerte) > 0;
            var tr = document.createElement("tr");
            if (enAlerte) tr.classList.add("table-warning");

            tr.innerHTML =
                "<td>" + escapeHtml(a.code) + "</td>" +
                "<td>" + escapeHtml(a.nom) + "</td>" +
                "<td>" + escapeHtml(a.categorieNom || "-") + "</td>" +
                "<td>" + escapeHtml(a.uniteCode || a.uniteNom || "-") + "</td>" +
                "<td>" + escapeHtml(a.fournisseurNom || "-") + "</td>" +
                "<td>" + escapeHtml(a.emplacementNom || "-") + "</td>" +
                "<td>" + Number(a.stockTotal).toFixed(2) + (enAlerte ? ' <i class="fa fa-exclamation-triangle text-warning" title="Stock sous le seuil d\'alerte"></i>' : "") + "</td>" +
                "<td>" + Number(a.seuilAlerte).toFixed(2) + "</td>" +
                "<td>" + (a.active ? '<span class="badge bg-success">Actif</span>' : '<span class="badge bg-secondary">Inactif</span>') + "</td>" +
                '<td>' +
                '<button type="button" class="btn btn-sm btn-outline-primary" data-action="edit" data-id="' + a.id + '"><i class="fa fa-pen"></i></button> ' +
                '<button type="button" class="btn btn-sm btn-outline-danger" data-action="delete" data-id="' + a.id + '"><i class="fa fa-trash"></i></button>' +
                "</td>";

            tbody.appendChild(tr);
        });
    }

    // ---------------------------------------------------
    // MODAL : OUVERTURE / FERMETURE
    // ---------------------------------------------------
    function ouvrirModalCreation() {
        document.getElementById("frmArticle").reset();
        document.getElementById("articleId").value = "";
        document.getElementById("modalArticleTitle").textContent = "Nouvel article";
        document.getElementById("chkActive").checked = true;
        afficherModal();
    }

    function ouvrirModalModification(id) {
        fetch(HANDLER_URL + "?action=get&id=" + id)
            .then(function (r) { return r.json(); })
            .then(function (res) {
                if (!res.success) { afficherErreur(res.message); return; }
                var a = res.data;

                document.getElementById("articleId").value = a.id;
                document.getElementById("txtCode").value = a.code || "";
                document.getElementById("txtCodeBarre").value = a.codeBarre || "";
                document.getElementById("txtNom").value = a.nom || "";
                document.getElementById("txtDescription").value = a.description || "";
                document.getElementById("ddlCategorie").value = a.categorieId || "";
                document.getElementById("ddlUnite").value = a.uniteId || "";
                document.getElementById("ddlFournisseur").value = a.fournisseurId || "";
                document.getElementById("ddlEmplacement").value = a.emplacementId || "";
                document.getElementById("txtSeuilMin").value = a.seuilMin;
                document.getElementById("txtSeuilMax").value = a.seuilMax;
                document.getElementById("txtSeuilAlerte").value = a.seuilAlerte;
                document.getElementById("txtPoids").value = a.poids || "";
                document.getElementById("txtVolume").value = a.volume || "";
                document.getElementById("chkActive").checked = !!a.active;
                document.getElementById("chkEstService").checked = !!a.estService;
                document.getElementById("chkEstPerissable").checked = !!a.estPerissable;

                document.getElementById("modalArticleTitle").textContent = "Modifier l'article";
                afficherModal();
            })
            .catch(function (err) { afficherErreur("Impossible de charger l'article : " + err.message); });
    }

    function afficherModal() {
        document.getElementById("modalArticle").classList.add("show");
        document.getElementById("modalArticle").style.display = "block";
    }

    function fermerModal() {
        document.getElementById("modalArticle").classList.remove("show");
        document.getElementById("modalArticle").style.display = "none";
    }

    // ---------------------------------------------------
    // ENREGISTREMENT (creation ou modification)
    // ---------------------------------------------------
    function enregistrerArticle(e) {
        e.preventDefault();

        var payload = {
            id: document.getElementById("articleId").value || null,
            code: document.getElementById("txtCode").value.trim(),
            codeBarre: document.getElementById("txtCodeBarre").value.trim(),
            nom: document.getElementById("txtNom").value.trim(),
            description: document.getElementById("txtDescription").value.trim(),
            categorieId: document.getElementById("ddlCategorie").value || null,
            uniteId: document.getElementById("ddlUnite").value || null,
            fournisseurId: document.getElementById("ddlFournisseur").value || null,
            emplacementId: document.getElementById("ddlEmplacement").value || null,
            seuilMin: parseFloat(document.getElementById("txtSeuilMin").value) || 0,
            seuilMax: parseFloat(document.getElementById("txtSeuilMax").value) || 0,
            seuilAlerte: parseFloat(document.getElementById("txtSeuilAlerte").value) || 0,
            poids: document.getElementById("txtPoids").value ? parseFloat(document.getElementById("txtPoids").value) : null,
            volume: document.getElementById("txtVolume").value ? parseFloat(document.getElementById("txtVolume").value) : null,
            active: document.getElementById("chkActive").checked,
            estService: document.getElementById("chkEstService").checked,
            estPerissable: document.getElementById("chkEstPerissable").checked,
        };

        var btn = document.getElementById("btnEnregistrerArticle");
        btn.disabled = true;

        fetch(HANDLER_URL + "?action=save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        })
            .then(function (r) { return r.json(); })
            .then(function (res) {
                btn.disabled = false;
                if (!res.success) { afficherErreur(res.message); return; }
                afficherSucces(res.message);
                fermerModal();
                chargerArticles();
            })
            .catch(function (err) {
                btn.disabled = false;
                afficherErreur("Erreur lors de l'enregistrement : " + err.message);
            });
    }

    // ---------------------------------------------------
    // SUPPRESSION
    // ---------------------------------------------------
    function supprimerArticle(id) {
        if (!confirm("Confirmez-vous la suppression de cet article ?")) return;

        fetch(HANDLER_URL + "?action=delete&id=" + id, { method: "POST" })
            .then(function (r) { return r.json(); })
            .then(function (res) {
                if (!res.success) { afficherErreur(res.message); return; }
                afficherSucces(res.message);
                chargerArticles();
            })
            .catch(function (err) { afficherErreur("Erreur lors de la suppression : " + err.message); });
    }

    // ---------------------------------------------------
    // UTILITAIRES
    // ---------------------------------------------------
    function escapeHtml(str) {
        if (str === null || str === undefined) return "";
        return String(str)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;");
    }

    function afficherErreur(message) {
        // Remplacer par le systeme de notification utilise dans MONAPPECOLE2 (toastr, etc.)
        alert(message || "Une erreur est survenue.");
    }

    function afficherSucces(message) {
        alert(message || "Operation reussie.");
    }

    document.addEventListener("DOMContentLoaded", init);
})();
