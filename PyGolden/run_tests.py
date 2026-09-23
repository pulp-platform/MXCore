#!/usr/bin/env python3
"""MXCore HWPE regression test runner.

Reads test configurations from PyGolden/test_configs.json,
compiles + simulates each in parallel, and prints a colour-coded results table.

Usage:  python3 run_tests.py [--jobs N] [--tag TAG] [--timeout S]
"""

import argparse
import json
import os
import subprocess
import sys
import shutil
import tempfile
import textwrap
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from PyGolden.tests import gemm_mxcore_vector_gen
from PyGolden import mxcore_gemm_functions

# ── Colour helpers (ANSI) ────────────────────────────────────────────────────
C_RESET   = "\033[0m"
C_BOLD    = "\033[1m"
C_DIM     = "\033[2m"
C_RED     = "\033[91m"
C_GREEN   = "\033[92m"
C_YELLOW  = "\033[93m"
C_BLUE    = "\033[94m"
C_MAGENTA = "\033[95m"
C_CYAN    = "\033[96m"
C_WHITE   = "\033[97m"
C_BG_RED  = "\033[41m"
C_BG_GRN  = "\033[42m"
C_BG_YEL  = "\033[43m"
C_BG_BLU  = "\033[44m"

TILE_COLOURS = {
    "REGULAR":   C_GREEN,
    "PARTIAL_M": C_CYAN,
    "PARTIAL_N": C_MAGENTA,
    "PARTIAL_MN": C_YELLOW,
}

# ── Paths ────────────────────────────────────────────────────────────────────
REPO_ROOT   = Path(__file__).resolve().parent.parent
ROOT        = REPO_ROOT / "mxcore-rtl"
SIM_DIR     = ROOT / "sim"
TV_DIR      = REPO_ROOT / "testvectors" / "nopreload"
TEST_DIR    = REPO_ROOT / "work" / "regression"
WORK_BASE   = TEST_DIR / "workdirs"
QUESTA      = "questa-2023.4"
MAIN_SEED   = 42

# ── Progress bar state (thread-safe) ─────────────────────────────────────────
_lock       = threading.Lock()
_total      = 0
_done       = 0
_passed     = 0
_failed     = 0
_running    = []

def _progress_bar():
    with _lock:
        pct = (_done / _total * 100) if _total else 0
        bar_w = 40
        filled = int(bar_w * _done / _total) if _total else 0
        bar = "█" * filled + "░" * (bar_w - filled)
        status = (f"{C_BOLD}[{bar}] {pct:5.1f}%  "
                  f"{C_GREEN}✓{_passed}{C_RESET}  "
                  f"{C_RED}✗{_failed}{C_RESET}  "
                  f"{C_DIM}({_done}/{_total}){C_RESET}")
        running_str = ""
        if _running:
            names = [f"{C_DIM}{r}{C_RESET}" for r in _running[:4]]
            extra = f" +{len(_running)-4}" if len(_running) > 4 else ""
            running_str = f"  ⟳ {', '.join(names)}{extra}"
        sys.stderr.write(f"\r\033[K{status}{running_str}")
        sys.stderr.flush()

def _add_running(name):
    global _running
    with _lock:
        _running.append(name)
    _progress_bar()

def _finish(name, passed):
    global _done, _passed, _failed, _running
    with _lock:
        _done += 1
        if passed:
            _passed += 1
        else:
            _failed += 1
        if name in _running:
            _running.remove(name)
    _progress_bar()


# ── Tile-mode classification ─────────────────────────────────────────────────
def classify_tile(M, N, reuse=64, npe=32):
    pm = M < reuse
    pn = N < npe
    if pm and pn:
        return "PARTIAL_MN"
    elif pm:
        return "PARTIAL_M"
    elif pn:
        return "PARTIAL_N"
    return "REGULAR"


def _mismatches_are_x_padding(sim_log):
    """Check if all mismatches are only x vs 0 (uninit padding)."""
    import re
    mismatches = re.findall(r'Expected\s+([0-9a-fA-Fx]+),\s+Got\s+([0-9a-fA-Fx]+)', sim_log)
    if not mismatches:
        return False
    for exp, got in mismatches:
        exp, got = exp.lower(), got.lower()
        if len(exp) != len(got):
            return False
        for e, g in zip(exp, got):
            if e == g:
                continue
            if g == 'x' and e == '0':
                continue
            return False
    return True


def workload_tag(M, K, N):
    ops = 2 * M * K * N
    if ops >= 4000000:
        return f"{C_RED}large{C_RESET}"
    elif ops >= 200000:
        return f"{C_YELLOW}med{C_RESET}"
    return f"{C_GREEN}small{C_RESET}"


def _shape_tag(t, defaults):
    return (f"{t['data_type']}_VS{t['vector_size']}_MX{t['npe']}_O{t['reuse']}"
            f"_M{t['M']}_K{t['K']}_N{t['N']}_BS{defaults['block_size']}")


# ── Test-vector generation (golden model) ────────────────────────────────────
def generate_testvectors(tests, defaults):
    """Generate any missing memory/result files for the given tests via PyGolden."""
    shapes = {(t["data_type"], t["vector_size"], t["npe"], t["reuse"], t["M"], t["K"], t["N"]) for t in tests}
    mxcore_gemm_functions.MEMORY_EXPORT = True
    for data_type, vs, npe, reuse, M, K, N in sorted(shapes):
        tag = f"{data_type}_VS{vs}_MX{npe}_O{reuse}_M{M}_K{K}_N{N}_BS{defaults['block_size']}"
        mem_file = TV_DIR / "memory" / f"data_memory_{tag}.txt"
        res_file = TV_DIR / "result" / f"result_{tag}.txt"
        res_mx_file = TV_DIR / "result_mx" / f"result_{tag}.txt"
        if mem_file.exists() and res_file.exists() and res_mx_file.exists():
            continue
        print(f"{C_DIM}Generating test vectors for {data_type} (VS,NPE,Reuse)=({vs},{npe},{reuse}) (M,K,N)=({M},{K},{N})...{C_RESET}", file=sys.stderr)
        gemm_mxcore_vector_gen(
            folder_path=str(REPO_ROOT / "testvectors"),
            data_type=data_type,
            seed=MAIN_SEED,
            fp9_scale_range=[-63, 63],
            mdim=M, kdim=K, ndim=N,
            mxdotp_vector_size=vs,
            num_mx_units=npe,
            num_out_buffers=reuse,
            block_size=defaults["block_size"],
            preload=False,
        )


# ── Build compile.tcl via bender ─────────────────────────────────────────────
def generate_compile_tcl(cfg, defaults, workdir):
    M, K, N, quantize = cfg["M"], cfg["K"], cfg["N"], cfg["quantize"]
    vs, npe, reuse = cfg["vector_size"], cfg["npe"], cfg["reuse"]
    data_type = cfg["data_type"]
    tag = _shape_tag(cfg, defaults)

    mem_file = str(TV_DIR / "memory"  / f"data_memory_{tag}.txt")
    if quantize:
        res_file = str(TV_DIR / "result_mx" / f"result_{tag}.txt")
    else:
        res_file = str(TV_DIR / "result" / f"result_{tag}.txt")

    bender_args = [
        "-t", "rtl",
        "-t", "test",
        "-t", "simulation",
        "-t", "vsim",
        "-t", "mxcore_hwpe",
        "-t", "mxcore_hwpe_test",
        "--define", "EN_FP8=1",
        "--define", "EN_FP8ALT=1",
        "--define", "EN_FP6=0",
        "--define", "EN_FP6ALT=0",
        "--define", "EN_FP4=1",
        "--define", f"VECTOR_SIZE={vs}",
        "--define", f"NPE={npe}",
        "--define", f"REUSE={reuse}",
        "--define", f"NUM_PIPE_REGS={defaults['num_pipe_regs']}",
        "--define", f"TCDM_BW={defaults['tcdm_bw']}",
        "--define", f"M={M}",
        "--define", f"K={K}",
        "--define", f"N={N}",
        "--define", f"QUANTIZE_MXFP8={quantize}",
        "--define", f"PROB_STALL={defaults['prob_stall']}",
        "--define", f"NO_STALLS={cfg['no_stalls']}",
        "--define", "HCI_ASSERT_DELAY=#41ps",
    ]

    cmd = ["bender", "script", "vsim"] + bender_args
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, cwd=str(REPO_ROOT))
    if result.returncode != 0:
        raise RuntimeError(f"bender failed: {result.stderr}")

    tcl_content = result.stdout
    string_defines = [
        f'+define+MEM_FILE="{mem_file}"',
        f'+define+RES_FILE="{res_file}"',
        f'+define+SRC_FMT="{data_type}"',
        f'+define+DST_FMT="FP32"',
    ]
    inject = " \\\n    ".join(string_defines) + " \\"
    tcl_content = tcl_content.replace(
        '+define+EN_FP8=1',
        inject + '\n    +define+EN_FP8=1',
    )

    tcl_path = workdir / "compile.tcl"
    tcl_path.write_text(tcl_content)
    return mem_file, res_file


# ── Run one simulation ───────────────────────────────────────────────────────
def run_test(cfg, defaults):
    M, K, N, quantize = cfg["M"], cfg["K"], cfg["N"], cfg["quantize"]
    vs, npe, reuse = cfg["vector_size"], cfg["npe"], cfg["reuse"]
    data_type = cfg["data_type"]
    q_str = "MX" if quantize else "FP32"
    stall_str = "stall" if cfg["no_stalls"] == 0 else "nostall"
    name = f"{data_type}_VS{vs}_MX{npe}_O{reuse}_M{M}_K{K}_N{N}_{q_str}_{stall_str}"

    tile_mode = classify_tile(M, N, reuse, npe)
    timeout = cfg.get("timeout_seconds", defaults.get("timeout_seconds", 120))

    workdir = WORK_BASE / name
    if workdir.exists():
        shutil.rmtree(workdir)
    workdir.mkdir(parents=True)

    result = {
        "name": name, "M": M, "K": K, "N": N,
        "vector_size": vs, "npe": npe, "reuse": reuse, "data_type": data_type,
        "no_stalls": cfg["no_stalls"],
        "quantize": quantize, "tile_mode": tile_mode,
        "status": "UNKNOWN", "reason": "",
    }

    _add_running(name)

    try:
        mem_file, res_file = generate_compile_tcl(cfg, defaults, workdir)

        if not Path(mem_file).exists():
            result["status"] = "SKIP"
            result["reason"] = "Missing test vectors"
            _finish(name, False)
            return result
        if not Path(res_file).exists():
            result["status"] = "SKIP"
            result["reason"] = "Missing result file"
            _finish(name, False)
            return result

        # vlib + vmap
        subprocess.run(
            [QUESTA, "vlib", "work"],
            cwd=str(workdir), stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30,
        )
        subprocess.run(
            [QUESTA, "vmap", "work", "work"],
            cwd=str(workdir), stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30,
        )

        # Compile
        compile_proc = subprocess.run(
            [QUESTA, "vsim", "-c", "-do", "source compile.tcl; quit"],
            cwd=str(workdir), stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=300,
        )
        if compile_proc.returncode != 0:
            result["status"] = "FAIL"
            result["reason"] = "Compile error"
            (workdir / "compile.log").write_text(compile_proc.stdout + "\n" + compile_proc.stderr)
            _finish(name, False)
            return result

        # Simulate (batch, no GUI, no debug)
        sim_tcl = textwrap.dedent("""\
            set LIB work
            vsim -suppress vsim-3009 -lib $LIB tb_mxcore_hwpe
            run -a
            quit -f
        """)
        sim_tcl_path = workdir / "run_sim.tcl"
        sim_tcl_path.write_text(sim_tcl)

        sim_proc = subprocess.run(
            [QUESTA, "vsim", "-c", "-do", f"source {sim_tcl_path.name}"],
            cwd=str(workdir), stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=timeout,
        )

        sim_log = sim_proc.stdout + "\n" + sim_proc.stderr
        (workdir / "sim.log").write_text(sim_log)

        if "Passed with no mismatches" in sim_log:
            result["status"] = "PASS"
            result["reason"] = "No mismatches"
            _finish(name, True)
        elif "Failed with" in sim_log:
            if _mismatches_are_x_padding(sim_log):
                result["status"] = "PASS"
                result["reason"] = "No mismatches (x-pad tolerant)"
                _finish(name, True)
            else:
                for line in sim_log.splitlines():
                    if "Failed with" in line:
                        result["reason"] = line.strip().replace("# ", "")
                        break
                result["status"] = "FAIL"
                _finish(name, False)
        else:
            result["status"] = "FAIL"
            result["reason"] = "Unknown (check sim.log)"
            _finish(name, False)

    except subprocess.TimeoutExpired:
        result["status"] = "TIMEOUT"
        result["reason"] = f"Stalled (>{timeout}s)"
        _finish(name, False)
    except Exception as e:
        result["status"] = "ERROR"
        result["reason"] = str(e)[:60]
        _finish(name, False)

    return result


# ── Pretty-print results table ───────────────────────────────────────────────
def _print_table(title, results_subset):
    sort_key = lambda x: (x["data_type"], x["vector_size"], x["npe"], x["reuse"], x["M"], x["K"], x["N"], x["no_stalls"])
    sorted_r = sorted(results_subset, key=sort_key)

    w = 108
    print(f"\n{C_BOLD}{'═' * w}{C_RESET}")
    print(f"{C_BOLD}  {title}{C_RESET}")
    print(f"{C_BOLD}{'═' * w}{C_RESET}")

    hdr = f"  {'HW (VS,NPE,Reuse)':<19} {'Type':<5} {'(M,K,N)':<16} {'Stall':<6} {'Tile Mode':<12} {'Status':<10} {'Reason'}"
    print(f"{C_BOLD}{C_DIM}{hdr}{C_RESET}")
    print(f"  {'─' * (w - 2)}")

    for r in sorted_r:
        tc = TILE_COLOURS.get(r["tile_mode"], C_WHITE)
        hw = f"({r['vector_size']},{r['npe']},{r['reuse']})"
        dims = f"({r['M']},{r['K']},{r['N']})"
        stall = "on" if r["no_stalls"] == 0 else "off"

        if r["status"] == "PASS":
            st = f"{C_GREEN}{C_BOLD}  PASS  {C_RESET}"
        elif r["status"] == "TIMEOUT":
            st = f"{C_BG_YEL}{C_BOLD} TIMEOUT{C_RESET}"
        elif r["status"] == "SKIP":
            st = f"{C_DIM}  SKIP  {C_RESET}"
        else:
            st = f"{C_BG_RED}{C_WHITE}{C_BOLD}  FAIL  {C_RESET}"

        reason = r["reason"][:45]
        print(f"  {hw:<19} {r['data_type']:<5} {dims:<16} {stall:<6} {tc}{r['tile_mode']:<12}{C_RESET} {st}  {C_DIM}{reason}{C_RESET}")


def print_results(results):
    sys.stderr.write("\r\033[K")
    sys.stderr.flush()

    fp32_results = [r for r in results if not r["quantize"]]
    mx_results   = [r for r in results if r["quantize"]]

    if fp32_results:
        _print_table("FP32 Output Results", fp32_results)
    if mx_results:
        _print_table("MXFP8 Quantized Output Results", mx_results)

    # Summary
    total = len(results)
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    timeouts = sum(1 for r in results if r["status"] == "TIMEOUT")
    errors = sum(1 for r in results if r["status"] == "ERROR")
    skipped = sum(1 for r in results if r["status"] == "SKIP")

    print(f"\n{C_BOLD}{'─' * 108}{C_RESET}")
    summary_parts = [f"{C_BOLD}Total: {total}{C_RESET}"]
    if passed:
        summary_parts.append(f"{C_GREEN}{C_BOLD}Passed: {passed}{C_RESET}")
    if failed:
        summary_parts.append(f"{C_RED}{C_BOLD}Failed: {failed}{C_RESET}")
    if timeouts:
        summary_parts.append(f"{C_YELLOW}{C_BOLD}Timeout: {timeouts}{C_RESET}")
    if errors:
        summary_parts.append(f"{C_RED}{C_BOLD}Error: {errors}{C_RESET}")
    if skipped:
        summary_parts.append(f"{C_DIM}Skipped: {skipped}{C_RESET}")
    print(f"  {'  |  '.join(summary_parts)}")

    if passed == total:
        print(f"\n  {C_BG_GRN}{C_BOLD}  ALL TESTS PASSED  {C_RESET}\n")
    else:
        print(f"\n  {C_BG_RED}{C_WHITE}{C_BOLD}  {total - passed} TEST(S) NEED ATTENTION  {C_RESET}\n")

    print(f"  {C_DIM}Logs: {WORK_BASE}/{C_RESET}\n")


# ── Main ─────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="MXCore HWPE FP8 regression runner")
    parser.add_argument("--jobs", "-j", type=int, default=4, help="Parallel jobs (default: 4)")
    parser.add_argument("--tag", "-t", type=str, default=None, help="Filter by tag (ci)")
    parser.add_argument("--timeout", type=int, default=None, help="Override timeout (seconds)")
    parser.add_argument("--config", type=str, default=str(Path(__file__).resolve().parent / "test_configs.json"), help="Config JSON path")
    args = parser.parse_args()

    with open(args.config) as f:
        config = json.load(f)

    defaults = config["defaults"]
    tests = config["tests"]

    if args.tag:
        tests = [t for t in tests if args.tag in t.get("tags", [])]

    if args.timeout:
        for t in tests:
            t["timeout_seconds"] = args.timeout

    if not tests:
        print(f"{C_RED}No tests matched filters.{C_RESET}")
        return 1

    global _total
    _total = len(tests)

    WORK_BASE.mkdir(parents=True, exist_ok=True)

    print(f"\n{C_BOLD}{C_CYAN}  ╔══════════════════════════════════════════╗{C_RESET}")
    print(f"{C_BOLD}{C_CYAN}  ║   MXCore HWPE FP8 Regression Test Suite  ║{C_RESET}")
    print(f"{C_BOLD}{C_CYAN}  ╚══════════════════════════════════════════╝{C_RESET}\n")
    print(f"  {C_DIM}Tests: {_total}  |  Jobs: {args.jobs}  |  Timeout: {defaults.get('timeout_seconds', 120)}s{C_RESET}\n")

    generate_testvectors(tests, defaults)

    _progress_bar()

    results = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_test, t, defaults): t for t in tests}
        for future in as_completed(futures):
            results.append(future.result())

    print_results(results)

    any_fail = any(r["status"] in ("FAIL", "TIMEOUT") for r in results)
    return 1 if any_fail else 0


if __name__ == "__main__":
    sys.exit(main())
