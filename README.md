# Physical AI Book Robot

## 새 컴퓨터에서 처음 실행하기

**[여기를 눌러 새 PC 설치·실행 가이드 열기](docs/new-pc-guide.md)**

가이드의 **0. 화면과 터미널 열기**부터 순서대로 따라오세요. 설치 사이트 링크와 클릭할 메뉴, 복사할 명령, 실행 후 확인할 결과가 들어 있습니다.

1. **GitHub와 외장 SSD 준비** — 코드와 설정은 이 저장소에서 받고, ANG 학습 데이터와 ACT 모델은 외장 SSD에서 불러옵니다.
2. **필수 프로그램 설치** — ROS 2 Humble, Docker, NVIDIA Container Toolkit, Orbbec 카메라 드라이버를 설치합니다.
3. **카메라와 OCR 실행** — 터미널별 명령을 실행하고, 목표 책이 인식되는지 확인합니다.
4. **양팔 ACT 실행과 학습** — 브라우저에서 `http://localhost`를 열어 Physical AI Manager를 사용합니다. 기존 모델 실행, 새 학습, 이어서 학습하는 절차가 가이드에 있습니다.

Git을 이미 설치했다면 아래 명령으로 이 배포 저장소를 받을 수 있습니다.

```bash
git clone --recurse-submodules https://github.com/higging-good/physical-ai-book-robot.git ~/physical_ai_tools
```

Nav2 자동 연동은 기존 주행 프로젝트의 실행 구성을 반영하는 단계가 남아 있습니다.

## ROBOTIS 원본 프로젝트

This repository offers an interface for developing physical AI applications using LeRobot and ROS 2. For detailed usage instructions, please refer to the documentation below.
  - [Documentation for AI Worker](https://ai.robotis.com/)

To clone the upstream ROBOTIS repository:
```bash
git clone -b jazzy https://github.com/ROBOTIS-GIT/physical_ai_tools.git --recursive
```

To learn more about the ROS 2 packages for the AI Worker, visit:
  - [AI Worker ROS 2 Packages](https://github.com/ROBOTIS-GIT/ai_worker)

To explore our open-source platforms in a simulation environment, visit:
  - [Simulation Models](https://github.com/ROBOTIS-GIT/robotis_mujoco_menagerie)

For usage instructions and demonstrations of the AI Worker, check out:
  - [Tutorial Videos](https://www.youtube.com/@ROBOTISOpenSourceTeam)

To access datasets and pre-trained models for our open-source platforms, see:
  - [AI Models & Datasets](https://huggingface.co/ROBOTIS)

To use the Docker image for running ROS packages and Physical AI tools with the AI Worker, visit:
  - [Docker Images](https://hub.docker.com/r/robotis/ros/tags)
