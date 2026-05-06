from __future__ import annotations

import importlib.util
from importlib.machinery import SourceFileLoader
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
HELPER_PATH = REPO_ROOT / "scripts" / "dns" / "adguard-rewrite"


def load_helper():
    loader = SourceFileLoader("adguard_rewrite", str(HELPER_PATH))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


helper = load_helper()


class ValidationTests(unittest.TestCase):
    def test_normalize_domain_accepts_exact_home_lan(self):
        cases = [
            ("Termix.Home.Lan", "termix.home.lan"),
            ("termix.home.lan.", "termix.home.lan"),
            ("svc-01.home.lan", "svc-01.home.lan"),
            ("deep.service.home.lan", "deep.service.home.lan"),
        ]
        for raw, expected in cases:
            with self.subTest(raw=raw):
                self.assertEqual(helper.normalize_domain(raw), expected)

    def test_normalize_domain_rejects_disallowed_names(self):
        cases = [
            "*.home.lan",
            "termix.example.com",
            "termix.local",
            "home.lan",
            "-bad.home.lan",
            "bad-.home.lan",
            "bad_name.home.lan",
            "bad/name.home.lan",
            "bad;name.home.lan",
            "",
        ]
        for raw in cases:
            with self.subTest(raw=raw):
                with self.assertRaises(helper.RewriteError):
                    helper.normalize_domain(raw)

    def test_validate_rfc1918_ipv4_accepts_private_ranges(self):
        cases = [
            "10.0.0.1",
            "172.16.0.1",
            "172.31.255.254",
            "192.168.30.10",
        ]
        for raw in cases:
            with self.subTest(raw=raw):
                self.assertEqual(helper.validate_rfc1918_ipv4(raw), raw)

    def test_validate_rfc1918_ipv4_rejects_non_rfc1918(self):
        cases = [
            "8.8.8.8",
            "1.1.1.1",
            "172.32.0.1",
            "169.254.1.1",
            "100.64.0.1",
            "fd12:3456:7801::55",
            "not-an-ip",
            "",
        ]
        for raw in cases:
            with self.subTest(raw=raw):
                with self.assertRaises(helper.RewriteError):
                    helper.validate_rfc1918_ipv4(raw)

    def test_add_detects_exact_entry(self):
        rewrites = [{"domain": "termix.home.lan", "answer": "192.168.30.10"}]
        self.assertTrue(helper.has_exact_entry(rewrites, "termix.home.lan", "192.168.30.10"))

    def test_find_entries_uses_normalized_domain_only(self):
        rewrites = [
            {"domain": "termix.home.lan", "answer": "192.168.30.10"},
            {"domain": "kuma.home.lan", "answer": "192.168.30.10"},
        ]
        self.assertEqual(helper.find_entries(rewrites, "termix.home.lan"), [rewrites[0]])


if __name__ == "__main__":
    unittest.main()
