# OMX Bimanual Book Project

This project brings up two OMX leader/follower pairs without modifying the
existing single-arm Physical AI setup.

## Isolation

- Container: `omx_bimanual_book` (the existing container is `open_manipulator`)
- ROS domain: `31` by default (the existing Physical AI setup uses `30`)
- ROS root namespace: `/bimanual`
- Configuration: this project's `.env` only

The same USB robot cannot be controlled by two projects at once. The motion
scripts refuse to start while robot processes are active in the legacy
`open_manipulator` container.

## Expected USB mapping

The initial mapping is copied to `.env` on first use:

| Role | Default serial ID |
|---|---|
| Left follower | `E2D74E6A5157375037202020FF121310` |
| Left leader | `75EAD7AE5157375037202020FF0F1312` |
| Right follower | `E578036D5157375037202020FF122834` |
| Right leader | `FD2478A75157375037202020FF132C3C` |

These left/right labels are assumptions. Verify them by unplugging one OpenRB
at a time and edit `.env` before enabling torque.

### Identify all four USB roles without enabling motors

Disconnect all four robot USB cables, then run:

```bash
cd ~/physical_ai_tools/omx_bimanual_book
./scripts/identify_usb_roles.sh
```

Follow the prompts and connect exactly one new USB in this order: left leader,
right leader, left follower, right follower. The script only reads udev serial
links and never starts ROS or enables torque. It prints the mapping but does not
modify `.env`.

## Initial setup (no arm motion)

```bash
cd ~/physical_ai_tools/omx_bimanual_book
cp .env.example .env
nano .env
./scripts/build.sh
./scripts/start_container.sh
./scripts/check_devices.sh
```

`check_devices.sh` must report four `OK` lines. It does not enable motors.

## Phase 1: dual follower ROS control

Stop the legacy single-arm launch with `Ctrl+C`. If needed, clear its stale
processes without deleting the container:

```bash
docker restart open_manipulator
```

Clear both workspaces and keep an emergency stop ready. Then run once:

```bash
./scripts/phase1_bringup.sh --arms-clear-and-estop-ready
```

In another terminal:

```bash
cd ~/physical_ai_tools/omx_bimanual_book
./scripts/status.sh
```

Expected controller namespaces:

```text
/bimanual/left/follower/controller_manager
/bimanual/right/follower/controller_manager
```

Both `arm_controller` and `joint_state_broadcaster` should be `active`. Stop
the launch with `Ctrl+C` before proceeding.

If the log reports `Input Voltage Error`, stop immediately with `Ctrl+C` and
check that each follower has a stable 12 V supply connected and switched on.
USB power alone is not sufficient. Power-cycle the follower after correcting
the supply, then retry phase 1.

## Phase 2: simultaneous bimanual teleoperation

Place both follower arms near the corresponding leader poses before launch.
The follower arms can move as soon as each leader starts publishing.

```bash
./scripts/phase2_teleop.sh --arms-clear-and-estop-ready
```

The pairs are isolated under:

```text
/bimanual/left/follower
/bimanual/left/leader
/bimanual/right/follower
/bimanual/right/leader
```

Move one leader a few degrees at a time and confirm that only its matching
follower moves. Press `Ctrl+C` immediately if sides are swapped or either arm
moves unexpectedly.

## Phase 3A: record a joint-only pilot bag

Keep phase 2 running. In another terminal, record 15 seconds while moving both
leaders slowly:

```bash
cd ~/physical_ai_tools/omx_bimanual_book
./scripts/phase3_record_pilot.sh 15
```

The bag contains left/right follower states and left/right leader actions. It
is stored under `log/bimanual_pilot_*` and is used to validate the future 12D
state/action ordering before cameras or ACT training are added.

## Stop and remove only this project container

```bash
./scripts/stop.sh
```

This does not remove or edit the legacy `open_manipulator`,
`physical_ai_server`, or `physical_ai_manager` containers.
