#!/usr/bin/env python3
"""Offline MCAP validator. It never publishes ROS data."""

import argparse
import statistics
import sys

import rosbag2_py
from rclpy.serialization import deserialize_message
from rosidl_runtime_py.utilities import get_message

TOPICS = {
    "/bimanual/left/follower/joint_states": ("left", "state"),
    "/bimanual/right/follower/joint_states": ("right", "state"),
    "/bimanual/left/leader/joint_trajectory": ("left", "action"),
    "/bimanual/right/leader/joint_trajectory": ("right", "action"),
}


def canonical(side):
    return [f"{side}_joint{i}" for i in range(1, 6)] + [f"{side}_gripper_joint_1"]


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * fraction)] if ordered else 0.0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("bag", help="bag directory containing metadata.yaml")
    args = parser.parse_args()
    reader = rosbag2_py.SequentialReader()
    reader.open(
        rosbag2_py.StorageOptions(uri=args.bag, storage_id="mcap"),
        rosbag2_py.ConverterOptions("", ""),
    )
    types = {item.name: item.type for item in reader.get_all_topics_and_types()}
    missing = sorted(set(TOPICS) - set(types))
    if missing:
        print("FAIL: missing topics: " + ", ".join(missing), file=sys.stderr)
        return 2

    data = {topic: {"times": [], "orders": set(), "bad": 0} for topic in TOPICS}
    while reader.has_next():
        topic, raw, timestamp = reader.read_next()
        if topic not in data:
            continue
        msg = deserialize_message(raw, get_message(types[topic]))
        names = tuple(msg.name if hasattr(msg, "name") else msg.joint_names)
        values = msg.position if hasattr(msg, "position") else (
            msg.points[0].positions if msg.points else []
        )
        side, _ = TOPICS[topic]
        if len(values) != 6 or set(names) != set(canonical(side)):
            data[topic]["bad"] += 1
        data[topic]["times"].append(timestamp / 1e9)
        data[topic]["orders"].add(names)

    passed = True
    starts, ends = [], []
    for topic, (side, kind) in TOPICS.items():
        item = data[topic]
        times = item["times"]
        if len(times) < 2:
            print(f"FAIL {topic}: only {len(times)} messages")
            passed = False
            continue
        starts.append(times[0])
        ends.append(times[-1])
        gaps = [(b - a) * 1000 for a, b in zip(times, times[1:])]
        duration = times[-1] - times[0]
        rate = (len(times) - 1) / duration
        print(f"\n{topic}")
        print(f"  role={kind} count={len(times)} rate={rate:.2f} Hz span={duration:.3f} s")
        print(
            f"  interval median={statistics.median(gaps):.2f} ms "
            f"p99={percentile(gaps, .99):.2f} ms max={max(gaps):.2f} ms"
        )
        for order in sorted(item["orders"]):
            print("  received order: " + ", ".join(order))
        print("  ACT order:      " + ", ".join(canonical(side)))
        if item["bad"]:
            print(f"  FAIL: {item['bad']} messages have invalid joint data")
            passed = False

    if starts and ends:
        overlap = max(0.0, min(ends) - max(starts))
        print(f"\nStream start skew: {max(starts) - min(starts):.3f} s")
        print(f"Common usable interval: {overlap:.3f} s")
    print("\nPASS: safe for name-based 12D conversion" if passed else "\nFAIL")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
