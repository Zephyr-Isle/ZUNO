/// English strings — the source-of-truth key set for every other language.
///
/// Pure Dart on purpose: the import validator runs inside a background isolate,
/// so the string tables must not depend on Flutter.
const Map<String, String> zunoStringsEn = {
  // ---- Common ----
  'cancel': 'Cancel',
  'delete': 'Delete',
  'later': 'Later',
  'gotIt': 'Got it',
  'back': 'Back',
  'settings': 'Settings',
  'save': 'Save',
  'clearAddress': 'Clear address',
  'retry': 'Retry',
  'close': 'Close',
  'exitFullscreen': 'Exit full screen',
  'fullscreenPreview': 'Full-screen preview',
  'openSettings': 'Open settings',
  'unknownError': 'Unknown error',
  'calculating': 'Calculating…',

  // ---- Navigation / shell ----
  'myWallpapers': 'My wallpapers',
  'wallpaperLibrary': 'Wallpaper library',
  'settingsTitle': 'Settings',
  'aboutTitle': 'About',
  'languageTitle': 'Language',
  'languageSystem': 'Follow system',
  'languageDescription':
      'Choose the display language for the app. “Follow system” uses your Android language setting.',
  'languageCurrent': 'Current',
  'openLibrary': 'Open wallpaper library',
  'backToMyWallpapers': 'Back to my wallpapers',
  'refreshLibrary': 'Refresh wallpaper library',
  'settingsSemantic': 'Settings',
  'inUse': 'In use',
  'installed': 'Installed',

  // ---- Home ----
  'importingPackage':
      'Extracting and verifying the wallpaper package (background isolate)…',
  'importZuno': 'Import .zuno',
  'emptyLibraryTitle': 'Your library is empty',
  'emptyLibraryBody':
      'Import a .zuno package that follows the ZUNO Package v1 spec.\n'
      'Video / depth parallax / HTML / timed wallpapers are supported.',
  'importSuccessWarnings': 'Imported with warnings',
  'importRejected': 'Import rejected',
  'importFailedUnreadable': 'Import failed: the file could not be read',

  // ---- Wallpaper detail ----
  'performanceHint': 'Performance hint',
  'hintLow': 'Low',
  'hintMedium': 'Medium',
  'hintHigh': 'High',
  'authorLabel': 'Author',
  'parameters': 'Parameters',
  'noParameters': 'This wallpaper has no adjustable parameters',
  'capTouch': 'Touch input',
  'capSensors': 'Sensors: {sensors}',
  'capNetwork': 'Network declared (still blocked in v1)',
  'scheduleWindows': 'Schedule',
  'currentSlot': 'Current: {slot}',
  'defaultSlot': 'Default: {slot}',
  'timedPreview': 'Time preview',
  'timedPreviewActiveHint':
      'Drag to preview each slot. The real schedule is restored by WorkManager on its next check.',
  'timedPreviewInactiveHint':
      'Apply this wallpaper before previewing slots (preview hot-swaps the active slot).',
  'applyWallpaper': 'Apply wallpaper',
  'applyHint':
      'Opens the system wallpaper preview — tap “Set wallpaper” to confirm',
  'livePreview': 'Live preview',
  'noThumbnail': 'No thumbnail',
  'thumbnailLoadFailed': 'Failed to load thumbnail',
  'htmlPreviewFullscreen': 'HTML wallpaper preview (pinch to zoom)',
  'videoFullscreen': 'Video full-screen preview',
  'depthFullscreen': 'Depth parallax full-screen preview',
  'timedNoRender':
      'The timed type does not render by itself.\n'
      'Full-screen preview shows the slot active right now.',
  'currentPeriod': 'Current period: {slot}',
  'unsupportedFullscreen':
      'Full-screen preview is not supported for the current slot ({slot})',
  'exportShare': 'Export / share',
  'deletePackageTitle': 'Delete wallpaper package?',
  'deletePackageBody': '{title} and its files will be deleted.',
  'packingPackage': 'Packing wallpaper package (streaming export)…',
  'exportFailed': 'Export failed',
  'exportedTo': 'Exported to: {path}',
  'applyPreviewPrompt': 'Opening the system preview — tap “Set wallpaper”',
  'videoPreviewInitFailed': 'Could not start the video preview: {error}',
  'videoUnsupported':
      'This device cannot play this video live; the wallpaper will show a still frame',
  'videoLoading': 'Loading video…',
  'colorImageLoadFailed': 'Failed to load color image',
  'depthApproxHint':
      'Preview is approximate; the real wallpaper is smoother',
  'slotResolveFailed': 'Could not resolve the current slot',
  'deleteInUse':
      'This wallpaper is in use. Apply another wallpaper before deleting it.',
  'deleteFailed': 'Delete failed: {error}',
  'applyFailedGeneric': 'Apply failed',
  'applyFailed': 'Apply failed: {error}',
  'applyNoPreview':
      'Wallpaper settings saved, but the system preview could not be opened — choose ZUNO manually in the system wallpaper settings',
  'applyTimedFailed':
      'Could not resolve the current slot (it may be restricted to charging; connect a charger and try again)',

  // ---- Online library ----
  'libraryNotConfiguredTitle': 'Library not configured',
  'libraryNotConfiguredBody':
      'The wallpaper library points to your own zuno-api backend '
      '(Docker or Cloudflare Workers; see the deployment section in the README). '
      'Set the server address under Settings → Wallpaper library address to get started.',
  'goSettings': 'Open settings',
  'libraryEmptyTitle': 'The library is empty',
  'libraryEmptyBody':
      'If this is your own backend, check the address under '
      'Settings → Wallpaper library address. If the address is correct but the '
      'list is empty, the admin tool has not synced any .zuno packages yet.',
  'setLibraryAddress': 'Set library address',
  'catalogLoadFailed': 'Could not load the catalog',
  'changeAddress': 'Change address',
  'endOfList': 'That’s everything',
  'packageInfo': 'Package info',
  'authorField': 'Author',
  'versionField': 'Version',
  'sizeField': 'Size',
  'updatedField': 'Updated',
  'idField': 'ID',
  'unsigned': 'Uncredited',
  'downloadImport': 'Download and import',
  'downloading': 'Downloading…',
  'downloadingPercent': 'Downloading {percent}%',
  'addedToMyWallpapers': 'Added to My wallpapers',
  'importBusy': 'An import is already running. Please wait.',
  'downloadFailed': 'Download failed: {error}',
  'downloadFileUnreadable':
      'Import failed: the downloaded file could not be read',
  'verifyNote':
      'The manifest and checksum are verified again on this device after '
      'download. Only packages that pass are added to My wallpapers; failures '
      'list the exact reason.',

  // ---- Settings ----
  'appearance': 'Appearance',
  'followSystem': 'System',
  'light': 'Light',
  'dark': 'Dark',
  'appearanceHint':
      'Follows the system by default. Changes apply immediately and are remembered.',
  'interfaceSection': 'Interface',
  'showTabBar': 'Show bottom tab bar',
  'showTabBarHint':
      'When hidden, use the top-bar button to switch between My wallpapers / Library',
  'performanceTier': 'Performance',
  'tierHigh': 'High',
  'tierMedium': 'Medium',
  'tierLow': 'Low',
  'performanceHintBody':
      'Applies to every wallpaper rendering path (default: Medium):\n'
      '· Video: High/Medium play normally; Low shows a still first frame\n'
      '· Depth: 30 / 20 / 15 fps (battery saver forces 15)\n'
      '· HTML: High is unlimited, Medium ~30 fps, Low freezes CSS animations',
  'videoDecode': 'Video decoding',
  'decodeAuto': 'Auto',
  'decodeHardware': 'Hardware',
  'decodeSoftware': 'Software',
  'decodeHintBody':
      'Auto: prefer hardware, fall back to software only when hardware is '
      'unavailable; runtime failures are reported.\n'
      'Hardware: most power-efficient; compatibility depends on the device decoder.\n'
      'Software: widest compatibility, but uses more power and may drop frames '
      'on high-resolution video.\n'
      'Volume is still controlled per package and is muted by default.',
  'decodePrompt': 'Notify on decode failure',
  'decodePromptHint':
      'Offer to switch to software decoding when you return to the app',
  'depthParallax': 'Depth parallax',
  'depthSoft': 'Soft',
  'depthStandard': 'Standard',
  'depthStrong': 'Strong',
  'depthHint':
      'Global multiplier applied on top of each depth package’s own parallax '
      'strength. Choose Soft if the home screen feels too shaky.',
  'libraryAddress': 'Wallpaper library address',
  'addressConfigured':
      'Active: {url}\n'
      'This points to your own zuno-api deployment (Docker or Cloudflare '
      'Workers; see the README). Saving rebuilds the catalog immediately. '
      'When unset, the library tab shows a setup guide.',
  'addressNotConfigured':
      'Not configured. Enter the address of your own zuno-api server '
      '(see “Backend deployment” in the README). Saving rebuilds the catalog '
      'immediately.',
  'addressHint': 'https://api.example.com',
  'libraryAddressSaved': 'Wallpaper library address saved',
  'libraryAddressCleared': 'Wallpaper library address cleared',
  'batteryOptimization': 'Battery optimization',
  'batteryFooter':
      'Timed wallpapers need to run in the background to switch on time. '
      'Adding ZUNO to the battery-optimization allowlist prevents the system '
      'from delaying switches while asleep.',
  'batteryAllowed': 'Added to the battery-optimization allowlist',
  'batteryNotAllowed': 'Not in the battery-optimization allowlist',
  'storage': 'Storage',
  'libraryUsage': 'Library storage',
  'libraryUsageSubtitle':
      'Installed wallpaper package files (app-private directory)',
  'aboutZuno': 'About ZUNO',
  'aboutZunoSubtitle': 'Version · Community',

  // ---- About ----
  'aboutDescription':
      'Bring your home screen to life. ZUNO offers video, depth-parallax, '
      'interactive HTML and timed wallpapers: import a package, apply it, and '
      'your desktop starts moving.',
  'qqGroup': 'QQ group',
  'qqGroupSubtitle': 'Report issues, share wallpapers and get packages',
  'groupLinkCopied': 'Group link copied — paste it in QQ to join',
  'highlights': 'Highlights',
  'featureVideoTitle': 'Video wallpapers',
  'featureVideoDesc':
      'Smooth playback, muted by default, speed and volume adjustable',
  'featureDepthTitle': 'Depth parallax',
  'featureDepthDesc': 'A 3D sense of depth as you tilt your phone',
  'featureHtmlTitle': 'Interactive HTML',
  'featureHtmlDesc': 'Web wallpapers that respond to taps',
  'featureTimedTitle': 'Timed switching',
  'featureTimedDesc': 'Different wallpapers for day and night',
  'featurePerformanceTitle': 'Performance tiers',
  'featurePerformanceDesc':
      'High / Medium / Low — balance looks and battery',
  'madeWith': 'Made with ZUNO',

  // ---- Account ----
  'login': 'Sign in',
  'register': 'Create account',
  'email': 'Email',
  'password': 'Password',
  'passwordMin': 'Password (at least 8 characters)',
  'confirmPassword': 'Enter the password again',
  'loginRegister': 'Sign in / Register',
  'emailInvalid': 'Invalid email address',
  'passwordLength': 'Password must be 8–128 characters',
  'passwordMismatch': 'The passwords do not match',
  'signingIn': 'Signing in…',
  'creating': 'Creating…',
  'createAccount': 'Create account',
  'authNote':
      'Accounts are used for the online library and download tickets. '
      'Uploading wallpapers and user management are admin-side features '
      '(Admin Secret) and are not exposed in the client.',
  'logoutTitle': 'Sign out?',
  'logoutBody':
      'You will need to sign in again to download online wallpapers. '
      'Installed wallpapers are not affected.',
  'logout': 'Sign out',
  'account': 'Account',
  'sessionValidity': 'Session validity',
  'sessionDaysLeft':
      '{days} days left; you will need to sign in again after it expires',
  'notSignedIn': 'Not signed in',
  'signedInSubtitle': 'Free account · {days} days left',
  'freeAccountDays': 'Free account · {days} days left',
  'loginToDownload':
      'Sign in to download online wallpapers; browsing is unrestricted',
  'management': 'Management',
  'managementFooter':
      'Uploads and session management require the server-side ADMIN_SECRET: '
      'packages are written directly to WebDAV by the admin tool, then '
      '/api/admin/sync records the metadata. The client is never involved.',
  'uploadWallpaper': 'Upload wallpaper',
  'uploadSubtitle': 'Direct WebDAV upload + background sync',
  'userManagement': 'User management',
  'userManagementSubtitle': 'D1 users table, admin only',
  'adminBadge': 'Admin',

  // ---- Dialogs ----
  'setWallpaperTitle': 'Set ZUNO as your live wallpaper?',
  'setWallpaperMessage':
      'The system wallpaper preview will open. Tap “Set wallpaper” to bring '
      'your home screen to life.',
  'goSet': 'Set up',
  'decodeSoftwareFailedTitle': 'Software decoding failed too',
  'decodeSoftwareFailedMessage':
      'This video cannot be played by the software decoder either; the '
      'wallpaper will stay on a still first frame. Try an H.264 / H.265 video '
      'at 1080p or lower.',
  'decodeHardwareFailedTitle': 'Video hardware decoding failed',
  'decodeHardwareFailedMessage':
      'This video cannot be played with hardware decoding. You can switch to '
      'software decoding, but it uses noticeably more power and may stutter on '
      'high-resolution video.',
  'neverAsk': 'Don’t ask again',
  'useSoftware': 'Use software',
  'switchedToSoftware':
      'Switched to software decoding; the wallpaper will reload when you '
      'return to the home screen',

  // ---- Wallpaper types ----
  'typeVideo': 'Video',
  'typeHtml': 'HTML',
  'typeDepth': 'Depth',
  'typeTimed': 'Timed',

  // ---- Validation: issue codes ----
  'issueZipInvalid': 'ZIP cannot be extracted',
  'issueZipSlip': 'ZIP path traversal attack',
  'issueManifestMissing': 'manifest.json is missing',
  'issueManifestUnreadable': 'manifest.json cannot be parsed',
  'issueFieldInvalid': 'Invalid field',
  'issueEntryMissing': 'Entry file is missing',
  'issueContentEmpty': 'content/ is empty',
  'issueChecksumMismatch': 'Checksum mismatch',
  'issueMinSdkTooHigh': 'Package minSdk is higher than this device',
  'issueTimedScheduleInvalid': 'Invalid schedule.json',
  'issueTimedSlotMissing': 'A slot referenced by schedule.json is missing',
  'issueTimedSlotInvalid': 'Invalid slot manifest',
  'issueUnknown': 'Unknown error',

  // ---- Validation: import details ----
  'errFileNotFound': 'File not found: {path}',
  'errOpenZip': 'Could not open the ZIP file: {error}',
  'errInvalidZip': 'Not a valid ZIP container: {error}',
  'errTooManyEntries':
      'Import rejected: too many ZIP entries (possible zip bomb)',
  'errPathTraversal':
      'Import rejected: entry "{entry}" contains path traversal or an '
      'absolute path',
  'errEntryTooLarge':
      'Import rejected: entry "{entry}" exceeds the {bytes}-byte uncompressed '
      'limit (possible zip bomb)',
  'errTotalTooLarge':
      'Import rejected: total uncompressed size exceeds the limit '
      '(possible zip bomb)',
  'errNoFiles': 'The ZIP contains no files',
  'errManifestMissingRoot':
      'No manifest.json at the root (or inside a single top-level folder)',
  'errManifestMultiple':
      'Multiple top-level folders contain manifest.json: {folders}',
  'errManifestJson': 'manifest.json is not valid JSON: {error}',
  'errManifestTopLevel': 'The top level of manifest.json must be an object',
  'errTimedNeedsSchedule': 'A timed package must contain content/schedule.json',
  'errPathEscapesStaging':
      'An extracted path escaped the staging directory',
  'errImportException': 'Import failed unexpectedly: {error}',
  'errChecksumMismatch':
      'Checksum mismatch: expected {expected}, computed {actual}',
  'errChecksumRecompute': 'Could not recompute the checksum: {error}',
  'errManifestParse':
      'Could not parse the manifest (malformed package): {error}',
  'errEntryNotInPackage':
      'entry "{entry}" is not in the package ({count} files found)',
  'errContentEmpty':
      'The content/ directory is empty (or the ZIP has no content/ entries)',
  'errMinSdk':
      'The package requires minSdk={required}, this device is API {actual}',
  'errDepthRequires':
      'The depth type requires content/depth.png (a grayscale depth map the '
      'same size as the color image)',
  'errDepthEntryFormat': 'The depth entry must be a jpg/png, got: {entry}',
  'errHtmlEntryFormat': 'The HTML entry must be an .html file, got: {entry}',
  'errVideoEntryFormat': 'The video entry must be mp4/webm, got: {entry}',
  'errSlotMissing':
      'The schedule references slot "{slot}", which is missing ({path})',
  'errSlotContentEmpty': 'Slot "{slot}" has an empty content/ directory',
  'errSlotSchema': 'Slot "{slot}" must have manifest.schemaVersion = 1',
  'errSlotIdMissing': 'Slot "{slot}" is missing manifest.id',
  'errSlotIdConflict':
      'Slot "{slot}" has the same id as the top-level package',
  'errSlotNestedTimed': 'Slot "{slot}" cannot contain a nested timed type',
  'errSlotTypeInvalid':
      'Slot "{slot}" must be video/html/depth, got: {type}',
  'errSlotEntryMissing': 'Slot "{slot}" is missing manifest.entry',
  'errSlotEntryNotFound': 'Slot "{slot}" entry "{entry}" does not exist',
  'errSlotManifestUnreadable':
      'Could not parse manifest.json for slot "{slot}": {error}',
  'errScheduleJson': 'schedule.json is not valid JSON: {error}',
  'errScheduleTopLevel': 'The top level of schedule.json must be an object',
  'errScheduleRules': 'schedule.rules must be an array',
  'errRuleNotObject': 'rules[{index}] must be an object',
  'errRuleFrom': 'rules[{index}].from must be HH:mm, got: {value}',
  'errRuleTo': 'rules[{index}].to must be HH:mm, got: {value}',
  'errRuleWallpaper':
      'rules[{index}].wallpaper must be a non-empty string',
  'errDefaultString': 'default must be a string',
  'warnVideoCodec':
      'This video codec may not be supported on some phones. The wallpaper may '
      'show a still image; an H.264/H.265 video is recommended.',
  'warnVideoDecodeLimit':
      'This video’s resolution/frame rate exceeds this device’s decoding '
      'capability. Preview and wallpaper will show a still first frame.',

  // ---- Network / API ----
  'errSessionIncomplete': 'The server returned incomplete session data',
  'errTicketIncomplete':
      'The server returned an incomplete download ticket',
  'errCannotConnect': 'Cannot connect to the server: {error}',
  'errRequestFailed': 'Request failed: {error}',
  'errResponseReadFailed': 'Could not read the response: {error}',
  'errorDetailSeparator': ': ',
  'errDownloadHttp': 'Download failed (HTTP {code}){body}',
  'errCatalogLoad': 'Could not load the catalog: {error}',
  'errLoadMore': 'Could not load more: {error}',
  'errWallpaperDownloading': 'This wallpaper is already downloading',
  'errEndpointInvalid':
      'Enter a full address, for example https://api.example.com',
  'errOperationFailed': 'Operation failed: {error}',
  'errSizeUnknown': 'Size unknown',

  // ---- Manifest reasons ----
  'reasonMustBeObject': 'must be an object',
  'reasonRequiredString':
      'required and must be a non-empty string, got: {value}',
  'reasonMustBeString': 'must be a string, got: {value}',
  'reasonRequiredInt': 'required and must be an integer, got: {value}',
  'reasonMustBeInt': 'must be an integer, got: {value}',
  'reasonMustBeNumber': 'must be a number, got: {value}',
  'reasonConfigObject': 'config[{index}] must be an object',
  'reasonConfigKey': 'config[{index}].key is required and must be a string',
  'reasonConfigType':
      'config[{index}].type must be float/int/bool/color, got: {type}',
  'reasonDefaultFloat':
      'the default of a float parameter must be a number',
  'reasonDefaultInt': 'the default of an int parameter must be an integer',
  'reasonDefaultBool': 'the default of a bool parameter must be a boolean',
  'reasonDefaultColor':
      'the default of a color parameter must be #RRGGBB(AA)',
  'reasonMinMax': 'min > max',
  'reasonCapabilitiesObject': 'must be an object',
  'reasonStringArray': 'must be an array of strings',
  'reasonElementString': 'elements must be strings, got: {value}',
  'reasonSchemaOnly1': 'only schemaVersion 1 is supported, got: {value}',
  'reasonIdCharset':
      'only letters/digits/dots/underscores are allowed, and "." or ".." is '
      'not allowed, got: {value}',
  'reasonSemver':
      'must be a semantic version (e.g. 1.0.0), got: {value}',
  'reasonTypeOneOf': 'must be one of video/html/depth/timed',
  'reasonPerformanceHint': 'must be low/medium/high, got: {value}',
  'reasonConfigArray': 'must be an array',
  'reasonDuplicateKeys': 'duplicate keys',
};
