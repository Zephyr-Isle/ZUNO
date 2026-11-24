/// 한국어.
const Map<String, String> zunoStringsKo = {
  // ---- 공통 ----
  'cancel': '취소',
  'delete': '삭제',
  'later': '나중에',
  'gotIt': '확인',
  'back': '뒤로',
  'settings': '설정',
  'save': '저장',
  'clearAddress': '주소 지우기',
  'retry': '다시 시도',
  'close': '닫기',
  'exitFullscreen': '전체 화면 종료',
  'fullscreenPreview': '전체 화면 미리보기',
  'openSettings': '설정 열기',
  'unknownError': '알 수 없는 오류',
  'calculating': '계산 중…',

  // ---- 탐색 ----
  'myWallpapers': '내 배경화면',
  'wallpaperLibrary': '배경화면 라이브러리',
  'settingsTitle': '설정',
  'aboutTitle': '정보',
  'languageTitle': '언어',
  'languageSystem': '시스템 설정 따르기',
  'languageDescription': '앱 표시 언어를 선택하세요. “시스템 설정 따르기”는 Android 언어 설정을 사용합니다.',
  'languageCurrent': '현재',
  'openLibrary': '배경화면 라이브러리 열기',
  'backToMyWallpapers': '내 배경화면으로 돌아가기',
  'refreshLibrary': '배경화면 라이브러리 새로고침',
  'settingsSemantic': '설정',
  'inUse': '사용 중',
  'installed': '설치됨',

  // ---- 내 배경화면 ----
  'importingPackage': '배경화면 패키지를 압축 해제하고 검증하는 중(백그라운드 isolate)…',
  'importZuno': '.zuno 가져오기',
  'emptyLibraryTitle': '배경화면이 없습니다',
  'emptyLibraryBody':
      'ZUNO Package v1 사양을 따르는 .zuno 패키지를 가져오세요.\n'
      '동영상 / 심도 시차 / HTML / 타이머 배경화면을 지원합니다.',
  'importSuccessWarnings': '가져왔지만 경고가 있습니다',
  'importRejected': '가져오기 거부됨',
  'importFailedUnreadable': '가져오기 실패: 파일을 읽을 수 없습니다',

  // ---- 배경화면 상세 ----
  'performanceHint': '성능 권장',
  'hintLow': '낮음',
  'hintMedium': '보통',
  'hintHigh': '높음',
  'authorLabel': '제작자',
  'parameters': '매개변수',
  'noParameters': '이 배경화면에는 조정 가능한 매개변수가 없습니다',
  'capTouch': '터치 입력',
  'capSensors': '센서: {sensors}',
  'capNetwork': '네트워크 선언됨(v1에서는 계속 차단)',
  'scheduleWindows': '일정',
  'currentSlot': '현재: {slot}',
  'defaultSlot': '기본: {slot}',
  'timedPreview': '시간대 미리보기',
  'timedPreviewActiveHint':
      '드래그하여 각 시간대를 미리 봅니다. 실제 일정은 다음 WorkManager 확인 시 복원됩니다.',
  'timedPreviewInactiveHint': '슬롯을 미리 보려면 먼저 이 배경화면을 적용하세요(미리보기는 활성 슬롯을 핫스왑합니다).',
  'applyWallpaper': '이 배경화면 적용',
  'applyHint': '시스템 배경화면 미리보기가 열립니다. “배경화면 설정”을 눌러 확정하세요',
  'livePreview': '실시간 미리보기',
  'noThumbnail': '썸네일 없음',
  'thumbnailLoadFailed': '썸네일을 불러오지 못했습니다',
  'htmlPreviewFullscreen': 'HTML 배경화면 미리보기(핀치로 확대)',
  'videoFullscreen': '동영상 전체 화면 미리보기',
  'depthFullscreen': '심도 시차 전체 화면 미리보기',
  'timedNoRender':
      '타이머 유형은 자체적으로 렌더링하지 않습니다.\n'
      '전체 화면 미리보기는 현재 활성 슬롯을 표시합니다.',
  'currentPeriod': '현재 시간대: {slot}',
  'unsupportedFullscreen': '현재 슬롯({slot})은 전체 화면 미리보기를 지원하지 않습니다',
  'exportShare': '내보내기 / 공유',
  'deletePackageTitle': '배경화면 패키지를 삭제할까요?',
  'deletePackageBody': '{title} 및 해당 파일이 삭제됩니다.',
  'packingPackage': '배경화면 패키지를 묶는 중(스트리밍 내보내기)…',
  'exportFailed': '내보내기 실패',
  'exportedTo': '내보낸 위치: {path}',
  'applyPreviewPrompt': '시스템 미리보기를 엽니다. “배경화면 설정”을 누르세요',
  'videoPreviewInitFailed': '동영상 미리보기 초기화 실패: {error}',
  'videoUnsupported': '이 기기에서는 이 동영상을 실시간 재생할 수 없습니다. 배경화면은 정지 화면으로 표시됩니다',
  'videoLoading': '동영상 불러오는 중…',
  'colorImageLoadFailed': '컬러 이미지를 불러오지 못했습니다',
  'depthApproxHint': '미리보기는 근사치입니다. 실제 배경화면은 더 부드럽습니다',
  'slotResolveFailed': '현재 슬롯을 확인할 수 없습니다',
  'deleteInUse': '이 배경화면은 사용 중입니다. 다른 배경화면을 적용한 후 삭제하세요.',
  'deleteFailed': '삭제 실패: {error}',
  'applyFailedGeneric': '적용 실패',
  'applyFailed': '적용 실패: {error}',
  'applyNoPreview': '배경화면 설정은 저장되었지만 시스템 미리보기를 열 수 없습니다. 시스템 배경화면 설정에서 ZUNO를 직접 선택하세요',
  'applyTimedFailed': '현재 슬롯을 확인할 수 없습니다(충전 중에만 허용되는 제한일 수 있습니다. 충전기를 연결하고 다시 시도하세요)',

  // ---- 온라인 라이브러리 ----
  'libraryNotConfiguredTitle': '라이브러리가 설정되지 않음',
  'libraryNotConfiguredBody':
      '배경화면 라이브러리는 직접 배포한 zuno-api 백엔드를 가리킵니다'
      '(Docker 또는 Cloudflare Workers. README의 배포 장을 참조).'
      '“설정 → 배경화면 라이브러리 주소”에 서버 주소를 입력하여 시작하세요.',
  'goSettings': '설정으로 이동',
  'libraryEmptyTitle': '라이브러리가 비어 있습니다',
  'libraryEmptyBody':
      '직접 배포한 백엔드라면 “설정 → 배경화면 라이브러리 주소”를 확인하세요. '
      '주소가 올바른데 목록이 비어 있다면 관리 도구가 아직 .zuno 패키지를 '
      '동기화하지 않은 것입니다.',
  'setLibraryAddress': '라이브러리 주소 설정',
  'catalogLoadFailed': '카탈로그를 불러오지 못했습니다',
  'changeAddress': '주소 변경',
  'endOfList': '끝입니다',
  'packageInfo': '패키지 정보',
  'authorField': '제작자',
  'versionField': '버전',
  'sizeField': '크기',
  'updatedField': '업데이트',
  'idField': 'ID',
  'unsigned': '제작자 미상',
  'downloadImport': '다운로드 및 가져오기',
  'downloading': '다운로드 중…',
  'downloadingPercent': '다운로드 중 {percent}%',
  'addedToMyWallpapers': '“내 배경화면”에 추가됨',
  'importBusy': '이미 가져오기가 진행 중입니다. 잠시 기다려 주세요.',
  'downloadFailed': '다운로드 실패: {error}',
  'downloadFileUnreadable': '가져오기 실패: 다운로드한 파일을 읽을 수 없습니다',
  'verifyNote':
      '다운로드 후 기기에서 manifest와 체크섬을 다시 검증합니다. '
      '통과한 패키지만 “내 배경화면”에 추가되며, 실패 시 구체적인 이유가 표시됩니다.',

  // ---- 설정 ----
  'appearance': '화면 스타일',
  'followSystem': '시스템',
  'light': '라이트',
  'dark': '다크',
  'appearanceHint': '기본값은 시스템 설정을 따릅니다. 변경 사항은 즉시 적용되고 기억됩니다.',
  'interfaceSection': '인터페이스',
  'showTabBar': '하단 탭 표시',
  'showTabBarHint': '숨기면 상단 버튼으로 “내 배경화면 / 라이브러리”를 전환합니다',
  'performanceTier': '성능 단계',
  'tierHigh': '높음',
  'tierMedium': '보통',
  'tierLow': '낮음',
  'performanceHintBody':
      '배경화면 실행 시 모든 렌더링 경로에 적용됩니다(기본값: 보통):\n'
      '· 동영상: 높음/보통은 정상 재생, 낮음은 정지된 첫 프레임\n'
      '· 심도: 30 / 20 / 15 fps(절전 모드에서는 15로 고정)\n'
      '· HTML: 높음은 무제한, 보통은 약 30fps, 낮음은 CSS 애니메이션 정지',
  'videoDecode': '동영상 디코딩',
  'decodeAuto': '자동',
  'decodeHardware': '하드웨어',
  'decodeSoftware': '소프트웨어',
  'decodeHintBody':
      '자동: 하드웨어를 우선하고 사용할 수 없을 때만 소프트웨어로 전환합니다. 실행 중 실패는 알림으로 표시됩니다.\n'
      '하드웨어: 가장 전력 효율적이지만 호환성은 기기 디코더에 따라 다릅니다.\n'
      '소프트웨어: 호환성이 가장 넓지만 전력과 발열이 늘고 고해상도 동영상에서 끊길 수 있습니다.\n'
      '볼륨은 계속 패키지별 매개변수로 제어되며 기본값은 음소거입니다.',
  'decodePrompt': '디코딩 실패 시 알림',
  'decodePromptHint': '앱으로 돌아왔을 때 소프트웨어 디코딩 전환을 제안합니다',
  'depthParallax': '심도 시차',
  'depthSoft': '약하게',
  'depthStandard': '표준',
  'depthStrong': '강하게',
  'depthHint':
      '각 심도 패키지의 시차 강도에 추가로 곱해지는 전역 배율입니다. '
      '홈 화면이 너무 흔들리면 “약하게”를 선택하세요.',
  'libraryAddress': '배경화면 라이브러리 주소',
  'addressConfigured':
      '사용 중: {url}\n'
      '직접 배포한 zuno-api(Docker 또는 Cloudflare Workers. README 참조)를 가리킵니다. '
      '저장하면 카탈로그가 즉시 다시 만들어집니다. 설정하지 않으면 라이브러리 탭에 안내가 표시됩니다.',
  'addressNotConfigured':
      '설정되지 않았습니다. 직접 배포한 zuno-api 서버 주소를 입력하세요'
      '(README의 “백엔드 배포” 참조). 저장하면 카탈로그가 즉시 다시 만들어집니다.',
  'addressHint': 'https://api.example.com',
  'libraryAddressSaved': '배경화면 라이브러리 주소가 저장되었습니다',
  'libraryAddressCleared': '배경화면 라이브러리 주소를 지웠습니다',
  'batteryOptimization': '배터리 최적화',
  'batteryFooter':
      '타이머 배경화면이 제시간에 전환되려면 백그라운드 실행이 필요합니다. '
      'ZUNO를 배터리 최적화 허용 목록에 추가하면 절전 상태에서 전환이 '
      '크게 지연되는 것을 방지할 수 있습니다.',
  'batteryAllowed': '배터리 최적화 허용 목록에 추가됨',
  'batteryNotAllowed': '배터리 최적화 허용 목록에 없음',
  'storage': '저장공간',
  'libraryUsage': '라이브러리 사용량',
  'libraryUsageSubtitle': '설치된 배경화면 패키지 파일(앱 전용 디렉터리)',
  'aboutZuno': 'ZUNO 정보',
  'aboutZunoSubtitle': '버전 정보 · 커뮤니티',

  // ---- 정보 ----
  'aboutDescription':
      '홈 화면을 살아 움직이게 하세요. ZUNO는 동영상, 심도 시차, 인터랙티브 HTML, '
      '타이머 전환의 네 가지 동적 배경화면을 제공합니다. 패키지를 가져와 적용하면 '
      '움직이는 데스크톱을 얻을 수 있습니다.',
  'qqGroup': 'QQ 그룹',
  'qqGroupSubtitle': '문제 제보, 배경화면 공유 및 패키지 받기',
  'groupLinkCopied': '그룹 링크를 복사했습니다. QQ에 붙여넣어 참여하세요',
  'highlights': '주요 기능',
  'featureVideoTitle': '동영상 배경화면',
  'featureVideoDesc': '부드러운 재생, 기본 음소거, 속도와 볼륨 조절 가능',
  'featureDepthTitle': '심도 시차',
  'featureDepthDesc': '휴대폰을 기울이면 입체적인 깊이감',
  'featureHtmlTitle': '인터랙티브 HTML',
  'featureHtmlDesc': '탭에 반응하는 웹 배경화면',
  'featureTimedTitle': '타이머 전환',
  'featureTimedDesc': '낮과 밤에 다른 배경화면으로 자동 전환',
  'featurePerformanceTitle': '성능 단계',
  'featurePerformanceDesc': '높음 / 보통 / 낮음으로 화질과 전력의 균형',
  'madeWith': 'Made with ZUNO',

  // ---- 계정 ----
  'login': '로그인',
  'register': '계정 만들기',
  'email': '이메일',
  'password': '비밀번호',
  'passwordMin': '비밀번호(8자 이상)',
  'confirmPassword': '비밀번호를 다시 입력하세요',
  'loginRegister': '로그인 / 가입',
  'emailInvalid': '이메일 형식이 올바르지 않습니다',
  'passwordLength': '비밀번호는 8–128자여야 합니다',
  'passwordMismatch': '비밀번호가 일치하지 않습니다',
  'signingIn': '로그인 중…',
  'creating': '생성 중…',
  'createAccount': '계정 만들기',
  'authNote':
      '계정은 온라인 라이브러리와 다운로드 티켓에 사용됩니다. '
      '배경화면 업로드와 사용자 관리는 관리자 측 기능(Admin Secret)이며 '
      '클라이언트에는 제공되지 않습니다.',
  'logoutTitle': '로그아웃할까요?',
  'logoutBody': '온라인 배경화면을 다운로드하려면 다시 로그인해야 합니다. 설치된 배경화면은 영향을 받지 않습니다.',
  'logout': '로그아웃',
  'account': '계정',
  'sessionValidity': '세션 유효 기간',
  'sessionDaysLeft': '{days}일 남음. 만료 후 다시 로그인해야 합니다',
  'notSignedIn': '로그인하지 않음',
  'signedInSubtitle': '무료 계정 · {days}일 남음',
  'freeAccountDays': '무료 계정 · {days}일 남음',
  'loginToDownload': '로그인하면 온라인 배경화면을 다운로드할 수 있습니다. 탐색은 제한되지 않습니다',
  'management': '관리 기능',
  'managementFooter':
      '업로드와 세션 관리에는 서버 측 ADMIN_SECRET이 필요합니다. 패키지는 관리 도구가 '
      'WebDAV에 직접 기록한 뒤 /api/admin/sync로 메타데이터를 등록합니다. '
      '클라이언트는 관여하지 않습니다.',
  'uploadWallpaper': '배경화면 업로드',
  'uploadSubtitle': 'WebDAV 직접 업로드 + 백그라운드 동기화',
  'userManagement': '사용자 관리',
  'userManagementSubtitle': 'D1 users 테이블, 관리자 전용',
  'adminBadge': '관리자',

  // ---- 대화상자 ----
  'setWallpaperTitle': 'ZUNO를 동적 배경화면으로 설정할까요?',
  'setWallpaperMessage': '시스템 배경화면 미리보기가 열립니다. “배경화면 설정”을 누르면 홈 화면이 움직이기 시작합니다.',
  'goSet': '설정하기',
  'decodeSoftwareFailedTitle': '소프트웨어 디코딩도 실패했습니다',
  'decodeSoftwareFailedMessage':
      '이 동영상은 소프트웨어 디코더로도 재생할 수 없습니다. 배경화면은 정지된 첫 프레임에 머뭅니다. '
      'H.264 / H.265 인코딩의 1080p 이하 동영상을 사용해 보세요.',
  'decodeHardwareFailedTitle': '동영상 하드웨어 디코딩 실패',
  'decodeHardwareFailedMessage':
      '이 동영상은 하드웨어 디코딩으로 재생할 수 없습니다. 소프트웨어 디코딩으로 전환할 수 있지만 '
      '전력 소모와 발열이 눈에 띄게 늘고 고해상도 동영상에서는 끊길 수 있습니다.',
  'neverAsk': '다시 묻지 않기',
  'useSoftware': '소프트웨어 사용',
  'switchedToSoftware': '소프트웨어 디코딩으로 전환했습니다. 홈 화면으로 돌아가면 배경화면이 다시 로드됩니다',

  // ---- 배경화면 유형 ----
  'typeVideo': '동영상',
  'typeHtml': 'HTML',
  'typeDepth': '심도',
  'typeTimed': '타이머',

  // ---- 검증: 문제 코드 ----
  'issueZipInvalid': 'ZIP 압축을 풀 수 없음',
  'issueZipSlip': 'ZIP 경로 순회 공격',
  'issueManifestMissing': 'manifest.json 없음',
  'issueManifestUnreadable': 'manifest.json을 분석할 수 없음',
  'issueFieldInvalid': '잘못된 필드',
  'issueEntryMissing': '진입 파일 없음',
  'issueContentEmpty': 'content/가 비어 있음',
  'issueChecksumMismatch': '체크섬 불일치',
  'issueMinSdkTooHigh': '패키지의 minSdk가 이 기기보다 높음',
  'issueTimedScheduleInvalid': 'schedule.json이 잘못됨',
  'issueTimedSlotMissing': 'schedule.json이 참조하는 슬롯이 없음',
  'issueTimedSlotInvalid': '슬롯 manifest가 잘못됨',
  'issueUnknown': '알 수 없는 오류',

  // ---- 검증: 가져오기 상세 ----
  'errFileNotFound': '파일을 찾을 수 없음: {path}',
  'errOpenZip': 'ZIP 파일을 열 수 없음: {error}',
  'errInvalidZip': '유효한 ZIP 컨테이너가 아님: {error}',
  'errTooManyEntries': '가져오기 거부: ZIP 항목 수가 한도를 초과함(zip bomb 의심)',
  'errPathTraversal': '가져오기 거부: 항목 "{entry}"에 경로 순회/절대 경로가 포함됨',
  'errEntryTooLarge': '가져오기 거부: 항목 "{entry}"의 압축 해제 크기가 {bytes}바이트 한도를 초과함(zip bomb 의심)',
  'errTotalTooLarge': '가져오기 거부: ZIP 압축 해제 총량이 한도를 초과함(zip bomb 의심)',
  'errNoFiles': 'ZIP에 파일이 없음',
  'errManifestMissingRoot': '루트(또는 단일 최상위 폴더 내)에 manifest.json이 없음',
  'errManifestMultiple': '여러 최상위 폴더에 manifest.json이 있음: {folders}',
  'errManifestJson': 'manifest.json이 유효한 JSON이 아님: {error}',
  'errManifestTopLevel': 'manifest.json의 최상위는 객체여야 함',
  'errTimedNeedsSchedule': '타이머 패키지에는 content/schedule.json이 필요함',
  'errPathEscapesStaging': '압축 해제된 경로가 임시 디렉터리를 벗어남',
  'errImportException': '가져오기 중 예기치 않은 오류: {error}',
  'errChecksumMismatch': '체크섬 불일치: 예상 {expected}, 계산 {actual}',
  'errChecksumRecompute': '체크섬 재계산 실패: {error}',
  'errManifestParse': 'manifest 분석 실패(잘못된 패키지 구조): {error}',
  'errEntryNotInPackage': 'entry "{entry}"가 패키지에 없음(파일 {count}개)',
  'errContentEmpty': 'content/ 디렉터리가 비어 있음(또는 ZIP에 content/ 항목이 없음)',
  'errMinSdk': '패키지가 minSdk={required}를 요구하지만 이 기기는 API {actual}임',
  'errDepthRequires': 'depth 유형은 content/depth.png(컬러 이미지와 같은 크기의 회색조 심도 맵)가 필요함',
  'errDepthEntryFormat': 'depth의 entry는 jpg/png여야 함. 실제: {entry}',
  'errHtmlEntryFormat': 'html의 entry는 .html 파일이어야 함. 실제: {entry}',
  'errVideoEntryFormat': 'video의 entry는 mp4/webm이어야 함. 실제: {entry}',
  'errSlotMissing': 'schedule이 참조하는 slot "{slot}"이 없음({path} 누락)',
  'errSlotContentEmpty': 'slot "{slot}"의 content/가 비어 있음',
  'errSlotSchema': 'slot "{slot}"의 manifest.schemaVersion은 1이어야 함',
  'errSlotIdMissing': 'slot "{slot}"의 manifest.id가 없음',
  'errSlotIdConflict': 'slot "{slot}"의 id가 최상위 패키지 id와 충돌함',
  'errSlotNestedTimed': 'slot "{slot}"에 타이머 유형을 중첩할 수 없음',
  'errSlotTypeInvalid': 'slot "{slot}"의 type은 video/html/depth여야 함. 실제: {type}',
  'errSlotEntryMissing': 'slot "{slot}"의 manifest.entry가 없음',
  'errSlotEntryNotFound': 'slot "{slot}"의 entry "{entry}"가 존재하지 않음',
  'errSlotManifestUnreadable': 'slot "{slot}"의 manifest.json 분석 실패: {error}',
  'errScheduleJson': 'schedule.json이 유효한 JSON이 아님: {error}',
  'errScheduleTopLevel': 'schedule.json의 최상위는 객체여야 함',
  'errScheduleRules': 'schedule.rules는 배열이어야 함',
  'errRuleNotObject': 'rules[{index}]는 객체여야 함',
  'errRuleFrom': 'rules[{index}].from은 HH:mm이어야 함. 실제: {value}',
  'errRuleTo': 'rules[{index}].to는 HH:mm이어야 함. 실제: {value}',
  'errRuleWallpaper': 'rules[{index}].wallpaper는 비어 있지 않은 문자열이어야 함',
  'errDefaultString': 'default는 문자열이어야 함',
  'warnVideoCodec':
      '이 동영상의 코덱은 일부 휴대폰에서 지원되지 않을 수 있습니다. '
      '배경화면이 정지 화면으로 표시될 수 있으니 H.264/H.265 동영상을 권장합니다.',
  'warnVideoDecodeLimit':
      '이 동영상의 해상도/프레임률이 이 기기의 디코딩 능력을 초과합니다. '
      '미리보기와 배경화면은 정지된 첫 프레임으로 표시됩니다.',

  // ---- 네트워크 / API ----
  'errSessionIncomplete': '서버가 반환한 세션 데이터가 불완전함',
  'errTicketIncomplete': '서버가 반환한 다운로드 티켓이 불완전함',
  'errCannotConnect': '서버에 연결할 수 없음: {error}',
  'errRequestFailed': '요청 실패: {error}',
  'errResponseReadFailed': '응답을 읽을 수 없음: {error}',
  'errorDetailSeparator': ': ',
  'errDownloadHttp': '다운로드 실패(HTTP {code}){body}',
  'errCatalogLoad': '카탈로그를 불러오지 못함: {error}',
  'errLoadMore': '더 불러오지 못함: {error}',
  'errWallpaperDownloading': '이 배경화면은 이미 다운로드 중임',
  'errEndpointInvalid': '전체 주소를 입력하세요(예: https://api.example.com)',
  'errOperationFailed': '작업 실패: {error}',
  'errSizeUnknown': '크기 알 수 없음',

  // ---- manifest 사유 ----
  'reasonMustBeObject': '객체여야 함',
  'reasonRequiredString': '필수이며 비어 있지 않은 문자열이어야 함. 실제: {value}',
  'reasonMustBeString': '문자열이어야 함. 실제: {value}',
  'reasonRequiredInt': '필수이며 정수여야 함. 실제: {value}',
  'reasonMustBeInt': '정수여야 함. 실제: {value}',
  'reasonMustBeNumber': '숫자여야 함. 실제: {value}',
  'reasonConfigObject': 'config[{index}]는 객체여야 함',
  'reasonConfigKey': 'config[{index}].key는 필수이며 문자열이어야 함',
  'reasonConfigType': 'config[{index}].type은 float/int/bool/color 중 하나여야 함. 실제: {type}',
  'reasonDefaultFloat': 'float 매개변수의 default는 숫자여야 함',
  'reasonDefaultInt': 'int 매개변수의 default는 정수여야 함',
  'reasonDefaultBool': 'bool 매개변수의 default는 불리언이어야 함',
  'reasonDefaultColor': 'color 매개변수의 default는 #RRGGBB(AA)여야 함',
  'reasonMinMax': 'min > max',
  'reasonCapabilitiesObject': '객체여야 함',
  'reasonStringArray': '문자열 배열이어야 함',
  'reasonElementString': '요소는 문자열이어야 함. 실제: {value}',
  'reasonSchemaOnly1': '현재 1만 지원함. 실제: {value}',
  'reasonIdCharset': '영문/숫자/점/밑줄만 허용되며 "." 또는 ".."는 허용되지 않음. 실제: {value}',
  'reasonSemver': '시맨틱 버전(예: 1.0.0)이어야 함. 실제: {value}',
  'reasonTypeOneOf': 'video/html/depth/timed 중 하나여야 함',
  'reasonPerformanceHint': 'low/medium/high 중 하나여야 함. 실제: {value}',
  'reasonConfigArray': '배열이어야 함',
  'reasonDuplicateKeys': '중복된 key가 있음',
};
