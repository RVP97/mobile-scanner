export type Language = "en" | "es" | "fr";

export interface Translations {
  // Tab labels
  tabs: {
    scanner: string;
    history: string;
    generator: string;
    settings: string;
  };

  // Common
  common: {
    copy: string;
    share: string;
    delete: string;
    cancel: string;
    done: string;
    error: string;
    copied: string;
    enable: string;
    unlock: string;
    preview: string;
    open: string;
    clearAll: string;
  };

  // Scanner screen
  scanner: {
    requestingPermission: string;
    cameraAccess: string;
    cameraPermissionText: string;
    grantPermission: string;
    scanComplete: string;
    urlDetected: string;
    contentCaptured: string;
    content: string;
    url: string;
    openUrl: string;
    previewCode: string;
    scanAnother: string;
    scanAgain: string;
    pointAtCode: string;
    scanMultipleCodes: string;
    fromGallery: string;
    codesScanned: string;
    codeScanned: string;
    tapForOptions: string;
    scannedItems: string;
    addMoreCodes: string;
    noCodeFound: string;
    noCodeFoundMessage: string;
    imageCopied: string;
    textCopied: string;
    unableToOpenUrl: string;
    sharingNotAvailable: string;
    failedToShare: string;
  };

  // History screen
  history: {
    scans: string;
    generations: string;
    searchScans: string;
    searchGenerations: string;
    noScansYet: string;
    noScansDescription: string;
    noGenerationsYet: string;
    noGenerationsDescription: string;
    noResults: string;
    noResultsFor: string;
    historyDisabled: string;
    historyDisabledDescription: string;
    enableHistory: string;
    historyPaused: string;
    newScansNotSaved: string;
    historyLocked: string;
    authenticateToView: string;
    authenticating: string;
    deleteScan: string;
    deleteScanConfirm: string;
    deleteGeneration: string;
    deleteGenerationConfirm: string;
    clearScanHistory: string;
    clearGenerationHistory: string;
    clearConfirm: string;
    scan: string;
    generation: string;
    of: string;
  };

  // Generator screen
  generator: {
    codeType: string;
    content: string;
    generate: string;
    generatedCode: string;
    enterValue: string;
    invalidInput: string;
    invalidBarcodeData: string;
    checkInputFormat: string;
    // Placeholders
    enterAnyTextOrUrl: string;
    enterAnyText: string;
    enterDigits: string;
    enterAlphanumeric: string;
    enter13Digits: string;
    enter8Digits: string;
    enter12Digits: string;
    enter6to8Digits: string;
    enter13to14Digits: string;
    enterEvenDigits: string;
    enterNumber3to131070: string;
    codabarPlaceholder: string;
  };

  // Settings screen
  settings: {
    general: string;
    language: string;
    selectLanguage: string;
    scanner: string;
    hapticFeedback: string;
    vibrateWhenScanning: string;
    sound: string;
    playSoundWhenScanning: string;
    autoCopy: string;
    autoCopyDescription: string;
    scanAndGo: string;
    scanAndGoDescription: string;
    multiCodeScanning: string;
    multiCodeDescription: string;
    historySection: string;
    saveHistory: string;
    saveHistoryDescription: string;
    requireAuth: string;
    requireAuthDescription: string;
    exportCsv: string;
    exportCsvDescription: string;
    clearAllHistory: string;
    about: string;
    rateApp: string;
    shareApp: string;
    shareAppMessage: string;
    version: string;
    noHistory: string;
    noHistoryToExport: string;
    exportError: string;
    clearHistoryTitle: string;
    clearHistoryMessage: string;
    cleared: string;
    allHistoryCleared: string;
    notAvailable: string;
    authNotSetup: string;
    authenticateTo: string;
  };

  // Alerts
  alerts: {
    copied: string;
    textCopiedToClipboard: string;
    imageCopiedToClipboard: string;
    error: string;
    sharingNotAvailable: string;
    failedToExport: string;
  };
}

const en: Translations = {
  tabs: {
    scanner: "Scanner",
    history: "History",
    generator: "Generator",
    settings: "Settings",
  },
  common: {
    copy: "Copy",
    share: "Share",
    delete: "Delete",
    cancel: "Cancel",
    done: "Done",
    error: "Error",
    copied: "Copied",
    enable: "Enable",
    unlock: "Unlock",
    preview: "Preview",
    open: "Open",
    clearAll: "Clear All",
  },
  scanner: {
    requestingPermission: "Requesting camera permission...",
    cameraAccess: "Camera Access",
    cameraPermissionText: "We need camera access to scan barcodes and QR codes",
    grantPermission: "Grant Permission",
    scanComplete: "Scan Complete",
    urlDetected: "Website URL detected",
    contentCaptured: "Content captured",
    content: "Content",
    url: "URL",
    openUrl: "Open URL",
    previewCode: "Preview Code",
    scanAnother: "Scan Another",
    scanAgain: "Scan Again",
    pointAtCode: "Point at a barcode or QR code",
    scanMultipleCodes: "Scan multiple codes, tap Done when finished",
    fromGallery: "From Gallery",
    codesScanned: "Codes Scanned",
    codeScanned: "Code Scanned",
    tapForOptions: "Tap any item for more options",
    scannedItems: "SCANNED ITEMS",
    addMoreCodes: "Add More Codes",
    noCodeFound: "No Code Found",
    noCodeFoundMessage:
      "No barcode or QR code was found in the selected image.",
    imageCopied: "Image copied to clipboard",
    textCopied: "Text copied to clipboard",
    unableToOpenUrl: "Unable to open this URL",
    sharingNotAvailable: "Sharing is not available on this device",
    failedToShare: "Failed to share the image",
  },
  history: {
    scans: "Scans",
    generations: "Generations",
    searchScans: "Search scans...",
    searchGenerations: "Search generations...",
    noScansYet: "No Scans Yet",
    noScansDescription: "Scanned barcodes and QR codes will appear here",
    noGenerationsYet: "No Generations Yet",
    noGenerationsDescription:
      "Generated QR codes and barcodes will appear here",
    noResults: "No Results",
    noResultsFor: "No items found for",
    historyDisabled: "History Disabled",
    historyDisabledDescription:
      "Scan history is turned off. Enable it to keep a record of your scans.",
    enableHistory: "Enable History",
    historyPaused: "History Paused",
    newScansNotSaved: "New scans won't be saved",
    historyLocked: "History Locked",
    authenticateToView: "Authenticate to view your scan history",
    authenticating: "Authenticating...",
    deleteScan: "Delete Scan",
    deleteScanConfirm: "Are you sure you want to delete this scan?",
    deleteGeneration: "Delete Generation",
    deleteGenerationConfirm: "Are you sure you want to delete this generation?",
    clearScanHistory: "Clear Scan History",
    clearGenerationHistory: "Clear Generation History",
    clearConfirm: "Delete all history? This cannot be undone.",
    scan: "scan",
    generation: "generation",
    of: "of",
  },
  generator: {
    codeType: "CODE TYPE",
    content: "CONTENT",
    generate: "Generate",
    generatedCode: "GENERATED CODE",
    enterValue: "Please enter a value to generate",
    invalidInput: "Invalid Input",
    invalidBarcodeData: "Invalid barcode data",
    checkInputFormat: "Please check the input format",
    enterAnyTextOrUrl: "Enter any text or URL",
    enterAnyText: "Enter any text",
    enterDigits: "Enter digits",
    enterAlphanumeric: "Enter alphanumeric text",
    enter13Digits: "Enter 13 digits (with valid checksum)",
    enter8Digits: "Enter 8 digits (with valid checksum)",
    enter12Digits: "Enter 12 digits (with valid checksum)",
    enter6to8Digits: "Enter 6-8 digits (start with 0)",
    enter13to14Digits: "Enter 13-14 digits",
    enterEvenDigits: "Enter even number of digits",
    enterNumber3to131070: "Enter number 3-131070",
    codabarPlaceholder: "A1234B (start/end with A-D)",
  },
  settings: {
    general: "GENERAL",
    language: "Language",
    selectLanguage: "Choose your preferred language",
    scanner: "SCANNER",
    hapticFeedback: "Haptic Feedback",
    vibrateWhenScanning: "Vibrate when scanning",
    sound: "Sound",
    playSoundWhenScanning: "Play sound when scanning",
    autoCopy: "Auto-Copy",
    autoCopyDescription: "Copy scanned content automatically",
    scanAndGo: "Scan and Go",
    scanAndGoDescription: "Open URLs automatically after scanning",
    multiCodeScanning: "Multi-Code Scanning",
    multiCodeDescription: "Scan multiple codes before viewing results",
    historySection: "HISTORY",
    saveHistory: "Save Scan History",
    saveHistoryDescription: "Keep a record of scanned items",
    requireAuth: "Require",
    requireAuthDescription: "Protect history with authentication",
    exportCsv: "Export to CSV",
    exportCsvDescription: "Save history as spreadsheet",
    clearAllHistory: "Clear All History",
    about: "ABOUT",
    rateApp: "Rate App",
    shareApp: "Share App",
    shareAppMessage: "Check out this awesome scanner app!",
    version: "Version",
    noHistory: "No History",
    noHistoryToExport: "There is no scan history to export.",
    exportError: "Failed to export history.",
    clearHistoryTitle: "Clear All History",
    clearHistoryMessage:
      "This will permanently delete all your scan history. This action cannot be undone.",
    cleared: "Done",
    allHistoryCleared: "All scan history has been cleared",
    notAvailable: "Not Available",
    authNotSetup: "is not set up on this device. Please enable it in Settings.",
    authenticateTo: "Authenticate to enable",
  },
  alerts: {
    copied: "Copied",
    textCopiedToClipboard: "Text copied to clipboard",
    imageCopiedToClipboard: "Image copied to clipboard",
    error: "Error",
    sharingNotAvailable: "Sharing is not available on this device",
    failedToExport: "Failed to export history.",
  },
};

const es: Translations = {
  tabs: {
    scanner: "Escáner",
    history: "Historial",
    generator: "Generador",
    settings: "Ajustes",
  },
  common: {
    copy: "Copiar",
    share: "Compartir",
    delete: "Eliminar",
    cancel: "Cancelar",
    done: "Listo",
    error: "Error",
    copied: "Copiado",
    enable: "Activar",
    unlock: "Desbloquear",
    preview: "Ver",
    open: "Abrir",
    clearAll: "Borrar todo",
  },
  scanner: {
    requestingPermission: "Solicitando permiso de cámara...",
    cameraAccess: "Acceso a Cámara",
    cameraPermissionText:
      "Necesitamos acceso a la cámara para escanear códigos de barras y QR",
    grantPermission: "Permitir Acceso",
    scanComplete: "Escaneo Completo",
    urlDetected: "URL detectada",
    contentCaptured: "Contenido capturado",
    content: "Contenido",
    url: "URL",
    openUrl: "Abrir URL",
    previewCode: "Ver Código",
    scanAnother: "Escanear Otro",
    scanAgain: "Escanear de Nuevo",
    pointAtCode: "Apunta a un código de barras o QR",
    scanMultipleCodes: "Escanea múltiples códigos, toca Listo al terminar",
    fromGallery: "Desde Galería",
    codesScanned: "Códigos Escaneados",
    codeScanned: "Código Escaneado",
    tapForOptions: "Toca cualquier elemento para más opciones",
    scannedItems: "ELEMENTOS ESCANEADOS",
    addMoreCodes: "Agregar Más Códigos",
    noCodeFound: "Código No Encontrado",
    noCodeFoundMessage:
      "No se encontró ningún código de barras o QR en la imagen seleccionada.",
    imageCopied: "Imagen copiada al portapapeles",
    textCopied: "Texto copiado al portapapeles",
    unableToOpenUrl: "No se puede abrir esta URL",
    sharingNotAvailable: "Compartir no está disponible en este dispositivo",
    failedToShare: "Error al compartir la imagen",
  },
  history: {
    scans: "Escaneos",
    generations: "Generaciones",
    searchScans: "Buscar escaneos...",
    searchGenerations: "Buscar generaciones...",
    noScansYet: "Sin Escaneos",
    noScansDescription: "Los códigos escaneados aparecerán aquí",
    noGenerationsYet: "Sin Generaciones",
    noGenerationsDescription:
      "Los códigos QR y de barras generados aparecerán aquí",
    noResults: "Sin Resultados",
    noResultsFor: "No se encontraron elementos para",
    historyDisabled: "Historial Desactivado",
    historyDisabledDescription:
      "El historial de escaneos está desactivado. Actívalo para guardar tus escaneos.",
    enableHistory: "Activar Historial",
    historyPaused: "Historial Pausado",
    newScansNotSaved: "Los nuevos escaneos no se guardarán",
    historyLocked: "Historial Bloqueado",
    authenticateToView: "Autentícate para ver tu historial de escaneos",
    authenticating: "Autenticando...",
    deleteScan: "Eliminar Escaneo",
    deleteScanConfirm: "¿Estás seguro de que quieres eliminar este escaneo?",
    deleteGeneration: "Eliminar Generación",
    deleteGenerationConfirm:
      "¿Estás seguro de que quieres eliminar esta generación?",
    clearScanHistory: "Borrar Historial de Escaneos",
    clearGenerationHistory: "Borrar Historial de Generaciones",
    clearConfirm:
      "¿Eliminar todo el historial? Esta acción no se puede deshacer.",
    scan: "escaneo",
    generation: "generación",
    of: "de",
  },
  generator: {
    codeType: "TIPO DE CÓDIGO",
    content: "CONTENIDO",
    generate: "Generar",
    generatedCode: "CÓDIGO GENERADO",
    enterValue: "Por favor ingresa un valor para generar",
    invalidInput: "Entrada Inválida",
    invalidBarcodeData: "Datos de código de barras inválidos",
    checkInputFormat: "Por favor verifica el formato de entrada",
    enterAnyTextOrUrl: "Ingresa cualquier texto o URL",
    enterAnyText: "Ingresa cualquier texto",
    enterDigits: "Ingresa dígitos",
    enterAlphanumeric: "Ingresa texto alfanumérico",
    enter13Digits: "Ingresa 13 dígitos (con checksum válido)",
    enter8Digits: "Ingresa 8 dígitos (con checksum válido)",
    enter12Digits: "Ingresa 12 dígitos (con checksum válido)",
    enter6to8Digits: "Ingresa 6-8 dígitos (empezar con 0)",
    enter13to14Digits: "Ingresa 13-14 dígitos",
    enterEvenDigits: "Ingresa número par de dígitos",
    enterNumber3to131070: "Ingresa número 3-131070",
    codabarPlaceholder: "A1234B (empezar/terminar con A-D)",
  },
  settings: {
    general: "GENERAL",
    language: "Idioma",
    selectLanguage: "Elige tu idioma preferido",
    scanner: "ESCÁNER",
    hapticFeedback: "Vibración",
    vibrateWhenScanning: "Vibrar al escanear",
    sound: "Sonido",
    playSoundWhenScanning: "Reproducir sonido al escanear",
    autoCopy: "Auto-Copiar",
    autoCopyDescription: "Copiar contenido automáticamente",
    scanAndGo: "Escanear e Ir",
    scanAndGoDescription: "Abrir URLs automáticamente",
    multiCodeScanning: "Escaneo Múltiple",
    multiCodeDescription: "Escanear múltiples códigos antes de ver resultados",
    historySection: "HISTORIAL",
    saveHistory: "Guardar Historial",
    saveHistoryDescription: "Mantener registro de elementos escaneados",
    requireAuth: "Requerir",
    requireAuthDescription: "Proteger historial con autenticación",
    exportCsv: "Exportar a CSV",
    exportCsvDescription: "Guardar historial como hoja de cálculo",
    clearAllHistory: "Borrar Todo el Historial",
    about: "ACERCA DE",
    rateApp: "Calificar App",
    shareApp: "Compartir App",
    shareAppMessage: "¡Mira esta increíble app de escáner!",
    version: "Versión",
    noHistory: "Sin Historial",
    noHistoryToExport: "No hay historial de escaneos para exportar.",
    exportError: "Error al exportar historial.",
    clearHistoryTitle: "Borrar Todo el Historial",
    clearHistoryMessage:
      "Esto eliminará permanentemente todo tu historial de escaneos. Esta acción no se puede deshacer.",
    cleared: "Listo",
    allHistoryCleared: "Todo el historial ha sido borrado",
    notAvailable: "No Disponible",
    authNotSetup:
      "no está configurado en este dispositivo. Por favor actívalo en Ajustes.",
    authenticateTo: "Autentícate para activar",
  },
  alerts: {
    copied: "Copiado",
    textCopiedToClipboard: "Texto copiado al portapapeles",
    imageCopiedToClipboard: "Imagen copiada al portapapeles",
    error: "Error",
    sharingNotAvailable: "Compartir no está disponible en este dispositivo",
    failedToExport: "Error al exportar historial.",
  },
};

const fr: Translations = {
  tabs: {
    scanner: "Scanner",
    history: "Historique",
    generator: "Générateur",
    settings: "Réglages",
  },
  common: {
    copy: "Copier",
    share: "Partager",
    delete: "Supprimer",
    cancel: "Annuler",
    done: "Terminé",
    error: "Erreur",
    copied: "Copié",
    enable: "Activer",
    unlock: "Déverrouiller",
    preview: "Aperçu",
    open: "Ouvrir",
    clearAll: "Tout effacer",
  },
  scanner: {
    requestingPermission: "Demande d'accès à la caméra...",
    cameraAccess: "Accès Caméra",
    cameraPermissionText:
      "Nous avons besoin de la caméra pour scanner les codes-barres et QR",
    grantPermission: "Autoriser l'Accès",
    scanComplete: "Scan Terminé",
    urlDetected: "URL détectée",
    contentCaptured: "Contenu capturé",
    content: "Contenu",
    url: "URL",
    openUrl: "Ouvrir URL",
    previewCode: "Aperçu Code",
    scanAnother: "Scanner un Autre",
    scanAgain: "Rescanner",
    pointAtCode: "Pointez vers un code-barres ou QR",
    scanMultipleCodes: "Scannez plusieurs codes, appuyez sur Terminé",
    fromGallery: "Depuis la Galerie",
    codesScanned: "Codes Scannés",
    codeScanned: "Code Scanné",
    tapForOptions: "Appuyez sur un élément pour plus d'options",
    scannedItems: "ÉLÉMENTS SCANNÉS",
    addMoreCodes: "Ajouter Plus de Codes",
    noCodeFound: "Aucun Code Trouvé",
    noCodeFoundMessage:
      "Aucun code-barres ou QR n'a été trouvé dans l'image sélectionnée.",
    imageCopied: "Image copiée dans le presse-papiers",
    textCopied: "Texte copié dans le presse-papiers",
    unableToOpenUrl: "Impossible d'ouvrir cette URL",
    sharingNotAvailable: "Le partage n'est pas disponible sur cet appareil",
    failedToShare: "Échec du partage de l'image",
  },
  history: {
    scans: "Scans",
    generations: "Générations",
    searchScans: "Rechercher scans...",
    searchGenerations: "Rechercher générations...",
    noScansYet: "Aucun Scan",
    noScansDescription: "Les codes scannés apparaîtront ici",
    noGenerationsYet: "Aucune Génération",
    noGenerationsDescription:
      "Les codes QR et codes-barres générés apparaîtront ici",
    noResults: "Aucun Résultat",
    noResultsFor: "Aucun élément trouvé pour",
    historyDisabled: "Historique Désactivé",
    historyDisabledDescription:
      "L'historique des scans est désactivé. Activez-le pour enregistrer vos scans.",
    enableHistory: "Activer l'Historique",
    historyPaused: "Historique en Pause",
    newScansNotSaved: "Les nouveaux scans ne seront pas sauvegardés",
    historyLocked: "Historique Verrouillé",
    authenticateToView: "Authentifiez-vous pour voir votre historique",
    authenticating: "Authentification...",
    deleteScan: "Supprimer le Scan",
    deleteScanConfirm: "Êtes-vous sûr de vouloir supprimer ce scan?",
    deleteGeneration: "Supprimer la Génération",
    deleteGenerationConfirm:
      "Êtes-vous sûr de vouloir supprimer cette génération?",
    clearScanHistory: "Effacer l'Historique des Scans",
    clearGenerationHistory: "Effacer l'Historique des Générations",
    clearConfirm: "Supprimer tout l'historique? Cette action est irréversible.",
    scan: "scan",
    generation: "génération",
    of: "sur",
  },
  generator: {
    codeType: "TYPE DE CODE",
    content: "CONTENU",
    generate: "Générer",
    generatedCode: "CODE GÉNÉRÉ",
    enterValue: "Veuillez entrer une valeur à générer",
    invalidInput: "Entrée Invalide",
    invalidBarcodeData: "Données de code-barres invalides",
    checkInputFormat: "Veuillez vérifier le format d'entrée",
    enterAnyTextOrUrl: "Entrez du texte ou une URL",
    enterAnyText: "Entrez du texte",
    enterDigits: "Entrez des chiffres",
    enterAlphanumeric: "Entrez du texte alphanumérique",
    enter13Digits: "Entrez 13 chiffres (checksum valide)",
    enter8Digits: "Entrez 8 chiffres (checksum valide)",
    enter12Digits: "Entrez 12 chiffres (checksum valide)",
    enter6to8Digits: "Entrez 6-8 chiffres (commencer par 0)",
    enter13to14Digits: "Entrez 13-14 chiffres",
    enterEvenDigits: "Entrez un nombre pair de chiffres",
    enterNumber3to131070: "Entrez un nombre 3-131070",
    codabarPlaceholder: "A1234B (commencer/finir par A-D)",
  },
  settings: {
    general: "GÉNÉRAL",
    language: "Langue",
    selectLanguage: "Choisissez votre langue préférée",
    scanner: "SCANNER",
    hapticFeedback: "Retour Haptique",
    vibrateWhenScanning: "Vibrer lors du scan",
    sound: "Son",
    playSoundWhenScanning: "Jouer un son lors du scan",
    autoCopy: "Copie Auto",
    autoCopyDescription: "Copier automatiquement le contenu scanné",
    scanAndGo: "Scanner et Ouvrir",
    scanAndGoDescription: "Ouvrir automatiquement les URLs",
    multiCodeScanning: "Scan Multiple",
    multiCodeDescription: "Scanner plusieurs codes avant de voir les résultats",
    historySection: "HISTORIQUE",
    saveHistory: "Sauvegarder l'Historique",
    saveHistoryDescription: "Conserver un enregistrement des scans",
    requireAuth: "Exiger",
    requireAuthDescription: "Protéger l'historique avec authentification",
    exportCsv: "Exporter en CSV",
    exportCsvDescription: "Enregistrer l'historique en tableur",
    clearAllHistory: "Effacer Tout l'Historique",
    about: "À PROPOS",
    rateApp: "Noter l'App",
    shareApp: "Partager l'App",
    shareAppMessage: "Découvrez cette super app de scanner !",
    version: "Version",
    noHistory: "Aucun Historique",
    noHistoryToExport: "Il n'y a pas d'historique de scans à exporter.",
    exportError: "Échec de l'exportation de l'historique.",
    clearHistoryTitle: "Effacer Tout l'Historique",
    clearHistoryMessage:
      "Cela supprimera définitivement tout votre historique de scans. Cette action est irréversible.",
    cleared: "Terminé",
    allHistoryCleared: "Tout l'historique a été effacé",
    notAvailable: "Non Disponible",
    authNotSetup:
      "n'est pas configuré sur cet appareil. Veuillez l'activer dans les Réglages.",
    authenticateTo: "Authentifiez-vous pour activer",
  },
  alerts: {
    copied: "Copié",
    textCopiedToClipboard: "Texte copié dans le presse-papiers",
    imageCopiedToClipboard: "Image copiée dans le presse-papiers",
    error: "Erreur",
    sharingNotAvailable: "Le partage n'est pas disponible sur cet appareil",
    failedToExport: "Échec de l'exportation de l'historique.",
  },
};

const translations: Record<Language, Translations> = {
  en,
  es,
  fr,
};

export function getTranslations(language: Language): Translations {
  return translations[language] || translations.en;
}

export const languageNames: Record<Language, string> = {
  en: "English",
  es: "Español",
  fr: "Français",
};
