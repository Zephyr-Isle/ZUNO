/// Deutsch.
const Map<String, String> zunoStringsDe = {
  // ---- Allgemein ----
  'cancel': 'Abbrechen',
  'delete': 'Löschen',
  'later': 'Später',
  'gotIt': 'Verstanden',
  'back': 'Zurück',
  'settings': 'Einstellungen',
  'save': 'Speichern',
  'clearAddress': 'Adresse löschen',
  'retry': 'Erneut versuchen',
  'close': 'Schließen',
  'exitFullscreen': 'Vollbild beenden',
  'fullscreenPreview': 'Vollbildvorschau',
  'openSettings': 'Einstellungen öffnen',
  'unknownError': 'Unbekannter Fehler',
  'calculating': 'Wird berechnet…',

  // ---- Navigation ----
  'myWallpapers': 'Meine Hintergrundbilder',
  'wallpaperLibrary': 'Hintergrundbibliothek',
  'settingsTitle': 'Einstellungen',
  'aboutTitle': 'Über',
  'languageTitle': 'Sprache',
  'languageSystem': 'Systemeinstellung folgen',
  'languageDescription': 'Wähle die Anzeigesprache der App. „Systemeinstellung folgen“ verwendet die Android-Sprache.',
  'languageCurrent': 'Aktuell',
  'openLibrary': 'Hintergrundbibliothek öffnen',
  'backToMyWallpapers': 'Zurück zu meinen Hintergrundbildern',
  'refreshLibrary': 'Hintergrundbibliothek aktualisieren',
  'settingsSemantic': 'Einstellungen',
  'inUse': 'In Verwendung',
  'installed': 'Installiert',

  // ---- Meine Hintergrundbilder ----
  'importingPackage': 'Hintergrundpaket wird entpackt und geprüft (Hintergrund-Isolate)…',
  'importZuno': '.zuno importieren',
  'emptyLibraryTitle': 'Deine Bibliothek ist leer',
  'emptyLibraryBody':
      'Importiere ein .zuno-Paket nach der ZUNO-Package-v1-Spezifikation.\n'
      'Unterstützt werden Video-, Tiefenparallax-, HTML- und zeitgesteuerte Hintergründe.',
  'importSuccessWarnings': 'Importiert, mit Hinweisen',
  'importRejected': 'Import abgelehnt',
  'importFailedUnreadable': 'Import fehlgeschlagen: Datei konnte nicht gelesen werden',

  // ---- Hintergrunddetails ----
  'performanceHint': 'Leistungsempfehlung',
  'hintLow': 'Niedrig',
  'hintMedium': 'Mittel',
  'hintHigh': 'Hoch',
  'authorLabel': 'Autor',
  'parameters': 'Parameter',
  'noParameters': 'Dieser Hintergrund hat keine einstellbaren Parameter',
  'capTouch': 'Berührungseingabe',
  'capSensors': 'Sensoren: {sensors}',
  'capNetwork': 'Netzwerk deklariert (in v1 weiterhin blockiert)',
  'scheduleWindows': 'Zeitplan',
  'currentSlot': 'Aktuell: {slot}',
  'defaultSlot': 'Standard: {slot}',
  'timedPreview': 'Zeitvorschau',
  'timedPreviewActiveHint':
      'Ziehen, um die einzelnen Zeitfenster anzusehen. Der echte Zeitplan wird bei der nächsten WorkManager-Prüfung wiederhergestellt.',
  'timedPreviewInactiveHint':
      'Wende diesen Hintergrund zuerst an, um Zeitfenster anzusehen (die Vorschau wechselt das aktive Fenster live).',
  'applyWallpaper': 'Hintergrund anwenden',
  'applyHint': 'Öffnet die Systemvorschau – tippe auf „Hintergrund festlegen“, um zu bestätigen',
  'livePreview': 'Live-Vorschau',
  'noThumbnail': 'Kein Vorschaubild',
  'thumbnailLoadFailed': 'Vorschaubild konnte nicht geladen werden',
  'htmlPreviewFullscreen': 'HTML-Hintergrundvorschau (zum Zoomen zusammenziehen)',
  'videoFullscreen': 'Video-Vollbildvorschau',
  'depthFullscreen': 'Tiefenparallax-Vollbildvorschau',
  'timedNoRender':
      'Der zeitgesteuerte Typ rendert nicht selbst.\n'
      'Die Vollbildvorschau zeigt das aktuell aktive Zeitfenster.',
  'currentPeriod': 'Aktuelles Zeitfenster: {slot}',
  'unsupportedFullscreen': 'Für das aktuelle Zeitfenster ({slot}) ist keine Vollbildvorschau verfügbar',
  'exportShare': 'Exportieren / teilen',
  'deletePackageTitle': 'Hintergrundpaket löschen?',
  'deletePackageBody': '{title} und die zugehörigen Dateien werden gelöscht.',
  'packingPackage': 'Hintergrundpaket wird gepackt (Streaming-Export)…',
  'exportFailed': 'Export fehlgeschlagen',
  'exportedTo': 'Exportiert nach: {path}',
  'applyPreviewPrompt': 'Systemvorschau wird geöffnet – tippe auf „Hintergrund festlegen“',
  'videoPreviewInitFailed':
      'Videovorschau konnte nicht gestartet werden: {error}',
  'videoUnsupported': 'Dieses Gerät kann das Video nicht live abspielen; der Hintergrund zeigt ein Standbild',
  'videoLoading': 'Video wird geladen…',
  'colorImageLoadFailed': 'Farbbild konnte nicht geladen werden',
  'depthApproxHint': 'Die Vorschau ist eine Näherung; der echte Hintergrund ist flüssiger',
  'slotResolveFailed': 'Das aktuelle Zeitfenster konnte nicht ermittelt werden',
  'deleteInUse': 'Dieser Hintergrund wird verwendet. Wende zuerst einen anderen an, bevor du ihn löschst.',
  'deleteFailed': 'Löschen fehlgeschlagen: {error}',
  'applyFailedGeneric': 'Anwenden fehlgeschlagen',
  'applyFailed': 'Anwenden fehlgeschlagen: {error}',
  'applyNoPreview':
      'Die Einstellungen wurden gespeichert, aber die Systemvorschau konnte nicht geöffnet werden – wähle ZUNO in den System-Hintergrundeinstellungen manuell aus',
  'applyTimedFailed':
      'Das aktuelle Zeitfenster konnte nicht ermittelt werden (evtl. nur beim Laden erlaubt; schließe ein Ladegerät an und versuche es erneut)',

  // ---- Online-Bibliothek ----
  'libraryNotConfiguredTitle': 'Bibliothek nicht konfiguriert',
  'libraryNotConfiguredBody':
      'Die Hintergrundbibliothek verweist auf dein eigenes zuno-api-Backend '
      '(Docker oder Cloudflare Workers; siehe Bereitstellungsabschnitt im README). '
      'Trage die Serveradresse unter Einstellungen → Adresse der Hintergrundbibliothek ein.',
  'goSettings': 'Zu den Einstellungen',
  'libraryEmptyTitle': 'Die Bibliothek ist leer',
  'libraryEmptyBody':
      'Wenn dies dein eigenes Backend ist, prüfe die Adresse unter Einstellungen → '
      'Adresse der Hintergrundbibliothek. Ist die Adresse korrekt, aber die Liste leer, '
      'hat das Admin-Werkzeug noch keine .zuno-Pakete synchronisiert.',
  'setLibraryAddress': 'Adresse festlegen',
  'catalogLoadFailed': 'Katalog konnte nicht geladen werden',
  'changeAddress': 'Adresse ändern',
  'endOfList': 'Das war alles',
  'packageInfo': 'Paketinformationen',
  'authorField': 'Autor',
  'versionField': 'Version',
  'sizeField': 'Größe',
  'updatedField': 'Aktualisiert',
  'idField': 'ID',
  'unsigned': 'Ohne Angabe',
  'downloadImport': 'Herunterladen und importieren',
  'downloading': 'Wird heruntergeladen…',
  'downloadingPercent': 'Wird heruntergeladen: {percent} %',
  'addedToMyWallpapers': 'Zu „Meine Hintergrundbilder“ hinzugefügt',
  'importBusy': 'Es läuft bereits ein Import. Bitte warten.',
  'downloadFailed': 'Download fehlgeschlagen: {error}',
  'downloadFileUnreadable': 'Import fehlgeschlagen: heruntergeladene Datei konnte nicht gelesen werden',
  'verifyNote':
      'Manifest und Prüfsumme werden nach dem Download auf diesem Gerät erneut '
      'geprüft. Nur gültige Pakete landen unter „Meine Hintergrundbilder“; bei '
      'Fehlern wird der genaue Grund angezeigt.',

  // ---- Einstellungen ----
  'appearance': 'Darstellung',
  'followSystem': 'System',
  'light': 'Hell',
  'dark': 'Dunkel',
  'appearanceHint': 'Folgt standardmäßig dem System. Änderungen gelten sofort und werden gespeichert.',
  'interfaceSection': 'Oberfläche',
  'showTabBar': 'Untere Tab-Leiste anzeigen',
  'showTabBarHint': 'Wenn ausgeblendet, wechsle über die obere Schaltfläche zwischen Meine Hintergründe / Bibliothek',
  'performanceTier': 'Leistung',
  'tierHigh': 'Hoch',
  'tierMedium': 'Mittel',
  'tierLow': 'Niedrig',
  'performanceHintBody':
      'Gilt für alle Rendering-Pfade der Hintergründe (Standard: Mittel):\n'
      '· Video: Hoch/Mittel spielen normal; Niedrig zeigt ein stehendes erstes Bild\n'
      '· Tiefe: 30 / 20 / 15 fps (Energiesparmodus erzwingt 15)\n'
      '· HTML: Hoch unbegrenzt, Mittel ~30 fps, Niedrig friert CSS-Animationen ein',
  'videoDecode': 'Videodekodierung',
  'decodeAuto': 'Automatisch',
  'decodeHardware': 'Hardware',
  'decodeSoftware': 'Software',
  'decodeHintBody':
      'Automatisch: Hardware bevorzugen und nur bei Nichtverfügbarkeit auf Software ausweichen; Laufzeitfehler werden gemeldet.\n'
      'Hardware: am energieeffizientesten; Kompatibilität hängt vom Decoder des Geräts ab.\n'
      'Software: größte Kompatibilität, aber höherer Verbrauch und mögliche Bildaussetzer bei hochauflösendem Video.\n'
      'Die Lautstärke wird weiterhin pro Paket gesteuert und ist standardmäßig stumm.',
  'decodePrompt': 'Bei Dekodierungsfehler benachrichtigen',
  'decodePromptHint': 'Beim Zurückkehren in die App Software-Dekodierung anbieten',
  'depthParallax': 'Tiefenparallaxe',
  'depthSoft': 'Sanft',
  'depthStandard': 'Standard',
  'depthStrong': 'Stark',
  'depthHint':
      'Globaler Multiplikator, der auf die Parallaxstärke jedes Tiefenpakets '
      'angewendet wird. Wähle Sanft, wenn der Startbildschirm zu stark wackelt.',
  'libraryAddress': 'Adresse der Hintergrundbibliothek',
  'addressConfigured':
      'Aktiv: {url}\n'
      'Verweist auf deine eigene zuno-api-Bereitstellung (Docker oder Cloudflare Workers; siehe README). '
      'Speichern baut den Katalog sofort neu auf. Ist nichts gesetzt, zeigt der Bibliothek-Tab eine Anleitung.',
  'addressNotConfigured':
      'Nicht konfiguriert. Gib die Adresse deines eigenen zuno-api-Servers ein '
      '(siehe „Backend-Bereitstellung“ im README). Speichern baut den Katalog sofort neu auf.',
  'addressHint': 'https://api.example.com',
  'libraryAddressSaved': 'Adresse der Wallpaper-Bibliothek gespeichert',
  'libraryAddressCleared': 'Adresse der Wallpaper-Bibliothek gelöscht',
  'batteryOptimization': 'Akkuoptimierung',
  'batteryFooter':
      'Zeitgesteuerte Hintergründe müssen im Hintergrund laufen, um pünktlich zu '
      'wechseln. Wenn ZUNO zur Akkuoptimierungs-Ausnahmeliste hinzugefügt wird, '
      'verschiebt das System die Wechsel im Ruhezustand nicht stark.',
  'batteryAllowed': 'Zur Akkuoptimierungs-Ausnahmeliste hinzugefügt',
  'batteryNotAllowed': 'Nicht in der Akkuoptimierungs-Ausnahmeliste',
  'storage': 'Speicher',
  'libraryUsage': 'Bibliotheksspeicher',
  'libraryUsageSubtitle': 'Installierte Hintergrundpaket-Dateien (app-privates Verzeichnis)',
  'aboutZuno': 'Über ZUNO',
  'aboutZunoSubtitle': 'Versionsinfo · Community',

  // ---- Über ----
  'aboutDescription':
      'Bring deinen Startbildschirm in Bewegung. ZUNO bietet Video-, Tiefenparallax-, '
      'interaktive HTML- und zeitgesteuerte Hintergründe: Paket importieren, anwenden, '
      'und der Desktop bewegt sich.',
  'qqGroup': 'QQ-Gruppe',
  'qqGroupSubtitle': 'Probleme melden, Hintergründe teilen und Pakete erhalten',
  'groupLinkCopied': 'Gruppenlink kopiert – in QQ einfügen, um beizutreten',
  'highlights': 'Highlights',
  'featureVideoTitle': 'Video-Hintergründe',
  'featureVideoDesc': 'Flüssige Wiedergabe, standardmäßig stumm, Geschwindigkeit und Lautstärke anpassbar',
  'featureDepthTitle': 'Tiefenparallaxe',
  'featureDepthDesc': 'Räumliche Tiefe beim Neigen des Telefons',
  'featureHtmlTitle': 'Interaktives HTML',
  'featureHtmlDesc': 'Web-Hintergründe, die auf Berührungen reagieren',
  'featureTimedTitle': 'Zeitgesteuerter Wechsel',
  'featureTimedDesc': 'Andere Hintergründe für Tag und Nacht',
  'featurePerformanceTitle': 'Leistungsstufen',
  'featurePerformanceDesc': 'Hoch / Mittel / Niedrig – Optik und Akku ausbalancieren',
  'madeWith': 'Made with ZUNO',

  // ---- Konto ----
  'login': 'Anmelden',
  'register': 'Konto erstellen',
  'email': 'E-Mail',
  'password': 'Passwort',
  'passwordMin': 'Passwort (mindestens 8 Zeichen)',
  'confirmPassword': 'Passwort erneut eingeben',
  'loginRegister': 'Anmelden / Registrieren',
  'emailInvalid': 'Ungültige E-Mail-Adresse',
  'passwordLength': 'Das Passwort muss 8–128 Zeichen lang sein',
  'passwordMismatch': 'Die Passwörter stimmen nicht überein',
  'signingIn': 'Anmeldung…',
  'creating': 'Wird erstellt…',
  'createAccount': 'Konto erstellen',
  'authNote':
      'Konten werden für die Online-Bibliothek und Download-Tickets verwendet. '
      'Das Hochladen von Hintergründen und die Benutzerverwaltung sind '
      'Admin-Funktionen (Admin Secret) und im Client nicht verfügbar.',
  'logoutTitle': 'Abmelden?',
  'logoutBody': 'Zum Herunterladen von Online-Hintergründen musst du dich erneut anmelden. Installierte Hintergründe sind nicht betroffen.',
  'logout': 'Abmelden',
  'account': 'Konto',
  'sessionValidity': 'Sitzungsgültigkeit',
  'sessionDaysLeft': 'Noch {days} Tage; danach ist eine erneute Anmeldung nötig',
  'notSignedIn': 'Nicht angemeldet',
  'signedInSubtitle': 'Kostenloses Konto · noch {days} Tage',
  'freeAccountDays': 'Kostenloses Konto · noch {days} Tage',
  'loginToDownload': 'Melde dich an, um Online-Hintergründe herunterzuladen; das Stöbern ist frei',
  'management': 'Verwaltung',
  'managementFooter':
      'Uploads und Sitzungsverwaltung erfordern serverseitiges ADMIN_SECRET: Pakete '
      'werden vom Admin-Werkzeug direkt in WebDAV geschrieben, danach werden die '
      'Metadaten über /api/admin/sync erfasst. Der Client ist nie beteiligt.',
  'uploadWallpaper': 'Hintergrund hochladen',
  'uploadSubtitle': 'Direkter WebDAV-Upload + Hintergrund-Synchronisierung',
  'userManagement': 'Benutzerverwaltung',
  'userManagementSubtitle': 'D1-users-Tabelle, nur Admin',
  'adminBadge': 'Admin',

  // ---- Dialoge ----
  'setWallpaperTitle': 'ZUNO als Live-Hintergrund festlegen?',
  'setWallpaperMessage':
      'Die Systemvorschau für Hintergründe wird geöffnet. Tippe auf '
      '„Hintergrund festlegen“, um deinen Startbildschirm zu beleben.',
  'goSet': 'Einrichten',
  'decodeSoftwareFailedTitle': 'Auch Software-Dekodierung fehlgeschlagen',
  'decodeSoftwareFailedMessage':
      'Dieses Video kann auch der Software-Decoder nicht abspielen; der Hintergrund '
      'bleibt auf einem stehenden ersten Bild. Versuche ein H.264-/H.265-Video mit '
      '1080p oder weniger.',
  'decodeHardwareFailedTitle': 'Hardware-Dekodierung des Videos fehlgeschlagen',
  'decodeHardwareFailedMessage':
      'Dieses Video kann nicht mit Hardware-Dekodierung abgespielt werden. Du kannst '
      'auf Software umstellen, was aber deutlich mehr Energie verbraucht und bei '
      'hochauflösendem Video ruckeln kann.',
  'neverAsk': 'Nicht mehr fragen',
  'useSoftware': 'Software verwenden',
  'switchedToSoftware':
      'Auf Software-Dekodierung umgestellt; der Hintergrund wird beim Zurückkehren '
      'zum Startbildschirm neu geladen',

  // ---- Hintergrundtypen ----
  'typeVideo': 'Video',
  'typeHtml': 'HTML',
  'typeDepth': 'Tiefe',
  'typeTimed': 'Zeitgesteuert',

  // ---- Validierung: Codes ----
  'issueZipInvalid': 'ZIP kann nicht entpackt werden',
  'issueZipSlip': 'ZIP-Pfad-Traversal-Angriff',
  'issueManifestMissing': 'manifest.json fehlt',
  'issueManifestUnreadable': 'manifest.json kann nicht geparst werden',
  'issueFieldInvalid': 'Ungültiges Feld',
  'issueEntryMissing': 'Einstiegsdatei fehlt',
  'issueContentEmpty': 'content/ ist leer',
  'issueChecksumMismatch': 'Prüfsumme stimmt nicht überein',
  'issueMinSdkTooHigh': 'Das minSdk des Pakets ist höher als das des Geräts',
  'issueTimedScheduleInvalid': 'schedule.json ist ungültig',
  'issueTimedSlotMissing': 'Ein von schedule.json referenziertes Zeitfenster fehlt',
  'issueTimedSlotInvalid': 'Manifest des Zeitfensters ist ungültig',
  'issueUnknown': 'Unbekannter Fehler',

  // ---- Validierung: Importdetails ----
  'errFileNotFound': 'Datei nicht gefunden: {path}',
  'errOpenZip': 'ZIP-Datei konnte nicht geöffnet werden: {error}',
  'errInvalidZip': 'Kein gültiger ZIP-Container: {error}',
  'errTooManyEntries': 'Import abgelehnt: zu viele ZIP-Einträge (mögliche Zip-Bombe)',
  'errPathTraversal': 'Import abgelehnt: Eintrag „{entry}“ enthält Pfad-Traversal oder einen absoluten Pfad',
  'errEntryTooLarge': 'Import abgelehnt: Eintrag „{entry}“ überschreitet das Limit von {bytes} Byte entpackt (mögliche Zip-Bombe)',
  'errTotalTooLarge': 'Import abgelehnt: entpackte Gesamtgröße überschreitet das Limit (mögliche Zip-Bombe)',
  'errNoFiles': 'Die ZIP-Datei enthält keine Dateien',
  'errManifestMissingRoot': 'Keine manifest.json im Stammverzeichnis (oder in einem einzelnen obersten Ordner)',
  'errManifestMultiple': 'Mehrere oberste Ordner enthalten manifest.json: {folders}',
  'errManifestJson': 'manifest.json ist kein gültiges JSON: {error}',
  'errManifestTopLevel': 'Die oberste Ebene von manifest.json muss ein Objekt sein',
  'errTimedNeedsSchedule': 'Ein zeitgesteuertes Paket muss content/schedule.json enthalten',
  'errPathEscapesStaging': 'Ein entpackter Pfad ist aus dem Staging-Verzeichnis entkommen',
  'errImportException': 'Unerwarteter Fehler beim Import: {error}',
  'errChecksumMismatch': 'Prüfsumme stimmt nicht überein: erwartet {expected}, berechnet {actual}',
  'errChecksumRecompute': 'Prüfsumme konnte nicht neu berechnet werden: {error}',
  'errManifestParse': 'Manifest konnte nicht geparst werden (fehlerhaftes Paket): {error}',
  'errEntryNotInPackage': 'Eintrag „{entry}“ ist nicht im Paket ({count} Dateien gefunden)',
  'errContentEmpty': 'Das Verzeichnis content/ ist leer (oder die ZIP hat keine content/-Einträge)',
  'errMinSdk': 'Das Paket verlangt minSdk={required}, dieses Gerät ist API {actual}',
  'errDepthRequires': 'Der Typ depth erfordert content/depth.png (eine Graustufen-Tiefenkarte in derselben Größe wie das Farbbild)',
  'errDepthEntryFormat': 'Der depth-Eintrag muss jpg/png sein, erhalten: {entry}',
  'errHtmlEntryFormat': 'Der HTML-Eintrag muss eine .html-Datei sein, erhalten: {entry}',
  'errVideoEntryFormat': 'Der Video-Eintrag muss mp4/webm sein, erhalten: {entry}',
  'errSlotMissing': 'Der Zeitplan verweist auf das Zeitfenster „{slot}“, das fehlt ({path})',
  'errSlotContentEmpty': 'Zeitfenster „{slot}“ hat ein leeres content/-Verzeichnis',
  'errSlotSchema': 'Zeitfenster „{slot}“ muss manifest.schemaVersion = 1 haben',
  'errSlotIdMissing': 'Zeitfenster „{slot}“ fehlt manifest.id',
  'errSlotIdConflict': 'Zeitfenster „{slot}“ hat dieselbe id wie das oberste Paket',
  'errSlotNestedTimed': 'Zeitfenster „{slot}“ darf keinen verschachtelten zeitgesteuerten Typ enthalten',
  'errSlotTypeInvalid': 'Zeitfenster „{slot}“ muss video/html/depth sein, erhalten: {type}',
  'errSlotEntryMissing': 'Zeitfenster „{slot}“ fehlt manifest.entry',
  'errSlotEntryNotFound': 'Eintrag „{entry}“ von Zeitfenster „{slot}“ existiert nicht',
  'errSlotManifestUnreadable': 'manifest.json von Zeitfenster „{slot}“ konnte nicht geparst werden: {error}',
  'errScheduleJson': 'schedule.json ist kein gültiges JSON: {error}',
  'errScheduleTopLevel': 'Die oberste Ebene von schedule.json muss ein Objekt sein',
  'errScheduleRules': 'schedule.rules muss ein Array sein',
  'errRuleNotObject': 'rules[{index}] muss ein Objekt sein',
  'errRuleFrom': 'rules[{index}].from muss HH:mm sein, erhalten: {value}',
  'errRuleTo': 'rules[{index}].to muss HH:mm sein, erhalten: {value}',
  'errRuleWallpaper': 'rules[{index}].wallpaper muss eine nicht leere Zeichenkette sein',
  'errDefaultString': 'default muss eine Zeichenkette sein',
  'warnVideoCodec':
      'Dieser Video-Codec wird auf manchen Telefonen möglicherweise nicht '
      'unterstützt. Der Hintergrund zeigt dann evtl. ein Standbild; ein H.264/H.265-Video wird empfohlen.',
  'warnVideoDecodeLimit':
      'Auflösung/Bildrate dieses Videos übersteigen die Dekodierfähigkeit dieses '
      'Geräts. Vorschau und Hintergrund zeigen ein stehendes erstes Bild.',

  // ---- Netzwerk / API ----
  'errSessionIncomplete': 'Der Server hat unvollständige Sitzungsdaten zurückgegeben',
  'errTicketIncomplete': 'Der Server hat ein unvollständiges Download-Ticket zurückgegeben',
  'errCannotConnect': 'Keine Verbindung zum Server: {error}',
  'errRequestFailed': 'Anfrage fehlgeschlagen: {error}',
  'errResponseReadFailed': 'Antwort konnte nicht gelesen werden: {error}',
  'errorDetailSeparator': ': ',
  'errDownloadHttp': 'Download fehlgeschlagen (HTTP {code}){body}',
  'errCatalogLoad': 'Katalog konnte nicht geladen werden: {error}',
  'errLoadMore': 'Weitere Einträge konnten nicht geladen werden: {error}',
  'errWallpaperDownloading': 'Dieser Hintergrund wird bereits heruntergeladen',
  'errEndpointInvalid': 'Gib eine vollständige Adresse ein, z. B. https://api.example.com',
  'errOperationFailed': 'Vorgang fehlgeschlagen: {error}',
  'errSizeUnknown': 'Größe unbekannt',

  // ---- Manifest-Gründe ----
  'reasonMustBeObject': 'muss ein Objekt sein',
  'reasonRequiredString': 'erforderlich und muss eine nicht leere Zeichenkette sein, erhalten: {value}',
  'reasonMustBeString': 'muss eine Zeichenkette sein, erhalten: {value}',
  'reasonRequiredInt': 'erforderlich und muss eine Ganzzahl sein, erhalten: {value}',
  'reasonMustBeInt': 'muss eine Ganzzahl sein, erhalten: {value}',
  'reasonMustBeNumber': 'muss eine Zahl sein, erhalten: {value}',
  'reasonConfigObject': 'config[{index}] muss ein Objekt sein',
  'reasonConfigKey': 'config[{index}].key ist erforderlich und muss eine Zeichenkette sein',
  'reasonConfigType': 'config[{index}].type muss float/int/bool/color sein, erhalten: {type}',
  'reasonDefaultFloat': 'der Standardwert eines float-Parameters muss eine Zahl sein',
  'reasonDefaultInt': 'der Standardwert eines int-Parameters muss eine Ganzzahl sein',
  'reasonDefaultBool': 'der Standardwert eines bool-Parameters muss ein Wahrheitswert sein',
  'reasonDefaultColor': 'der Standardwert eines color-Parameters muss #RRGGBB(AA) sein',
  'reasonMinMax': 'min > max',
  'reasonCapabilitiesObject': 'muss ein Objekt sein',
  'reasonStringArray': 'muss ein Array von Zeichenketten sein',
  'reasonElementString': 'Elemente müssen Zeichenketten sein, erhalten: {value}',
  'reasonSchemaOnly1': 'nur schemaVersion 1 wird unterstützt, erhalten: {value}',
  'reasonIdCharset': 'nur Buchstaben/Ziffern/Punkte/Unterstriche erlaubt, "." oder ".." ist nicht erlaubt, erhalten: {value}',
  'reasonSemver': 'muss eine semantische Version sein (z. B. 1.0.0), erhalten: {value}',
  'reasonTypeOneOf': 'muss video/html/depth/timed sein',
  'reasonPerformanceHint': 'muss low/medium/high sein, erhalten: {value}',
  'reasonConfigArray': 'muss ein Array sein',
  'reasonDuplicateKeys': 'doppelte Schlüssel',
};
