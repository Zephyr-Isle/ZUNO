/// Español.
const Map<String, String> zunoStringsEs = {
  // ---- Común ----
  'cancel': 'Cancelar',
  'delete': 'Eliminar',
  'later': 'Más tarde',
  'gotIt': 'Entendido',
  'back': 'Atrás',
  'settings': 'Ajustes',
  'save': 'Guardar',
  'clearAddress': 'Borrar dirección',
  'retry': 'Reintentar',
  'close': 'Cerrar',
  'exitFullscreen': 'Salir de pantalla completa',
  'fullscreenPreview': 'Vista previa a pantalla completa',
  'openSettings': 'Abrir ajustes',
  'unknownError': 'Error desconocido',
  'calculating': 'Calculando…',

  // ---- Navegación ----
  'myWallpapers': 'Mis fondos',
  'wallpaperLibrary': 'Biblioteca de fondos',
  'settingsTitle': 'Ajustes',
  'aboutTitle': 'Acerca de',
  'languageTitle': 'Idioma',
  'languageSystem': 'Seguir al sistema',
  'languageDescription': 'Elige el idioma de la app. «Seguir al sistema» usa el idioma de Android.',
  'languageCurrent': 'Actual',
  'openLibrary': 'Abrir biblioteca de fondos',
  'backToMyWallpapers': 'Volver a mis fondos',
  'refreshLibrary': 'Actualizar biblioteca de fondos',
  'settingsSemantic': 'Ajustes',
  'inUse': 'En uso',
  'installed': 'Instalado',

  // ---- Mis fondos ----
  'importingPackage': 'Extrayendo y verificando el paquete de fondo (isolate en segundo plano)…',
  'importZuno': 'Importar .zuno',
  'emptyLibraryTitle': 'Tu biblioteca está vacía',
  'emptyLibraryBody':
      'Importa un paquete .zuno que cumpla la especificación ZUNO Package v1.\n'
      'Se admiten fondos de vídeo, paralaje de profundidad, HTML y temporizados.',
  'importSuccessWarnings': 'Importado con advertencias',
  'importRejected': 'Importación rechazada',
  'importFailedUnreadable': 'Error de importación: no se pudo leer el archivo',

  // ---- Detalle del fondo ----
  'performanceHint': 'Rendimiento recomendado',
  'hintLow': 'Bajo',
  'hintMedium': 'Medio',
  'hintHigh': 'Alto',
  'authorLabel': 'Autor',
  'parameters': 'Parámetros',
  'noParameters': 'Este fondo no tiene parámetros ajustables',
  'capTouch': 'Entrada táctil',
  'capSensors': 'Sensores: {sensors}',
  'capNetwork': 'Red declarada (sigue bloqueada en v1)',
  'scheduleWindows': 'Horario',
  'currentSlot': 'Actual: {slot}',
  'defaultSlot': 'Predeterminado: {slot}',
  'timedPreview': 'Vista previa por hora',
  'timedPreviewActiveHint':
      'Arrastra para previsualizar cada franja. WorkManager restaurará el horario real en su próxima comprobación.',
  'timedPreviewInactiveHint':
      'Aplica este fondo antes de previsualizar franjas (la vista previa cambia en caliente la franja activa).',
  'applyWallpaper': 'Aplicar fondo',
  'applyHint': 'Abre la vista previa del sistema: pulsa «Establecer fondo» para confirmar',
  'livePreview': 'Vista previa en vivo',
  'noThumbnail': 'Sin miniatura',
  'thumbnailLoadFailed': 'No se pudo cargar la miniatura',
  'htmlPreviewFullscreen': 'Vista previa del fondo HTML (pellizca para ampliar)',
  'videoFullscreen': 'Vista previa del vídeo a pantalla completa',
  'depthFullscreen': 'Vista previa del paralaje a pantalla completa',
  'timedNoRender':
      'El tipo temporizado no se dibuja por sí mismo.\n'
      'La vista previa a pantalla completa muestra la franja activa ahora.',
  'currentPeriod': 'Franja actual: {slot}',
  'unsupportedFullscreen': 'La franja actual ({slot}) no admite vista previa a pantalla completa',
  'exportShare': 'Exportar / compartir',
  'deletePackageTitle': '¿Eliminar el paquete de fondo?',
  'deletePackageBody': 'Se eliminarán {title} y sus archivos.',
  'packingPackage': 'Empaquetando el fondo (exportación en streaming)…',
  'exportFailed': 'Error al exportar',
  'exportedTo': 'Exportado a: {path}',
  'applyPreviewPrompt': 'Abriendo la vista previa del sistema: pulsa «Establecer fondo»',
  'videoPreviewInitFailed':
      'No se pudo iniciar la vista previa del vídeo: {error}',
  'videoUnsupported': 'Este dispositivo no puede reproducir el vídeo en directo; el fondo mostrará un fotograma fijo',
  'videoLoading': 'Cargando vídeo…',
  'colorImageLoadFailed': 'No se pudo cargar la imagen de color',
  'depthApproxHint': 'La vista previa es aproximada; el fondo real es más fluido',
  'slotResolveFailed': 'No se pudo resolver la franja actual',
  'deleteInUse': 'Este fondo está en uso. Aplica otro fondo antes de eliminarlo.',
  'deleteFailed': 'Error al eliminar: {error}',
  'applyFailedGeneric': 'No se pudo aplicar',
  'applyFailed': 'Error al aplicar: {error}',
  'applyNoPreview':
      'La configuración se guardó, pero no se pudo abrir la vista previa del sistema. Elige ZUNO manualmente en los ajustes de fondo del sistema',
  'applyTimedFailed':
      'No se pudo resolver la franja actual (puede estar limitada a la carga; conecta el cargador e inténtalo de nuevo)',

  // ---- Biblioteca en línea ----
  'libraryNotConfiguredTitle': 'Biblioteca no configurada',
  'libraryNotConfiguredBody':
      'La biblioteca apunta a tu propio backend zuno-api '
      '(Docker o Cloudflare Workers; consulta la sección de despliegue del README). '
      'Configura la dirección del servidor en Ajustes → Dirección de la biblioteca.',
  'goSettings': 'Ir a ajustes',
  'libraryEmptyTitle': 'La biblioteca está vacía',
  'libraryEmptyBody':
      'Si es tu propio backend, revisa la dirección en Ajustes → Dirección de la '
      'biblioteca. Si la dirección es correcta pero la lista está vacía, la '
      'herramienta de administración aún no ha sincronizado ningún paquete .zuno.',
  'setLibraryAddress': 'Configurar dirección',
  'catalogLoadFailed': 'No se pudo cargar el catálogo',
  'changeAddress': 'Cambiar dirección',
  'endOfList': 'Eso es todo',
  'packageInfo': 'Información del paquete',
  'authorField': 'Autor',
  'versionField': 'Versión',
  'sizeField': 'Tamaño',
  'updatedField': 'Actualizado',
  'idField': 'ID',
  'unsigned': 'Sin autor',
  'downloadImport': 'Descargar e importar',
  'downloading': 'Descargando…',
  'downloadingPercent': 'Descargando {percent}%',
  'addedToMyWallpapers': 'Añadido a Mis fondos',
  'importBusy': 'Ya hay una importación en curso. Espera un momento.',
  'downloadFailed': 'Error de descarga: {error}',
  'downloadFileUnreadable': 'Error de importación: no se pudo leer el archivo descargado',
  'verifyNote':
      'El manifiesto y la suma de comprobación se verifican de nuevo en este '
      'dispositivo tras la descarga. Solo los paquetes válidos pasan a Mis fondos; '
      'si fallan, se muestra el motivo exacto.',

  // ---- Ajustes ----
  'appearance': 'Apariencia',
  'followSystem': 'Sistema',
  'light': 'Claro',
  'dark': 'Oscuro',
  'appearanceHint': 'Sigue al sistema de forma predeterminada. Los cambios se aplican al instante y se recuerdan.',
  'interfaceSection': 'Interfaz',
  'showTabBar': 'Mostrar barra de pestañas inferior',
  'showTabBarHint': 'Si se oculta, usa el botón superior para cambiar entre Mis fondos / Biblioteca',
  'performanceTier': 'Rendimiento',
  'tierHigh': 'Alto',
  'tierMedium': 'Medio',
  'tierLow': 'Bajo',
  'performanceHintBody':
      'Se aplica a todas las rutas de renderizado del fondo (predeterminado: Medio):\n'
      '· Vídeo: Alto/Medio reproducen con normalidad; Bajo muestra un fotograma fijo\n'
      '· Profundidad: 30 / 20 / 15 fps (el ahorro de batería fuerza 15)\n'
      '· HTML: Alto sin límite, Medio ~30 fps, Bajo congela las animaciones CSS',
  'videoDecode': 'Decodificación de vídeo',
  'decodeAuto': 'Automática',
  'decodeHardware': 'Hardware',
  'decodeSoftware': 'Software',
  'decodeHintBody':
      'Automática: prioriza hardware y solo usa software si el hardware no está disponible; los fallos se notifican.\n'
      'Hardware: máxima eficiencia; la compatibilidad depende del decodificador del dispositivo.\n'
      'Software: máxima compatibilidad, pero consume más y puede perder fotogramas en vídeo de alta resolución.\n'
      'El volumen sigue controlándose por paquete y está silenciado de forma predeterminada.',
  'decodePrompt': 'Avisar si falla la decodificación',
  'decodePromptHint': 'Ofrecer cambiar a decodificación por software al volver a la app',
  'depthParallax': 'Paralaje de profundidad',
  'depthSoft': 'Suave',
  'depthStandard': 'Estándar',
  'depthStrong': 'Fuerte',
  'depthHint':
      'Multiplicador global que se aplica sobre la intensidad de paralaje de cada '
      'paquete de profundidad. Elige Suave si la pantalla de inicio se mueve demasiado.',
  'libraryAddress': 'Dirección de la biblioteca',
  'addressConfigured':
      'Activa: {url}\n'
      'Apunta a tu propio despliegue de zuno-api (Docker o Cloudflare Workers; consulta el README). '
      'Al guardar se reconstruye el catálogo al instante. Si no está configurada, la pestaña Biblioteca muestra una guía.',
  'addressNotConfigured':
      'Sin configurar. Introduce la dirección de tu servidor zuno-api '
      '(consulta «Despliegue del backend» en el README). Al guardar se reconstruye el catálogo al instante.',
  'addressHint': 'https://api.example.com',
  'libraryAddressSaved': 'Dirección de la biblioteca guardada',
  'libraryAddressCleared': 'Dirección de la biblioteca borrada',
  'batteryOptimization': 'Optimización de batería',
  'batteryFooter':
      'Los fondos temporizados necesitan ejecutarse en segundo plano para cambiar '
      'a tiempo. Añadir ZUNO a la lista de optimización de batería evita que el '
      'sistema retrase los cambios mientras duerme.',
  'batteryAllowed': 'Añadido a la lista de optimización de batería',
  'batteryNotAllowed': 'No está en la lista de optimización de batería',
  'storage': 'Almacenamiento',
  'libraryUsage': 'Uso de la biblioteca',
  'libraryUsageSubtitle': 'Archivos de paquetes instalados (directorio privado de la app)',
  'aboutZuno': 'Acerca de ZUNO',
  'aboutZunoSubtitle': 'Versión · Comunidad',

  // ---- Acerca de ----
  'aboutDescription':
      'Da vida a tu pantalla de inicio. ZUNO ofrece fondos de vídeo, paralaje de '
      'profundidad, HTML interactivo y temporizados: importa un paquete, aplícalo '
      'y tu escritorio empezará a moverse.',
  'qqGroup': 'Grupo de QQ',
  'qqGroupSubtitle': 'Informa de problemas, comparte fondos y consigue paquetes',
  'groupLinkCopied': 'Enlace del grupo copiado: pégalo en QQ para unirte',
  'highlights': 'Aspectos destacados',
  'featureVideoTitle': 'Fondos de vídeo',
  'featureVideoDesc': 'Reproducción fluida, silencio por defecto, velocidad y volumen ajustables',
  'featureDepthTitle': 'Paralaje de profundidad',
  'featureDepthDesc': 'Sensación de profundidad 3D al inclinar el teléfono',
  'featureHtmlTitle': 'HTML interactivo',
  'featureHtmlDesc': 'Fondos web que responden a los toques',
  'featureTimedTitle': 'Cambio temporizado',
  'featureTimedDesc': 'Fondos distintos para el día y la noche',
  'featurePerformanceTitle': 'Niveles de rendimiento',
  'featurePerformanceDesc': 'Alto / Medio / Bajo: equilibrio entre aspecto y batería',
  'madeWith': 'Made with ZUNO',

  // ---- Cuenta ----
  'login': 'Iniciar sesión',
  'register': 'Crear cuenta',
  'email': 'Correo electrónico',
  'password': 'Contraseña',
  'passwordMin': 'Contraseña (al menos 8 caracteres)',
  'confirmPassword': 'Introduce la contraseña de nuevo',
  'loginRegister': 'Iniciar sesión / Registrarse',
  'emailInvalid': 'Dirección de correo no válida',
  'passwordLength': 'La contraseña debe tener entre 8 y 128 caracteres',
  'passwordMismatch': 'Las contraseñas no coinciden',
  'signingIn': 'Iniciando sesión…',
  'creating': 'Creando…',
  'createAccount': 'Crear cuenta',
  'authNote':
      'Las cuentas se usan para la biblioteca en línea y los tiques de descarga. '
      'Subir fondos y gestionar usuarios son funciones del administrador '
      '(Admin Secret) y no se exponen en el cliente.',
  'logoutTitle': '¿Cerrar sesión?',
  'logoutBody': 'Tendrás que iniciar sesión de nuevo para descargar fondos en línea. Los fondos instalados no se ven afectados.',
  'logout': 'Cerrar sesión',
  'account': 'Cuenta',
  'sessionValidity': 'Validez de la sesión',
  'sessionDaysLeft': 'Quedan {days} días; tendrás que iniciar sesión de nuevo al caducar',
  'notSignedIn': 'Sin iniciar sesión',
  'signedInSubtitle': 'Cuenta gratuita · quedan {days} días',
  'freeAccountDays': 'Cuenta gratuita · quedan {days} días',
  'loginToDownload': 'Inicia sesión para descargar fondos en línea; la navegación no tiene límites',
  'management': 'Gestión',
  'managementFooter':
      'Las subidas y la gestión de sesiones requieren ADMIN_SECRET en el servidor: '
      'la herramienta de administración escribe los paquetes directamente en WebDAV '
      'y luego /api/admin/sync registra los metadatos. El cliente nunca interviene.',
  'uploadWallpaper': 'Subir fondo',
  'uploadSubtitle': 'Subida directa por WebDAV + sincronización en segundo plano',
  'userManagement': 'Gestión de usuarios',
  'userManagementSubtitle': 'Tabla D1 users, solo administración',
  'adminBadge': 'Admin',

  // ---- Diálogos ----
  'setWallpaperTitle': '¿Establecer ZUNO como fondo animado?',
  'setWallpaperMessage':
      'Se abrirá la vista previa de fondos del sistema. Pulsa «Establecer fondo» '
      'para dar vida a tu pantalla de inicio.',
  'goSet': 'Configurar',
  'decodeSoftwareFailedTitle': 'La decodificación por software también falla',
  'decodeSoftwareFailedMessage':
      'Este vídeo tampoco puede reproducirse con el decodificador por software; '
      'el fondo se quedará en un fotograma fijo. Prueba con un vídeo H.264 / H.265 '
      'de 1080p o menos.',
  'decodeHardwareFailedTitle': 'Fallo de decodificación por hardware',
  'decodeHardwareFailedMessage':
      'Este vídeo no puede reproducirse con decodificación por hardware. Puedes '
      'cambiar a software, pero consumirá bastante más batería y puede entrecortarse '
      'en vídeo de alta resolución.',
  'neverAsk': 'No volver a preguntar',
  'useSoftware': 'Usar software',
  'switchedToSoftware':
      'Cambiado a decodificación por software; el fondo se recargará al volver '
      'a la pantalla de inicio',

  // ---- Tipos de fondo ----
  'typeVideo': 'Vídeo',
  'typeHtml': 'HTML',
  'typeDepth': 'Profundidad',
  'typeTimed': 'Temporizado',

  // ---- Validación: códigos ----
  'issueZipInvalid': 'No se puede extraer el ZIP',
  'issueZipSlip': 'Ataque de recorrido de rutas ZIP',
  'issueManifestMissing': 'Falta manifest.json',
  'issueManifestUnreadable': 'No se puede analizar manifest.json',
  'issueFieldInvalid': 'Campo no válido',
  'issueEntryMissing': 'Falta el archivo de entrada',
  'issueContentEmpty': 'content/ está vacío',
  'issueChecksumMismatch': 'La suma de comprobación no coincide',
  'issueMinSdkTooHigh': 'El minSdk del paquete es superior al de este dispositivo',
  'issueTimedScheduleInvalid': 'schedule.json no válido',
  'issueTimedSlotMissing': 'Falta una franja a la que hace referencia schedule.json',
  'issueTimedSlotInvalid': 'Manifiesto de franja no válido',
  'issueUnknown': 'Error desconocido',

  // ---- Validación: detalles de importación ----
  'errFileNotFound': 'Archivo no encontrado: {path}',
  'errOpenZip': 'No se pudo abrir el ZIP: {error}',
  'errInvalidZip': 'No es un contenedor ZIP válido: {error}',
  'errTooManyEntries': 'Importación rechazada: demasiadas entradas ZIP (posible zip bomb)',
  'errPathTraversal': 'Importación rechazada: la entrada "{entry}" contiene recorrido de rutas o una ruta absoluta',
  'errEntryTooLarge': 'Importación rechazada: la entrada "{entry}" supera el límite de {bytes} bytes descomprimidos (posible zip bomb)',
  'errTotalTooLarge': 'Importación rechazada: el tamaño descomprimido total supera el límite (posible zip bomb)',
  'errNoFiles': 'El ZIP no contiene archivos',
  'errManifestMissingRoot': 'No hay manifest.json en la raíz (ni dentro de una única carpeta de nivel superior)',
  'errManifestMultiple': 'Varias carpetas de nivel superior contienen manifest.json: {folders}',
  'errManifestJson': 'manifest.json no es JSON válido: {error}',
  'errManifestTopLevel': 'El nivel superior de manifest.json debe ser un objeto',
  'errTimedNeedsSchedule': 'Un paquete temporizado debe contener content/schedule.json',
  'errPathEscapesStaging': 'Una ruta extraída se salió del directorio temporal',
  'errImportException': 'Error inesperado durante la importación: {error}',
  'errChecksumMismatch': 'La suma de comprobación no coincide: se esperaba {expected}, se calculó {actual}',
  'errChecksumRecompute': 'No se pudo recalcular la suma de comprobación: {error}',
  'errManifestParse': 'No se pudo analizar el manifiesto (paquete mal formado): {error}',
  'errEntryNotInPackage': 'la entrada "{entry}" no está en el paquete ({count} archivos encontrados)',
  'errContentEmpty': 'El directorio content/ está vacío (o el ZIP no tiene entradas content/)',
  'errMinSdk': 'El paquete requiere minSdk={required}; este dispositivo es API {actual}',
  'errDepthRequires': 'El tipo depth requiere content/depth.png (un mapa de profundidad en escala de grises del mismo tamaño que la imagen de color)',
  'errDepthEntryFormat': 'La entrada depth debe ser jpg/png; se recibió: {entry}',
  'errHtmlEntryFormat': 'La entrada HTML debe ser un archivo .html; se recibió: {entry}',
  'errVideoEntryFormat': 'La entrada de vídeo debe ser mp4/webm; se recibió: {entry}',
  'errSlotMissing': 'El horario hace referencia a la franja "{slot}", que falta ({path})',
  'errSlotContentEmpty': 'La franja "{slot}" tiene el directorio content/ vacío',
  'errSlotSchema': 'La franja "{slot}" debe tener manifest.schemaVersion = 1',
  'errSlotIdMissing': 'A la franja "{slot}" le falta manifest.id',
  'errSlotIdConflict': 'La franja "{slot}" tiene el mismo id que el paquete de nivel superior',
  'errSlotNestedTimed': 'La franja "{slot}" no puede contener un tipo temporizado anidado',
  'errSlotTypeInvalid': 'La franja "{slot}" debe ser video/html/depth; se recibió: {type}',
  'errSlotEntryMissing': 'A la franja "{slot}" le falta manifest.entry',
  'errSlotEntryNotFound': 'La entrada "{entry}" de la franja "{slot}" no existe',
  'errSlotManifestUnreadable': 'No se pudo analizar manifest.json de la franja "{slot}": {error}',
  'errScheduleJson': 'schedule.json no es JSON válido: {error}',
  'errScheduleTopLevel': 'El nivel superior de schedule.json debe ser un objeto',
  'errScheduleRules': 'schedule.rules debe ser un array',
  'errRuleNotObject': 'rules[{index}] debe ser un objeto',
  'errRuleFrom': 'rules[{index}].from debe ser HH:mm; se recibió: {value}',
  'errRuleTo': 'rules[{index}].to debe ser HH:mm; se recibió: {value}',
  'errRuleWallpaper': 'rules[{index}].wallpaper debe ser una cadena no vacía',
  'errDefaultString': 'default debe ser una cadena',
  'warnVideoCodec':
      'Puede que este códec de vídeo no sea compatible con algunos teléfonos. '
      'El fondo podría mostrarse como imagen fija; se recomienda un vídeo H.264/H.265.',
  'warnVideoDecodeLimit':
      'La resolución/frecuencia de este vídeo supera la capacidad de decodificación '
      'de este dispositivo. La vista previa y el fondo mostrarán un fotograma fijo.',

  // ---- Red / API ----
  'errSessionIncomplete': 'El servidor devolvió datos de sesión incompletos',
  'errTicketIncomplete': 'El servidor devolvió un tique de descarga incompleto',
  'errCannotConnect': 'No se puede conectar al servidor: {error}',
  'errRequestFailed': 'La solicitud falló: {error}',
  'errResponseReadFailed': 'No se pudo leer la respuesta: {error}',
  'errorDetailSeparator': ': ',
  'errDownloadHttp': 'Error de descarga (HTTP {code}){body}',
  'errCatalogLoad': 'No se pudo cargar el catálogo: {error}',
  'errLoadMore': 'No se pudo cargar más: {error}',
  'errWallpaperDownloading': 'Este fondo ya se está descargando',
  'errEndpointInvalid': 'Introduce una dirección completa, por ejemplo https://api.example.com',
  'errOperationFailed': 'La operación falló: {error}',
  'errSizeUnknown': 'Tamaño desconocido',

  // ---- Motivos del manifiesto ----
  'reasonMustBeObject': 'debe ser un objeto',
  'reasonRequiredString': 'es obligatorio y debe ser una cadena no vacía; se recibió: {value}',
  'reasonMustBeString': 'debe ser una cadena; se recibió: {value}',
  'reasonRequiredInt': 'es obligatorio y debe ser un entero; se recibió: {value}',
  'reasonMustBeInt': 'debe ser un entero; se recibió: {value}',
  'reasonMustBeNumber': 'debe ser un número; se recibió: {value}',
  'reasonConfigObject': 'config[{index}] debe ser un objeto',
  'reasonConfigKey': 'config[{index}].key es obligatorio y debe ser una cadena',
  'reasonConfigType': 'config[{index}].type debe ser float/int/bool/color; se recibió: {type}',
  'reasonDefaultFloat': 'el valor predeterminado de un parámetro float debe ser un número',
  'reasonDefaultInt': 'el valor predeterminado de un parámetro int debe ser un entero',
  'reasonDefaultBool': 'el valor predeterminado de un parámetro bool debe ser booleano',
  'reasonDefaultColor': 'el valor predeterminado de un parámetro color debe ser #RRGGBB(AA)',
  'reasonMinMax': 'min > max',
  'reasonCapabilitiesObject': 'debe ser un objeto',
  'reasonStringArray': 'debe ser un array de cadenas',
  'reasonElementString': 'los elementos deben ser cadenas; se recibió: {value}',
  'reasonSchemaOnly1': 'solo se admite schemaVersion 1; se recibió: {value}',
  'reasonIdCharset': 'solo se permiten letras/dígitos/puntos/guiones bajos, y "." o ".." no están permitidos; se recibió: {value}',
  'reasonSemver': 'debe ser una versión semántica (p. ej. 1.0.0); se recibió: {value}',
  'reasonTypeOneOf': 'debe ser video/html/depth/timed',
  'reasonPerformanceHint': 'debe ser low/medium/high; se recibió: {value}',
  'reasonConfigArray': 'debe ser un array',
  'reasonDuplicateKeys': 'claves duplicadas',
};
