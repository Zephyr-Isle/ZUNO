/// Français.
const Map<String, String> zunoStringsFr = {
  // ---- Commun ----
  'cancel': 'Annuler',
  'delete': 'Supprimer',
  'later': 'Plus tard',
  'gotIt': 'Compris',
  'back': 'Retour',
  'settings': 'Réglages',
  'save': 'Enregistrer',
  'clearAddress': 'Effacer l’adresse',
  'retry': 'Réessayer',
  'close': 'Fermer',
  'exitFullscreen': 'Quitter le plein écran',
  'fullscreenPreview': 'Aperçu plein écran',
  'openSettings': 'Ouvrir les réglages',
  'unknownError': 'Erreur inconnue',
  'calculating': 'Calcul…',

  // ---- Navigation ----
  'myWallpapers': 'Mes fonds d’écran',
  'wallpaperLibrary': 'Bibliothèque de fonds',
  'settingsTitle': 'Réglages',
  'aboutTitle': 'À propos',
  'languageTitle': 'Langue',
  'languageSystem': 'Suivre le système',
  'languageDescription': 'Choisissez la langue d’affichage de l’application. « Suivre le système » utilise la langue d’Android.',
  'languageCurrent': 'Actuelle',
  'openLibrary': 'Ouvrir la bibliothèque de fonds',
  'backToMyWallpapers': 'Retour à mes fonds d’écran',
  'refreshLibrary': 'Actualiser la bibliothèque',
  'settingsSemantic': 'Réglages',
  'inUse': 'En cours',
  'installed': 'Installé',

  // ---- Mes fonds ----
  'importingPackage': 'Extraction et vérification du paquet de fond d’écran (isolate en arrière-plan)…',
  'importZuno': 'Importer un .zuno',
  'emptyLibraryTitle': 'Votre bibliothèque est vide',
  'emptyLibraryBody':
      'Importez un paquet .zuno conforme à la spécification ZUNO Package v1.\n'
      'Fonds vidéo, parallaxe de profondeur, HTML et planifiés pris en charge.',
  'importSuccessWarnings': 'Importé avec des avertissements',
  'importRejected': 'Import refusé',
  'importFailedUnreadable': 'Échec de l’import : impossible de lire le fichier',

  // ---- Détail du fond ----
  'performanceHint': 'Performances conseillées',
  'hintLow': 'Basses',
  'hintMedium': 'Moyennes',
  'hintHigh': 'Hautes',
  'authorLabel': 'Auteur',
  'parameters': 'Paramètres',
  'noParameters': 'Ce fond d’écran n’a aucun paramètre réglable',
  'capTouch': 'Entrée tactile',
  'capSensors': 'Capteurs : {sensors}',
  'capNetwork': 'Réseau déclaré (toujours bloqué en v1)',
  'scheduleWindows': 'Planning',
  'currentSlot': 'Actuel : {slot}',
  'defaultSlot': 'Par défaut : {slot}',
  'timedPreview': 'Aperçu horaire',
  'timedPreviewActiveHint':
      'Faites glisser pour prévisualiser chaque plage. Le planning réel sera restauré par WorkManager lors de sa prochaine vérification.',
  'timedPreviewInactiveHint':
      'Appliquez ce fond d’écran avant de prévisualiser les plages (l’aperçu permute à chaud la plage active).',
  'applyWallpaper': 'Appliquer ce fond',
  'applyHint': 'Ouvre l’aperçu système — appuyez sur « Définir le fond d’écran » pour confirmer',
  'livePreview': 'Aperçu en direct',
  'noThumbnail': 'Aucune miniature',
  'thumbnailLoadFailed': 'Impossible de charger la miniature',
  'htmlPreviewFullscreen': 'Aperçu du fond HTML (pincez pour zoomer)',
  'videoFullscreen': 'Aperçu vidéo plein écran',
  'depthFullscreen': 'Aperçu parallaxe plein écran',
  'timedNoRender':
      'Le type planifié ne s’affiche pas lui-même.\n'
      'L’aperçu plein écran montre la plage actuellement active.',
  'currentPeriod': 'Plage actuelle : {slot}',
  'unsupportedFullscreen': 'L’aperçu plein écran n’est pas pris en charge pour la plage actuelle ({slot})',
  'exportShare': 'Exporter / partager',
  'deletePackageTitle': 'Supprimer le paquet de fond d’écran ?',
  'deletePackageBody': '{title} et ses fichiers seront supprimés.',
  'packingPackage': 'Empaquetage du fond d’écran (export en flux)…',
  'exportFailed': 'Échec de l’export',
  'exportedTo': 'Exporté vers : {path}',
  'applyPreviewPrompt': 'Ouverture de l’aperçu système — appuyez sur « Définir le fond d’écran »',
  'videoPreviewInitFailed':
      "Échec de l'initialisation de l'aperçu vidéo : {error}",
  'videoUnsupported': 'Cet appareil ne peut pas lire cette vidéo en direct ; le fond affichera une image fixe',
  'videoLoading': 'Chargement de la vidéo…',
  'colorImageLoadFailed': 'Impossible de charger l’image couleur',
  'depthApproxHint': 'L’aperçu est approximatif ; le fond réel est plus fluide',
  'slotResolveFailed': 'Impossible de déterminer la plage actuelle',
  'deleteInUse': 'Ce fond d’écran est utilisé. Appliquez-en un autre avant de le supprimer.',
  'deleteFailed': 'Échec de la suppression : {error}',
  'applyFailedGeneric': "Échec de l'application",
  'applyFailed': 'Échec de l’application : {error}',
  'applyNoPreview':
      'Les réglages ont été enregistrés, mais l’aperçu système n’a pas pu s’ouvrir — choisissez ZUNO manuellement dans les réglages de fond d’écran du système',
  'applyTimedFailed':
      'Impossible de déterminer la plage actuelle (elle peut être limitée au chargement ; branchez le chargeur et réessayez)',

  // ---- Bibliothèque en ligne ----
  'libraryNotConfiguredTitle': 'Bibliothèque non configurée',
  'libraryNotConfiguredBody':
      'La bibliothèque pointe vers votre propre backend zuno-api '
      '(Docker ou Cloudflare Workers ; voir la section de déploiement du README). '
      'Renseignez l’adresse du serveur dans Réglages → Adresse de la bibliothèque.',
  'goSettings': 'Aller aux réglages',
  'libraryEmptyTitle': 'La bibliothèque est vide',
  'libraryEmptyBody':
      'S’il s’agit de votre propre backend, vérifiez l’adresse dans Réglages → '
      'Adresse de la bibliothèque. Si l’adresse est correcte mais que la liste est '
      'vide, l’outil d’administration n’a encore synchronisé aucun paquet .zuno.',
  'setLibraryAddress': 'Définir l’adresse',
  'catalogLoadFailed': 'Impossible de charger le catalogue',
  'changeAddress': 'Changer l’adresse',
  'endOfList': 'C’est tout',
  'packageInfo': 'Informations du paquet',
  'authorField': 'Auteur',
  'versionField': 'Version',
  'sizeField': 'Taille',
  'updatedField': 'Mise à jour',
  'idField': 'ID',
  'unsigned': 'Non signé',
  'downloadImport': 'Télécharger et importer',
  'downloading': 'Téléchargement…',
  'downloadingPercent': 'Téléchargement {percent} %',
  'addedToMyWallpapers': 'Ajouté à Mes fonds d’écran',
  'importBusy': 'Un import est déjà en cours. Veuillez patienter.',
  'downloadFailed': 'Échec du téléchargement : {error}',
  'downloadFileUnreadable': 'Échec de l’import : impossible de lire le fichier téléchargé',
  'verifyNote':
      'Le manifeste et la somme de contrôle sont revérifiés sur cet appareil après '
      'le téléchargement. Seuls les paquets valides rejoignent Mes fonds d’écran ; '
      'en cas d’échec, la raison exacte est affichée.',

  // ---- Réglages ----
  'appearance': 'Apparence',
  'followSystem': 'Système',
  'light': 'Clair',
  'dark': 'Sombre',
  'appearanceHint': 'Suit le système par défaut. Les changements s’appliquent immédiatement et sont mémorisés.',
  'interfaceSection': 'Interface',
  'showTabBar': 'Afficher la barre d’onglets inférieure',
  'showTabBarHint': 'Si elle est masquée, utilisez le bouton de la barre supérieure pour basculer entre Mes fonds / Bibliothèque',
  'performanceTier': 'Performances',
  'tierHigh': 'Élevées',
  'tierMedium': 'Moyennes',
  'tierLow': 'Basses',
  'performanceHintBody':
      'S’applique à tous les chemins de rendu des fonds (par défaut : Moyennes) :\n'
      '· Vidéo : Élevées/Moyennes lisent normalement ; Basses affiche une première image fixe\n'
      '· Profondeur : 30 / 20 / 15 fps (l’économie de batterie force 15)\n'
      '· HTML : Élevées illimité, Moyennes ~30 fps, Basses gèle les animations CSS',
  'videoDecode': 'Décodage vidéo',
  'decodeAuto': 'Auto',
  'decodeHardware': 'Matériel',
  'decodeSoftware': 'Logiciel',
  'decodeHintBody':
      'Auto : privilégie le matériel et ne bascule sur le logiciel qu’en cas d’indisponibilité ; les échecs sont signalés.\n'
      'Matériel : le plus économe ; la compatibilité dépend du décodeur de l’appareil.\n'
      'Logiciel : compatibilité maximale, mais consommation et chaleur accrues, avec des images perdues possibles en haute résolution.\n'
      'Le volume reste contrôlé par paquet et est coupé par défaut.',
  'decodePrompt': 'Signaler les échecs de décodage',
  'decodePromptHint': 'Proposer le décodage logiciel au retour dans l’application',
  'depthParallax': 'Parallaxe de profondeur',
  'depthSoft': 'Douce',
  'depthStandard': 'Standard',
  'depthStrong': 'Forte',
  'depthHint':
      'Multiplicateur global appliqué à l’intensité de parallaxe de chaque paquet '
      'de profondeur. Choisissez Douce si l’écran d’accueil bouge trop.',
  'libraryAddress': 'Adresse de la bibliothèque',
  'addressConfigured':
      'Active : {url}\n'
      'Pointe vers votre propre déploiement zuno-api (Docker ou Cloudflare Workers ; voir le README). '
      'L’enregistrement reconstruit immédiatement le catalogue. Si elle est vide, l’onglet Bibliothèque affiche un guide.',
  'addressNotConfigured':
      'Non configurée. Saisissez l’adresse de votre serveur zuno-api '
      '(voir « Déploiement du backend » dans le README). L’enregistrement reconstruit immédiatement le catalogue.',
  'addressHint': 'https://api.example.com',
  'libraryAddressSaved': 'Adresse de la bibliothèque enregistrée',
  'libraryAddressCleared': 'Adresse de la bibliothèque effacée',
  'batteryOptimization': 'Optimisation de la batterie',
  'batteryFooter':
      'Les fonds planifiés doivent s’exécuter en arrière-plan pour changer à '
      'l’heure. Ajouter ZUNO à la liste d’optimisation de la batterie évite que '
      'le système retarde les changements pendant la veille.',
  'batteryAllowed': 'Ajouté à la liste d’optimisation de la batterie',
  'batteryNotAllowed': 'Absent de la liste d’optimisation de la batterie',
  'storage': 'Stockage',
  'libraryUsage': 'Espace de la bibliothèque',
  'libraryUsageSubtitle': 'Fichiers des paquets installés (répertoire privé de l’application)',
  'aboutZuno': 'À propos de ZUNO',
  'aboutZunoSubtitle': 'Version · Communauté',

  // ---- À propos ----
  'aboutDescription':
      'Donnez vie à votre écran d’accueil. ZUNO propose des fonds vidéo, parallaxe '
      'de profondeur, HTML interactif et planifiés : importez un paquet, appliquez-le, '
      'et votre bureau s’anime.',
  'qqGroup': 'Groupe QQ',
  'qqGroupSubtitle': 'Signaler des problèmes, partager des fonds et obtenir des paquets',
  'groupLinkCopied': 'Lien du groupe copié — collez-le dans QQ pour rejoindre',
  'highlights': 'Points forts',
  'featureVideoTitle': 'Fonds vidéo',
  'featureVideoDesc': 'Lecture fluide, silencieux par défaut, vitesse et volume réglables',
  'featureDepthTitle': 'Parallaxe de profondeur',
  'featureDepthDesc': 'Une sensation de profondeur 3D en inclinant le téléphone',
  'featureHtmlTitle': 'HTML interactif',
  'featureHtmlDesc': 'Des fonds web qui réagissent aux touches',
  'featureTimedTitle': 'Changement planifié',
  'featureTimedDesc': 'Des fonds différents le jour et la nuit',
  'featurePerformanceTitle': 'Niveaux de performance',
  'featurePerformanceDesc': 'Élevées / Moyennes / Basses : équilibre entre rendu et batterie',
  'madeWith': 'Made with ZUNO',

  // ---- Compte ----
  'login': 'Se connecter',
  'register': 'Créer un compte',
  'email': 'E-mail',
  'password': 'Mot de passe',
  'passwordMin': 'Mot de passe (au moins 8 caractères)',
  'confirmPassword': 'Saisissez à nouveau le mot de passe',
  'loginRegister': 'Connexion / Inscription',
  'emailInvalid': 'Adresse e-mail invalide',
  'passwordLength': 'Le mot de passe doit contenir entre 8 et 128 caractères',
  'passwordMismatch': 'Les mots de passe ne correspondent pas',
  'signingIn': 'Connexion…',
  'creating': 'Création…',
  'createAccount': 'Créer un compte',
  'authNote':
      'Les comptes servent à la bibliothèque en ligne et aux tickets de '
      'téléchargement. L’envoi de fonds et la gestion des utilisateurs sont des '
      'fonctions d’administration (Admin Secret), absentes du client.',
  'logoutTitle': 'Se déconnecter ?',
  'logoutBody': 'Vous devrez vous reconnecter pour télécharger des fonds en ligne. Les fonds installés ne sont pas affectés.',
  'logout': 'Se déconnecter',
  'account': 'Compte',
  'sessionValidity': 'Validité de la session',
  'sessionDaysLeft': '{days} jours restants ; vous devrez vous reconnecter après expiration',
  'notSignedIn': 'Non connecté',
  'signedInSubtitle': 'Compte gratuit · {days} jours restants',
  'freeAccountDays': 'Compte gratuit · {days} jours restants',
  'loginToDownload': 'Connectez-vous pour télécharger des fonds en ligne ; la navigation reste libre',
  'management': 'Gestion',
  'managementFooter':
      'L’envoi et la gestion des sessions nécessitent ADMIN_SECRET côté serveur : '
      'l’outil d’administration écrit les paquets directement dans WebDAV, puis '
      '/api/admin/sync enregistre les métadonnées. Le client n’intervient jamais.',
  'uploadWallpaper': 'Envoyer un fond',
  'uploadSubtitle': 'Envoi direct WebDAV + synchronisation en arrière-plan',
  'userManagement': 'Gestion des utilisateurs',
  'userManagementSubtitle': 'Table D1 users, administration uniquement',
  'adminBadge': 'Admin',

  // ---- Dialogues ----
  'setWallpaperTitle': 'Définir ZUNO comme fond d’écran animé ?',
  'setWallpaperMessage':
      'L’aperçu des fonds d’écran du système va s’ouvrir. Appuyez sur '
      '« Définir le fond d’écran » pour animer votre écran d’accueil.',
  'goSet': 'Configurer',
  'decodeSoftwareFailedTitle': 'Le décodage logiciel échoue aussi',
  'decodeSoftwareFailedMessage':
      'Cette vidéo ne peut pas non plus être lue par le décodeur logiciel ; le fond '
      'restera sur une première image fixe. Essayez une vidéo H.264 / H.265 en '
      '1080p ou moins.',
  'decodeHardwareFailedTitle': 'Échec du décodage matériel',
  'decodeHardwareFailedMessage':
      'Cette vidéo ne peut pas être lue avec le décodage matériel. Vous pouvez '
      'passer au logiciel, mais cela consomme nettement plus et peut saccader en '
      'haute résolution.',
  'neverAsk': 'Ne plus demander',
  'useSoftware': 'Utiliser le logiciel',
  'switchedToSoftware':
      'Décodage logiciel activé ; le fond se rechargera au retour sur l’écran d’accueil',

  // ---- Types de fond ----
  'typeVideo': 'Vidéo',
  'typeHtml': 'HTML',
  'typeDepth': 'Profondeur',
  'typeTimed': 'Planifié',

  // ---- Validation : codes ----
  'issueZipInvalid': 'Impossible d’extraire le ZIP',
  'issueZipSlip': 'Attaque par traversée de chemin ZIP',
  'issueManifestMissing': 'manifest.json est absent',
  'issueManifestUnreadable': 'Impossible d’analyser manifest.json',
  'issueFieldInvalid': 'Champ invalide',
  'issueEntryMissing': 'Fichier d’entrée absent',
  'issueContentEmpty': 'content/ est vide',
  'issueChecksumMismatch': 'Somme de contrôle incorrecte',
  'issueMinSdkTooHigh': 'Le minSdk du paquet dépasse celui de l’appareil',
  'issueTimedScheduleInvalid': 'schedule.json invalide',
  'issueTimedSlotMissing': 'Une plage référencée par schedule.json est absente',
  'issueTimedSlotInvalid': 'Manifeste de plage invalide',
  'issueUnknown': 'Erreur inconnue',

  // ---- Validation : détails d’import ----
  'errFileNotFound': 'Fichier introuvable : {path}',
  'errOpenZip': 'Impossible d’ouvrir le ZIP : {error}',
  'errInvalidZip': 'Conteneur ZIP invalide : {error}',
  'errTooManyEntries': 'Import refusé : trop d’entrées ZIP (zip bomb possible)',
  'errPathTraversal': 'Import refusé : l’entrée « {entry} » contient une traversée de chemin ou un chemin absolu',
  'errEntryTooLarge': 'Import refusé : l’entrée « {entry} » dépasse la limite de {bytes} octets décompressés (zip bomb possible)',
  'errTotalTooLarge': 'Import refusé : la taille décompressée totale dépasse la limite (zip bomb possible)',
  'errNoFiles': 'Le ZIP ne contient aucun fichier',
  'errManifestMissingRoot': 'Aucun manifest.json à la racine (ou dans un unique dossier de premier niveau)',
  'errManifestMultiple': 'Plusieurs dossiers de premier niveau contiennent manifest.json : {folders}',
  'errManifestJson': 'manifest.json n’est pas un JSON valide : {error}',
  'errManifestTopLevel': 'Le niveau racine de manifest.json doit être un objet',
  'errTimedNeedsSchedule': 'Un paquet planifié doit contenir content/schedule.json',
  'errPathEscapesStaging': 'Un chemin extrait s’est échappé du répertoire temporaire',
  'errImportException': 'Erreur inattendue pendant l’import : {error}',
  'errChecksumMismatch': 'Somme de contrôle incorrecte : attendue {expected}, calculée {actual}',
  'errChecksumRecompute': 'Impossible de recalculer la somme de contrôle : {error}',
  'errManifestParse': 'Impossible d’analyser le manifeste (paquet malformé) : {error}',
  'errEntryNotInPackage': 'l’entrée « {entry} » n’est pas dans le paquet ({count} fichiers trouvés)',
  'errContentEmpty': 'Le répertoire content/ est vide (ou le ZIP n’a aucune entrée content/)',
  'errMinSdk': 'Le paquet exige minSdk={required}, cet appareil est en API {actual}',
  'errDepthRequires': 'Le type depth exige content/depth.png (une carte de profondeur en niveaux de gris de la même taille que l’image couleur)',
  'errDepthEntryFormat': 'L’entrée depth doit être jpg/png, reçu : {entry}',
  'errHtmlEntryFormat': 'L’entrée HTML doit être un fichier .html, reçu : {entry}',
  'errVideoEntryFormat': 'L’entrée vidéo doit être mp4/webm, reçu : {entry}',
  'errSlotMissing': 'Le planning référence la plage « {slot} », absente ({path})',
  'errSlotContentEmpty': 'La plage « {slot} » a un répertoire content/ vide',
  'errSlotSchema': 'La plage « {slot} » doit avoir manifest.schemaVersion = 1',
  'errSlotIdMissing': 'La plage « {slot} » n’a pas de manifest.id',
  'errSlotIdConflict': 'La plage « {slot} » a le même id que le paquet de premier niveau',
  'errSlotNestedTimed': 'La plage « {slot} » ne peut pas contenir un type planifié imbriqué',
  'errSlotTypeInvalid': 'La plage « {slot} » doit être video/html/depth, reçu : {type}',
  'errSlotEntryMissing': 'La plage « {slot} » n’a pas de manifest.entry',
  'errSlotEntryNotFound': 'L’entrée « {entry} » de la plage « {slot} » n’existe pas',
  'errSlotManifestUnreadable': 'Impossible d’analyser manifest.json de la plage « {slot} » : {error}',
  'errScheduleJson': 'schedule.json n’est pas un JSON valide : {error}',
  'errScheduleTopLevel': 'Le niveau racine de schedule.json doit être un objet',
  'errScheduleRules': 'schedule.rules doit être un tableau',
  'errRuleNotObject': 'rules[{index}] doit être un objet',
  'errRuleFrom': 'rules[{index}].from doit être HH:mm, reçu : {value}',
  'errRuleTo': 'rules[{index}].to doit être HH:mm, reçu : {value}',
  'errRuleWallpaper': 'rules[{index}].wallpaper doit être une chaîne non vide',
  'errDefaultString': 'default doit être une chaîne',
  'warnVideoCodec':
      'Ce codec vidéo peut ne pas être pris en charge sur certains téléphones. '
      'Le fond peut s’afficher comme une image fixe ; une vidéo H.264/H.265 est recommandée.',
  'warnVideoDecodeLimit':
      'La résolution/fréquence de cette vidéo dépasse la capacité de décodage de '
      'cet appareil. L’aperçu et le fond afficheront une première image fixe.',

  // ---- Réseau / API ----
  'errSessionIncomplete': 'Le serveur a renvoyé des données de session incomplètes',
  'errTicketIncomplete': 'Le serveur a renvoyé un ticket de téléchargement incomplet',
  'errCannotConnect': 'Impossible de se connecter au serveur : {error}',
  'errRequestFailed': 'Échec de la requête : {error}',
  'errResponseReadFailed': 'Impossible de lire la réponse : {error}',
  'errorDetailSeparator': ' : ',
  'errDownloadHttp': 'Échec du téléchargement (HTTP {code}){body}',
  'errCatalogLoad': 'Impossible de charger le catalogue : {error}',
  'errLoadMore': 'Impossible de charger la suite : {error}',
  'errWallpaperDownloading': 'Ce fond d’écran est déjà en cours de téléchargement',
  'errEndpointInvalid': 'Saisissez une adresse complète, par exemple https://api.example.com',
  'errOperationFailed': 'Échec de l’opération : {error}',
  'errSizeUnknown': 'Taille inconnue',

  // ---- Raisons du manifeste ----
  'reasonMustBeObject': 'doit être un objet',
  'reasonRequiredString': 'obligatoire et doit être une chaîne non vide, reçu : {value}',
  'reasonMustBeString': 'doit être une chaîne, reçu : {value}',
  'reasonRequiredInt': 'obligatoire et doit être un entier, reçu : {value}',
  'reasonMustBeInt': 'doit être un entier, reçu : {value}',
  'reasonMustBeNumber': 'doit être un nombre, reçu : {value}',
  'reasonConfigObject': 'config[{index}] doit être un objet',
  'reasonConfigKey': 'config[{index}].key est obligatoire et doit être une chaîne',
  'reasonConfigType': 'config[{index}].type doit être float/int/bool/color, reçu : {type}',
  'reasonDefaultFloat': 'la valeur par défaut d’un paramètre float doit être un nombre',
  'reasonDefaultInt': 'la valeur par défaut d’un paramètre int doit être un entier',
  'reasonDefaultBool': 'la valeur par défaut d’un paramètre bool doit être un booléen',
  'reasonDefaultColor': 'la valeur par défaut d’un paramètre color doit être #RRGGBB(AA)',
  'reasonMinMax': 'min > max',
  'reasonCapabilitiesObject': 'doit être un objet',
  'reasonStringArray': 'doit être un tableau de chaînes',
  'reasonElementString': 'les éléments doivent être des chaînes, reçu : {value}',
  'reasonSchemaOnly1': 'seul schemaVersion 1 est pris en charge, reçu : {value}',
  'reasonIdCharset': 'seuls les lettres/chiffres/points/underscores sont autorisés, et « . » ou « .. » est interdit, reçu : {value}',
  'reasonSemver': 'doit être une version sémantique (p. ex. 1.0.0), reçu : {value}',
  'reasonTypeOneOf': 'doit être video/html/depth/timed',
  'reasonPerformanceHint': 'doit être low/medium/high, reçu : {value}',
  'reasonConfigArray': 'doit être un tableau',
  'reasonDuplicateKeys': 'clés en double',
};
