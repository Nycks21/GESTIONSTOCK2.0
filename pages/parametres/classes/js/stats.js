'use strict';

// État global du module Classes
var STATE = {
    classesData: [],
    filteredClasses: [],
    currentPage: 1,
    rowsPerPage: 10,
    editId: null,          // ID de la classe en cours d'édition (int)
    isEditMode: false
};