# CloudKit Sync Status Visibility — Design

## Problem

1. **동기화 상태가 거짓으로 보일 수 있음**: `SettingsScreen.swift`의 "iCloud 동기화" 행은 하드코딩된 정적 텍스트(`cloud_done` · "iCloud에 안전하게 보관돼요")라 실제 CloudKit 연결 상태를 전혀 반영하지 않는다. `PersistenceController.makeAppContainer()`가 CloudKit 초기화에 실패해 로컬 전용 저장소로 조용히 폴백해도, 설정 화면은 계속 iCloud가 정상 동작하는 것처럼 보여준다.
2. **재설치 직후 복원 대기 상태에 대한 피드백 없음**: 앱을 지웠다 다시 깔면 CloudKit이 백그라운드에서 기존 데이터를 비동기로 임포트한다(수 초~수 분 소요). 이 동안 대시보드는 그냥 "거래 0건"으로 보여서, 사용자가 "복원 중"과 "데이터가 원래 없음"을 구분할 방법이 없다.
3. **커스텀 카테고리 중복 병합 미지원**: `CategorySeeder.reconcileDuplicateDefaults`는 기본 8개 카테고리의 이름 중복만 병합한다. 여러 기기가 CloudKit으로 병합될 때 사용자가 만든 커스텀 카테고리가 같은 이름으로 중복 생성되는 경우는 처리하지 않는다.
4. **삭제 전 백업 확인 수단 없음**: 사용자가 데이터를 정리하다가 앱을 지워야 할 때, 로컬 변경사항이 iCloud에 다 업로드됐는지 확인할 방법이 없다.

## Non-Goals

- CloudKit 직접 쿼리(`CKQuery`)로 서버 전체 레코드 수를 세어 실시간 퍼센티지를 표시하지 않는다 — SwiftData가 내부적으로 사용하는 CloudKit 레코드 타입 네이밍은 공식 문서화된 계약이 아니고, 별도 쿼리는 API 쿼터 낭비이자 실제 임포트 상태와 어긋날 수 있다. 대신 비결정적(indeterminate) 표시만 한다.
- 실행 중인 세션에서 CloudKit을 강제로 즉시 동기화시키는 기능은 만들지 않는다 — 그런 공개 API가 없다. "iCloud 백업 상태 확인" 버튼은 강제 트리거가 아니라 현재 상태 조회다.
- `ModelContainer`를 런타임에 재생성/교체하지 않는다 — SwiftData의 `ModelContainer`는 앱 시작 시 한 번 만들어져 전체 화면 계층에 물려있는 구조라, 계정 상태가 바뀌었다고 컨테이너를 교체하는 건 이번 스코프를 크게 벗어나는 리팩터링이다. `unavailable` 상태에서 사용자가 할 수 있는 건 iCloud 로그인 상태를 확인하는 것뿐이며, 앱을 재시작해야 반영된다는 사실을 문구로 노출하지 않는다(Apple도 이런 지시를 하지 않음 — 계정 변경은 세션 중 자동으로 재개될 수 있다는 전제로 안내만 한다).
- 커스텀 카테고리 병합 시 "이름은 같지만 실제로는 다른 카테고리일 수 있다"는 충돌을 사용자에게 확인받는 UI는 만들지 않는다 — 기존 기본 카테고리 병합과 동일하게 자동·결정적으로 병합한다.

## 1. 공유 상태 모델 — `CloudSyncMonitor`

새 파일 `WadeMoney/Persistence/CloudSyncMonitor.swift`. `@MainActor @Observable` 클래스로, 대시보드 배너와 설정 화면이 동일한 인스턴스를 구독한다.

```swift
enum CloudSyncState {
    case normal
    case importing
    case unavailable
}
```

### 상태 필드

- `private(set) var state: CloudSyncState`
- `private(set) var pendingExport: Bool = false` — 로컬 변경사항이 아직 iCloud로 업로드되지 않았으면 `true`.

### 초기화

```swift
init(cloudKitEnabled: Bool, hasExistingData: Bool)
```

- `cloudKitEnabled == false` → `state = .unavailable` (App Group/CloudKit 컨테이너 생성 자체가 실패한 경우, `PersistenceController`가 로컬 전용으로 폴백했을 때)
- `cloudKitEnabled == true` && `FileManager.default.ubiquityIdentityToken == nil` → `state = .unavailable` (iCloud 계정에 로그인되어 있지 않음 — Apple이 공식 제공하는 동기 확인 방법. 컨테이너 생성 자체는 로그인 여부와 무관하게 보통 성공하므로 이 체크가 별도로 필요하다)
- 위 두 경우가 아니고 `hasExistingData == false` → `state = .importing`
- 그 외(`cloudKitEnabled == true`, 로그인됨, 로컬에 이미 데이터 있음) → `state = .normal`

`hasExistingData`는 호출 측(`WadeMoneyApp.swift`)에서 컨테이너 생성 직후 `context.fetchCount(FetchDescriptor<TransactionModel>()) > 0`로 판단해 넘긴다.

### 이벤트 구독

`cloudKitEnabled == true`이면(초기 상태가 `importing`이든 `normal`이든, 심지어 로그인 안 돼 있어 `unavailable`이든) 앱 세션 내내 `NSPersistentCloudKitContainer.eventChangedNotification`을 구독한다. `cloudKitEnabled == false`(컨테이너 자체가 CloudKit 없이 만들어진 경우)면 애초에 이벤트가 올 수 없으므로 구독하지 않는다.

이렇게 항상 구독해야 하는 이유 두 가지:
- 이미 데이터가 있어 시작부터 `normal`인 사용자(대다수)도 이후의 로컬 변경 → export 이벤트를 계속 추적해야 "iCloud 백업 상태 확인" 버튼(§4)이 의미 있는 값을 준다.
- `unavailable`로 시작했더라도(iCloud 미로그인 등) 세션 중 사용자가 로그인하면 CloudKit이 자동으로 재개되어 import/export 이벤트가 들어올 수 있다 — 이 경우 앱 재시작 없이 `normal`로 자연 복귀한다(Non-Goals에서 언급한 "세션 중 자동 재개" 전제의 근거).

```swift
NotificationCenter.default.addObserver(
    forName: NSPersistentCloudKitContainer.eventChangedNotification,
    object: nil, queue: .main
) { [weak self] note in ... }
```

- `event.type == .import` && `event.endDate != nil` → `state = event.succeeded ? .normal : .unavailable`
- `event.type == .export`: `event.endDate == nil`이면 `pendingExport = true`, `endDate != nil`이면 `pendingExport = (succeeded == false)`(성공하면 대기 해제, 실패하면 계속 대기 중으로 남겨 다음 저장/재시도를 기다림)

이 알림이 SwiftData 컨테이너에서도 실제로 발행되는지는 구현 단계 첫 태스크에서 시뮬레이터로 스파이크 검증한다(Core Data 하부 구조를 공유하므로 발행될 것으로 예상되나, 문서로 보증되지 않음).

## 2. `PersistenceController` / `WadeMoneyApp` 변경

- `PersistenceController.makeAppContainer()`가 `ModelContainer` 단독 반환 대신 아래 구조체를 반환하도록 변경:

```swift
struct AppContainerResult {
    let container: ModelContainer
    let cloudKitEnabled: Bool
}
```

  - App Group 미가용 → `makeLocalContainer()` 결과 + `cloudKitEnabled: false`
  - CloudKit 설정 포함 `ModelContainer` 생성 성공 → `cloudKitEnabled: true`
  - CloudKit 설정 생성 실패해 App Group-only로 폴백 → `cloudKitEnabled: false`
- `WadeMoneyApp.swift`의 `catch` 폴백 경로(`makeLocalContainer()`, `makeInMemoryContainer()`)도 모두 `cloudKitEnabled: false`로 취급한다.
- 컨테이너 확보 후, 카테고리 시드 이전에 `hasExistingData`를 조회하고 `CloudSyncMonitor`를 생성해 `.environment(monitor)`로 씬에 주입한다.
- XCTest 호스트 경로(`makeInMemoryContainer()` 직행)는 `cloudKitEnabled: false, hasExistingData: false`로 모니터를 만들되, 테스트에서는 `CloudSyncMonitor`를 사용하는 화면이 없으므로 사실상 영향 없음.

## 3. 대시보드 배너 — `SyncStatusBanner`

`WadeMoney/Screens/Dashboard/DashboardComponents.swift`에 새 컴포넌트 추가. `DashboardScreen`이 `@Environment(CloudSyncMonitor.self)`로 상태를 읽어 헤더 바로 아래(기존 카드들 위)에 배치한다.

- `state == .normal` → 렌더링 안 함(공간도 차지하지 않음)
- `state == .importing` → 옅은 배경의 한 줄. 아이콘(`cloud_sync`, 정적) + 텍스트 "iCloud에서 가져오는 중" + 뒤에 점 0~3개가 약 0.5초 간격으로 순환하는 애니메이션(`TimelineView(.periodic(from: .now, by: 0.5))` 또는 로컬 `Timer` 기반 `@State private var dotCount: Int`을 0→1→2→3→0으로 순환). 실제 진행 중임을 시각적으로 표현하기 위함이며 진행률 수치는 아니다.
- `state == .unavailable` → 더 옅은(muted) 톤 한 줄: 아이콘 `cloud_off` + "iCloud 동기화 꺼짐"만, 부가 설명 없이 최대한 간결하게.
- 기존 `WadeColors`/`WadeSpacing`/`WadeFont` 토큰만 사용, 새 컬러 토큰 추가 없음.

## 4. 설정 화면 변경

`SettingsScreen.swift`의 "동기화 · 데이터" 섹션(58-62번째 줄 부근)을 상태 기반으로 교체한다. `@Environment(CloudSyncMonitor.self)` 구독.

### iCloud 동기화 행

| state | 아이콘 | 톤 | 문구 |
|---|---|---|---|
| `normal` | `cloud_done` | `WadeColors.good` | "모든 기기에서 최신 상태로 유지돼요" |
| `importing` | `cloud_sync` | `WadeColors.ink2` | "iCloud에서 가져오는 중" + 점 순환 애니메이션(배너와 동일 로직) |
| `unavailable` | `cloud_off` | `WadeColors.ink3` | "iCloud 로그인 상태를 확인해주세요" |

### 새 행: "iCloud 백업 상태 확인"

- `state == .unavailable`이면 행 자체를 탭 불가(비활성 톤)로 표시하고 트레일링에 "확인 불가" — CloudKit이 아예 연결 안 된 상태에서는 조회할 대상이 없음.
- 그 외 상태에서 탭하면 `monitor.pendingExport`를 즉시 읽어 짧은 토스트(기존 `settingsToast` 패턴 재사용)를 띄운다:
  - `pendingExport == false` → "모든 데이터가 iCloud에 안전하게 저장됐어요. 지금 앱을 삭제해도 괜찮아요."
  - `pendingExport == true` → "아직 업로드 중이에요. 네트워크 연결을 확인하고 잠시 후 다시 확인해주세요."
- 강제로 동기화를 트리거하지 않는다(그런 API 없음) — 현재 상태를 즉시 읽어 보여주기만 한다.

## 5. 커스텀 카테고리 중복 병합 확장

`CategorySeeder.swift`의 `reconcileDuplicateDefaults(_:)`를 일반화한다.

- 함수명을 `reconcileDuplicateCategories(_:)`로 변경.
- `defaultNames` 필터(`all.filter { defaultNames.contains($0.name) }`)를 제거하고, 전체 카테고리(`all`)를 이름으로 그룹핑해 2개 이상인 그룹을 모두 병합 대상으로 삼는다. 병합 로직(승자 = id 최솟값, 패자의 거래를 승자로 재연결 후 패자 삭제)은 기존과 동일하게 유지한다.
- 호출부(`WadeMoneyApp.swift`의 `try? CategorySeeder.reconcileDuplicateDefaults(...)`)도 새 함수명으로 갱신.
- 기존 기본 카테고리 병합 동작은 회귀 없이 그대로 커버된다(전체 병합의 부분집합이므로).

## Files (expected)

- `WadeMoney/Persistence/CloudSyncMonitor.swift` (신규)
- `WadeMoney/Persistence/PersistenceController.swift` — `AppContainerResult` 반환 타입 변경
- `WadeMoney/WadeMoneyApp.swift` — 컨테이너 결과 처리, `hasExistingData` 조회, 모니터 생성/주입
- `WadeMoney/Persistence/CategorySeeder.swift` — `reconcileDuplicateDefaults` → `reconcileDuplicateCategories` 일반화
- `WadeMoney/Screens/Dashboard/DashboardComponents.swift` — `SyncStatusBanner` 신규 컴포넌트
- `WadeMoney/Screens/Dashboard/DashboardScreen.swift` — 배너 배치
- `WadeMoney/Screens/Settings/SettingsScreen.swift` — 동기화 행 상태 기반 전환, 백업 확인 행 추가
- 관련 테스트: `WadeMoneyTests/CloudSyncMonitorTests.swift`(신규 — 초기 상태 판정 로직, 이벤트 기반 전이), `WadeMoneyTests/CategorySeederTests.swift`(일반화된 병합 케이스 추가)

## Verification

- `CloudSyncMonitor`의 초기 상태 판정(`cloudKitEnabled` × `ubiquityIdentityToken` × `hasExistingData` 조합)과 이벤트 기반 전이는 순수 로직 위주라 유닛 테스트로 커버 가능(알림 발행을 시뮬레이션).
- `reconcileDuplicateCategories`는 커스텀 카테고리 중복 케이스를 추가해 기존 테스트 패턴대로 검증.
- 구현 첫 태스크: 시뮬레이터에서 `NSPersistentCloudKitContainer.eventChangedNotification`이 SwiftData + CloudKit 컨테이너에서도 실제로 발행되는지 스파이크로 확인(문서로 보증되지 않는 부분이므로 실증 필요). 발행되지 않는 것으로 확인되면 이 스펙의 이벤트 기반 전이 부분을 재설계해야 한다 — 그 경우 구현을 멈추고 사용자에게 보고한다.
- 시뮬레이터 스크린샷으로 대시보드 배너 3상태(정상 시 미표시, importing 시 점 애니메이션, unavailable 시 축약 문구)와 설정 화면 3상태 + 백업 확인 토스트를 확인한다.
