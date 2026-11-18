#!/usr/bin/env python3
"""Generate an offline SVG plot from a bimanual PAM episode."""
import argparse
import html
import json
from pathlib import Path
import numpy as np
import pyarrow.parquet as pq


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dataset", type=Path)
    ap.add_argument("--episode", type=int, default=0)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    with (args.dataset / "meta" / "info.json").open() as stream:
        info = json.load(stream)
    names = info["features"]["observation.state"]["names"]
    if len(names) != 12:
        raise RuntimeError(f"Expected 12 state joints, found {len(names)}")
    chunk = args.episode // int(info.get("chunks_size", 1000))
    path = args.dataset / "data" / f"chunk-{chunk:03d}" / f"episode_{args.episode:06d}.parquet"
    table = pq.read_table(path)
    times = np.asarray(table["timestamp"].to_pylist(), dtype=float)
    state = np.rad2deg(np.asarray(table["observation.state"].to_pylist(), dtype=float))
    action = np.rad2deg(np.asarray(table["action"].to_pylist(), dtype=float))
    colors = ["#2563eb", "#dc2626", "#16a34a", "#9333ea", "#ea580c", "#0891b2"]
    svg = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="920" viewBox="0 0 1600 920">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<style>text{font-family:sans-serif;fill:#111827}.grid{stroke:#d1d5db}.axis{stroke:#374151;stroke-width:1.5}</style>',
        f'<text x="800" y="32" text-anchor="middle" font-size="22">{html.escape(args.dataset.name)} — '
        f'episode {args.episode:06d} ({len(times)} frames, {times[-1]:.2f} s)</text>',
    ]
    groups = [
        (40, 60, state[:, :6], names[:6], "Left follower state"),
        (800, 60, state[:, 6:], names[6:], "Right follower state"),
        (40, 480, action[:, :6], names[:6], "Left leader action"),
        (800, 480, action[:, 6:], names[6:], "Right leader action"),
    ]
    for px, py, values, labels, title in groups:
        left, right, top, bottom = px + 65, px + 740, py + 45, py + 325
        ymin, ymax = float(values.min()), float(values.max())
        margin = max(5.0, (ymax - ymin) * 0.08)
        ymin, ymax = ymin - margin, ymax + margin
        svg.append(f'<text x="{px + 380}" y="{py + 22}" text-anchor="middle" font-size="18">{title}</text>')
        for tick in range(6):
            y = top + (bottom - top) * tick / 5
            value = ymax - (ymax - ymin) * tick / 5
            svg.append(f'<line class="grid" x1="{left}" y1="{y:.1f}" x2="{right}" y2="{y:.1f}"/>')
            svg.append(f'<text x="{left - 8}" y="{y + 4:.1f}" text-anchor="end" font-size="11">{value:.0f}</text>')
        svg.append(f'<line class="axis" x1="{left}" y1="{top}" x2="{left}" y2="{bottom}"/>')
        svg.append(f'<line class="axis" x1="{left}" y1="{bottom}" x2="{right}" y2="{bottom}"/>')
        for index, label in enumerate(labels):
            points = []
            for time_value, angle in zip(times, values[:, index]):
                x = left + (right - left) * time_value / max(times[-1], 1e-9)
                y = bottom - (bottom - top) * (angle - ymin) / (ymax - ymin)
                points.append(f"{x:.1f},{y:.1f}")
            color = colors[index]
            svg.append(f'<polyline fill="none" stroke="{color}" stroke-width="1.6" points="{" ".join(points)}"/>')
            lx, ly = left + (index % 3) * 215, bottom + 25 + (index // 3) * 18
            svg.append(f'<line x1="{lx}" y1="{ly - 4}" x2="{lx + 18}" y2="{ly - 4}" stroke="{color}" stroke-width="2"/>')
            svg.append(f'<text x="{lx + 23}" y="{ly}" font-size="11">{html.escape(label)}</text>')
        svg.append(f'<text x="{px + 8}" y="{py + 190}" font-size="12" transform="rotate(-90 {px + 8} {py + 190})">Angle (deg)</text>')
        svg.append(f'<text x="{px + 380}" y="{py + 375}" text-anchor="middle" font-size="12">Time (s)</text>')
        svg.append(f'<text x="{left}" y="{bottom + 14}" font-size="10">0</text>')
        svg.append(f'<text x="{right}" y="{bottom + 14}" text-anchor="end" font-size="10">{times[-1]:.2f}</text>')
    svg.append("</svg>")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(svg))
    print(args.output)


if __name__ == "__main__":
    main()
