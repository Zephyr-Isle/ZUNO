/// 日本語。
const Map<String, String> zunoStringsJa = {
  // ---- 共通 ----
  'cancel': 'キャンセル',
  'delete': '削除',
  'later': 'あとで',
  'gotIt': 'OK',
  'back': '戻る',
  'settings': '設定',
  'save': '保存',
  'clearAddress': 'アドレスを消去',
  'retry': '再試行',
  'close': '閉じる',
  'exitFullscreen': '全画面を終了',
  'fullscreenPreview': '全画面プレビュー',
  'openSettings': '設定を開く',
  'unknownError': '不明なエラー',
  'calculating': '計算中…',

  // ---- ナビゲーション ----
  'myWallpapers': 'マイ壁紙',
  'wallpaperLibrary': '壁紙ライブラリ',
  'settingsTitle': '設定',
  'aboutTitle': 'このアプリについて',
  'languageTitle': '言語',
  'languageSystem': 'システムに従う',
  'languageDescription': 'アプリの表示言語を選択します。「システムに従う」は Android の言語設定を使用します。',
  'languageCurrent': '現在',
  'openLibrary': '壁紙ライブラリを開く',
  'backToMyWallpapers': 'マイ壁紙に戻る',
  'refreshLibrary': '壁紙ライブラリを更新',
  'settingsSemantic': '設定',
  'inUse': '使用中',
  'installed': 'インストール済み',

  // ---- マイ壁紙 ----
  'importingPackage': '壁紙パッケージを展開・検証しています（バックグラウンド isolate）…',
  'importZuno': '.zuno をインポート',
  'emptyLibraryTitle': '壁紙がありません',
  'emptyLibraryBody':
      'ZUNO Package v1 仕様の .zuno パッケージをインポートしてください。\n'
      '動画 / 深度パララックス / HTML / タイマー に対応しています。',
  'importSuccessWarnings': 'インポートしました（警告あり）',
  'importRejected': 'インポートが拒否されました',
  'importFailedUnreadable': 'インポート失敗：ファイルを読み取れません',

  // ---- 壁紙の詳細 ----
  'performanceHint': 'パフォーマンス推奨',
  'hintLow': '低',
  'hintMedium': '中',
  'hintHigh': '高',
  'authorLabel': '作者',
  'parameters': 'パラメータ',
  'noParameters': 'この壁紙に調整できるパラメータはありません',
  'capTouch': 'タッチ入力',
  'capSensors': 'センサー: {sensors}',
  'capNetwork': 'ネットワークを宣言（v1 では引き続き遮断）',
  'scheduleWindows': 'スケジュール',
  'currentSlot': '現在: {slot}',
  'defaultSlot': 'デフォルト: {slot}',
  'timedPreview': '時間帯プレビュー',
  'timedPreviewActiveHint':
      'ドラッグして各時間帯をプレビューします。実際のスケジュールは次回の WorkManager チェックで復元されます。',
  'timedPreviewInactiveHint': 'スロットをプレビューするには、先にこの壁紙を適用してください（プレビューはアクティブなスロットをホットスワップします）。',
  'applyWallpaper': 'この壁紙を適用',
  'applyHint': 'システムの壁紙プレビューが開きます。「壁紙を設定」をタップして確定してください',
  'livePreview': 'ライブプレビュー',
  'noThumbnail': 'サムネイルなし',
  'thumbnailLoadFailed': 'サムネイルの読み込みに失敗',
  'htmlPreviewFullscreen': 'HTML 壁紙プレビュー（ピンチで拡大）',
  'videoFullscreen': '動画の全画面プレビュー',
  'depthFullscreen': '深度パララックスの全画面プレビュー',
  'timedNoRender':
      'タイマータイプ自体は描画しません。\n'
      '全画面プレビューでは現在アクティブなスロットを表示します。',
  'currentPeriod': '現在の時間帯: {slot}',
  'unsupportedFullscreen': '現在のスロット（{slot}）は全画面プレビューに対応していません',
  'exportShare': 'エクスポート / 共有',
  'deletePackageTitle': '壁紙パッケージを削除しますか？',
  'deletePackageBody': '{title} とそのファイルが削除されます。',
  'packingPackage': '壁紙パッケージを梱包中（ストリーミング書き出し）…',
  'exportFailed': 'エクスポートに失敗しました',
  'exportedTo': '書き出し先: {path}',
  'applyPreviewPrompt': 'システムプレビューを開きます。「壁紙を設定」をタップしてください',
  'videoPreviewInitFailed': '動画プレビューの初期化に失敗しました：{error}',
  'videoUnsupported': 'この端末ではこの動画をリアルタイム再生できません。壁紙は静止画になります',
  'videoLoading': '動画を読み込み中…',
  'colorImageLoadFailed': 'カラー画像の読み込みに失敗',
  'depthApproxHint': 'プレビューは近似表示です。実際の壁紙はより滑らかです',
  'slotResolveFailed': '現在のスロットを解決できませんでした',
  'deleteInUse': 'この壁紙は使用中です。先に別の壁紙を適用してから削除してください。',
  'deleteFailed': '削除に失敗: {error}',
  'applyFailedGeneric': '適用に失敗しました',
  'applyFailed': '適用に失敗: {error}',
  'applyNoPreview': '壁紙設定は保存されましたが、システムプレビューを開けませんでした。システムの壁紙設定から ZUNO を手動で選択してください',
  'applyTimedFailed': '現在のスロットを解決できませんでした（充電時のみの制限がある可能性があります。充電器を接続して再試行してください）',

  // ---- オンラインライブラリ ----
  'libraryNotConfiguredTitle': 'ライブラリが未設定です',
  'libraryNotConfiguredBody':
      '壁紙ライブラリは、自分でデプロイした zuno-api バックエンドを参照します'
      '（Docker または Cloudflare Workers。README のデプロイ章を参照）。'
      '「設定 → 壁紙ライブラリのアドレス」にサーバーアドレスを入力して開始してください。',
  'goSettings': '設定へ',
  'libraryEmptyTitle': 'ライブラリは空です',
  'libraryEmptyBody':
      '自分でデプロイしたバックエンドの場合は、「設定 → 壁紙ライブラリのアドレス」'
      'を確認してください。アドレスが正しいのに一覧が空の場合、管理ツールがまだ'
      '.zuno パッケージを同期していません。',
  'setLibraryAddress': 'ライブラリアドレスを設定',
  'catalogLoadFailed': 'カタログを読み込めませんでした',
  'changeAddress': 'アドレスを変更',
  'endOfList': 'これで終わりです',
  'packageInfo': 'パッケージ情報',
  'authorField': '作者',
  'versionField': 'バージョン',
  'sizeField': 'サイズ',
  'updatedField': '更新',
  'idField': 'ID',
  'unsigned': '作者不明',
  'downloadImport': 'ダウンロードしてインポート',
  'downloading': 'ダウンロード中…',
  'downloadingPercent': 'ダウンロード中 {percent}%',
  'addedToMyWallpapers': '「マイ壁紙」に追加しました',
  'importBusy': 'インポートが実行中です。しばらくお待ちください。',
  'downloadFailed': 'ダウンロードに失敗：{error}',
  'downloadFileUnreadable': 'インポート失敗：ダウンロードしたファイルを読み取れません',
  'verifyNote':
      'ダウンロード後に端末上で manifest とチェックサムを再検証します。'
      '合格したパッケージだけが「マイ壁紙」に追加され、失敗時は具体的な理由が表示されます。',

  // ---- 設定 ----
  'appearance': '外観',
  'followSystem': 'システム',
  'light': 'ライト',
  'dark': 'ダーク',
  'appearanceHint': 'デフォルトではシステムに従います。変更はすぐに反映され、記憶されます。',
  'interfaceSection': 'インターフェース',
  'showTabBar': '下部タブバーを表示',
  'showTabBarHint': '非表示時は上部バーのボタンで「マイ壁紙 / ライブラリ」を切り替えます',
  'performanceTier': 'パフォーマンス',
  'tierHigh': '高',
  'tierMedium': '中',
  'tierLow': '低',
  'performanceHintBody':
      '壁紙実行時の各レンダリング経路に適用されます（デフォルト：中）：\n'
      '· 動画：高/中は通常再生、低は静止した先頭フレーム\n'
      '· 深度：30 / 20 / 15 fps（省電力モードでは 15 に固定）\n'
      '· HTML：高は無制限、中は約 30fps、低は CSS アニメーションを凍結',
  'videoDecode': '動画デコード',
  'decodeAuto': '自動',
  'decodeHardware': 'ハードウェア',
  'decodeSoftware': 'ソフトウェア',
  'decodeHintBody':
      '自動：ハードウェアを優先し、利用できない場合のみソフトウェアに切り替えます。実行中の失敗は通知されます。\n'
      'ハードウェア：最も省電力ですが、互換性は端末のデコーダーに依存します。\n'
      'ソフトウェア：互換性は最も広いですが、消費電力と発熱が増え、高解像度動画ではコマ落ちする場合があります。\n'
      '音量は引き続き各パッケージのパラメータで制御され、デフォルトはミュートです。',
  'decodePrompt': 'デコード失敗時に通知',
  'decodePromptHint': 'アプリに戻ったときにソフトウェアデコードへの切り替えを提案します',
  'depthParallax': '深度パララックス',
  'depthSoft': '弱',
  'depthStandard': '標準',
  'depthStrong': '強',
  'depthHint':
      '各深度パッケージ自身のパララックス強度に掛かる全体倍率です。'
      'ホーム画面の揺れが強すぎる場合は「弱」を選んでください。',
  'libraryAddress': '壁紙ライブラリのアドレス',
  'addressConfigured':
      '有効: {url}\n'
      '自分でデプロイした zuno-api（Docker または Cloudflare Workers。README 参照）を指します。'
      '保存するとカタログがすぐに再構築されます。未設定時はライブラリタブに設定ガイドが表示されます。',
  'addressNotConfigured':
      '未設定です。自分でデプロイした zuno-api サーバーのアドレスを入力してください'
      '（README の「バックエンドのデプロイ」参照）。保存するとカタログがすぐに再構築されます。',
  'addressHint': 'https://api.example.com',
  'libraryAddressSaved': '壁紙ライブラリのアドレスを保存しました',
  'libraryAddressCleared': '壁紙ライブラリのアドレスを消去しました',
  'batteryOptimization': 'バッテリー最適化',
  'batteryFooter':
      'タイマー壁紙は時間どおりに切り替えるためバックグラウンド実行が必要です。'
      'ZUNO をバッテリー最適化の許可リストに追加すると、スリープ中に切り替えが'
      '大きく遅れるのを防げます。',
  'batteryAllowed': 'バッテリー最適化の許可リストに追加済み',
  'batteryNotAllowed': 'バッテリー最適化の許可リストに未追加',
  'storage': 'ストレージ',
  'libraryUsage': 'ライブラリの使用量',
  'libraryUsageSubtitle': 'インストール済み壁紙パッケージのファイル（アプリ専用ディレクトリ）',
  'aboutZuno': 'ZUNO について',
  'aboutZunoSubtitle': 'バージョン情報 · コミュニティ',

  // ---- このアプリについて ----
  'aboutDescription':
      'ホーム画面を動かそう。ZUNO は動画、深度パララックス、インタラクティブ HTML、'
      'タイマー切り替えの 4 種類の動く壁紙を提供します。パッケージをインポートして'
      '適用するだけで、動くデスクトップが手に入ります。',
  'qqGroup': 'QQ グループ',
  'qqGroupSubtitle': '問題の報告、壁紙の共有、パッケージの入手',
  'groupLinkCopied': 'グループリンクをコピーしました。QQ に貼り付けて参加できます',
  'highlights': '特徴',
  'featureVideoTitle': '動画壁紙',
  'featureVideoDesc': '滑らかな再生、デフォルトはミュート、速度と音量を調整可能',
  'featureDepthTitle': '深度パララックス',
  'featureDepthDesc': '端末を傾けると立体的な奥行きを感じられます',
  'featureHtmlTitle': 'インタラクティブ HTML',
  'featureHtmlDesc': 'タップに反応する Web 壁紙',
  'featureTimedTitle': 'タイマー切り替え',
  'featureTimedDesc': '昼と夜で異なる壁紙に自動で切り替え',
  'featurePerformanceTitle': 'パフォーマンス段階',
  'featurePerformanceDesc': '高 / 中 / 低で見た目と省電力を両立',
  'madeWith': 'Made with ZUNO',

  // ---- アカウント ----
  'login': 'ログイン',
  'register': 'アカウント作成',
  'email': 'メールアドレス',
  'password': 'パスワード',
  'passwordMin': 'パスワード（8 文字以上）',
  'confirmPassword': 'もう一度パスワードを入力',
  'loginRegister': 'ログイン / 登録',
  'emailInvalid': 'メールアドレスの形式が正しくありません',
  'passwordLength': 'パスワードは 8〜128 文字である必要があります',
  'passwordMismatch': 'パスワードが一致しません',
  'signingIn': 'ログイン中…',
  'creating': '作成中…',
  'createAccount': 'アカウントを作成',
  'authNote':
      'アカウントはオンラインライブラリとダウンロードチケットに使用されます。'
      '壁紙のアップロードとユーザー管理は管理側の機能（Admin Secret）であり、'
      'クライアントには公開されていません。',
  'logoutTitle': 'ログアウトしますか？',
  'logoutBody': 'オンライン壁紙をダウンロードするには再度ログインが必要です。インストール済みの壁紙には影響しません。',
  'logout': 'ログアウト',
  'account': 'アカウント',
  'sessionValidity': 'セッション有効期限',
  'sessionDaysLeft': '残り {days} 日。期限切れ後は再度ログインが必要です',
  'notSignedIn': '未ログイン',
  'signedInSubtitle': '無料アカウント · 残り {days} 日',
  'freeAccountDays': '無料アカウント · 残り {days} 日',
  'loginToDownload': 'ログインするとオンライン壁紙をダウンロードできます。閲覧は制限されません',
  'management': '管理機能',
  'managementFooter':
      'アップロードとセッション管理にはサーバー側の ADMIN_SECRET が必要です。'
      'パッケージは管理ツールから WebDAV に直接書き込まれ、その後 /api/admin/sync で'
      'メタデータが登録されます。クライアントは関与しません。',
  'uploadWallpaper': '壁紙をアップロード',
  'uploadSubtitle': 'WebDAV 直接アップロード + バックグラウンド同期',
  'userManagement': 'ユーザー管理',
  'userManagementSubtitle': 'D1 users テーブル、管理画面のみ',
  'adminBadge': '管理',

  // ---- ダイアログ ----
  'setWallpaperTitle': 'ZUNO を動く壁紙に設定しますか？',
  'setWallpaperMessage': 'システムの壁紙プレビューが開きます。「壁紙を設定」をタップするとホーム画面が動き出します。',
  'goSet': '設定する',
  'decodeSoftwareFailedTitle': 'ソフトウェアデコードでも再生できません',
  'decodeSoftwareFailedMessage':
      'この動画はソフトウェアデコーダーでも再生できません。壁紙は静止した先頭フレームのままになります。'
      'H.264 / H.265 エンコードの 1080p 以下の動画をお試しください。',
  'decodeHardwareFailedTitle': '動画のハードウェアデコードに失敗しました',
  'decodeHardwareFailedMessage':
      'この動画はハードウェアデコードで再生できません。ソフトウェアデコードに切り替えられますが、'
      '消費電力と発熱が明らかに増え、高解像度動画ではカクつく場合があります。',
  'neverAsk': '今後表示しない',
  'useSoftware': 'ソフトウェアを使用',
  'switchedToSoftware': 'ソフトウェアデコードに切り替えました。ホーム画面に戻ると壁紙が再読み込みされます',

  // ---- 壁紙タイプ ----
  'typeVideo': '動画',
  'typeHtml': 'HTML',
  'typeDepth': '深度',
  'typeTimed': 'タイマー',

  // ---- 検証：問題コード ----
  'issueZipInvalid': 'ZIP を展開できません',
  'issueZipSlip': 'ZIP パストラバーサル攻撃',
  'issueManifestMissing': 'manifest.json がありません',
  'issueManifestUnreadable': 'manifest.json を解析できません',
  'issueFieldInvalid': '無効なフィールド',
  'issueEntryMissing': 'エントリファイルがありません',
  'issueContentEmpty': 'content/ が空です',
  'issueChecksumMismatch': 'チェックサムが一致しません',
  'issueMinSdkTooHigh': 'パッケージの minSdk がこの端末より高いです',
  'issueTimedScheduleInvalid': 'schedule.json が無効です',
  'issueTimedSlotMissing': 'schedule.json が参照するスロットがありません',
  'issueTimedSlotInvalid': 'スロットの manifest が無効です',
  'issueUnknown': '不明なエラー',

  // ---- 検証：インポート詳細 ----
  'errFileNotFound': 'ファイルが見つかりません: {path}',
  'errOpenZip': 'ZIP ファイルを開けません: {error}',
  'errInvalidZip': '有効な ZIP コンテナではありません: {error}',
  'errTooManyEntries': 'インポート拒否：ZIP エントリ数が上限を超えています（zip bomb の疑い）',
  'errPathTraversal': 'インポート拒否：エントリ "{entry}" にパストラバーサル/絶対パスが含まれています',
  'errEntryTooLarge': 'インポート拒否：エントリ "{entry}" の展開後サイズが {bytes} バイトの上限を超えています（zip bomb の疑い）',
  'errTotalTooLarge': 'インポート拒否：ZIP の展開後合計サイズが上限を超えています（zip bomb の疑い）',
  'errNoFiles': 'ZIP にファイルがありません',
  'errManifestMissingRoot': 'ルート（または単一のトップレベルフォルダ内）に manifest.json がありません',
  'errManifestMultiple': '複数のトップレベルフォルダに manifest.json があります：{folders}',
  'errManifestJson': 'manifest.json が有効な JSON ではありません: {error}',
  'errManifestTopLevel': 'manifest.json の最上位はオブジェクトである必要があります',
  'errTimedNeedsSchedule': 'タイマーパッケージには content/schedule.json が必要です',
  'errPathEscapesStaging': '展開後のパスがステージングディレクトリの外に出ています',
  'errImportException': 'インポート中に予期しないエラーが発生しました: {error}',
  'errChecksumMismatch': 'チェックサムが一致しません：期待値 {expected}、計算値 {actual}',
  'errChecksumRecompute': 'チェックサムの再計算に失敗: {error}',
  'errManifestParse': 'manifest の解析に失敗（不正なパッケージ構造）: {error}',
  'errEntryNotInPackage': 'entry "{entry}" がパッケージ内にありません（ファイル数 {count}）',
  'errContentEmpty': 'content/ ディレクトリが空です（または ZIP に content/ エントリがありません）',
  'errMinSdk': 'パッケージは minSdk={required} を要求していますが、この端末は API {actual} です',
  'errDepthRequires': 'depth タイプには content/depth.png（カラー画像と同じサイズのグレースケール深度マップ）が必要です',
  'errDepthEntryFormat': 'depth の entry は jpg/png である必要があります。実際: {entry}',
  'errHtmlEntryFormat': 'html の entry は .html ファイルである必要があります。実際: {entry}',
  'errVideoEntryFormat': 'video の entry は mp4/webm である必要があります。実際: {entry}',
  'errSlotMissing': 'schedule が参照する slot "{slot}" がありません（{path} が不足）',
  'errSlotContentEmpty': 'slot "{slot}" の content/ が空です',
  'errSlotSchema': 'slot "{slot}" の manifest.schemaVersion は 1 である必要があります',
  'errSlotIdMissing': 'slot "{slot}" の manifest.id がありません',
  'errSlotIdConflict': 'slot "{slot}" の id がトップレベルパッケージの id と衝突しています',
  'errSlotNestedTimed': 'slot "{slot}" にタイマータイプをネストすることはできません',
  'errSlotTypeInvalid': 'slot "{slot}" の type は video/html/depth である必要があります。実際: {type}',
  'errSlotEntryMissing': 'slot "{slot}" の manifest.entry がありません',
  'errSlotEntryNotFound': 'slot "{slot}" の entry "{entry}" が存在しません',
  'errSlotManifestUnreadable': 'slot "{slot}" の manifest.json を解析できません: {error}',
  'errScheduleJson': 'schedule.json が有効な JSON ではありません: {error}',
  'errScheduleTopLevel': 'schedule.json の最上位はオブジェクトである必要があります',
  'errScheduleRules': 'schedule.rules は配列である必要があります',
  'errRuleNotObject': 'rules[{index}] はオブジェクトである必要があります',
  'errRuleFrom': 'rules[{index}].from は HH:mm である必要があります。実際: {value}',
  'errRuleTo': 'rules[{index}].to は HH:mm である必要があります。実際: {value}',
  'errRuleWallpaper': 'rules[{index}].wallpaper は空でない文字列である必要があります',
  'errDefaultString': 'default は文字列である必要があります',
  'warnVideoCodec':
      'この動画のコーデックは一部の端末でサポートされない可能性があります。'
      '壁紙が静止画になる場合があります。H.264/H.265 の動画を推奨します。',
  'warnVideoDecodeLimit':
      'この動画の解像度/フレームレートはこの端末のデコード能力を超えています。'
      'プレビューと壁紙は静止した先頭フレームになります。',

  // ---- ネットワーク / API ----
  'errSessionIncomplete': 'サーバーが返したセッションデータが不完全です',
  'errTicketIncomplete': 'サーバーが返したダウンロードチケットが不完全です',
  'errCannotConnect': 'サーバーに接続できません：{error}',
  'errRequestFailed': 'リクエストに失敗：{error}',
  'errResponseReadFailed': 'レスポンスを読み取れません：{error}',
  'errorDetailSeparator': '：',
  'errDownloadHttp': 'ダウンロードに失敗（HTTP {code}）{body}',
  'errCatalogLoad': 'カタログを読み込めません：{error}',
  'errLoadMore': '追加読み込みに失敗：{error}',
  'errWallpaperDownloading': 'この壁紙はダウンロード中です',
  'errEndpointInvalid': '完全なアドレスを入力してください（例: https://api.example.com）',
  'errOperationFailed': '操作に失敗：{error}',
  'errSizeUnknown': 'サイズ不明',

  // ---- manifest の理由 ----
  'reasonMustBeObject': 'オブジェクトである必要があります',
  'reasonRequiredString': '必須で、空でない文字列である必要があります。実際: {value}',
  'reasonMustBeString': '文字列である必要があります。実際: {value}',
  'reasonRequiredInt': '必須で、整数である必要があります。実際: {value}',
  'reasonMustBeInt': '整数である必要があります。実際: {value}',
  'reasonMustBeNumber': '数値である必要があります。実際: {value}',
  'reasonConfigObject': 'config[{index}] はオブジェクトである必要があります',
  'reasonConfigKey': 'config[{index}].key は必須で文字列である必要があります',
  'reasonConfigType': 'config[{index}].type は float/int/bool/color のいずれかである必要があります。実際: {type}',
  'reasonDefaultFloat': 'float パラメータの default は数値である必要があります',
  'reasonDefaultInt': 'int パラメータの default は整数である必要があります',
  'reasonDefaultBool': 'bool パラメータの default は真偽値である必要があります',
  'reasonDefaultColor': 'color パラメータの default は #RRGGBB(AA) である必要があります',
  'reasonMinMax': 'min > max',
  'reasonCapabilitiesObject': 'オブジェクトである必要があります',
  'reasonStringArray': '文字列の配列である必要があります',
  'reasonElementString': '要素は文字列である必要があります。実際: {value}',
  'reasonSchemaOnly1': '現在サポートされるのは 1 のみです。実際: {value}',
  'reasonIdCharset': '英字/数字/ドット/アンダースコアのみ使用でき、"." や ".." は使用できません。実際: {value}',
  'reasonSemver': 'セマンティックバージョン（例: 1.0.0）である必要があります。実際: {value}',
  'reasonTypeOneOf': 'video/html/depth/timed のいずれかである必要があります',
  'reasonPerformanceHint': 'low/medium/high のいずれかである必要があります。実際: {value}',
  'reasonConfigArray': '配列である必要があります',
  'reasonDuplicateKeys': 'key が重複しています',
};
