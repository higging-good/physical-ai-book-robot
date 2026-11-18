# 새 PC에서 양팔 ACT·책 OCR·Nav2 실행하기

현재 양팔 구성은 Ubuntu 22.04 / ROS 2 Humble 호스트에서 Astra 카메라와 OCR을 실행하고, Docker의 ROS 2 Jazzy에서 양팔 제어와 Physical AI를 실행합니다. 양팔 프로젝트의 ROS 도메인은 31이고 RMW는 Fast DDS입니다. 현재 학습 설정과 Compose는 NVIDIA CUDA를 사용하며 서버 빌드는 amd64용입니다. 아래 절차는 이 구성을 기준으로 합니다.

## 0. 화면과 터미널 열기

1. Ubuntu 바탕화면에서 왼쪽 아래 **앱 표시**를 누르고 **Terminal**을 검색해 엽니다. `Ctrl+Alt+T`로도 열 수 있습니다.
2. 터미널에서 명령을 붙여넣을 때는 `Ctrl+Shift+V`, 실행할 때는 `Enter`를 누릅니다. 새 터미널 탭은 `Ctrl+Shift+T`로 엽니다.
3. 브라우저에서 팀 GitHub 저장소를 엽니다. 파일 목록 위의 초록색 **Code** → **Local** → **HTTPS**를 누르고 주소 옆 복사 버튼을 누릅니다. 비공개 저장소는 접근 권한이 있는 GitHub 계정으로 로그인합니다. [GitHub 저장소 복제 안내](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository#cloning-a-repository)
4. Ubuntu 터미널에 아래 명령을 붙여넣어 기본 도구를 설치합니다. `sudo`에서 암호를 입력하면 화면에는 글자가 표시되지 않습니다.

```bash
sudo apt update
sudo apt install git python3-venv usbutils
```

## 1. 코드와 외장 SSD 준비

터미널에서 아래 명령을 실행하고, `GitHub 주소:`가 나오면 복사한 주소를 붙여넣습니다.

```bash
read -r -p "GitHub 주소: " PHYSICAL_AI_REPO_URL
git clone --recurse-submodules "$PHYSICAL_AI_REPO_URL" "$HOME/physical_ai_tools"
cd ~/physical_ai_tools
git submodule status
```

현재 LeRobot 커밋은 `989f3d05ba47f872d75c587e76838e9cc574857a`입니다. 팀 배포본의 폴더 구조는 다음과 같습니다. OCR의 책등 검출 모델은 OCR 폴더 아래에, ANG의 양팔 ACT 모델은 SSD에 둡니다.

```text
~/physical_ai_tools/
  docs/new-pc-guide.md
  deployment/ANG-training-SHA256SUMS.txt
  docker/
  lerobot/
  omx_bimanual_book/
  OMX_BimanuAI_book_ocr_8_26/models/book_spine_detector.pt
  physical_ai_server/config/omx_bimanual_config.yaml
```

SSD를 연결하고 Ubuntu의 **파일** 앱에서 왼쪽에 뜬 SSD 이름을 클릭합니다. 아래 첫 명령으로 마운트 경로를 확인하고, 둘째 줄의 예시를 실제 경로로 바꿔 실행합니다. 경로 양쪽 따옴표는 그대로 둡니다.

```bash
ls -1 "/media/$USER"
export EXTERNAL_DRIVE_MOUNT="/media/사용자/외장SSD"
mountpoint "$EXTERNAL_DRIVE_MOUNT"
test -f "$EXTERNAL_DRIVE_MOUNT/physical_ai/cache/lerobot/YERI84/ANG/meta/info.json"
test -f "$EXTERNAL_DRIVE_MOUNT/physical_ai/models/train/ANG/checkpoints/050000/pretrained_model/model.safetensors"
```

SSD의 `physical_ai` 아래에 다음 구조를 유지합니다.

| 경로 | 용도 |
|---|---|
| `datasets/` | 수집 파일용 컨테이너 마운트 |
| `cache/lerobot/YERI84/ANG/{meta,data,videos}/` | ANG 학습 데이터셋 57개 에피소드 |
| `models/train/ANG/checkpoints/050000/pretrained_model/` | 추론 가중치와 학습 설정 |
| `models/train/ANG/checkpoints/050000/training_state/` | 50,000스텝부터 이어서 학습할 때 필요한 상태 |

추론 압축 파일로 복구할 경우 압축을 푼 폴더에서 `sha256sum -c SHA256SUMS`를 실행한 뒤 `pretrained_model`을 위 체크포인트 위치에 복사합니다. 인증 토큰은 팀 저장소에 올리지 않고 새 PC에서 필요한 계정으로 로그인합니다.

ANG 학습 데이터와 체크포인트를 이전한 뒤 원본 파일과 같은지 확인합니다.

```bash
cd "$EXTERNAL_DRIVE_MOUNT/physical_ai"
sha256sum --quiet -c "$HOME/physical_ai_tools/deployment/ANG-training-SHA256SUMS.txt"
cd "$HOME/physical_ai_tools"
```

## 2. 새 PC 환경 확인

1. **Ubuntu 버전 확인** — 화면 오른쪽 위 시스템 메뉴 → **설정** → **정보**에서 운영 체제 버전을 확인합니다. 아래 절차는 Ubuntu 22.04와 `x86_64`를 기준으로 합니다.
2. **ROS 2 Humble 설치** — 공식 페이지를 열고 **Setup Sources**, **Install ROS 2 packages** 순서로 진행합니다. 패키지 선택 단계에서 `ros-humble-desktop`을 선택합니다. [ROS 2 Humble Ubuntu 설치](https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debians.html)
3. **Docker 설치** — 공식 페이지의 **Install using the apt repository**를 클릭해 저장소 추가, 패키지 설치, `hello-world` 실행까지 진행합니다. 아래 프로젝트 명령은 현재 사용자로 Docker를 실행할 수 있어야 합니다. [Docker Engine 설치](https://docs.docker.com/engine/install/ubuntu/#install-using-the-apt-repository) · [Docker 사용자 설정](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user)
4. **NVIDIA 설치** — Ubuntu에서 **소프트웨어 및 업데이트** → **추가 드라이버**를 열어 지원되는 NVIDIA 드라이버를 설치하고 재부팅합니다. `nvidia-smi`가 GPU 이름을 보여주면 NVIDIA 공식 문서에서 **With apt: Ubuntu, Debian**을 따라 Container Toolkit을 설치하고 **Configuring Docker**를 진행합니다. [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
5. **Orbbec 카메라 드라이버 설치** — 아래 명령으로 기존 PC에서 확인한 버전을 빌드합니다. [Orbbec 드라이버 소스 및 설치 문서](https://github.com/orbbec/OrbbecSDK_ROS2/tree/c780bc110826536500dd706baa1eca8392ed39cb)

```bash
source /opt/ros/humble/setup.bash
sudo apt install python3-colcon-common-extensions libgflags-dev nlohmann-json3-dev \
  ros-humble-image-transport ros-humble-image-transport-plugins \
  ros-humble-compressed-image-transport ros-humble-image-publisher \
  ros-humble-camera-info-manager ros-humble-diagnostic-updater \
  ros-humble-diagnostic-msgs ros-humble-statistics-msgs ros-humble-backward-ros libdw-dev
mkdir -p "$HOME/orbbec_ws/src"
git clone https://github.com/orbbec/OrbbecSDK_ROS2.git "$HOME/orbbec_ws/src/OrbbecSDK_ROS2"
git -C "$HOME/orbbec_ws/src/OrbbecSDK_ROS2" checkout c780bc110826536500dd706baa1eca8392ed39cb
cd "$HOME/orbbec_ws/src/OrbbecSDK_ROS2/orbbec_camera/scripts"
sudo bash install_udev_rules.sh
sudo udevadm control --reload-rules
sudo udevadm trigger
cd "$HOME/orbbec_ws"
colcon build --event-handlers console_direct+ --cmake-args -DCMAKE_BUILD_TYPE=Release
```

```bash
uname -m
nvidia-smi
docker compose version
test -f /opt/ros/humble/setup.bash
test -f "$HOME/orbbec_ws/install/setup.bash"
```

Orbbec 설치 위치가 다르면 카메라와 OCR 터미널에서 `ORBBEC_WS`를 해당 경로로 내보냅니다. NVIDIA GPU와 Docker 권한이 확인되면 다음 명령으로 설치와 SSD 경로를 한 번에 점검할 수 있습니다.

```bash
cd "$HOME/physical_ai_tools"
bash deployment/check-new-pc.sh "$EXTERNAL_DRIVE_MOUNT"
```

## 3. 카메라와 OCR 확인

**터미널 A — 카메라.** 저장소 루트에서 실행한 뒤 창을 열어 둡니다.

```bash
./omx_bimanual_book/scripts/phase3_cameras.sh
```

기존 카메라 시리얼은 camera1에 X3, camera2에 X1입니다. 장치를 바꾸면 실행 전에 `CAMERA1_SERIAL`, `CAMERA2_SERIAL`을 지정하고 학습 때와 같은 위치에 장착합니다.

**터미널 B — OCR.** 설치 명령은 처음 한 번 실행합니다. 마지막 줄의 책 제목은 원하는 제목으로 바꿉니다.

```bash
cd ~/physical_ai_tools/OMX_BimanuAI_book_ocr_8_26
./scripts/install.sh
./scripts/run_detection_view.sh "찾을 책 제목"
```

**터미널 C — 결과 확인.** 목표 책을 카메라 앞에 놓고 메시지가 들어오는지 확인합니다. 확인이 끝나면 이 터미널에서 `Ctrl+C`를 누릅니다.

```bash
source /opt/ros/humble/setup.bash
export ROS_DOMAIN_ID=31 RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ros2 topic list
ros2 topic echo /book_detection/target_match std_msgs/msg/String
```

`/camera1/color/image_raw/compressed`와 `/book_detection/image_raw/compressed`가 보이는지 확인합니다. 목표 책이 인식되면 `target_match`에 제목과 카메라 프레임 시각이 나옵니다.

## 4. Physical AI와 양팔 실행

**터미널 D — Physical AI.** 1단계에서 SSD 경로를 설정한 터미널에서 저장소 루트를 기준으로 실행합니다.

```bash
export PAM_ROS_DOMAIN_ID=31
docker compose -f docker/docker-compose.yml build physical_ai_server
docker compose -f docker/docker-compose.yml up -d
docker logs --tail 100 physical_ai_server
```

새 브라우저 탭을 열고 주소창에 `http://localhost`를 입력합니다. Physical AI Manager에서 로봇 유형을 선택하는 화면을 열고 `omx_bimanual`이 목록에 있는지 확인합니다. 양팔 제어를 설치하려면 [양팔 프로젝트 안내](../omx_bimanual_book/README.md)의 USB 식별 및 초기 설정을 따라갑니다. `.env.example`을 복사한 뒤 실제 좌우 USB 포트를 확인합니다.

카메라와 관절 연결을 확인하고 작업 공간을 비운 상태에서, 추론용 follower 실행기를 사용합니다. 이 명령은 로봇 제어를 시작합니다.

```bash
./omx_bimanual_book/scripts/phase6_followers_ai.sh --arms-clear-and-estop-ready
```

Manager의 추론에서 아래 서버 경로를 사용합니다.

```text
/root/ros2_ws/src/physical_ai_tools/lerobot/outputs/train/ANG/checkpoints/050000/pretrained_model
```

camera1, OCR 영상, 양팔 상태와 좌우 관절 순서를 [양팔 설정](../physical_ai_server/config/omx_bimanual_config.yaml)과 대조합니다. 베이스를 정지시킨 상태에서 양팔 추론을 먼저 검증합니다.

## 5. 학습 재현

체크포인트 안의 `train_config.json`을 기준으로 ACT, 데이터셋 `YERI84/ANG`, CUDA, seed 1000, batch size 8을 사용합니다. Manager에서 별도 출력 이름으로 짧은 학습을 먼저 실행해 데이터 로드와 체크포인트 저장을 확인합니다. 원래 결과를 재현할 때는 50,000스텝과 저장 간격 25,000스텝을 적용하고 나머지 값도 저장된 설정과 맞춥니다. 이어서 학습할 때는 050000 체크포인트의 `training_state`가 함께 필요하며, 원본 보관용 체크포인트를 복사한 뒤 재개 설정을 적용합니다.

## 6. Nav2 연결

기존 자율주행 저장소에서 실행 명령, 지도 YAML과 이미지, Nav2 파라미터, 로봇 bringup 및 프레임 설정을 가져옵니다. 같은 ROS 그래프에서 실행한다면 주행 노드와 작업 관리 노드가 양팔/OCR과 통신할 수 있도록 도메인과 DDS 설정을 맞춥니다.

1. 기존 Nav2 실행 방법으로 지도를 올리고 위치 추정과 목표 지점 이동을 확인합니다.
2. 책장 작업 위치를 `map` 기준 위치와 방향으로 등록합니다.
3. 작업 관리 노드는 `NavigateToPose`의 성공과 베이스 정지를 확인하고, 정지 이후 카메라 프레임에서 요청한 책 제목이 일치하면 ACT를 한 번 시작합니다.
4. 주행이 취소되거나 실패하거나 OCR이 시간 내 일치하지 않으면 팔 작업을 시작하지 않습니다.

현재 작업 관리 노드와 Nav2 실행 명령은 이 저장소에 포함되어 있지 않습니다. 기존 주행 프로젝트를 확인한 뒤 실제 액션과 정지 확인용 토픽을 반영해야 합니다. 새 PC에서 전체 실행을 검증하면 이 문서에 실제 통합 실행 명령을 추가합니다.
