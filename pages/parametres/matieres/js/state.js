'use strict';

// État global du module Matières
var STATE = {
    matieresData: [],
    filteredMatieres: [],
    currentPage: 1,
    rowsPerPage: 10,
    editId: null,          // GUID de la matière en cours d'édition
    isEditMode: false
};