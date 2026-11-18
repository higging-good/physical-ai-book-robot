# Physical AI + Two Astra + Book Detection

All ROS processes use domain 30 and Fast DDS. A Zenoh router and a separate JPEG
conversion node are not used.

## Terminal 1 — Physical AI Manager and Server

```bash
cd ~/physical_ai_tools/docker
./container.sh start
```

The server, rosbridge, web video server, and Manager start automatically.

## Terminal 2 — Open Manipulator

```bash
~/run_omx_ai_fastdds.sh
```

## Terminal 3 — Two Astra cameras

```bash
~/run_two_astra_clean.sh
```

Camera X3 publishes the normal camera1 stream. Camera X1 publishes the camera2
stream used as the input for book detection.

## Terminal 4 — CPU-only book detection

```bash
run_detection
```

Enter the target book title when prompted. The processed output is published as
`/book_detection/image_raw` and `/book_detection/image_raw/compressed`.

In Physical AI Manager, select robot type `omx_f`, then select these image topics:

- `/camera1/color/image_raw`
- `/book_detection/image_raw`
