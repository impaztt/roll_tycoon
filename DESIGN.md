# Pastel Park Tycoon — Design (Globe Edition)

> 이전 평면 격자 버전을 폐기하고, **3D 지구본 + 땅 구매 + 놀이공원 건설** 컨셉으로 재정의한 설계서.

## 1. 한 줄 컨셉

**손바닥 위의 파스텔 행성을 굴리며, 한 칸 한 칸 땅을 사 모으고 그 위에 놀이공원을 키워 나만의 나라를 만드는 힐링 타이쿤.**

## 2. 시각적 레퍼런스

| 게임 | 참고 포인트 |
|---|---|
| **Abyssrium** | 부드러운 파스텔 구체, glow, 캐릭터 중심 힐링 톤 |
| **My Oasis** | 작은 행성/섬을 키우는 ASMR 감성, 부드러운 입자 |
| **Google Earth** | 지구본 회전, 줌인/줌아웃, 위치 선택 UX |
| **RollerCoaster Tycoon 1/2** | 줌인 후 평면 위 시설 배치, 아이소메트릭 |

## 3. 핵심 게임 루프

```
지구본을 굴려 마음에 드는 빈 땅 발견
→ 코인 모아서 그 땅 구매
→ 줌인 → 평평해진 땅 위에 놀이공원 건설
→ 손님이 와서 코인/추억 점수 적립
→ 다음 땅 구매 자금 마련
→ 줌아웃 → 자라나는 나의 나라 감상
→ 반복
```

작은 단위 루프(놀이공원 운영)는 기존 §10–§15와 같지만,
**상위 컨테이너가 "나의 나라(행성)"** 라는 점이 결정적 차이.

## 4. 게임의 두 화면

### 4.1 GLOBE VIEW — 나의 행성

- 3D 구체가 화면 중앙에 떠있고, 부드러운 atmosphere glow
- 드래그로 회전 (관성)
- 핀치로 줌
- 구체 표면에는 ~20개의 **Parcel(땅)** 이 헥사 패턴으로 배치
- 각 땅은 **Biome**(스위트 가든 / 구름 / 숲 / 바다 / 별빛 등)을 가짐
- 잠긴 땅: 흐릿한 회색 + 자물쇠 아이콘
- 보유 땅: 바이옴 색 + 작은 시설 실루엣 미리보기
- 탭하면 해당 땅이 화면 정면을 향해 자동 회전 후 "줌인" 시작

### 4.2 PARCEL VIEW — 놀이공원 건설/운영

- 줌인 transition 끝나면 평평한 땅이 isometric 뷰로 표시됨
- 땅 가장자리는 절벽 + 구름/바다로 fade out — "행성 위" 느낌 유지
- 그 위에 RCT-스타일 시설 배치 (격자 + 아이소메트릭)
- 손님 AI, 청소부, 시설 수익 등 모든 기존 시뮬레이션은 여기서 작동
- 좌상단 "← 행성으로" 버튼으로 globe view 복귀

## 5. 데이터 구조 (도메인)

```
Country (= 행성, 플레이어 1명 = 1나라)
 ├─ name
 ├─ level
 ├─ currency (coin / gem / heart) — 나라 단위
 ├─ memoryScore (전체 평균)
 └─ parcels: [Parcel]

Parcel (= 행성 위 한 칸의 땅)
 ├─ id
 ├─ lat, lon  (구체 위 위치)
 ├─ biome (sweetGarden / cloud / forest / ocean / starlight / ...)
 ├─ isOwned
 ├─ purchaseCost
 └─ park: Park?  (소유한 경우만)

Park (= 한 parcel의 놀이공원, 기존 시뮬레이션 그대로)
 ├─ tiles[][]
 ├─ facilities[]
 ├─ guests[]
 ├─ staff[]
 ├─ trash[]
 ├─ satisfaction, cleanliness, memoryScore (parcel 단위)
 └─ ...
```

## 6. 진행 시스템

### 6.1 첫 5분 (튜토리얼)

```
1. 행성이 천천히 회전하며 등장 (낮은 BGM)
2. 루미: "여기는 당신만의 작은 행성이에요. 첫 번째 땅을 받아볼게요."
3. 사용자가 빛나는 땅 탭 → 자동 줌인
4. 평면 위에 회전목마 1개 무료 배치 → 손님 입장
5. 첫 코인 적립 → "더 큰 나라를 만들려면 다음 땅을 사보세요."
6. 줌아웃 → 다음 땅의 가격 표시
```

### 6.2 땅 구매 곡선

| 보유 땅 수 | 다음 땅 비용 |
|---:|---:|
| 1 | 무료 (튜토 + 첫 땅) |
| 2 | 2,000 |
| 3 | 6,000 |
| 4 | 15,000 |
| 5 | 35,000 |
| 6 | 80,000 |
| ... | `1500 × pow(2.4, n-2)` |

### 6.3 바이옴 효과 (MVP는 시각만, v1+에서 게임 효과)

| Biome | 색감 | 효과 (v1+) |
|---|---|---|
| Sweet Garden | 핑크/크림 | 가족·어린이 손님 +20% |
| Cloud | 파스텔 블루/화이트 | 야간 매출 보정, 대관람차 시너지 |
| Forest | 민트/세이지 | 피로도 -, 시니어 손님 + |
| Ocean | 스카이/터쿠아즈 | 여름 시즌 +, 워터 시설 해금 |
| Starlight | 라벤더/딥블루 | 야간 만족도 +, 커플 손님 + |

## 7. 시각/렌더링 가이드

### 7.1 Globe view

- **구체**: 라디얼 그라디언트 (중앙 밝은 민트 → 가장자리 진한 라벤더)
- **Atmosphere**: 외곽에 1.15x 반경의 반투명 glow ring
- **Parcels**: 각 위치에서 작은 둥근 hex/패치, 바이옴 색
- **Owned parcel marker**: 작은 회전목마/관람차 silhouette 미니어처
- **Locked parcel marker**: 회색 + 자물쇠
- **Background**: 위→아래 그라디언트 (별빛 우주 느낌, 어두운 라벤더)
- **Particles**: 작은 별/입자가 천천히 떠다님

### 7.2 Parcel view

- **Isometric 투영** (30도 다이아몬드 타일)
- **타일**: 그라디언트 잔디 (밝→어두운 민트), 사이에 아주 옅은 실선
- **시설**: 박스+지붕 isometric 도형 + 그라디언트 + soft drop shadow
- **가장자리 fade**: 땅 바깥은 구름/하늘 fade — 행성 위라는 느낌
- **Background**: 하늘색→복숭아색 sunset 그라디언트
- **Guests/Staff**: 작은 둥근 캡슐 + 두 점 눈 (도트가 아닌 vector shape)

### 7.3 색상 (이전과 동일)

| 용도 | 색상 |
|---|---|
| Primary | 파스텔 민트 `#A8E6CF` |
| Secondary | 라벤더 `#CDB4F6` |
| Accent | 피치 코랄 `#FFB5A7` |
| Premium | 부드러운 골드 `#F6D689` |
| Sky | 라이트 스카이 `#A8D8EA` |
| Atmosphere | 라벤더 글로우 `#D9C9F6` (반투명) |

## 8. 기술 구조 (Flutter only, MVP)

```
lib/
 ├─ app/                 # theme, root app
 ├─ core/                # constants, utils, math (3d projection)
 ├─ features/
 │  ├─ country/          # 나라 = 행성 도메인 + state
 │  ├─ globe/            # 3D globe view + 회전/줌 transition
 │  ├─ parcel/           # 한 parcel의 isometric view
 │  ├─ park/             # 기존 시뮬레이션 (parcel 안에서 작동)
 │  ├─ construction/     # build mode (재사용)
 │  ├─ guest/, staff/, economy/, report/   # 기존 그대로
 └─ shared/widgets/
```

**3D 렌더링**:
- 별도 3D 엔진 없이 **CustomPainter + 직접 3D 수학** 으로 시작
- Sphere = 라디얼 그라디언트 원
- Parcel position = lat/lon → 3D Cartesian → 회전 매트릭스 → 2D 투영
- 후면 뒤집힘 처리 (z<0이면 안 그림 + 보이는 면만 fade)
- 충분히 부드러우면 그대로, 부족하면 향후 `flutter_scene` 또는 Unity 연동

## 9. 우선순위와 절단선

**MVP (지금 짜는 것)**
- 회전하는 globe view + 20개 parcel 배치
- Parcel 클릭 → 줌인 transition → parcel view
- Parcel view: isometric 격자 + 시설 배치 + 손님/청소부/수익 (기존 시뮬레이션 재사용)
- 첫 parcel 무료, 나머지는 코인으로 구매
- 나라 단위 currency, 나라 panel

**v1 (다음)**
- 바이옴별 게임 효과 (손님 선호 등)
- 단골 손님 시스템 (§60)
- 파크 인사이트 리포트 — 문제 TOP 3 + 추천 액션
- 튜토리얼 시퀀스

**v2+**
- 은행/대출, 투자
- 시즌/이벤트
- 롤러코스터 커스텀
- Unity 연동으로 진짜 3D 모델

## 10. 폐기된 것

- 평면 20×20 top-down grid (단일 공원)
- Emoji 기반 시설/손님 표현
- "Park" 단일 컨테이너 — 이제 country.parcels[i].park 으로 nested

기존 simulation/economy/staff/guest 도메인 코드는 유지·재배선되어 parcel 안에서 그대로 돌아간다. UI 레이어와 컨테이너 구조만 바뀌었다.
