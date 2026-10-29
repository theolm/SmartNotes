#!/usr/bin/env python3
"""Build an isolated Android CPU/Vulkan probe; never installs or opens the app.

Python 3.12+ is required for filtered source-archive extraction. Model/audio paths
must refer to approved fixtures, never personal journal data. No alternate driver,
root, Termux, telemetry, or global pub-cache modifications are used.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import statistics
import subprocess
import tarfile
import time
import urllib.request
import uuid

WHISPER_REVISION = "f049fff95a089aa9969deb009cdd4892b3e74916"
SOURCES = {
    "whisper": ("ggml-org/whisper.cpp", WHISPER_REVISION,
                "279af4ce60dbf397362868f3bacc75b56a4332ac2541cae155070093f6aaf0e3"),
    "spirv": ("KhronosGroup/SPIRV-Headers", "2a611a970fdbc41ac2e3e328802aed9985352dca",
              "c2225a49c3d7efa5c4f4ce4a6b42081e6ea3daca376f3353d9d7c2722d77a28a"),
    "vulkan": ("KhronosGroup/Vulkan-Headers", "2cd90f9d20df57eac214c148f3aed885372ddcfe",
               "e3865307e665f6a4ac4f7bbca7b3ba95e4191c7f8adf9f04b084ef514a2454e9"),
}
NDK_VERSION = "29.0.13113456"
BASE_Q8_SHA256 = "c577b9a86e7e048a0b7eada054f4dd79a56bbfa911fbdacf900ac5b567cbb7d9"
BASE_Q8_URL = (
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/"
    "5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base-q8_0.bin"
)
MODEL_FIXTURES = {
    "base": ("ggml-base-q8_0.bin", BASE_Q8_URL, BASE_Q8_SHA256),
    "small": (
        "ggml-small-q5_1.bin",
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/"
        "5359861c739e955e79d9a303bcbc70fb988958b1/ggml-small-q5_1.bin",
        "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb",
    ),
    "turbo": (
        "ggml-large-v3-turbo-q5_0.bin",
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/"
        "5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo-q5_0.bin",
        "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
    ),
}
JFK_SHA256 = "59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e"
# Public read speech with per-utterance transcripts. Concatenating distinct
# utterances gives natural long audio without repetition; it is still read
# speech, not spontaneous conversation.
LIBRISPEECH_TEST_CLEAN = (
    "https://www.openslr.org/resources/12/test-clean.tar.gz",
    "39fde525e59672dc6d1551919b1478f724438a95aa55f874b576be21967e6c23",
    "LibriSpeech test-clean (CC BY 4.0)",
)
UTTERANCE_GAP_SECONDS = 0.3
VK_OPTIONS = {
    "prefer-host-memory": "GGML_VK_PREFER_HOST_MEMORY",
    "disable-async": "GGML_VK_DISABLE_ASYNC",
    "disable-f16": "GGML_VK_DISABLE_F16",
    "disable-fusion": "GGML_VK_DISABLE_FUSION",
    "disable-graph-optimize": "GGML_VK_DISABLE_GRAPH_OPTIMIZE",
}
SHADERC_BOTTLE_SHA256 = "12ba0c59a98fb8f671f9473573002b2a812f26d2e60ea4f577f0c8c750c9838a"
SHADERC_BINARY_SHA256 = "73f9f514345e732bee65d4b92043af384b34f26af3ed797e0afbfb4e1449f8ce"


def profile_timings(stderr):
    """Keep GPU timestamp aggregates only, never raw native/driver log messages."""
    result = {}
    for line in stderr.splitlines():
        match = re.match(r"^([A-Z][A-Z_0-9]*)(?::|[ (].*?:) \d+ x [\d.e+-]+ us = ([\d.e+-]+) us", line)
        if match:
            op, microseconds = match.groups()
            result[op] = result.get(op, 0) + float(microseconds)
    return result


def normalized_words(text):
    return re.findall(r"\w+", text.casefold())


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def download(url, destination, sha256, headers=None):
    if not destination.exists() or digest(destination) != sha256:
        partial = destination.with_suffix(".partial")
        request = urllib.request.Request(url, headers=headers or {})
        with urllib.request.urlopen(request, timeout=120) as response, partial.open("wb") as output:
            shutil.copyfileobj(response, output)
        if digest(partial) != sha256:
            raise ValueError("Pinned artifact checksum mismatch")
        partial.replace(destination)


def fetch_shaderc(work):
    """Extract a pinned Homebrew bottle locally; do not install system packages."""
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("The pinned experimental compiler bottle targets macOS arm64 only")
    if int(platform.mac_ver()[0].split(".")[0]) < 26:
        raise ValueError("The pinned Tahoe compiler bottle requires macOS 26 or later")
    work.mkdir(parents=True, exist_ok=True)
    archive = work / "shaderc-2026.4-bottle.tar.gz"
    if not archive.exists() or digest(archive) != SHADERC_BOTTLE_SHA256:
        # This is an anonymous, public-registry pull token, not a user credential.
        # It is kept in memory only and is never included in logs or reports.
        with urllib.request.urlopen(
                "https://ghcr.io/token?service=ghcr.io&scope=repository:homebrew/core/shaderc:pull",
                timeout=30) as response:
            token = json.load(response)["token"]
        download("https://ghcr.io/v2/homebrew/core/shaderc/blobs/sha256:" + SHADERC_BOTTLE_SHA256,
                 archive, SHADERC_BOTTLE_SHA256, {"Authorization": "Bearer " + token})
    target = work / "modern-tools"
    binary = target / "shaderc/2026.4/bin/glslc"
    if not target.exists():
        staging = work / f"extract-{uuid.uuid4().hex}"
        staging.mkdir()
        with tarfile.open(archive) as source:
            source.extractall(staging, filter="data")
        staging.rename(target)
    if digest(binary) != SHADERC_BINARY_SHA256:
        raise ValueError("Experimental compiler binary checksum mismatch")
    print("Verified isolated shaderc 2026.4 compiler")


def run(arguments, **kwargs):
    return subprocess.run([str(arg) for arg in arguments], check=True, **kwargs)


def summarize(rows):
    measured = [row for row in rows if not row.get("warmup") and not row.get("failed")]
    summary = {}
    for backend in ("cpu", "vulkan"):
        selected = [row for row in measured if row["requested_backend"] == backend]
        if selected:
            summary[backend] = {
                "measured_runs": len(selected),
                "median_native_total_ms": statistics.median(row["native_total_ms"] for row in selected),
                "min_native_total_ms": min(row["native_total_ms"] for row in selected),
                "max_native_total_ms": max(row["native_total_ms"] for row in selected),
            }
            for stage in ("model_load_ms", "inference_ms", "cleanup_ms"):
                if all(stage in row for row in selected):
                    summary[backend]["median_" + stage] = statistics.median(row[stage] for row in selected)
    if "cpu" in summary and "vulkan" in summary:
        summary["vulkan_over_cpu_latency_ratio"] = (
            summary["vulkan"]["median_native_total_ms"] / summary["cpu"]["median_native_total_ms"])
    hashes = {row["transcript_sha256"] for row in measured}
    summary["measured_transcripts_identical"] = bool(measured) and len(hashes) == 1
    word_hashes = {row.get("normalized_transcript_sha256") for row in measured}
    summary["measured_words_identical"] = (
        len(word_hashes) == 1 if measured and None not in word_hashes else None)
    summary["note"] = "Native feasibility only; transcript equality is not a reference-accuracy score"
    return summary


def sources(work):
    result = {}
    for name, (repository, revision, sha256) in SOURCES.items():
        archive = work / f"{name}-{revision}.tar.gz"
        download(f"https://codeload.github.com/{repository}/tar.gz/{revision}", archive, sha256)
        target = work / f"source-{name}-{revision}"
        if not target.exists():
            # Temporary extraction is promoted only after success.
            staging = work / f"extract-{uuid.uuid4().hex}"
            staging.mkdir()
            with tarfile.open(archive) as source:
                source.extractall(staging, filter="data")
            children = list(staging.iterdir())
            if len(children) != 1 or not children[0].is_dir():
                raise ValueError("Unexpected source archive layout")
            children[0].rename(target)
            staging.rmdir()
        result[name] = target
    return result


def build(args):
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    src = sources(work)
    sdk = args.sdk.resolve()
    cmake_bin = sdk / "cmake/3.22.1/bin"
    cmake = cmake_bin / "cmake"
    ndk = sdk / f"ndk/{NDK_VERSION}"
    host = "darwin-x86_64" if platform.system() == "Darwin" else "linux-x86_64"
    glslc = args.glslc.resolve() if args.glslc else ndk / f"shader-tools/{host}/glslc"
    if args.glslc and (not args.glslc_sha256 or digest(glslc) != args.glslc_sha256):
        raise ValueError("An explicit matching --glslc-sha256 is required for a custom compiler")
    sysroot = ndk / f"toolchains/llvm/prebuilt/{host}/sysroot"
    package = work / "spirv-package"
    package.mkdir(exist_ok=True)
    # Upstream requires find_package even though it consumes headers directly.
    (package / "SPIRV-HeadersConfig.cmake").write_text(
        'set(SPIRV-Headers_FOUND TRUE)\n', encoding="utf-8")
    project = Path(__file__).resolve().parents[1] / "native/whisper_vulkan_probe"
    env = dict(os.environ, PATH=f"{cmake_bin}{os.pathsep}{os.environ.get('PATH', '')}")
    for backend in ("cpu", "vulkan"):
        output = work / f"build-{backend}"
        # Upstream 1.9.1 directly references Vulkan 1.1's
        # vkGetPhysicalDeviceFeatures2 (Android API 28). This is a separate
        # executable, not an increase to the Flutter application's minSdk.
        api = 28 if backend == "vulkan" else 24
        with (work / f"build-{backend}.log").open("w") as log:
            run([
                cmake, "-S", project, "-B", output, "-G", "Ninja",
                f"-DCMAKE_TOOLCHAIN_FILE={ndk}/build/cmake/android.toolchain.cmake",
                "-DANDROID_ABI=arm64-v8a", f"-DANDROID_PLATFORM=android-{api}",
                "-DANDROID_STL=c++_static", "-DCMAKE_BUILD_TYPE=Release",
                f"-DWHISPER_SOURCE_DIR={src['whisper']}",
                f"-DGGML_VULKAN={'ON' if backend == 'vulkan' else 'OFF'}",
                f"-DSPIRV-Headers_DIR={package}",
                f"-DSPIRV_INCLUDE_DIR={src['spirv']}/include",
                f"-DVulkan_INCLUDE_DIR={src['vulkan']}/include",
                f"-DVulkan_LIBRARY={sysroot}/usr/lib/aarch64-linux-android/{api}/libvulkan.so",
                f"-DVulkan_GLSLC_EXECUTABLE={glslc}",
            ], env=env, stdout=log, stderr=subprocess.STDOUT)
            run([cmake, "--build", output, "--target", "smartnotes-whisper-probe",
                 "--parallel", str(args.jobs)], env=env, stdout=log, stderr=subprocess.STDOUT)
        print(f"Built {backend} probe")
    manifest = {
        "schema_version": 1,
        "ndk_version": NDK_VERSION,
        "cmake_version": "3.22.1",
        "abi": "arm64-v8a",
        "cpu_arch": "armv8-a",
        "openmp": False,
        "glslc_sha256": digest(glslc),
        "glslc_version": run([glslc, "--version"], capture_output=True, text=True).stdout.strip(),
        "source_archives": {
            name: {"repository": repo, "revision": rev, "sha256": sha}
            for name, (repo, rev, sha) in SOURCES.items()
        },
        "probe_source_sha256": digest(project / "probe.cpp"),
        "cmake_source_sha256": digest(project / "CMakeLists.txt"),
        "executables": {
            backend: {"sha256": digest(work / f"build-{backend}/smartnotes-whisper-probe"),
                      "android_api": 28 if backend == "vulkan" else 24}
            for backend in ("cpu", "vulkan")
        },
    }
    (work / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def benchmark(args):
    if not args.approved_fixture:
        raise ValueError("Explicit --approved-fixture confirmation is required")
    if (not 1 <= args.runs <= 20 or not 1 <= args.threads <= 16
            or not 0 <= args.cooldown <= 300 or not 1 <= args.timeout <= 1800):
        raise ValueError("Invalid benchmark bounds")
    if digest(args.model) != args.model_sha256:
        raise ValueError("Model checksum mismatch")
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((work / "build-manifest.json").read_text())
    for backend in args.backends:
        if digest(work / f"build-{backend}/smartnotes-whisper-probe") != manifest["executables"][backend]["sha256"]:
            raise ValueError("Executable differs from the recorded build manifest; rebuild first")
    # All paths on the device are generated, not supplied by the caller.
    remote = f"/data/local/tmp/smartnotes-whisper-{uuid.uuid4().hex}"
    adb = ["adb", "-s", args.device]
    pcm = work / f"fixture-{uuid.uuid4().hex}.f32"
    conversion_start = time.perf_counter()
    run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", args.audio,
         "-ar", "16000", "-ac", "1", "-f", "f32le", pcm], capture_output=True)
    conversion_ms = (time.perf_counter() - conversion_start) * 1000
    rows = []
    run([*adb, "shell", "mkdir", remote], capture_output=True)
    try:
        for backend in args.backends:
            binary = work / f"build-{backend}/smartnotes-whisper-probe"
            run([*adb, "push", binary, f"{remote}/{backend}"], capture_output=True)
            run([*adb, "shell", "chmod", "700", f"{remote}/{backend}"], capture_output=True)
        run([*adb, "push", args.model, f"{remote}/model.bin"], capture_output=True)
        run([*adb, "push", pcm, f"{remote}/fixture.f32"], capture_output=True)
        # Alternate order to reduce temperature/order bias. Every run loads and
        # frees its model, matching the app's non-resident model lifecycle.
        for iteration in range(args.runs + 1):
            order = args.backends if iteration % 2 == 0 else list(reversed(args.backends))
            for backend in order:
                environment = []
                if backend == "vulkan":
                    environment = [f"{VK_OPTIONS[option]}=1" for option in args.vk_option]
                    if args.profile:
                        environment.append("GGML_VK_PERF_LOGGER=1")
                command = shlex.join(["env", *environment, f"{remote}/{backend}",
                                      f"{remote}/model.bin", f"{remote}/fixture.f32",
                                      args.language, str(args.threads),
                                      args.vulkan_flash_attention if backend == "vulkan" and args.vulkan_flash_attention
                                      else args.flash_attention])
                try:
                    result = subprocess.run([*adb, "shell", command], capture_output=True,
                                            text=True, timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    rows.append({"requested_backend": backend, "iteration": iteration,
                                 "failed": True, "error": "host_timeout"})
                    # Terminate only the binary staged in this run's unique dir.
                    # Killing adb alone need not stop a still-running native job.
                    pattern = "^" + remote + "/" + backend + " "
                    run([*adb, "shell", f"pkill -f {shlex.quote(pattern)} || true"],
                        capture_output=True)
                    raise RuntimeError(f"{backend} probe timed out; not qualified") from None
                if result.returncode:
                    # Do not publish stderr: third-party backend/driver errors
                    # can include paths. Retain earlier CPU results on failure.
                    failure = {"requested_backend": backend, "iteration": iteration,
                               "failed": True, "exit_code": result.returncode}
                    try:
                        error = json.loads(result.stdout).get("error")
                        if error in {"vulkan_instance_failed", "vulkan_device_missing",
                                     "invalid_options", "invalid_pcm", "pcm_read_failed",
                                     "model_load_failed", "inference_failed",
                                     "vulkan_not_initialized_cpu_fallback_rejected"}:
                            failure["error"] = error
                    except (ValueError, AttributeError):
                        pass
                    rows.append(failure)
                    raise RuntimeError(f"{backend} probe failed (exit {result.returncode}); not qualified")
                row = json.loads(result.stdout.strip())
                text = row.pop("fixture_transcript")
                row.update(iteration=iteration, warmup=iteration == 0,
                           transcript_sha256=hashlib.sha256(text.encode()).hexdigest(),
                           normalized_transcript_sha256=hashlib.sha256(
                               " ".join(normalized_words(text)).encode()).hexdigest())
                if args.reference:
                    row["word_error_rate"] = word_error_rate(args.reference.read_text(), text)
                if args.profile and backend == "vulkan":
                    row["gpu_profile_us_by_op"] = profile_timings(result.stderr)
                    if row["gpu_profile_us_by_op"]:
                        row["offload_scope"] = "GPU timestamp evidence for the reported operations only"
                rows.append(row)
                print(f"{backend} run {iteration}: {row['native_total_ms']:.0f} ms")
                time.sleep(args.cooldown)
    finally:
        pcm.unlink(missing_ok=True)
        # Delete only the unique directory created by this invocation.
        report = {
            "schema_version": 1, "whisper_revision": WHISPER_REVISION,
            "build": manifest,
            "experiment": {"flash_attention": args.flash_attention,
                           "vulkan_flash_attention_override": args.vulkan_flash_attention,
                           "vulkan_options": args.vk_option, "gpu_profiling": args.profile},
            "model_sha256": args.model_sha256, "audio_sha256": digest(args.audio),
            "reference_sha256": digest(args.reference) if args.reference else None,
            "host_audio_conversion_ms": conversion_ms,
            "scope": "native feasibility only; excludes in-app conversion, queue, and persistence",
            "model_residency": "load and free on every run; warmup does not mean resident model",
            "qualification": "not qualified by this probe alone", "runs": rows,
            "summary": summarize(rows),
        }
        try:
            args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        finally:
            run([*adb, "shell", "rm", "-r", remote], capture_output=True)


def word_error_rate(reference, hypothesis):
    # Simple Unicode case/punctuation normalization, versioned with this probe.
    # No claim of equivalence with Open ASR leaderboard normalization.
    expected, actual = normalized_words(reference), normalized_words(hypothesis)
    if not expected:
        raise ValueError("A non-empty reference transcript is required")
    previous = list(range(len(actual) + 1))
    for i, word in enumerate(expected, 1):
        current = [i]
        for j, other in enumerate(actual, 1):
            current.append(min(current[-1] + 1, previous[j] + 1,
                               previous[j - 1] + (word != other)))
        previous = current
    return previous[-1] / len(expected)


def inspect_capabilities(args):
    work = args.work.resolve()
    binary = work / "build-vulkan/smartnotes-whisper-probe"
    manifest = json.loads((work / "build-manifest.json").read_text())
    if digest(binary) != manifest["executables"]["vulkan"]["sha256"]:
        raise ValueError("Executable differs from the build manifest")
    remote = f"/data/local/tmp/smartnotes-whisper-{uuid.uuid4().hex}"
    adb = ["adb", "-s", args.device]
    run([*adb, "shell", "mkdir", remote], capture_output=True)
    try:
        run([*adb, "push", binary, remote + "/inspect"], capture_output=True)
        run([*adb, "shell", "chmod", "700", remote + "/inspect"], capture_output=True)
        result = run([*adb, "shell", remote + "/inspect", "--capabilities"],
                     capture_output=True, text=True, timeout=30)
        print(json.dumps(json.loads(result.stdout), indent=2))
    finally:
        run([*adb, "shell", "rm", "-r", remote], capture_output=True)


def loop_fixture(args):
    """Generate a controlled duration-scaling fixture, not natural long speech."""
    if not 1 <= args.repetitions <= 60:
        raise ValueError("Fixture repetitions must be between 1 and 60")
    work = args.work.resolve()
    source = work / f"source-whisper-{WHISPER_REVISION}/samples/jfk.wav"
    if digest(source) != JFK_SHA256:
        raise ValueError("Public source fixture checksum mismatch; build verified sources first")
    target = work / f"jfk-repeat-{args.repetitions}.wav"
    reference = work / f"jfk-repeat-{args.repetitions}.txt"
    run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-stream_loop",
         str(args.repetitions - 1), "-i", source, "-ar", "16000", "-ac", "1",
         "-c:a", "pcm_s16le", target], capture_output=True)
    text = (Path(__file__).resolve().parent / "fixtures/jfk_reference.txt").read_text().strip()
    reference.write_text("\n".join([text] * args.repetitions) + "\n", encoding="utf-8")
    manifest = {
        "schema_version": 1, "kind": "looped_public_speech_not_natural_conversation",
        "source_audio_sha256": JFK_SHA256, "repetitions": args.repetitions,
        "duration_seconds": 11 * args.repetitions,
        "audio_sha256": digest(target), "reference_sha256": digest(reference),
        "whisper_revision": WHISPER_REVISION,
    }
    (work / f"jfk-repeat-{args.repetitions}.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared controlled {11 * args.repetitions}-second public loop fixture")


def media_duration(path):
    result = run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                  "-of", "csv=p=0", path], capture_output=True, text=True)
    return float(result.stdout.strip())


def natural_fixture(args):
    """Concatenate distinct public read-speech utterances, never journal audio."""
    if not 30 <= args.seconds <= 600:
        raise ValueError("Natural fixture duration must be between 30 and 600 seconds")
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    url, archive_sha, dataset = LIBRISPEECH_TEST_CLEAN
    archive = work / "librispeech-test-clean.tar.gz"
    download(url, archive, archive_sha)
    transcripts, utterances = {}, []
    with tarfile.open(archive) as source:
        for member in source:
            if member.name.endswith(".trans.txt"):
                text = source.extractfile(member).read().decode("utf-8")
                for line in text.splitlines():
                    identifier, _, phrase = line.partition(" ")
                    if identifier and phrase.strip():
                        transcripts[identifier] = phrase.strip()
            elif member.name.endswith(".flac"):
                utterances.append(member.name)
    utterances.sort()
    staging = work / f"natural-{uuid.uuid4().hex}"
    staging.mkdir()
    selected, total, phrases = [], 0.0, set()
    try:
        with tarfile.open(archive) as source:
            for name in utterances:
                identifier = Path(name).stem
                phrase = transcripts.get(identifier)
                if phrase is None or phrase in phrases:
                    continue
                # Utterance text must be distinct: repetition is the variable
                # this fixture is meant to avoid.
                target = staging / f"utterance-{len(selected):04d}.flac"
                with source.extractfile(name) as stream, target.open("wb") as output:
                    shutil.copyfileobj(stream, output)
                total += media_duration(target)
                phrases.add(phrase)
                selected.append((target, identifier, phrase))
                if len(selected) >= 2 and total >= args.seconds:
                    break
        if len(selected) < 2 or total < args.seconds:
            raise ValueError("Public dataset does not cover the requested duration")
        parts = []
        for index, (path, _, _) in enumerate(selected):
            part = staging / f"part-{index:04d}.wav"
            run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", path, "-ar", "16000",
                 "-ac", "1", "-c:a", "pcm_s16le", part], capture_output=True)
            parts.append(part)
        silence = staging / "silence.wav"
        run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i",
             "anullsrc=r=16000:cl=mono", "-t", str(UTTERANCE_GAP_SECONDS),
             "-c:a", "pcm_s16le", silence], capture_output=True)
        concat = staging / "concat.txt"
        entries = []
        for part in parts:
            entries.extend([f"file '{part}'", f"file '{silence}'"])
        concat.write_text("\n".join(entries) + "\n", encoding="utf-8")
        target = work / f"natural-{args.seconds}s.wav"
        run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "concat", "-safe", "0",
             "-i", concat, "-c", "copy", target], capture_output=True)
        reference = work / f"natural-{args.seconds}s.txt"
        reference.write_text("\n".join(phrase for _, _, phrase in selected) + "\n", encoding="utf-8")
        manifest = {
            "schema_version": 1,
            "kind": "natural_read_speech_concatenated_utterances_not_spontaneous_conversation",
            "dataset": dataset, "source_url": url, "source_archive_sha256": archive_sha,
            "utterance_gap_seconds": UTTERANCE_GAP_SECONDS,
            "utterance_ids": [identifier for _, identifier, _ in selected],
            "requested_seconds": args.seconds,
            "duration_seconds": round(media_duration(target), 3),
            "audio_sha256": digest(target), "reference_sha256": digest(reference),
            "whisper_revision": WHISPER_REVISION,
        }
        (work / f"natural-{args.seconds}s.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"Prepared natural {manifest['duration_seconds']}-second public read-speech fixture "
              f"from {len(selected)} distinct utterances")
    finally:
        shutil.rmtree(staging, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work", type=Path, required=True, help="Dedicated external build/cache directory")
    sub = parser.add_subparsers(dest="command", required=True)
    compile_parser = sub.add_parser("build")
    compile_parser.add_argument("--sdk", type=Path, required=True)
    compile_parser.add_argument("--jobs", type=int, default=4)
    compile_parser.add_argument("--glslc", type=Path)
    compile_parser.add_argument("--glslc-sha256")
    fetch = sub.add_parser("fetch-model", help="Download a pinned existing catalog model")
    fetch.add_argument("--model", choices=MODEL_FIXTURES, default="base")
    sub.add_parser("fetch-shaderc", help="Extract pinned experimental macOS arm64 shaderc locally")
    inspect = sub.add_parser("inspect", help="Read Vulkan features without loading a speech model")
    inspect.add_argument("--device", required=True)
    fixture = sub.add_parser("loop-fixture", help="Repeat the pinned public clip for duration-scaling tests")
    fixture.add_argument("--repetitions", type=int, default=12)
    natural = sub.add_parser("natural-fixture",
                             help="Concatenate distinct public LibriSpeech utterances")
    natural.add_argument("--seconds", type=int, default=132)
    bench = sub.add_parser("run")
    bench.add_argument("--device", required=True)
    bench.add_argument("--model", type=Path, required=True)
    bench.add_argument("--model-sha256", required=True)
    bench.add_argument("--audio", type=Path, required=True)
    bench.add_argument("--reference", type=Path)
    bench.add_argument("--language", choices=["en", "pt", "auto"], default="en")
    bench.add_argument("--threads", type=int, default=6)
    bench.add_argument("--backends", nargs="+", choices=["cpu", "vulkan"], default=["cpu", "vulkan"])
    bench.add_argument("--flash-attention", choices=["default", "on", "off"], default="default")
    bench.add_argument("--vulkan-flash-attention", choices=["on", "off"],
                       help="Override only Vulkan, preserving the default CPU reference")
    bench.add_argument("--vk-option", choices=VK_OPTIONS, action="append", default=[])
    bench.add_argument("--profile", action="store_true", help="GPU timestamps perturb timings; diagnostic runs only")
    bench.add_argument("--runs", type=int, default=3)
    bench.add_argument("--cooldown", type=float, default=10)
    bench.add_argument("--timeout", type=int, default=600)
    bench.add_argument("--approved-fixture", action="store_true")
    bench.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "build":
        build(args)
    elif args.command == "inspect":
        inspect_capabilities(args)
    elif args.command == "loop-fixture":
        loop_fixture(args)
    elif args.command == "natural-fixture":
        natural_fixture(args)
    elif args.command == "fetch-shaderc":
        fetch_shaderc(args.work)
    elif args.command == "fetch-model":
        args.work.mkdir(parents=True, exist_ok=True)
        name, url, sha256 = MODEL_FIXTURES[args.model]
        download(url, args.work / name, sha256)
        print(f"Verified pinned {args.model} fixture model")
    else:
        benchmark(args)


if __name__ == "__main__":
    main()
