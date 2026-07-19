import fs from 'node:fs/promises';
import { SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const outputDir = 'C:/Users/HsNT/CodexWorkFile/B4Y/outputs/optimization_review';
await fs.mkdir(outputDir, { recursive: true });

const workbook = Workbook.create();
const sheet = workbook.worksheets.add('최적화 점검표');
sheet.showGridLines = false;

sheet.mergeCells('A1:F1');
sheet.getRange('A1').values = [['B4Y 코드 최적화 점검표']];
sheet.mergeCells('A2:F2');
sheet.getRange('A2').values = [[
  '현재 코드를 기준으로 정리한 검토 목록입니다. 아직 코드 수정은 반영하지 않았습니다.',
]];

sheet.getRange('A4:F4').values = [[
  '우선순위',
  '영역',
  '코드 위치',
  '확인된 문제',
  '왜 최적화가 필요한가',
  '권장 검토 방향',
]];

sheet.getRange('A5:F19').values = [
  ['매우 높음', '메인 모드 전환', 'home_screen.dart:1169, 1236, 1280', '사진·미션 모드 진입 시 노선별·관광지별 Firestore 스트림을 여러 개 구독', '모드 전환 순간 다수의 네트워크 요청과 rebuild가 발생해 랙과 초기 로딩 지연이 생길 수 있음', '선택된 노선 또는 현재 화면에 필요한 데이터만 구독하고, 공통 데이터는 상위에서 한 번만 로드'],
  ['매우 높음', '지도 WebView', 'kakao_map_view.dart:108, 166', '마커나 폴리라인이 바뀔 때 카카오 지도 HTML 전체를 loadHtmlString으로 다시 로드', '지도 WebView 재초기화는 단순 마커 갱신보다 훨씬 무거워 모드 전환 랙의 핵심 원인이 될 가능성이 높음', '지도 인스턴스는 유지하고 JavaScript로 마커·폴리라인만 갱신'],
  ['높음', 'Firestore N+1 조회', 'gallery_repository.dart:47, engagement_repository.dart:81, 132', '사진·리뷰·미션 문서마다 사용자의 좋아요/인증 반응을 별도 하위 문서로 조회', '문서 20개를 읽으면 반응 조회가 추가로 최대 20번 발생할 수 있음', '목록 문서에 요약 반응 상태를 포함하거나 사용자 반응을 묶어서 조회'],
  ['높음', 'Provider 생명주기', 'b4y_providers.dart:487, 507, 591', 'StreamProvider.family에 autoDispose가 없음', '동적으로 생성된 노선·관광지별 스트림이 화면을 나가도 오래 유지될 수 있어 메모리와 Firestore listener가 누적될 가능성이 있음', '화면 수명에 맞춰 autoDispose를 검토하고 캐시가 필요한 데이터만 별도 보존'],
  ['높음', '지도 데이터 재계산', 'b4y_providers.dart:375', 'buildRouteMapOverlay가 노선마다 관광지·사진 클러스터·정류장을 반복 검색', '데이터가 많아지면 지도 rebuild마다 전체 데이터를 다시 순회하게 됨', '정류장·관광지·클러스터를 ID 기반 인덱스로 만들고 오버레이를 캐시'],
  ['높음', '홈 화면 카드 계산', 'home_screen.dart:378, 980', '노선 카드마다 _touristSpotsForRoute가 방향별 지도 오버레이를 다시 생성', '단순 카드 표시에도 지도용 계산이 반복되어 스크롤과 모드 변경 비용이 커짐', '노선별 관광지 목록을 provider 또는 메모이제이션 결과로 재사용'],
  ['높음', '이미지 저장 방식', 'image_data_url.dart:10, gallery_repository.dart:77', '이미지를 Base64 Data URL로 Firestore 문서에 저장', '문서 크기가 커지고 읽기·쓰기·메모리 사용량이 증가하며 Firestore 문서 크기 제한에도 가까워질 수 있음', 'Cloud Storage에 원본을 저장하고 Firestore에는 URL과 메타데이터만 저장'],
  ['중간', '이미지 렌더링', 'photo_thumb.dart:23', '위젯 rebuild마다 Base64를 다시 decode', '같은 사진을 다시 그릴 때 문자열 처리와 바이트 배열 생성이 반복됨', '디코딩 결과를 캐시하고 표시 크기에 맞춘 이미지 해상도를 사용'],
  ['중간', '네트워크 이미지 캐시', 'pubspec.yaml, photo_thumb.dart:27', 'cached_network_image 패키지는 설치되어 있지만 Image.network를 사용', '갤러리·지도·상세 화면에서 이미지가 반복 요청되거나 이미지 로딩 제어가 제한됨', '공통 이미지 위젯에서 네트워크 캐시·placeholder·재시도 정책을 통일'],
  ['중간', '갤러리 업로드', 'gallery_upload_screen.dart:115', '여러 사진을 await로 한 장씩 순차 저장', '사진 수가 늘어나면 업로드 전체 시간이 사진 개수만큼 선형 증가', '검증 후 병렬 처리 또는 Firestore batch를 사용하고 실패 항목을 별도 표시'],
  ['중간', '입력 중 전체 rebuild', 'mission_compose_screen.dart:140, home_screen.dart:694', '텍스트 입력 이벤트마다 부모 화면 전체에 setState', '입력할 때마다 지도·목록·검색 결과까지 다시 build될 수 있음', '입력 상태와 결과 목록을 분리하고 debounce 또는 ValueListenableBuilder 사용'],
  ['중간', '리뷰 사진 조회', 'engagement_repository.dart:421', '리뷰 목록을 읽을 때 리뷰마다 photos 하위 컬렉션을 별도 조회', '리뷰 수가 많을수록 화면 진입 시 읽기 횟수와 대기 시간이 증가', '목록용 썸네일만 문서에 두고 상세 진입 시 원본을 지연 조회'],
  ['중간', '검색·경로 계산', 'b4y_providers.dart:764', '환승 후보 계산이 노선·방향 조합을 중첩 순회', '노선 수가 늘어나면 계산량이 급격히 증가할 수 있음', '정류장 ID를 인덱싱하고 후보를 거리·공통 정류장 기준으로 먼저 줄임'],
  ['낮음', '파일 구조', 'home_screen.dart 2,376줄, mission_compose_screen.dart 1,607줄', '한 화면에 상태·지도·검색·카드·유틸리티가 집중', '직접적인 성능 문제는 아니지만 rebuild 범위를 분리하기 어렵고 향후 최적화 비용이 커짐', '지도·목록·검색·카드·상태 로직을 기능 단위로 분리'],
  ['낮음', 'API 초기 로딩', 'b4y_repository.dart:25', 'API 사용 시에도 먼저 fallback asset 데이터를 읽음', '시작 시 불필요한 JSON 파싱과 메모리 사용이 추가됨', 'fallback이 필요한 경우에만 지연 로드하고 API 성공 경로에서는 중복 로딩을 줄임'],
];

sheet.getRange('A1:F1').format = {
  fill: '#1F4E78',
  font: { bold: true, color: '#FFFFFF', size: 16 },
  horizontalAlignment: 'center',
  verticalAlignment: 'center',
};
sheet.getRange('A2:F2').format = {
  fill: '#D9EAF7',
  font: { color: '#404040', italic: true },
  wrapText: true,
};
sheet.getRange('A4:F4').format = {
  fill: '#5B9BD5',
  font: { bold: true, color: '#FFFFFF' },
  horizontalAlignment: 'center',
  verticalAlignment: 'center',
  wrapText: true,
  borders: { preset: 'all', style: 'thin', color: '#B7C9D6' },
};
sheet.getRange('A5:F19').format = {
  verticalAlignment: 'top',
  wrapText: true,
  borders: { preset: 'inside', style: 'thin', color: '#D9E2F3' },
};
sheet.getRange('A5:A19').format = { horizontalAlignment: 'center', font: { bold: true } };
sheet.getRange('B5:C19').format = { font: { color: '#1F1F1F' } };
sheet.getRange('A5:A6').format.fill = '#F4CCCC';
sheet.getRange('A7:A11').format.fill = '#FCE4D6';
sheet.getRange('A12:A16').format.fill = '#FFF2CC';
sheet.getRange('A17:A19').format.fill = '#E2F0D9';

sheet.getRange('A1:F1').format.rowHeight = 30;
sheet.getRange('A2:F2').format.rowHeight = 28;
sheet.getRange('A4:F4').format.rowHeight = 34;
sheet.getRange('A5:F19').format.rowHeight = 58;
sheet.getRange('A:A').format.columnWidth = 12;
sheet.getRange('B:B').format.columnWidth = 18;
sheet.getRange('C:C').format.columnWidth = 32;
sheet.getRange('D:D').format.columnWidth = 42;
sheet.getRange('E:E').format.columnWidth = 48;
sheet.getRange('F:F').format.columnWidth = 44;
sheet.freezePanes.freezeRows(4);
sheet.tables.add('A4:F19', true, 'OptimizationReviewTable');

const inspect = await workbook.inspect({
  kind: 'table',
  sheetId: '최적화 점검표',
  range: 'A1:F19',
  include: 'values,formulas',
  tableMaxRows: 20,
  tableMaxCols: 8,
  maxChars: 6000,
});
console.log(inspect.ndjson);

const errors = await workbook.inspect({
  kind: 'match',
  searchTerm: '#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A',
  options: { useRegex: true, maxResults: 100 },
  summary: 'formula error scan',
});
console.log(errors.ndjson);

const preview = await workbook.render({
  sheetName: '최적화 점검표',
  range: 'A1:F19',
  scale: 1,
  format: 'png',
});
await fs.writeFile(`${outputDir}/optimization_review_preview.png`, new Uint8Array(await preview.arrayBuffer()));

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(`${outputDir}/B4Y_코드_최적화_점검표.xlsx`);
console.log(`saved: ${outputDir}/B4Y_코드_최적화_점검표.xlsx`);
