import argparse
import csv
import math
from collections import defaultdict
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from matplotlib.ticker import MaxNLocator

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LOG = REPO_ROOT / "mxcore-rtl" / "sim" / "build" / "transcript"

STATE_COLORS = {
    "ComputeOnly":      "#4c72b0",
    "ComputeAndOutput": "#8172b2",
    "Output":           "#dd8452",
}

COLORS = {
    ("Config", "Config"):                 "#7f7f7f",
    ("Loads", "A"):                       "#1f77b4",
    ("Loads", "B"):                       "#2ca02c",
    ("Loads", "SA"):                      "#9467bd",
    ("Loads", "SB"):                      "#7b4173",
    ("Loads", "Preload bias"):            "#e6b800",
    ("Preload -> GOB", "Bias row"):       "#f2c200",
    ("Compute", "Tile even"): "#1f4e9c",
    ("Compute", "Tile odd"):  "#6fa8dc",
    ("Stall", "Wait GOB (partial / bias)"): "#e377c2",
    ("Stall", "PE backpressure"):         "#d62728",
    ("GOB Write", "Partial"):             "#9ecae1",
    ("GOB Write", "Final"):               "#08519c",
    ("Tile Readout", "Tile even"):        "#238b45",
    ("Tile Readout", "Tile odd"):         "#74c476",
    ("Drain C", "C"):                     "#e6550d",
    ("Drain SC", "SC"):                   "#fdae6b",
    ("Result Write (TCDM)", "Granted"):   "#8c2d04",
}

ROW_ORDER = ["Config", "Compute", "Jobs", "DMA (TB)", "Loads", "Preload -> GOB", "Stall", "GOB Write", "Tile Readout", "Drain C", "Drain SC", "Result Write (TCDM)", "Ctrl FSM"]


def parse_log(path):
    clk_ps, meta, events = None, {}, []
    with open(path, errors="replace") as f:
        for line in f:
            idx = line.find("DF ")
            if idx < 0:
                continue
            tok = line[idx:].split()
            if len(tok) < 3:
                continue
            if tok[1] == "CLK":
                clk_ps = float(tok[2])
                keys = ["vs", "npe", "reuse", "num_jobs", "multictx", "preload", "quantize_mxfp8", "quantize_bf16", "src_fmt"]
                meta = dict(zip(keys, tok[3:]))
                continue
            try:
                t_ns = float(tok[1])
            except ValueError:
                continue
            events.append((t_ns, tok[2], tok[3:]))
    if clk_ps is None:
        raise RuntimeError(f"No 'DF CLK' line in {path}: was the simulation run with dataflow_trace=1?")
    if not events:
        raise RuntimeError(f"No dataflow events in {path}")
    events = [(int(math.floor(t * 1000.0 / clk_ps + 1e-6)), name, args) for t, name, args in events]
    events.sort(key=lambda e: e[0])
    return clk_ps, meta, events


def build_tracks(events):
    cycles = defaultdict(lambda: defaultdict(set))
    intervals = defaultdict(list)
    markers = []
    jobs = []
    compute_tile, readout_tile = -1, -1
    state, state_start = None, None
    compute_done, job_done = 0, 0
    dma_open = {}

    for cyc, name, args in events:
        if name == "CFG":
            cycles["Config"]["Config"].add(cyc)
        elif name == "STATE":
            if state is not None and state != "MXCoreIdle":
                intervals["Ctrl FSM"].append((state_start, cyc, state, STATE_COLORS.get(state, "#999999")))
            state, state_start = args[0], cyc
        elif name == "JOB_START":
            m, k, n, pre, mx, bf, tiles = (int(a) for a in args)
            out = "BF16" if bf else ("MXFP8" if mx else "FP32")
            jobs.append(dict(start=cyc, compute_done=None, done=None, m=m, k=k, n=n, preload=pre, output=out, tiles=tiles))
        elif name == "COMPUTE_DONE":
            if compute_done < len(jobs):
                jobs[compute_done]["compute_done"] = cyc
            markers.append((cyc, f"J{compute_done} compute done", "#4c72b0"))
            compute_done += 1
        elif name == "JOB_DONE":
            if job_done < len(jobs):
                jobs[job_done]["done"] = cyc
            markers.append((cyc, f"J{job_done} done", "#2ca02c"))
            job_done += 1
        elif name == "DMA_START":
            dma_open[(args[0], args[1])] = cyc
        elif name == "DMA_END":
            start = dma_open.pop((args[0], args[1]), cyc)
            label = f"J{args[0]} {'inputs' if args[1] == 'IN' else 'C'}"
            intervals["DMA (TB)"].append((start, cyc + 1, label, "#8c564b" if args[1] == "IN" else "#c49c94"))
        elif name == "LOAD":
            cycles["Loads"]["Preload bias" if args[0] == "BIAS" else args[0]].add(cyc)
        elif name == "PRELOAD":
            cycles["Preload -> GOB"]["Bias row"].add(cyc)
        elif name == "COMPUTE":
            if int(args[0]) == 0:
                compute_tile += 1
            cycles["Compute"]["Tile even" if compute_tile % 2 == 0 else "Tile odd"].add(cyc)
        elif name == "STALL":
            cycles["Stall"]["PE backpressure" if args[0] == "PE" else "Wait GOB (partial / bias)"].add(cyc)
        elif name == "GOB_WRITE":
            cycles["GOB Write"]["Final" if args[1] == "1" else "Partial"].add(cyc)
        elif name == "TILE_READ":
            if int(args[0]) == 0:
                readout_tile += 1
            cycles["Tile Readout"]["Tile even" if readout_tile % 2 == 0 else "Tile odd"].add(cyc)
        elif name == "DRAIN":
            cycles["Drain C" if args[0] == "C" else "Drain SC"][args[0]].add(cyc)
        elif name == "TCDM_WRITE":
            cycles["Result Write (TCDM)"]["Granted"].add(cyc)

    if state is not None and state != "MXCoreIdle":
        intervals["Ctrl FSM"].append((state_start, events[-1][0] + 1, state, STATE_COLORS.get(state, "#999999")))

    for j, job in enumerate(jobs):
        cd = job["compute_done"] if job["compute_done"] is not None else events[-1][0]
        dn = job["done"] if job["done"] is not None else events[-1][0]
        intervals[f"Job {j}"].append((job["start"], cd, f"J{j} compute", "#4c72b0"))
        intervals[f"Job {j}"].append((cd, dn, f"J{j} drain", "#dd8452"))

    return cycles, intervals, markers, jobs


def runs(cycle_set, max_gap=0):
    out = []
    for c in sorted(cycle_set):
        if out and c <= out[-1][0] + out[-1][1] + max_gap:
            out[-1][1] = c - out[-1][0] + 1
        else:
            out.append([c, 1])
    return [tuple(r) for r in out]


def row_names(cycles, intervals, jobs):
    rows = []
    for name in ROW_ORDER:
        if name == "Jobs":
            if len(jobs) > 1:
                rows += [f"Job {j}" for j in range(len(jobs))]
        elif cycles.get(name) or intervals.get(name):
            rows.append(name)
    return rows


def title_for(meta, jobs):
    if not jobs:
        return "MXCore Dataflow"
    j0 = jobs[0]
    shapes = {(j["m"], j["k"], j["n"]) for j in jobs}
    shape = f"{j0['m']}x{j0['k']}x{j0['n']}" if len(shapes) == 1 else "mixed shapes"
    src = "MX" + meta.get("src_fmt", "FP8")
    parts = [f"MXCore ({meta.get('vs')}, {meta.get('npe')}, {meta.get('reuse')})",
             f"GEMM {shape}",
             f"{src} x {src} $\\rightarrow$ {j0['output']}",
             f"Preload {'ON' if j0['preload'] else 'OFF'}"]
    if len(jobs) > 1:
        parts.append(f"{len(jobs)} Jobs")
    return " | ".join(parts)


def summarize(cycles, jobs, t0, t_end):
    compute = sum(len(s) for s in cycles.get("Compute", {}).values())
    stall = {k: len(v) for k, v in cycles.get("Stall", {}).items()}
    print(f"Window: cycles {t0} .. {t_end} ({t_end - t0} cycles)")
    for j, job in enumerate(jobs):
        cd = job["compute_done"] - job["start"] if job["compute_done"] is not None else None
        dn = job["done"] - job["start"] if job["done"] is not None else None
        print(f"  Job {j}: {job['m']}x{job['k']}x{job['n']} -> {job['output']}, preload={job['preload']}, "
              f"start @{job['start']}, compute done +{cd}, job done +{dn}")
    print(f"  Compute (MXDOTP input) cycles: {compute}")
    for k, v in stall.items():
        print(f"  Stall cycles ({k}): {v}")


def write_trace_csv(path, events, t0):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["cycle", "event", "args"])
        for cyc, name, args in events:
            w.writerow([cyc - t0, name, " ".join(args)])


def plot(cycles, intervals, markers, jobs, meta, out_path, xlim=None):
    rows = row_names(cycles, intervals, jobs)
    n = len(rows)
    fig, ax = plt.subplots(figsize=(12, max(0.62 * n + 0.6, 6.5)))
    legend = {}

    for i, row in enumerate(rows):
        y = n - 1 - i
        for label, cset in cycles.get(row, {}).items():
            color = COLORS.get((row, label), "#999999")
            ax.broken_barh(runs(cset, 8 if row == "Config" else 0), (y - 0.3, 0.6), facecolors=color, edgecolor=color, linewidth=0.6)
            legend.setdefault(row if label == row else f"{row}: {label}", color)
        for start, end, label, color in intervals.get(row, []):
            ax.broken_barh([(start, max(end - start, 1))], (y - 0.3, 0.6), facecolors=color, edgecolor="black", linewidth=0.4)
            span = (xlim[1] - xlim[0]) if xlim else (max(e for _, e, _, _ in intervals[row]) + 1)
            if (end - start) > 0.06 * span:
                ax.text((start + end) / 2, y, label, ha="center", va="center", fontsize=7, color="white")
            if row == "Ctrl FSM":
                legend.setdefault(f"FSM: {label}", color)

    for cyc, label, color in markers:
        ax.axvline(cyc, color=color, linestyle=":", linewidth=0.9)

    ax.set_yticks(range(n))
    ax.set_yticklabels(list(reversed(rows)), fontsize=10)
    ax.set_ylim(-0.5, n - 0.5)
    ax.xaxis.set_major_locator(MaxNLocator(nbins=12, integer=True))
    ax.set_xlabel("Cycle", fontsize=10, labelpad=3)
    if xlim:
        ax.set_xlim(*xlim)
    ax.grid(True, axis="x", linestyle="--", alpha=0.35)
    ax.set_title(title_for(meta, jobs), pad=8, fontsize=14)
    fig.tight_layout()

    marker_fontsize = 8
    pt = fig.dpi / 72.0
    prev_px, prev_dx = None, -0.8 * marker_fontsize
    for cyc, label, color in sorted(markers):
        if len(jobs) <= 1:
            label = label.split(" ", 1)[1]
        px = ax.transData.transform((cyc, 0))[0]
        dx = -0.8 * marker_fontsize
        if prev_px is not None and (px + dx * pt) - (prev_px + prev_dx * pt) < 1.2 * marker_fontsize * pt:
            dx = prev_dx + 1.2 * marker_fontsize
        ax.annotate(label, xy=(cyc, 1.0), xycoords=("data", "axes fraction"), xytext=(dx, -4),
                    textcoords="offset points", ha="center", va="top", rotation=90,
                    fontsize=marker_fontsize, color=color,
                    bbox=dict(boxstyle="square,pad=0.1", facecolor="white", edgecolor="none", alpha=0.75))
        prev_px, prev_dx = px, dx

    fontsize = 9
    handles = [Patch(facecolor=c, label=l) for l, c in legend.items()]
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    em = fontsize * fig.dpi / 72.0
    label_widths = []
    for h in handles:
        t = ax.text(0, 0, h.get_label(), fontsize=fontsize)
        label_widths.append(t.get_window_extent(renderer).width)
        t.remove()
    axis_box = ax.get_window_extent(renderer)
    col_width = max(label_widths) + (2.0 + 0.8 + 1.5) * em
    ncol = max(1, min(len(handles), int(axis_box.width // col_width)))
    below = (ax.xaxis.label.get_window_extent(renderer).y0 - axis_box.y0 - 0.4 * em) / axis_box.height
    nrows, full_cols = divmod(len(handles), ncol)
    col_heights = [nrows + 1 if c < full_cols else nrows for c in range(ncol)]
    handles = [handles[r * ncol + c] for c in range(ncol) for r in range(col_heights[c])]
    ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(0.0, below, 1.0, 0.0), mode="expand", ncol=ncol,
              fontsize=fontsize, frameon=False, handlelength=2.0, handletextpad=0.8, columnspacing=1.5,
              borderaxespad=0.0, labelspacing=0.3)
    fig.canvas.draw()
    fig.savefig(out_path, bbox_inches="tight", pad_inches=0.1)
    print(f"Saved {out_path}")


def main():
    parser = argparse.ArgumentParser(description="Plot the MXCore dataflow from a simulation run with dataflow_trace=1.")
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG, help=f"Simulation transcript or make log (default: {DEFAULT_LOG})")
    parser.add_argument("--out", type=Path, default=None, help="Output plot (.pdf/.png, default: dataflow.pdf next to the log)")
    parser.add_argument("--trace", type=Path, default=None, help="Output trace CSV (default: dataflow_trace.csv next to the plot)")
    parser.add_argument("--xlim", type=int, nargs=2, default=None, help="Cycle window to plot (relative to the first event)")
    args = parser.parse_args()

    clk_ps, meta, events = parse_log(args.log)
    t0 = events[0][0]
    events = [(c - t0, name, a) for c, name, a in events]
    cycles, intervals, markers, jobs = build_tracks(events)

    out = args.out or args.log.with_name("dataflow.pdf")
    trace = args.trace or out.with_name("dataflow_trace.csv")
    write_trace_csv(trace, events, 0)
    print(f"Saved {trace}")
    summarize(cycles, jobs, 0, events[-1][0])
    plot(cycles, intervals, markers, jobs, meta, out, tuple(args.xlim) if args.xlim else None)


if __name__ == "__main__":
    main()
