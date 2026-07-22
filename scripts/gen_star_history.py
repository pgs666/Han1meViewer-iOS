#!/usr/bin/env python3
"""Generate a repository-hosted SVG chart from GitHub's stargazer timeline."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from html import escape
from pathlib import Path


WIDTH, HEIGHT = 800, 360
LEFT, RIGHT, TOP, BOTTOM = 64, 24, 48, 48


def fetch_star_dates(repo: str, token: str) -> list[date]:
    dates: list[date] = []
    page = 1
    while True:
        request = urllib.request.Request(
            f"https://api.github.com/repos/{repo}/stargazers?per_page=100&page={page}",
            headers={
                "Accept": "application/vnd.github.star+json",
                "Authorization": f"Bearer {token}",
                "User-Agent": "repository-star-history-action",
                "X-GitHub-Api-Version": "2026-03-10",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                batch = json.load(response)
        except urllib.error.HTTPError as error:
            message = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"GitHub API returned HTTP {error.code}: {message}") from error
        if not batch:
            break
        dates.extend(
            datetime.fromisoformat(item["starred_at"].replace("Z", "+00:00")).date()
            for item in batch
        )
        if len(batch) < 100:
            break
        page += 1
    return sorted(dates)


def nice_ceiling(value: int) -> int:
    if value <= 5:
        return 5
    magnitude = 10 ** (len(str(value)) - 1)
    for multiplier in (1, 2, 2.5, 5, 10):
        candidate = int(multiplier * magnitude)
        if candidate >= value:
            return candidate
    return value


def render_svg(repo: str, dates: list[date]) -> str:
    plot_width = WIDTH - LEFT - RIGHT
    plot_height = HEIGHT - TOP - BOTTOM
    counts = Counter(dates)
    unique_dates = sorted(counts)
    today = datetime.now(timezone.utc).date()
    first_date = unique_dates[0] - timedelta(days=1) if unique_dates else today
    last_date = max(today, unique_dates[-1] if unique_dates else today)
    span_days = max(1, (last_date - first_date).days)
    y_max = nice_ceiling(max(1, len(dates)))

    def x_position(day: date) -> float:
        return LEFT + ((day - first_date).days / span_days) * plot_width

    def y_position(count: int) -> float:
        return TOP + plot_height - (count / y_max) * plot_height

    points: list[tuple[float, float]] = [(LEFT, y_position(0))]
    running_total = 0
    for day in unique_dates:
        x = x_position(day)
        running_total += counts[day]
        points.append((x, y_position(running_total)))
    if points[-1][0] < LEFT + plot_width:
        points.append((LEFT + plot_width, y_position(running_total)))

    curve_parts = [f"M {points[0][0]:.1f} {points[0][1]:.1f}"]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        midpoint = (x0 + x1) / 2
        curve_parts.append(
            f"C {midpoint:.1f} {y0:.1f}, {midpoint:.1f} {y1:.1f}, {x1:.1f} {y1:.1f}"
        )
    curve_path = " ".join(curve_parts)
    area_path = (
        f"M {LEFT:.1f} {TOP + plot_height:.1f} "
        f"L {points[0][0]:.1f} {points[0][1]:.1f} "
        + " ".join(curve_parts[1:])
        + f" L {LEFT + plot_width:.1f} {TOP + plot_height:.1f} Z"
    )

    grid_lines: list[str] = []
    for index in range(5):
        value = round(y_max * index / 4)
        y = y_position(value)
        grid_lines.append(
            f'<line class="grid" x1="{LEFT}" y1="{y:.1f}" x2="{LEFT + plot_width}" y2="{y:.1f}" />'
            f'<text class="axis" x="{LEFT - 10}" y="{y + 4:.1f}" text-anchor="end">{value}</text>'
        )

    x_labels: list[str] = []
    for index in range(5):
        day = first_date.fromordinal(first_date.toordinal() + round(span_days * index / 4))
        x = x_position(day)
        x_labels.append(
            f'<text class="axis" x="{x:.1f}" y="{HEIGHT - 18}" text-anchor="middle">{day:%Y-%m-%d}</text>'
        )

    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    safe_repo = escape(repo)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-labelledby="title desc">
  <title id="title">Star history for {safe_repo}</title>
  <desc id="desc">{len(dates)} stars from {first_date:%Y-%m-%d} through {last_date:%Y-%m-%d}</desc>
  <style>
    .background {{ fill: #ffffff; }} .grid {{ stroke: #e5e7eb; stroke-width: 1; }}
    .axis {{ fill: #6b7280; font: 12px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    .heading {{ fill: #111827; font: 600 18px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    .subheading {{ fill: #6b7280; font: 12px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    .area {{ fill: #3b82f6; opacity: .12; }} .line {{ fill: none; stroke: #2563eb; stroke-width: 3; stroke-linejoin: round; }}
    @media (prefers-color-scheme: dark) {{
      .background {{ fill: #0d1117; }} .grid {{ stroke: #30363d; }} .axis, .subheading {{ fill: #8b949e; }}
      .heading {{ fill: #f0f6fc; }} .area {{ fill: #58a6ff; opacity: .16; }} .line {{ stroke: #58a6ff; }}
    }}
  </style>
  <rect class="background" width="100%" height="100%" rx="8" />
  <text class="heading" x="{LEFT}" y="26">{safe_repo} · {len(dates)} stars</text>
  <text class="subheading" x="{WIDTH - RIGHT}" y="26" text-anchor="end">Updated {generated}</text>
  {''.join(grid_lines)}
  {''.join(x_labels)}
  <path class="area" d="{area_path}" />
  <path class="line" d="{curve_path}" />
</svg>
'''


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY", "pgs666/Han1meViewer-iOS"))
    parser.add_argument("--output", default="docs/star-history.svg")
    args = parser.parse_args()
    token = os.getenv("GITHUB_TOKEN")
    if not token:
        print("GITHUB_TOKEN is required", file=sys.stderr)
        return 2
    dates = fetch_star_dates(args.repo, token)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_svg(args.repo, dates), encoding="utf-8", newline="\n")
    print(f"Generated {output} with {len(dates)} stars")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
