"""对独立参数试算模型做快速、确定性回归。"""

from __future__ import annotations

import random
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from experiment_model import (
    ExperimentConfig,
    Match,
    WordDefinition,
    count_sampled_pk_midpoint_crossings,
    run_single_replay,
    summarize_sampled_trend,
)


class AlwaysSuccess:
    def random(self) -> float:
        return 0.0


class AlwaysFailure:
    def random(self) -> float:
        return 1.0


class PlanBExperimentModelTests(unittest.TestCase):
    def setUp(self) -> None:
        self.match = Match(ExperimentConfig("test", "test"), seed=73, strategy="tactical")

    def neutral_ids(self, count: int = 4) -> list[int]:
        return [unit.unit_id for unit in self.match.units.values() if unit.team == "neutral"][:count]

    def test_failed_publish_does_not_consume_word_or_shared_order(self) -> None:
        first_neutral, second_neutral = self.neutral_ids(2)
        player_word = next(iter(self.match.pools["player"]))
        missing_word = "missing_word"
        self.assertFalse(self.match.publish_word("player", player_word, -1)["ok"])
        self.assertFalse(self.match.publish_word("player", missing_word, first_neutral)["ok"])
        self.assertEqual(self.match.next_word_order, 1)
        self.assertNotIn(player_word, self.match.used_words["player"])

        player_result = self.match.publish_word("player", player_word, first_neutral)
        self.assertTrue(player_result["ok"])
        self.assertEqual(player_result["word_order"], 1)
        self.assertFalse(self.match.publish_word("player", player_word, second_neutral)["ok"])
        self.assertEqual(self.match.next_word_order, 2)

        opponent_word = next(iter(self.match.pools["opponent"]))
        opponent_result = self.match.publish_word("opponent", opponent_word, second_neutral)
        self.assertTrue(opponent_result["ok"])
        self.assertEqual(opponent_result["word_order"], 2)

    def test_same_team_relay_inherits_entire_new_word_and_keeps_counts(self) -> None:
        first_id, second_id = self.neutral_ids(2)
        newer = WordDefinition("new", "new phrase", "type_c", 3, ("test_trait",), "heresy")
        older = WordDefinition("old", "old phrase", "type_a", 1, (), "neutral")
        first = self.match.units[first_id]
        second = self.match.units[second_id]
        first.team, first.word, first.word_order = "player", newer, 9
        second.team, second.word, second.word_order = "player", older, 4
        before = self.match.faction_counts()

        result = self.match.contact_units(first_id, second_id, force=True)

        self.assertEqual(result, "relay")
        self.assertEqual(second.word, newer)
        self.assertEqual(second.word_order, 9)
        self.assertEqual(self.match.faction_counts(), before)

    def test_equal_enemy_type_bounces_and_countered_enemy_can_convert(self) -> None:
        first_id, second_id = self.neutral_ids(2)
        first, second = self.match.units[first_id], self.match.units[second_id]
        first.team = "player"
        first.word = WordDefinition("a", "A", "type_a", 3)
        first.word_order = 1
        second.team = "opponent"
        second.word = WordDefinition("a2", "A2", "type_a", 1)
        second.word_order = 2
        self.match.rng = AlwaysSuccess()  # type: ignore[assignment]
        before = self.match.faction_counts()
        self.assertEqual(self.match.contact_units(first_id, second_id, force=True), "equal_type_bounce")
        self.assertEqual(self.match.faction_counts(), before)

        second.word = WordDefinition("b", "B", "type_b", 3)
        result = self.match.contact_units(first_id, second_id, force=True)
        self.assertEqual(result, "converted")
        self.assertEqual(second.team, "player")
        self.assertEqual(second.word.word_id, "a")  # type: ignore[union-attr]

    def test_strength_chances_increase_by_tier(self) -> None:
        probabilities = (0.20, 0.35, 0.50)
        measured: list[float] = []
        sample_count = 20000
        source_id, target_id = self.neutral_ids(2)
        source = self.match.units[source_id]
        target = self.match.units[target_id]
        source.team = "player"
        source.word_order = 1
        for strength in range(1, 4):
            source.word = WordDefinition("test_strength_%d" % strength, "test", "type_a", strength)
            self.match.rng = random.Random(20261017)
            successes = 0
            for _ in range(sample_count):
                target.team = "neutral"
                target.word = None
                target.word_order = 0
                if self.match.contact_units(source_id, target_id, force=True) == "converted":
                    successes += 1
            measured.append(successes / sample_count)
            self.assertAlmostEqual(measured[-1], probabilities[strength - 1], delta=0.015)
        self.assertLess(measured[0], measured[1])
        self.assertLess(measured[1], measured[2])

    def test_pk_is_population_delta_and_clamps_at_zero_and_hundred(self) -> None:
        first_id, second_id = self.neutral_ids(2)
        for unit in self.match.units.values():
            unit.team = "neutral"
        self.match.units[first_id].team = "player"
        self.match.units[first_id].word = WordDefinition("p", "P", "type_a", 1)
        self.match.units[second_id].team = "player"
        self.match.units[second_id].word = WordDefinition("p2", "P2", "type_a", 1)
        self.match.pk = 99.99
        self.match.update_pk(1.0)
        self.assertEqual(self.match.pk, 100.0)

        self.match.pk = 0.01
        for unit in self.match.units.values():
            unit.team = "neutral"
        self.match.units[first_id].team = "opponent"
        self.match.units[second_id].team = "opponent"
        self.match.update_pk(1.0)
        self.assertEqual(self.match.pk, 0.0)

    def test_fixed_seed_replays_same_result_and_trend(self) -> None:
        config = ExperimentConfig("replay", "test")
        first = Match(config, seed=20261017, strategy="random_word").run()
        second = Match(config, seed=20261017, strategy="random_word").run()
        self.assertEqual(first, second)
        sample_times = [float(point["time_s"]) for point in first.trend]
        self.assertIn(30.0, sample_times)
        self.assertEqual(len(sample_times), len(set(sample_times)))

    def test_single_replay_command_writes_complete_json_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            result = run_single_replay("base", "tactical", 20261017, Path(temporary_dir))
            replay = json.loads((Path(temporary_dir) / "experiment_replay.json").read_text(encoding="utf-8"))
        self.assertEqual(replay["classification"], "model_only_not_godot_or_human_playtest")
        self.assertEqual(replay["seed"], 20261017)
        self.assertEqual(replay["strategy"], "tactical")
        self.assertEqual(replay["result"]["outcome"], result.outcome)
        self.assertTrue(any(point["time_s"] == 30.0 for point in replay["result"]["trend"]))

    def test_sampled_midpoint_crossings_mark_comebacks(self) -> None:
        trend = [
            {"time_s": 0.0, "pk": 50.0},
            {"time_s": 30.0, "pk": 57.0},
            {"time_s": 60.0, "pk": 44.0},
            {"time_s": 90.0, "pk": 52.0},
            {"time_s": 120.0, "pk": 100.0},
        ]
        self.assertEqual(count_sampled_pk_midpoint_crossings(trend), 2)

    def test_sampled_metrics_report_neutral_shortage_snowball_and_jitter(self) -> None:
        trend = [
            {"time_s": 0.0, "pk": 50.0, "player": 10, "opponent": 10, "neutral": 80, "player_words": 0, "opponent_words": 1},
            {"time_s": 30.0, "pk": 57.0, "player": 90, "opponent": 5, "neutral": 3, "player_words": 3, "opponent_words": 1},
            {"time_s": 60.0, "pk": 60.0, "player": 95, "opponent": 2, "neutral": 1, "player_words": 7, "opponent_words": 1},
            {"time_s": 90.0, "pk": 44.0, "player": 40, "opponent": 50, "neutral": 8, "player_words": 7, "opponent_words": 1},
            {"time_s": 120.0, "pk": 52.0, "player": 60, "opponent": 30, "neutral": 8, "player_words": 8, "opponent_words": 1},
        ]
        summary = summarize_sampled_trend(trend)
        self.assertEqual(summary["longest_neutral_shortage_s"], 60.0)
        self.assertAlmostEqual(float(summary["max_team_share"]), 95.0 / 98.0)
        self.assertEqual(summary["max_sampled_pk_change_pp_per_30s"], 16.0)
        self.assertEqual(summary["peak_words_published_per_30s"], 4)


if __name__ == "__main__":
    unittest.main()
