# OMX Bimanual Book OCR (2026-08-26)

양팔형 OpenMANIPULATOR-X 프로젝트에서 사용하는 책등 검출·OCR 부분만 분리한
중간 확인용 저장소입니다. Orbbec 카메라의 ROS 2 영상을 받아 YOLOv8-OBB로
책등 바운딩박스를 찾고, EasyOCR로 입력한 책 제목을 검색합니다.

## 포함 범위

- `publish_book_detection_view.py`: ROS 영상 구독, YOLO OBB 검출, OCR 및 제목 매칭
- `view_book_detection.py`: 결과 영상 OpenCV 뷰어
- `models/book_spine_detector.pt`: 책등 검출 모델
- `scripts/run_detection_view.sh`: 양팔 프로젝트용 실행 환경과 파라미터
- `scripts/check_detection_topic.sh`: 결과 토픽/FPS 확인

로봇 팔 제어, 텔레오퍼레이션, 학습, rosbag 기록 코드는 포함하지 않습니다.

## 전제 조건

- Ubuntu 22.04 / ROS 2 Humble
- Orbbec ROS 2 카메라 드라이버가 빌드되어 있음
- `/opt/ros/humble/setup.bash` 존재
- Orbbec workspace가 기본적으로 `~/orbbec_ws`에 있음
- 카메라 영상 토픽: `/camera2/color/image_raw`
- 기본 ROS domain: `31`

Orbbec workspace가 다른 위치라면 실행 시 `ORBBEC_WS`를 지정할 수 있습니다.

## 설치

```bash
git clone https://github.com/higging-good/OMX_BimanuAI_book_ocr_8_26.git
cd OMX_BimanuAI_book_ocr_8_26
./scripts/install.sh
```

설치 스크립트는 `.venv`를 만들고 CPU용 PyTorch, EasyOCR, Ultralytics와
OpenCV를 설치합니다. ROS 패키지(`rclpy`, `cv_bridge`, `sensor_msgs`)는 시스템의
ROS 2 설치본을 사용합니다.

## 실행

먼저 Orbbec 드라이버에서 `camera2` 영상을 발행한 뒤 실행합니다.

```bash
source /opt/ros/humble/setup.bash
source ~/orbbec_ws/install/setup.bash
ros2 topic echo /camera2/color/image_raw --once

./scripts/run_detection_view.sh "찾을 책 제목"
```

제목을 생략하면 실행기가 입력을 요청합니다.

```bash
./scripts/run_detection_view.sh
```

결과는 다음 토픽에 발행됩니다.

- `/book_detection/image_raw`
- `/book_detection/image_raw/compressed`

```bash
./scripts/check_detection_topic.sh
```

## 목표 책 매칭 결과 확인

`/book_detection/target_match`는 기존 OCR 확정 조건을 만족할 때
`std_msgs/msg/String`으로 JSON을 발행합니다. OCR 실행기와 같은 ROS 도메인에서
확인합니다.

```bash
source /opt/ros/humble/setup.bash
ROS_DOMAIN_ID=31 ros2 topic echo /book_detection/target_match std_msgs/msg/String
```

메시지에는 `target_title`, `recognized_text`, `score`,
`image_stamp`(`sec`, `nanosec`)가 포함됩니다. `image_stamp`는 OCR에
사용한 카메라 프레임의 시각입니다. Nav2 연동 노드는 베이스가 정지한 시점
이후에 촬영된 프레임인지와 요청한 제목이 일치하는지 확인한 뒤 이 결과를
팔 작업 시작 조건으로 사용할 수 있습니다. 시각 비교에는 카메라와 작업
관리 노드가 공유하는 시계가 필요합니다.

## 양팔 프로젝트 기본 튜닝값

| 환경변수 | 기본값 | 설명 |
|---|---:|---|
| `BOOK_CAMERA_TOPIC` | `/camera2/color/image_raw` | OCR 입력 카메라 |
| `ROS_DOMAIN_ID` | `31` | 양팔 프로젝트 ROS domain |
| `BOOK_CONFIDENCE` | `0.40` | OBB 검출 임계값 |
| `BOOK_FPS` | `8` | 결과 발행 FPS |
| `BOOK_YOLO_INTERVAL` | `0.25` | YOLO 실행 간격(초) |
| `BOOK_OCR_INTERVAL` | `0.5` | OCR 실행 간격(초) |
| `BOOK_OCR_CANDIDATES` | `2` | 주기당 OCR 후보 수 |
| `BOOK_TORCH_THREADS` | `2` | CPU Torch thread 수 |
| `BOOK_MIN_MATCH` | `0.80` | 목표 제목 최소 유사도 |

다른 카메라 토픽으로 확인할 때는 다음처럼 덮어쓸 수 있습니다.

```bash
BOOK_CAMERA_TOPIC=/camera1/color/image_raw ./scripts/run_detection_view.sh "책 제목"
```

## 표시 의미

- 초록색 OBB: 검출된 일반 책
- 빨간색 OBB: OCR 문자열이 목표 제목과 일치한 책
- 뷰어에서 `q`: 종료
