#!/usr/bin/env python3
import cv2
import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import HistoryPolicy, QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import CompressedImage, Image


class CameraRelays(Node):
    def __init__(self):
        super().__init__("bimanual_camera_compressed_relays")
        qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=5,
            reliability=ReliabilityPolicy.RELIABLE,
        )
        self.jpeg_publishers = {}
        self.counts = {}
        for camera in ("camera1", "camera2"):
            raw = f"/{camera}/color/image_raw"
            compressed = f"{raw}/compressed"
            self.jpeg_publishers[camera] = self.create_publisher(CompressedImage, compressed, qos)
            self.counts[camera] = 0
            self.create_subscription(
                Image, raw, lambda msg, name=camera: self.convert(name, msg), qos
            )
            self.get_logger().info(f"Relay: {raw} -> {compressed}")

    def convert(self, camera, msg):
        try:
            image = np.frombuffer(msg.data, dtype=np.uint8)
            if msg.encoding in ("rgb8", "bgr8"):
                image = image.reshape((msg.height, msg.width, 3))
                if msg.encoding == "rgb8":
                    image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
            elif msg.encoding == "mono8":
                image = image.reshape((msg.height, msg.width))
            else:
                raise RuntimeError(f"unsupported encoding: {msg.encoding}")
            ok, encoded = cv2.imencode(
                ".jpg", image, [int(cv2.IMWRITE_JPEG_QUALITY), 85]
            )
            if not ok:
                raise RuntimeError("JPEG encoding failed")
            output = CompressedImage()
            output.header = msg.header
            output.format = "jpeg"
            output.data = encoded.tobytes()
            self.jpeg_publishers[camera].publish(output)
            self.counts[camera] += 1
            if self.counts[camera] % 30 == 0:
                self.get_logger().info(
                    f"{camera}: {self.counts[camera]} frames, {len(output.data)} bytes"
                )
        except Exception as error:
            self.get_logger().error(f"{camera}: {error}")


def main():
    rclpy.init()
    node = CameraRelays()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    main()
