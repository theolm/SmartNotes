"""Host-only tests: no Android device, real models, or network required."""

import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from argparse import Namespace
import contextlib
import io
import json
import subprocess
import tarfile

SPEC = importlib.util.spec_from_file_location(
    "probe", Path(__file__).resolve().parents[1] / "whisper_vulkan_probe.py")
probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe)


class ProbeTest(unittest.TestCase):
    def test_downloadable_model_fixtures_are_existing_pinned_catalog_artifacts(self):
        catalog = (Path(__file__).resolve().parents[2] /
                   "lib/domain/entities/speech_model.dart").read_text()
        for filename, url, sha256 in probe.MODEL_FIXTURES.values():
            self.assertIn(f"fileName: '{filename}'", catalog)
            self.assertIn(f"sha256: '{sha256}'", catalog)
            self.assertIn("5359861c739e955e79d9a303bcbc70fb988958b1", url)
            self.assertTrue(url.endswith("/" + filename))

    def test_loop_fixture_is_labeled_synthetic_and_preserves_reference_count(self):
        with tempfile.TemporaryDirectory() as folder:
            args = Namespace(work=Path(folder), repetitions=12)
            source = args.work / f"source-whisper-{probe.WHISPER_REVISION}/samples/jfk.wav"
            source.parent.mkdir(parents=True)
            source.write_bytes(b"approved public test fixture")
            with (patch.object(probe, "JFK_SHA256", probe.digest(source)),
                  patch.object(probe, "run", side_effect=self.fake_adb) as commands,
                  contextlib.redirect_stdout(io.StringIO())):
                probe.loop_fixture(args)
            manifest = json.loads((args.work / "jfk-repeat-12.json").read_text())
            self.assertEqual(manifest["kind"], "looped_public_speech_not_natural_conversation")
            self.assertEqual(manifest["duration_seconds"], 132)
            self.assertEqual(manifest["audio_sha256"], probe.digest(args.work / "jfk-repeat-12.wav"))
            self.assertEqual(len((args.work / "jfk-repeat-12.txt").read_text().splitlines()), 12)
            command = commands.call_args.args[0]
            self.assertEqual(command[command.index("-stream_loop") + 1], "11")

    def test_loop_fixture_rejects_unbounded_duration_before_native_work(self):
        for repetitions in (0, -1, 61):
            with patch.object(probe, "run") as commands, self.assertRaises(ValueError):
                probe.loop_fixture(Namespace(work=Path("unused"), repetitions=repetitions))
            commands.assert_not_called()

    def test_natural_fixture_concatenates_distinct_utterances_and_never_repeats(self):
        with tempfile.TemporaryDirectory() as folder:
            work = Path(folder)
            archive = work / "librispeech-test-clean.tar.gz"
            transcript = "1-2-0000 HELLO ONE\n1-2-0001 SECOND LINE\n1-2-0002 THIRD LINE\n"
            with tarfile.open(archive, "w:gz") as tar:
                for name, data in (("test-clean/1/2/1-2.trans.txt", transcript.encode()),
                                   ("test-clean/1/2/1-2-0000.flac", b"f0"),
                                   ("test-clean/1/2/1-2-0001.flac", b"f1"),
                                   ("test-clean/1/2/1-2-0002.flac", b"f2")):
                    info = tarfile.TarInfo(name)
                    info.size = len(data)
                    tar.addfile(info, io.BytesIO(data))
            args = Namespace(work=work, seconds=30)

            def fake_tools(command, **kwargs):
                arguments = [str(arg) for arg in command]
                if arguments[0] == "ffprobe":
                    return subprocess.CompletedProcess(arguments, 0, stdout="16.0\n")
                Path(arguments[-1]).write_bytes(b"decoded")
                return subprocess.CompletedProcess(arguments, 0)

            with (patch.object(probe, "LIBRISPEECH_TEST_CLEAN",
                               ("https://example.invalid/public.tar.gz", probe.digest(archive),
                                "Synthetic public dataset")),
                  patch.object(probe, "run", side_effect=fake_tools) as commands,
                  contextlib.redirect_stdout(io.StringIO())):
                probe.natural_fixture(args)
            manifest = json.loads((work / "natural-30s.json").read_text())
            self.assertEqual(
                manifest["kind"],
                "natural_read_speech_concatenated_utterances_not_spontaneous_conversation")
            self.assertEqual(manifest["utterance_ids"], ["1-2-0000", "1-2-0001"])
            self.assertEqual(manifest["duration_seconds"], 16.0)
            self.assertEqual(manifest["audio_sha256"], probe.digest(work / "natural-30s.wav"))
            self.assertEqual(len((work / "natural-30s.txt").read_text().splitlines()), 2)
            self.assertNotEqual(manifest["utterance_ids"][0], manifest["utterance_ids"][1])
            self.assertFalse([p for p in work.iterdir()
                              if p.is_dir() and p.name.startswith("natural-")])

    def test_natural_fixture_rejects_unbounded_duration_before_network(self):
        for seconds in (0, 29, 601):
            with patch.object(probe, "run") as commands, self.assertRaises(ValueError):
                probe.natural_fixture(Namespace(work=Path("unused"), seconds=seconds))
            commands.assert_not_called()

    def test_gpu_profile_keeps_aggregate_operations_not_raw_logs(self):
        raw = (
            "driver error /private/path-must-not-leak\n"
            "MUL_MAT q8_0 m=512 n=1500 k=512: 4 x 100 us = 400 us (1 GFLOPS/s)\n"
            "MUL_MAT f16 m=64 n=1500 k=64: 2 x 50 us = 100 us\n"
            "FLASH_ATTN_EXT dst(64,1500,8,1), q(64,1500,8,1): 1 x 200 us = 200 us\n"
            "NORM: 10 x 2 us = 20 us\n"
            "IM2COL: 1 x 30 us = 30 us\n"
            "Total time: 700 us.\n"
        )
        self.assertEqual(probe.profile_timings(raw), {
            "MUL_MAT": 500, "FLASH_ATTN_EXT": 200, "NORM": 20, "IM2COL": 30})

    def test_diagnostic_flags_are_recorded_and_do_not_affect_cpu_environment(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.fixture_args(folder)
            args.profile = True
            args.vk_option = ["disable-async"]
            args.vulkan_flash_attention = "off"
            with (patch.object(probe, "run", side_effect=self.fake_adb),
                  patch.object(probe.subprocess, "run", return_value=self.native_output()) as native,
                  patch.object(probe.time, "sleep"), contextlib.redirect_stdout(io.StringIO())):
                probe.benchmark(args)
            calls = [call.args[0][-1] for call in native.call_args_list]
            self.assertNotIn("GGML_VK", calls[0])
            self.assertIn("GGML_VK_DISABLE_ASYNC=1", calls[1])
            self.assertIn("GGML_VK_PERF_LOGGER=1", calls[1])
            self.assertEqual(probe.shlex.split(calls[0])[-1], "default")
            self.assertEqual(probe.shlex.split(calls[1])[-1], "off")
            report = json.loads(args.output.read_text())
            self.assertTrue(report["experiment"]["gpu_profiling"])
            self.assertEqual(report["experiment"]["vulkan_options"], ["disable-async"])
            self.assertEqual(report["experiment"]["vulkan_flash_attention_override"], "off")

    def test_capability_inspection_requires_no_model_and_cleans_up(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.fixture_args(folder)

            def fake_inspect(command, **kwargs):
                if command[-1] == "--capabilities":
                    return subprocess.CompletedProcess(command, 0, stdout=json.dumps({
                        "devices": [{"shader_float16": True,
                                     "packed_signed_4x8_dot_accelerated": False}]}))
                return self.fake_adb(command, **kwargs)

            with (patch.object(probe, "run", side_effect=fake_inspect) as commands,
                  contextlib.redirect_stdout(io.StringIO()) as printed):
                probe.inspect_capabilities(args)
            report = json.loads(printed.getvalue())
            self.assertFalse(report["devices"][0]["packed_signed_4x8_dot_accelerated"])
            for call in commands.call_args_list:
                self.assertNotIn(str(args.model), [str(arg) for arg in call.args[0]])
            self.assertEqual(commands.call_args_list[-1].args[0][3:6], ["shell", "rm", "-r"])

    def test_summary_excludes_warmup_and_failures(self):
        rows = [
            {"requested_backend": "cpu", "native_total_ms": 1000, "warmup": True},
            {"requested_backend": "vulkan", "failed": True},
            {"requested_backend": "cpu", "native_total_ms": 10, "transcript_sha256": "a"},
            {"requested_backend": "cpu", "native_total_ms": 20, "transcript_sha256": "a"},
            {"requested_backend": "vulkan", "native_total_ms": 30, "transcript_sha256": "a"},
        ]
        summary = probe.summarize(rows)
        self.assertEqual(summary["cpu"]["median_native_total_ms"], 15)
        self.assertEqual(summary["cpu"]["min_native_total_ms"], 10)
        self.assertEqual(summary["cpu"]["max_native_total_ms"], 20)
        self.assertEqual(summary["vulkan_over_cpu_latency_ratio"], 2)
        self.assertTrue(summary["measured_transcripts_identical"])

    def test_empty_or_failed_summary_does_not_claim_transcript_equality(self):
        self.assertFalse(probe.summarize([])["measured_transcripts_identical"])
        self.assertNotIn("vulkan_over_cpu_latency_ratio", probe.summarize([]))

    def test_summary_distinguishes_raw_text_from_normalized_words(self):
        rows = [
            {"requested_backend": "cpu", "native_total_ms": 10,
             "transcript_sha256": "punctuation-a", "normalized_transcript_sha256": "same-words"},
            {"requested_backend": "vulkan", "native_total_ms": 8,
             "transcript_sha256": "punctuation-b", "normalized_transcript_sha256": "same-words"},
        ]
        summary = probe.summarize(rows)
        self.assertFalse(summary["measured_transcripts_identical"])
        self.assertTrue(summary["measured_words_identical"])

    def fixture_args(self, folder):
        root = Path(folder)
        model = root / "fixture.bin"
        model.write_bytes(b"test model")
        audio = root / "fixture.wav"
        audio.write_bytes(b"test audio")
        binaries = {}
        for backend in ("cpu", "vulkan"):
            target = root / f"build-{backend}/smartnotes-whisper-probe"
            target.parent.mkdir()
            target.write_bytes(b"test executable")
            binaries[backend] = {"sha256": probe.digest(target)}
        (root / "build-manifest.json").write_text(json.dumps({"executables": binaries}))
        return Namespace(
            work=root, model=model, model_sha256=probe.digest(model), audio=audio,
            approved_fixture=True, runs=1, threads=6, device="test-device",
            reference=None, language="en", timeout=1, cooldown=0,
            backends=["cpu", "vulkan"], flash_attention="default", vk_option=[], profile=False,
            vulkan_flash_attention=None,
            output=root / "report.json")

    def native_output(self):
        return subprocess.CompletedProcess([], 0, stdout=json.dumps({
            "fixture_transcript": "approved sample words", "native_total_ms": 10,
            "requested_backend": "cpu", "vulkan_backend_initialized": False,
        }), stderr="")

    def fake_adb(self, command, **kwargs):
        if command[0] == "ffmpeg":
            Path(command[-1]).write_bytes(b"\x00" * 64)
        return subprocess.CompletedProcess(command, 0)

    def test_runner_reports_hashes_not_text_or_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.fixture_args(folder)
            args.reference = Path(folder) / "reference.txt"
            args.reference.write_text("Approved sample words.")
            with (patch.object(probe, "run", side_effect=self.fake_adb) as commands,
                  patch.object(probe.subprocess, "run", return_value=self.native_output()),
                  patch.object(probe.time, "sleep"), contextlib.redirect_stdout(io.StringIO())):
                probe.benchmark(args)
            encoded = args.output.read_text()
            report = json.loads(encoded)
            self.assertEqual(len(report["runs"]), 4)
            self.assertNotIn("approved sample words", encoded)
            self.assertNotIn(folder, encoded)
            self.assertNotIn("test-device", encoded)
            self.assertTrue(report["runs"][0]["warmup"])
            self.assertFalse(report["runs"][-1]["warmup"])
            self.assertEqual(report["reference_sha256"], probe.digest(args.reference))
            self.assertEqual(report["runs"][-1]["word_error_rate"], 0)
            cleanup = commands.call_args_list[-1].args[0]
            self.assertEqual(cleanup[3:6], ["shell", "rm", "-r"])
            self.assertTrue(cleanup[-1].startswith("/data/local/tmp/smartnotes-whisper-"))
            self.assertEqual(list(Path(folder).glob("fixture-*.f32")), [])

    def test_runner_preserves_report_and_cleans_up_after_native_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.fixture_args(folder)
            failed = subprocess.CompletedProcess([], 1, stdout=json.dumps({
                "error": "vulkan_device_missing"}), stderr="private-path-must-not-leak")
            with (patch.object(probe, "run", side_effect=self.fake_adb),
                  patch.object(probe.subprocess, "run", return_value=failed),
                  self.assertRaises(RuntimeError)):
                probe.benchmark(args)
            report = json.loads(args.output.read_text())
            self.assertTrue(report["runs"][0]["failed"])
            self.assertEqual(report["runs"][0]["error"], "vulkan_device_missing")
            self.assertNotIn("private-path", args.output.read_text())
            self.assertEqual(list(Path(folder).glob("fixture-*.f32")), [])

    def test_runner_requires_explicit_fixture_approval(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.fixture_args(folder)
            args.approved_fixture = False
            with patch.object(probe, "run") as commands, self.assertRaises(ValueError):
                probe.benchmark(args)
            commands.assert_not_called()

    def test_timeout_targets_only_this_invocations_process_and_saves_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.fixture_args(folder)
            with (patch.object(probe, "run", side_effect=self.fake_adb) as commands,
                  patch.object(probe.subprocess, "run", side_effect=subprocess.TimeoutExpired("adb", 1)),
                  self.assertRaises(RuntimeError)):
                probe.benchmark(args)
            kill_commands = [call.args[0][-1] for call in commands.call_args_list
                             if isinstance(call.args[0][-1], str) and "pkill -f" in call.args[0][-1]]
            self.assertEqual(len(kill_commands), 1)
            self.assertIn("'^/data/local/tmp/smartnotes-whisper-", kill_commands[0])
            self.assertIn("/cpu '", kill_commands[0])
            report = json.loads(args.output.read_text())
            self.assertEqual(report["runs"][0]["error"], "host_timeout")

    def test_modified_executable_is_rejected_before_adb(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.fixture_args(folder)
            (args.work / "build-vulkan/smartnotes-whisper-probe").write_bytes(b"modified")
            with patch.object(probe, "run") as commands, self.assertRaises(ValueError):
                probe.benchmark(args)
            commands.assert_not_called()

    def test_runner_rejects_mismatching_model_before_adb(self):
        with tempfile.TemporaryDirectory() as folder:
            args = self.fixture_args(folder)
            args.model_sha256 = "0" * 64
            with patch.object(probe, "run") as commands, self.assertRaises(ValueError):
                probe.benchmark(args)
            commands.assert_not_called()

    def test_reference_normalization_preserves_unicode(self):
        self.assertEqual(probe.word_error_rate("Olá, PROJETO!", "olá projeto"), 0)

    def test_wer_counts_substitution_insertion_deletion(self):
        self.assertEqual(probe.word_error_rate("one two three", "one four three"), 1 / 3)
        self.assertEqual(probe.word_error_rate("one two", "one two three"), 1 / 2)
        self.assertEqual(probe.word_error_rate("one two", "one"), 1 / 2)

    def test_empty_hypothesis_is_full_deletion(self):
        self.assertEqual(probe.word_error_rate("one two", ""), 1)

    def test_empty_reference_is_rejected(self):
        with self.assertRaises(ValueError):
            probe.word_error_rate("...", "one")

    def test_cached_download_still_verifies_digest(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "artifact"
            path.write_bytes(b"verified fixture")
            with patch.object(probe.urllib.request, "urlopen") as fetch:
                probe.download("https://example.invalid", path,
                               hashlib.sha256(b"verified fixture").hexdigest())
                fetch.assert_not_called()

    def test_corrupt_download_is_never_promoted(self):
        import io
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "artifact"
            path.write_bytes(b"previous artifact")
            with patch.object(probe.urllib.request, "urlopen", return_value=io.BytesIO(b"corrupt")):
                with self.assertRaises(ValueError):
                    probe.download("https://example.invalid", path, "0" * 64)
            self.assertEqual(path.read_bytes(), b"previous artifact")

    def test_sources_use_immutable_revisions_and_checksums(self):
        for repository, revision, digest in probe.SOURCES.values():
            self.assertEqual(len(revision), 40)
            self.assertEqual(len(digest), 64)
            int(revision, 16)
            int(digest, 16)
            self.assertNotIn("..", repository)


if __name__ == "__main__":
    unittest.main()
