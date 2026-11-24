import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_es.dart';
import 'strings_fr.dart';
import 'strings_ja.dart';
import 'strings_ko.dart';
import 'strings_zh.dart';
import 'strings_zh_hant.dart';

/// Pure-Dart string catalogue used by both the Flutter UI and the background
/// import isolate.
///
/// The isolate deliberately avoids Flutter imports, so localization cannot use
/// `BuildContext` there. Instead every consumer reads a [ZunoStrings] instance:
/// widgets resolve it from `Localizations`, while pure-Dart code (validators,
/// controllers, the isolate) uses [current].
class ZunoStrings {
  const ZunoStrings(this.languageCode);

  /// BCP-47-ish language codes supported by the app.
  static const List<String> supportedLanguageCodes = [
    'en',
    'zh',
    'zh_Hant',
    'ja',
    'ko',
    'es',
    'fr',
    'de',
  ];

  /// Native display names, deliberately not translated.
  static const Map<String, String> nativeNames = {
    'en': 'English',
    'zh': '简体中文',
    'zh_Hant': '繁體中文',
    'ja': '日本語',
    'ko': '한국어',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
  };

  static const Map<String, Map<String, String>> _tables = {
    'en': zunoStringsEn,
    'zh': zunoStringsZh,
    'zh_Hant': zunoStringsZhHant,
    'ja': zunoStringsJa,
    'ko': zunoStringsKo,
    'es': zunoStringsEs,
    'fr': zunoStringsFr,
    'de': zunoStringsDe,
  };

  /// Current catalogue. Updated by [LocaleController] / the localization
  /// delegate; background isolates set it from the language code they receive.
  static ZunoStrings current = const ZunoStrings('en');

  final String languageCode;

  static ZunoStrings forLanguage(String? code) {
    final normalized = normalizeCode(code);
    return ZunoStrings(normalized);
  }

  static String normalizeCode(String? code) {
    if (code == null || code.isEmpty) return 'en';
    if (_tables.containsKey(code)) return code;
    final parts = code.split(RegExp(r'[-_]'));
    final base = parts.first;
    if (base == 'zh') {
      final traditional = parts.any((p) {
        final lower = p.toLowerCase();
        return lower == 'hant' ||
            lower == 'tw' ||
            lower == 'hk' ||
            lower == 'mo';
      });
      return traditional ? 'zh_Hant' : 'zh';
    }
    return _tables.containsKey(base) ? base : 'en';
  }

  String _t(String key) {
    final table = _tables[languageCode] ?? zunoStringsEn;
    return table[key] ?? zunoStringsEn[key] ?? key;
  }

  String _fmt(String key, Map<String, Object?> args) {
    var text = _t(key);
    for (final entry in args.entries) {
      text = text.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return text;
  }

  // ---- Common ----
  String get cancel => _t('cancel');
  String get delete => _t('delete');
  String get later => _t('later');
  String get gotIt => _t('gotIt');
  String get back => _t('back');
  String get settings => _t('settings');
  String get save => _t('save');
  String get clearAddress => _t('clearAddress');
  String get retry => _t('retry');
  String get close => _t('close');
  String get exitFullscreen => _t('exitFullscreen');
  String get fullscreenPreview => _t('fullscreenPreview');
  String get openSettings => _t('openSettings');
  String get unknownError => _t('unknownError');
  String get calculating => _t('calculating');

  // ---- Navigation ----
  String get myWallpapers => _t('myWallpapers');
  String get wallpaperLibrary => _t('wallpaperLibrary');
  String get settingsTitle => _t('settingsTitle');
  String get aboutTitle => _t('aboutTitle');
  String get languageTitle => _t('languageTitle');
  String get languageSystem => _t('languageSystem');
  String get languageDescription => _t('languageDescription');
  String get languageCurrent => _t('languageCurrent');
  String get openLibrary => _t('openLibrary');
  String get backToMyWallpapers => _t('backToMyWallpapers');
  String get refreshLibrary => _t('refreshLibrary');
  String get settingsSemantic => _t('settingsSemantic');
  String get inUse => _t('inUse');
  String get installed => _t('installed');

  // ---- Home ----
  String get importingPackage => _t('importingPackage');
  String get importZuno => _t('importZuno');
  String get emptyLibraryTitle => _t('emptyLibraryTitle');
  String get emptyLibraryBody => _t('emptyLibraryBody');
  String get importSuccessWarnings => _t('importSuccessWarnings');
  String get importRejected => _t('importRejected');
  String get importFailedUnreadable => _t('importFailedUnreadable');

  // ---- Wallpaper detail ----
  String get performanceHint => _t('performanceHint');
  String get hintLow => _t('hintLow');
  String get hintMedium => _t('hintMedium');
  String get hintHigh => _t('hintHigh');
  String get authorLabel => _t('authorLabel');
  String get parameters => _t('parameters');
  String get noParameters => _t('noParameters');
  String get capTouch => _t('capTouch');
  String capSensors(Object? sensors) => _fmt('capSensors', {'sensors': sensors});
  String get capNetwork => _t('capNetwork');
  String get scheduleWindows => _t('scheduleWindows');
  String currentSlot(Object? slot) => _fmt('currentSlot', {'slot': slot});
  String defaultSlot(Object? slot) => _fmt('defaultSlot', {'slot': slot});
  String get timedPreview => _t('timedPreview');
  String get timedPreviewActiveHint => _t('timedPreviewActiveHint');
  String get timedPreviewInactiveHint => _t('timedPreviewInactiveHint');
  String get applyWallpaper => _t('applyWallpaper');
  String get applyHint => _t('applyHint');
  String get livePreview => _t('livePreview');
  String get noThumbnail => _t('noThumbnail');
  String get thumbnailLoadFailed => _t('thumbnailLoadFailed');
  String get htmlPreviewFullscreen => _t('htmlPreviewFullscreen');
  String get videoFullscreen => _t('videoFullscreen');
  String get depthFullscreen => _t('depthFullscreen');
  String get timedNoRender => _t('timedNoRender');
  String currentPeriod(Object? slot) => _fmt('currentPeriod', {'slot': slot});
  String unsupportedFullscreen(Object? slot) =>
      _fmt('unsupportedFullscreen', {'slot': slot});
  String get exportShare => _t('exportShare');
  String get deletePackageTitle => _t('deletePackageTitle');
  String deletePackageBody(Object? title) =>
      _fmt('deletePackageBody', {'title': title});
  String get packingPackage => _t('packingPackage');
  String get exportFailed => _t('exportFailed');
  String exportedTo(Object? path) => _fmt('exportedTo', {'path': path});
  String get applyPreviewPrompt => _t('applyPreviewPrompt');
  String videoPreviewInitFailed(Object? error) =>
      _fmt('videoPreviewInitFailed', {'error': error});
  String get videoUnsupported => _t('videoUnsupported');
  String get videoLoading => _t('videoLoading');
  String get colorImageLoadFailed => _t('colorImageLoadFailed');
  String get depthApproxHint => _t('depthApproxHint');
  String get slotResolveFailed => _t('slotResolveFailed');
  String get deleteInUse => _t('deleteInUse');
  String deleteFailed(Object? error) => _fmt('deleteFailed', {'error': error});
  String get applyFailedGeneric => _t('applyFailedGeneric');
  String applyFailed(Object? error) => _fmt('applyFailed', {'error': error});
  String get applyNoPreview => _t('applyNoPreview');
  String get applyTimedFailed => _t('applyTimedFailed');

  // ---- Online library ----
  String get libraryNotConfiguredTitle => _t('libraryNotConfiguredTitle');
  String get libraryNotConfiguredBody => _t('libraryNotConfiguredBody');
  String get goSettings => _t('goSettings');
  String get libraryEmptyTitle => _t('libraryEmptyTitle');
  String get libraryEmptyBody => _t('libraryEmptyBody');
  String get setLibraryAddress => _t('setLibraryAddress');
  String get catalogLoadFailed => _t('catalogLoadFailed');
  String get changeAddress => _t('changeAddress');
  String get endOfList => _t('endOfList');
  String get packageInfo => _t('packageInfo');
  String get authorField => _t('authorField');
  String get versionField => _t('versionField');
  String get sizeField => _t('sizeField');
  String get updatedField => _t('updatedField');
  String get idField => _t('idField');
  String get unsigned => _t('unsigned');
  String get downloadImport => _t('downloadImport');
  String get downloading => _t('downloading');
  String downloadingPercent(Object? percent) =>
      _fmt('downloadingPercent', {'percent': percent});
  String get addedToMyWallpapers => _t('addedToMyWallpapers');
  String get importBusy => _t('importBusy');
  String downloadFailed(Object? error) =>
      _fmt('downloadFailed', {'error': error});
  String get downloadFileUnreadable => _t('downloadFileUnreadable');
  String get verifyNote => _t('verifyNote');

  // ---- Settings ----
  String get appearance => _t('appearance');
  String get followSystem => _t('followSystem');
  String get light => _t('light');
  String get dark => _t('dark');
  String get appearanceHint => _t('appearanceHint');
  String get interfaceSection => _t('interfaceSection');
  String get showTabBar => _t('showTabBar');
  String get showTabBarHint => _t('showTabBarHint');
  String get performanceTier => _t('performanceTier');
  String get tierHigh => _t('tierHigh');
  String get tierMedium => _t('tierMedium');
  String get tierLow => _t('tierLow');
  String get performanceHintBody => _t('performanceHintBody');
  String get videoDecode => _t('videoDecode');
  String get decodeAuto => _t('decodeAuto');
  String get decodeHardware => _t('decodeHardware');
  String get decodeSoftware => _t('decodeSoftware');
  String get decodeHintBody => _t('decodeHintBody');
  String get decodePrompt => _t('decodePrompt');
  String get decodePromptHint => _t('decodePromptHint');
  String get depthParallax => _t('depthParallax');
  String get depthSoft => _t('depthSoft');
  String get depthStandard => _t('depthStandard');
  String get depthStrong => _t('depthStrong');
  String get depthHint => _t('depthHint');
  String get libraryAddress => _t('libraryAddress');
  String addressConfigured(Object? url) =>
      _fmt('addressConfigured', {'url': url});
  String get addressNotConfigured => _t('addressNotConfigured');
  String get addressHint => _t('addressHint');
  String get libraryAddressSaved => _t('libraryAddressSaved');
  String get libraryAddressCleared => _t('libraryAddressCleared');
  String get batteryOptimization => _t('batteryOptimization');
  String get batteryFooter => _t('batteryFooter');
  String get batteryAllowed => _t('batteryAllowed');
  String get batteryNotAllowed => _t('batteryNotAllowed');
  String get storage => _t('storage');
  String get libraryUsage => _t('libraryUsage');
  String get libraryUsageSubtitle => _t('libraryUsageSubtitle');
  String get aboutZuno => _t('aboutZuno');
  String get aboutZunoSubtitle => _t('aboutZunoSubtitle');

  // ---- About ----
  String get aboutDescription => _t('aboutDescription');
  String get qqGroup => _t('qqGroup');
  String get qqGroupSubtitle => _t('qqGroupSubtitle');
  String get groupLinkCopied => _t('groupLinkCopied');
  String get highlights => _t('highlights');
  String get featureVideoTitle => _t('featureVideoTitle');
  String get featureVideoDesc => _t('featureVideoDesc');
  String get featureDepthTitle => _t('featureDepthTitle');
  String get featureDepthDesc => _t('featureDepthDesc');
  String get featureHtmlTitle => _t('featureHtmlTitle');
  String get featureHtmlDesc => _t('featureHtmlDesc');
  String get featureTimedTitle => _t('featureTimedTitle');
  String get featureTimedDesc => _t('featureTimedDesc');
  String get featurePerformanceTitle => _t('featurePerformanceTitle');
  String get featurePerformanceDesc => _t('featurePerformanceDesc');
  String get madeWith => _t('madeWith');

  // ---- Account ----
  String get login => _t('login');
  String get register => _t('register');
  String get email => _t('email');
  String get password => _t('password');
  String get passwordMin => _t('passwordMin');
  String get confirmPassword => _t('confirmPassword');
  String get loginRegister => _t('loginRegister');
  String get emailInvalid => _t('emailInvalid');
  String get passwordLength => _t('passwordLength');
  String get passwordMismatch => _t('passwordMismatch');
  String get signingIn => _t('signingIn');
  String get creating => _t('creating');
  String get createAccount => _t('createAccount');
  String get authNote => _t('authNote');
  String get logoutTitle => _t('logoutTitle');
  String get logoutBody => _t('logoutBody');
  String get logout => _t('logout');
  String get account => _t('account');
  String get sessionValidity => _t('sessionValidity');
  String sessionDaysLeft(Object? days) =>
      _fmt('sessionDaysLeft', {'days': days});
  String get notSignedIn => _t('notSignedIn');
  String signedInSubtitle(Object? days) =>
      _fmt('signedInSubtitle', {'days': days});
  String freeAccountDays(Object? days) =>
      _fmt('freeAccountDays', {'days': days});
  String get loginToDownload => _t('loginToDownload');
  String get management => _t('management');
  String get managementFooter => _t('managementFooter');
  String get uploadWallpaper => _t('uploadWallpaper');
  String get uploadSubtitle => _t('uploadSubtitle');
  String get userManagement => _t('userManagement');
  String get userManagementSubtitle => _t('userManagementSubtitle');
  String get adminBadge => _t('adminBadge');

  // ---- Dialogs ----
  String get setWallpaperTitle => _t('setWallpaperTitle');
  String get setWallpaperMessage => _t('setWallpaperMessage');
  String get goSet => _t('goSet');
  String get decodeSoftwareFailedTitle => _t('decodeSoftwareFailedTitle');
  String get decodeSoftwareFailedMessage => _t('decodeSoftwareFailedMessage');
  String get decodeHardwareFailedTitle => _t('decodeHardwareFailedTitle');
  String get decodeHardwareFailedMessage => _t('decodeHardwareFailedMessage');
  String get neverAsk => _t('neverAsk');
  String get useSoftware => _t('useSoftware');
  String get switchedToSoftware => _t('switchedToSoftware');

  // ---- Wallpaper types ----
  String get typeVideo => _t('typeVideo');
  String get typeHtml => _t('typeHtml');
  String get typeDepth => _t('typeDepth');
  String get typeTimed => _t('typeTimed');

  String typeLabel(String type) => switch (type) {
    'video' => typeVideo,
    'html' => typeHtml,
    'depth' => typeDepth,
    'timed' => typeTimed,
    _ => type,
  };

  String hintLabel(String hint) => switch (hint) {
    'low' => hintLow,
    'high' => hintHigh,
    _ => hintMedium,
  };

  // ---- Validation: issue codes ----
  String issueLabel(String code) => switch (code) {
    'zipInvalid' => _t('issueZipInvalid'),
    'zipSlip' => _t('issueZipSlip'),
    'manifestMissing' => _t('issueManifestMissing'),
    'manifestUnreadable' => _t('issueManifestUnreadable'),
    'fieldInvalid' => _t('issueFieldInvalid'),
    'entryMissing' => _t('issueEntryMissing'),
    'contentEmpty' => _t('issueContentEmpty'),
    'checksumMismatch' => _t('issueChecksumMismatch'),
    'minSdkTooHigh' => _t('issueMinSdkTooHigh'),
    'timedScheduleInvalid' => _t('issueTimedScheduleInvalid'),
    'timedSlotMissing' => _t('issueTimedSlotMissing'),
    'timedSlotInvalid' => _t('issueTimedSlotInvalid'),
    _ => _t('issueUnknown'),
  };

  // ---- Validation: import details ----
  String errFileNotFound(Object? path) =>
      _fmt('errFileNotFound', {'path': path});
  String errOpenZip(Object? error) => _fmt('errOpenZip', {'error': error});
  String errInvalidZip(Object? error) => _fmt('errInvalidZip', {'error': error});
  String get errTooManyEntries => _t('errTooManyEntries');
  String errPathTraversal(Object? entry) =>
      _fmt('errPathTraversal', {'entry': entry});
  String errEntryTooLarge(Object? entry, Object? bytes) =>
      _fmt('errEntryTooLarge', {'entry': entry, 'bytes': bytes});
  String get errTotalTooLarge => _t('errTotalTooLarge');
  String get errNoFiles => _t('errNoFiles');
  String get errManifestMissingRoot => _t('errManifestMissingRoot');
  String errManifestMultiple(Object? folders) =>
      _fmt('errManifestMultiple', {'folders': folders});
  String errManifestJson(Object? error) =>
      _fmt('errManifestJson', {'error': error});
  String get errManifestTopLevel => _t('errManifestTopLevel');
  String get errTimedNeedsSchedule => _t('errTimedNeedsSchedule');
  String get errPathEscapesStaging => _t('errPathEscapesStaging');
  String errImportException(Object? error) =>
      _fmt('errImportException', {'error': error});
  String errChecksumMismatch(Object? expected, Object? actual) =>
      _fmt('errChecksumMismatch', {'expected': expected, 'actual': actual});
  String errChecksumRecompute(Object? error) =>
      _fmt('errChecksumRecompute', {'error': error});
  String errManifestParse(Object? error) =>
      _fmt('errManifestParse', {'error': error});
  String errEntryNotInPackage(Object? entry, Object? count) =>
      _fmt('errEntryNotInPackage', {'entry': entry, 'count': count});
  String get errContentEmpty => _t('errContentEmpty');
  String errMinSdk(Object? required, Object? actual) =>
      _fmt('errMinSdk', {'required': required, 'actual': actual});
  String get errDepthRequires => _t('errDepthRequires');
  String errDepthEntryFormat(Object? entry) =>
      _fmt('errDepthEntryFormat', {'entry': entry});
  String errHtmlEntryFormat(Object? entry) =>
      _fmt('errHtmlEntryFormat', {'entry': entry});
  String errVideoEntryFormat(Object? entry) =>
      _fmt('errVideoEntryFormat', {'entry': entry});
  String errSlotMissing(Object? slot, Object? path) =>
      _fmt('errSlotMissing', {'slot': slot, 'path': path});
  String errSlotContentEmpty(Object? slot) =>
      _fmt('errSlotContentEmpty', {'slot': slot});
  String errSlotSchema(Object? slot) => _fmt('errSlotSchema', {'slot': slot});
  String errSlotIdMissing(Object? slot) =>
      _fmt('errSlotIdMissing', {'slot': slot});
  String errSlotIdConflict(Object? slot) =>
      _fmt('errSlotIdConflict', {'slot': slot});
  String errSlotNestedTimed(Object? slot) =>
      _fmt('errSlotNestedTimed', {'slot': slot});
  String errSlotTypeInvalid(Object? slot, Object? type) =>
      _fmt('errSlotTypeInvalid', {'slot': slot, 'type': type});
  String errSlotEntryMissing(Object? slot) =>
      _fmt('errSlotEntryMissing', {'slot': slot});
  String errSlotEntryNotFound(Object? slot, Object? entry) =>
      _fmt('errSlotEntryNotFound', {'slot': slot, 'entry': entry});
  String errSlotManifestUnreadable(Object? slot, Object? error) =>
      _fmt('errSlotManifestUnreadable', {'slot': slot, 'error': error});
  String errScheduleJson(Object? error) =>
      _fmt('errScheduleJson', {'error': error});
  String get errScheduleTopLevel => _t('errScheduleTopLevel');
  String get errScheduleRules => _t('errScheduleRules');
  String errRuleNotObject(Object? index) =>
      _fmt('errRuleNotObject', {'index': index});
  String errRuleFrom(Object? index, Object? value) =>
      _fmt('errRuleFrom', {'index': index, 'value': value});
  String errRuleTo(Object? index, Object? value) =>
      _fmt('errRuleTo', {'index': index, 'value': value});
  String errRuleWallpaper(Object? index) =>
      _fmt('errRuleWallpaper', {'index': index});
  String get errDefaultString => _t('errDefaultString');
  String get warnVideoCodec => _t('warnVideoCodec');
  String get warnVideoDecodeLimit => _t('warnVideoDecodeLimit');

  // ---- Network / API ----
  String get errSessionIncomplete => _t('errSessionIncomplete');
  String get errTicketIncomplete => _t('errTicketIncomplete');
  String errCannotConnect(Object? error) =>
      _fmt('errCannotConnect', {'error': error});
  String errRequestFailed(Object? error) =>
      _fmt('errRequestFailed', {'error': error});
  String errResponseReadFailed(Object? error) =>
      _fmt('errResponseReadFailed', {'error': error});
  String get errorDetailSeparator => _t('errorDetailSeparator');
  String errDownloadHttp(Object? code, Object? body) =>
      _fmt('errDownloadHttp', {'code': code, 'body': body});
  String errCatalogLoad(Object? error) =>
      _fmt('errCatalogLoad', {'error': error});
  String errLoadMore(Object? error) => _fmt('errLoadMore', {'error': error});
  String get errWallpaperDownloading => _t('errWallpaperDownloading');
  String get errEndpointInvalid => _t('errEndpointInvalid');
  String errOperationFailed(Object? error) =>
      _fmt('errOperationFailed', {'error': error});
  String get errSizeUnknown => _t('errSizeUnknown');

  // ---- Manifest reasons ----
  String get reasonMustBeObject => _t('reasonMustBeObject');
  String reasonRequiredString(Object? value) =>
      _fmt('reasonRequiredString', {'value': value});
  String reasonMustBeString(Object? value) =>
      _fmt('reasonMustBeString', {'value': value});
  String reasonRequiredInt(Object? value) =>
      _fmt('reasonRequiredInt', {'value': value});
  String reasonMustBeInt(Object? value) =>
      _fmt('reasonMustBeInt', {'value': value});
  String reasonMustBeNumber(Object? value) =>
      _fmt('reasonMustBeNumber', {'value': value});
  String reasonConfigObject(Object? index) =>
      _fmt('reasonConfigObject', {'index': index});
  String reasonConfigKey(Object? index) =>
      _fmt('reasonConfigKey', {'index': index});
  String reasonConfigType(Object? index, Object? type) =>
      _fmt('reasonConfigType', {'index': index, 'type': type});
  String get reasonDefaultFloat => _t('reasonDefaultFloat');
  String get reasonDefaultInt => _t('reasonDefaultInt');
  String get reasonDefaultBool => _t('reasonDefaultBool');
  String get reasonDefaultColor => _t('reasonDefaultColor');
  String get reasonMinMax => _t('reasonMinMax');
  String get reasonCapabilitiesObject => _t('reasonCapabilitiesObject');
  String get reasonStringArray => _t('reasonStringArray');
  String reasonElementString(Object? value) =>
      _fmt('reasonElementString', {'value': value});
  String reasonSchemaOnly1(Object? value) =>
      _fmt('reasonSchemaOnly1', {'value': value});
  String reasonIdCharset(Object? value) =>
      _fmt('reasonIdCharset', {'value': value});
  String reasonSemver(Object? value) =>
      _fmt('reasonSemver', {'value': value});
  String get reasonTypeOneOf => _t('reasonTypeOneOf');
  String reasonPerformanceHint(Object? value) =>
      _fmt('reasonPerformanceHint', {'value': value});
  String get reasonConfigArray => _t('reasonConfigArray');
  String get reasonDuplicateKeys => _t('reasonDuplicateKeys');
}
