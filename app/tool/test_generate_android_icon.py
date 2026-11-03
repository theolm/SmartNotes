"""Run with the same development dependencies as generate_android_icon.py."""
import math
import unittest

import pathops
from fontTools.svgLib.path import parse_path

from generate_android_icon import seal


class VectorGeometryTest(unittest.TestCase):
    def setUp(self):
        self.path = pathops.Path()
        parse_path(seal(), self.path.getPen())

    def test_bounds_fit_launcher_and_splash_safe_circles(self):
        self.assertEqual(self.path.bounds, (220, 220, 804, 804))
        self.assertLess(292, 1024 * 33 / 108)
        self.assertLess(292, 1024 / 3)
        for degrees in range(360):
            angle = math.radians(degrees)
            self.assertFalse(self.path.contains((512 + 294 * math.cos(angle), 512 + 294 * math.sin(angle))))

    def test_quotes_are_transparent_including_overlapping_shapes(self):
        self.assertTrue(self.path.contains((512, 512)))
        for x, y in [(342, 420), (482, 420), (682, 604), (542, 604),
                     (412, 420), (612, 604), (246, 252), (778, 772)]:
            self.assertFalse(self.path.contains((153.6 + .7 * x, 153.6 + .7 * y)))

    def test_export_is_deterministic(self):
        self.assertEqual(seal(), seal())


if __name__ == '__main__':
    unittest.main()
