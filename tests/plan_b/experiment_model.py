"""Plan B V0 balancing model. This is analysis-only and does not emulate Godot physics exactly."""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
import statistics
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = Path(__file__).resolve().parent / "results"
TYPES = ("type_a", "type_b", "type_c")
STRATEGIES = ("no_op", "single_type", "random_word", "tactical")
MAX_SECONDS = 240.0  # 仅作实验截断上限，不代表正式超时规则。
DT = 0.2
PUBLISHER_SPAWN_RADIUS = 14.0
GRID_CELL = 112.0


@dataclass(frozen=True)
class ExperimentConfig:
    """仅存放本轮五项可调参数及与玩法文档一致的模型固定值。"""

    config_id: str
    varied_parameter: str
    pk_k: float = 0.85
    population_cap: int = 96
    infection_chances: tuple[float, float, float] = (0.20, 0.35, 0.50)
    natural_lifetime_mean_s: float = 65.0
    natural_lifetime_sd_s: float = 12.0
    player_cooldown_s: float = 5.0
    opponent_cooldown_s: float = 11.5


@dataclass(frozen=True)
class WordDefinition:
    word_id: str
    text: str
    battle_type: str
    strength: int
    traits: tuple[str, ...] = ()
    tendency: str = "neutral"


@dataclass
class Unit:
    unit_id: int
    team: str
    word: WordDefinition | None
    word_order: int
    x: float
    y: float
    vx: float
    vy: float
    age_s: float
    lifetime_s: float
    steer_due_s: float = 0.0


@dataclass
class MatchResult:
    config: ExperimentConfig
    seed: int
    strategy: str
    outcome: str
    model_seconds: float
    min_pk: float
    max_pk: float
    sampled_pk_midpoint_crossings: int
    longest_neutral_shortage_s: float
    max_team_share: float
    max_sampled_pk_change_pp_per_30s: float
    peak_words_published_per_30s: int
    final_pk: float
    player_count: int
    opponent_count: int
    neutral_count: int
    player_words: int
    opponent_words: int
    contact_resolutions: int
    legal_infection_attempts: int
    conversions: int
    relays: int
    equal_type_bounces: int
    trend: list[dict[str, float | int | str]] = field(default_factory=list)


def type_beats(attacker_type: str, target_type: str) -> bool:
    """使用临时三角克制表判断感染是否合法。"""
    return (attacker_type, target_type) in {
        ("type_a", "type_b"),
        ("type_b", "type_c"),
        ("type_c", "type_a"),
    }


def count_sampled_pk_midpoint_crossings(trend: list[dict[str, float | int | str]]) -> int:
    """按 30 秒 PK 采样点估计比赛中途回到另一方优势区的次数。"""
    previous_side = 0
    crossings = 0
    for sample in trend:
        pk_value = float(sample["pk"])
        current_side = 1 if pk_value > 50.0 else -1 if pk_value < 50.0 else 0
        if current_side != 0:
            if previous_side != 0 and current_side != previous_side:
                crossings += 1
            previous_side = current_side
    return crossings


def summarize_sampled_trend(trend: list[dict[str, float | int | str]]) -> dict[str, float | int]:
    """提取 30 秒采样可见的中立短缺、人数滚雪球和话语/PK 峰值。"""
    longest_neutral_shortage_s = 0.0
    current_shortage_samples = 0
    max_team_share = 0.0
    max_sampled_pk_change = 0.0
    peak_words_published = 0
    previous: dict[str, float | int | str] | None = None
    for sample in trend:
        total = int(sample["player"]) + int(sample["opponent"]) + int(sample["neutral"])
        if total > 0:
            max_team_share = max(
                max_team_share,
                max(int(sample["player"]), int(sample["opponent"])) / total,
            )
        if int(sample["neutral"]) <= 3:
            current_shortage_samples += 1
            longest_neutral_shortage_s = max(longest_neutral_shortage_s, current_shortage_samples * 30.0)
        else:
            current_shortage_samples = 0
        if previous is not None:
            max_sampled_pk_change = max(max_sampled_pk_change, abs(float(sample["pk"]) - float(previous["pk"])))
            previous_word_count = int(previous["player_words"]) + int(previous["opponent_words"])
            current_word_count = int(sample["player_words"]) + int(sample["opponent_words"])
            peak_words_published = max(peak_words_published, current_word_count - previous_word_count)
        previous = sample
    return {
        "longest_neutral_shortage_s": longest_neutral_shortage_s,
        "max_team_share": max_team_share,
        "max_sampled_pk_change_pp_per_30s": max_sampled_pk_change,
        "peak_words_published_per_30s": peak_words_published,
    }


def build_word_pool(team: str) -> dict[str, WordDefinition]:
    """生成 TEST_ONLY 词库；这些 ID 和文本不进入正式 03 表。"""
    pool: dict[str, WordDefinition] = {}
    for battle_type in TYPES:
        for strength in (1, 2, 3):
            for index in range(4):
                word_id = f"test_{team}_{battle_type[-1]}_s{strength}_{index + 1:02d}"
                pool[word_id] = WordDefinition(
                    word_id=word_id,
                    text=f"TEST_ONLY {team} {battle_type} strength {strength} line {index + 1}",
                    battle_type=battle_type,
                    strength=strength,
                    tendency="heresy" if team == "player" else "orthodoxy",
                )
    return pool


class Match:
    """以固定随机种子复现发表、接触、自然离场和人数驱动 PK 的试算模型。"""

    def __init__(self, config: ExperimentConfig, seed: int, strategy: str) -> None:
        self.config = config
        self.seed = seed
        self.strategy = strategy
        self.rng = random.Random(seed)
        self.width = 900.0
        self.height = 490.0
        self.time_s = 0.0
        self.pk = 50.0
        self.minimum_pk = self.pk
        self.maximum_pk = self.pk
        self.next_unit_id = 1
        self.next_word_order = 1
        self.next_recruit_s = 0.75
        self.next_player_publish_s = 0.0
        self.next_opponent_publish_s = 0.0
        self.last_contact_s: dict[tuple[int, int], float] = {}
        self.units: dict[int, Unit] = {}
        self.pools = {"player": build_word_pool("player"), "opponent": build_word_pool("opponent")}
        self.used_words: dict[str, set[str]] = {"player": set(), "opponent": {"fermi_initial"}}
        self.player_word_count = 0
        self.opponent_word_count = 1  # 开局费米的两名棋子共用一条初始发言。
        self.contact_resolutions = 0
        self.legal_infection_attempts = 0
        self.conversions = 0
        self.relays = 0
        self.equal_type_bounces = 0
        self._sample_at_s = 30.0
        self.trend: list[dict[str, float | int | str]] = []

        for _ in range(76 if config.population_cap == 96 else max(config.population_cap - 20, 0)):
            self._spawn_unit("neutral", None, 0)
        opening_word = WordDefinition("fermi_initial", "TEST_ONLY opening line", "type_b", 2)
        for _ in range(2):
            self._spawn_unit("opponent", opening_word, 0)
        self._record_trend()

    def faction_counts(self) -> dict[str, int]:
        counts = {"player": 0, "opponent": 0, "neutral": 0}
        for unit in self.units.values():
            counts[unit.team] += 1
        return counts

    def snapshots(self) -> list[dict[str, object]]:
        """返回独立副本，模拟只读棋子快照的公开形态。"""
        return [
            {
                "unit_id": unit.unit_id,
                "team": unit.team,
                "word_id": unit.word.word_id if unit.word else "",
                "word": unit.word,
                "word_order": unit.word_order,
                "battle_type": unit.word.battle_type if unit.word else "",
                "strength": unit.word.strength if unit.word else 0,
                "position": (unit.x, unit.y),
            }
            for unit in sorted(self.units.values(), key=lambda item: item.unit_id)
        ]

    def publish_word(self, team: str, word_id: str, neutral_unit_id: int) -> dict[str, object]:
        """双方共用的发表入口；只有播种成功才消耗词、冷却和全局顺序号。"""
        if team not in ("player", "opponent"):
            return {"ok": False, "reason": "invalid_team"}
        pool = self.pools[team]
        if word_id not in pool or word_id in self.used_words[team]:
            return {"ok": False, "reason": "word_unavailable"}
        ready_at = self.next_player_publish_s if team == "player" else self.next_opponent_publish_s
        if self.time_s + 1e-9 < ready_at:
            return {"ok": False, "reason": "cooldown"}
        neutral = self.units.get(neutral_unit_id)
        if neutral is None or neutral.team != "neutral":
            return {"ok": False, "reason": "target_not_neutral"}

        word = pool[word_id]
        word_order = self.next_word_order
        neutral.team = team
        neutral.word = word
        neutral.word_order = word_order
        self.used_words[team].add(word_id)
        self.next_word_order += 1
        if team == "player":
            self.player_word_count += 1
            self.next_player_publish_s = self.time_s + self.config.player_cooldown_s
        else:
            self.opponent_word_count += 1
            self.next_opponent_publish_s = self.time_s + self.config.opponent_cooldown_s
        return {"ok": True, "reason": "", "word_order": word_order}

    def contact_units(self, first_id: int, second_id: int, *, force: bool = False) -> str:
        """裁决一对接触棋子，便于对照规则进行固定种子回放。"""
        first = self.units.get(first_id)
        second = self.units.get(second_id)
        if first is None or second is None or first_id == second_id:
            return "invalid"
        pair = tuple(sorted((first_id, second_id)))
        if not force and self.time_s < self.last_contact_s.get(pair, -1.0):
            return "cooldown"
        self.last_contact_s[pair] = self.time_s + 0.7
        self.contact_resolutions += 1

        if first.team == second.team:
            if first.word_order == second.word_order:
                return "same_team_same_word"
            newer, older = (first, second) if first.word_order > second.word_order else (second, first)
            older.word = newer.word
            older.word_order = newer.word_order
            self.relays += 1
            return "relay"

        if "neutral" in (first.team, second.team):
            neutral = first if first.team == "neutral" else second
            source = second if neutral is first else first
            if source.word is None:
                return "neutral_banter"
            return self._try_conversion(source, neutral)

        if first.word is None or second.word is None:
            return "missing_word"
        if first.word.battle_type == second.word.battle_type:
            self.equal_type_bounces += 1
            return "equal_type_bounce"
        if type_beats(first.word.battle_type, second.word.battle_type):
            return self._try_conversion(first, second)
        if type_beats(second.word.battle_type, first.word.battle_type):
            return self._try_conversion(second, first)
        return "unresolved_matchup"

    def update_pk(self, elapsed_s: float) -> None:
        """只按实时阵营人数差和经过时间推进 PK，不给感染事件额外加分。"""
        counts = self.faction_counts()
        total = sum(counts.values())
        if total:
            difference = counts["player"] - counts["opponent"]
            self.pk += self.config.pk_k * difference / total * elapsed_s
        self.pk = min(100.0, max(0.0, self.pk))
        self.minimum_pk = min(self.minimum_pk, self.pk)
        self.maximum_pk = max(self.maximum_pk, self.pk)

    def run(self) -> MatchResult:
        """推进固定步长试算，240 秒只作为数据截断点。"""
        while self.time_s + DT <= MAX_SECONDS and 0.0 < self.pk < 100.0:
            self._step()
        counts = self.faction_counts()
        outcome = "player_100" if self.pk >= 100.0 else "opponent_0" if self.pk <= 0.0 else "censored_240s"
        self._record_trend()
        trend_summary = summarize_sampled_trend(self.trend)
        return MatchResult(
            config=self.config,
            seed=self.seed,
            strategy=self.strategy,
            outcome=outcome,
            model_seconds=round(self.time_s, 2),
            min_pk=round(self.minimum_pk, 3),
            max_pk=round(self.maximum_pk, 3),
            sampled_pk_midpoint_crossings=count_sampled_pk_midpoint_crossings(self.trend),
            longest_neutral_shortage_s=float(trend_summary["longest_neutral_shortage_s"]),
            max_team_share=round(float(trend_summary["max_team_share"]), 4),
            max_sampled_pk_change_pp_per_30s=round(float(trend_summary["max_sampled_pk_change_pp_per_30s"]), 3),
            peak_words_published_per_30s=int(trend_summary["peak_words_published_per_30s"]),
            final_pk=round(self.pk, 3),
            player_count=counts["player"],
            opponent_count=counts["opponent"],
            neutral_count=counts["neutral"],
            player_words=self.player_word_count,
            opponent_words=self.opponent_word_count,
            contact_resolutions=self.contact_resolutions,
            legal_infection_attempts=self.legal_infection_attempts,
            conversions=self.conversions,
            relays=self.relays,
            equal_type_bounces=self.equal_type_bounces,
            trend=self.trend,
        )

    def _step(self) -> None:
        self.time_s = round(self.time_s + DT, 6)
        self._publish_if_ready("player")
        self._publish_if_ready("opponent")
        self._spawn_replacements()
        grid = self._make_grid(GRID_CELL)
        for unit in list(self.units.values()):
            unit.age_s += DT
            if unit.age_s >= unit.lifetime_s:
                self.units.pop(unit.unit_id, None)
                continue
            if self.time_s >= unit.steer_due_s:
                self._steer(unit, grid)
                unit.steer_due_s = self.time_s + 0.4
            unit.x += unit.vx * DT
            unit.y += unit.vy * DT
            self._reflect_at_edges(unit)
        self._resolve_nearby_contacts()
        self.update_pk(DT)
        if self.time_s >= self._sample_at_s:
            self._record_trend()
            self._sample_at_s += 30.0

    def _publish_if_ready(self, team: str) -> None:
        neutrals = [unit for unit in self.units.values() if unit.team == "neutral"]
        if not neutrals:
            return
        if team == "player":
            if self.strategy == "no_op" or self.time_s + 1e-9 < self.next_player_publish_s:
                return
            word = self._select_player_word()
            target = self._select_player_target(neutrals)
        else:
            if self.time_s + 1e-9 < self.next_opponent_publish_s:
                return
            word = self._select_opponent_word()
            target = self._select_opponent_target(neutrals)
        if word is not None and target is not None:
            self.publish_word(team, word.word_id, target.unit_id)

    def _select_player_word(self) -> WordDefinition | None:
        available = [word for word in self.pools["player"].values() if word.word_id not in self.used_words["player"]]
        if not available:
            return None
        if self.strategy == "single_type":
            matches = [word for word in available if word.battle_type == "type_a" and word.strength == 3]
            return matches[0] if matches else None
        if self.strategy == "random_word":
            return self.rng.choice(available)
        if self.strategy == "tactical":
            counts: dict[str, int] = {battle_type: 0 for battle_type in TYPES}
            for unit in self.units.values():
                if unit.team == "opponent" and unit.word is not None:
                    counts[unit.word.battle_type] += 1
            dominant = max(TYPES, key=lambda item: (counts[item], item))
            winner_type = next((battle_type for battle_type in TYPES if type_beats(battle_type, dominant)), "type_a")
            matches = [word for word in available if word.battle_type == winner_type and word.strength == 3]
            return matches[0] if matches else self.rng.choice(available)
        return None

    def _select_opponent_word(self) -> WordDefinition | None:
        available = [word for word in self.pools["opponent"].values() if word.word_id not in self.used_words["opponent"]]
        if not available:
            return None
        player_types: dict[str, int] = {battle_type: 0 for battle_type in TYPES}
        for unit in self.units.values():
            if unit.team == "player" and unit.word is not None:
                player_types[unit.word.battle_type] += 1
        if not sum(player_types.values()):
            matches = [word for word in available if word.battle_type == "type_b" and word.strength == 2]
            return matches[0] if matches else self.rng.choice(available)
        dominant = max(TYPES, key=lambda item: (player_types[item], item))
        counter = next((battle_type for battle_type in TYPES if type_beats(battle_type, dominant)), "type_a")
        matches = [word for word in available if word.battle_type == counter]
        return self.rng.choice(matches) if matches else self.rng.choice(available)

    def _select_player_target(self, neutrals: list[Unit]) -> Unit:
        if self.strategy != "tactical":
            return self.rng.choice(neutrals)
        friends = [unit for unit in self.units.values() if unit.team == "player"]
        if not friends:
            center_x, center_y = self.width * 0.45, self.height * 0.5
        else:
            center_x = statistics.fmean(unit.x for unit in friends)
            center_y = statistics.fmean(unit.y for unit in friends)
        enemies = [unit for unit in self.units.values() if unit.team == "opponent"]
        if enemies:
            enemy_x = statistics.fmean(unit.x for unit in enemies)
            enemy_y = statistics.fmean(unit.y for unit in enemies)
        else:
            enemy_x, enemy_y = self.width * 0.65, self.height * 0.5
        # 靠近己方以利传话，同时避免把新信徒直接放进敌方群体中心。
        return min(neutrals, key=lambda unit: math.dist((unit.x, unit.y), (center_x, center_y)) + 0.25 * max(0.0, 120.0 - math.dist((unit.x, unit.y), (enemy_x, enemy_y))))

    def _select_opponent_target(self, neutrals: list[Unit]) -> Unit:
        opponents = [unit for unit in self.units.values() if unit.team == "opponent"]
        if not opponents:
            return self.rng.choice(neutrals)
        center_x = statistics.fmean(unit.x for unit in opponents)
        center_y = statistics.fmean(unit.y for unit in opponents)
        return min(neutrals, key=lambda unit: math.dist((unit.x, unit.y), (center_x, center_y)))

    def _spawn_replacements(self) -> None:
        if self.time_s < self.next_recruit_s:
            return
        self.next_recruit_s += 0.75
        if len(self.units) < self.config.population_cap:
            self._spawn_unit("neutral", None, 0)

    def _spawn_unit(self, team: str, word: WordDefinition | None, word_order: int) -> Unit:
        angle = self.rng.uniform(0.0, math.tau)
        speed = self.rng.uniform(52.0, 78.0)
        lifetime = max(25.0, self.rng.gauss(self.config.natural_lifetime_mean_s, self.config.natural_lifetime_sd_s))
        unit = Unit(
            unit_id=self.next_unit_id,
            team=team,
            word=word,
            word_order=word_order,
            x=self.rng.uniform(0.0, self.width),
            y=self.rng.uniform(0.0, self.height),
            vx=math.cos(angle) * speed,
            vy=math.sin(angle) * speed,
            age_s=0.0,
            lifetime_s=lifetime,
            steer_due_s=self.rng.uniform(0.0, 0.4),
        )
        self.units[unit.unit_id] = unit
        self.next_unit_id += 1
        return unit

    def _try_conversion(self, source: Unit, target: Unit) -> str:
        if source.word is None:
            return "missing_word"
        self.legal_infection_attempts += 1
        chance = self.config.infection_chances[source.word.strength - 1]
        if self.rng.random() >= chance:
            return "infection_failed"
        target.team = source.team
        target.word = source.word
        target.word_order = source.word_order
        self.conversions += 1
        return "converted"

    def _make_grid(self, cell_size: float) -> dict[tuple[int, int], list[Unit]]:
        grid: dict[tuple[int, int], list[Unit]] = {}
        for unit in self.units.values():
            key = (int(unit.x // cell_size), int(unit.y // cell_size))
            grid.setdefault(key, []).append(unit)
        return grid

    def _neighbors(self, unit: Unit, grid: dict[tuple[int, int], list[Unit]], cell_size: float, radius_cells: int = 2) -> Iterable[Unit]:
        cell_x, cell_y = int(unit.x // cell_size), int(unit.y // cell_size)
        for dx in range(-radius_cells, radius_cells + 1):
            for dy in range(-radius_cells, radius_cells + 1):
                yield from grid.get((cell_x + dx, cell_y + dy), ())

    def _steer(self, unit: Unit, grid: dict[tuple[int, int], list[Unit]]) -> None:
        speed = max(52.0, math.hypot(unit.vx, unit.vy))
        wander_angle = self.rng.uniform(0.0, math.tau)
        steer_x, steer_y = math.cos(wander_angle) * 0.35, math.sin(wander_angle) * 0.35
        nearby = [other for other in self._neighbors(unit, grid, GRID_CELL) if other.unit_id != unit.unit_id and math.dist((unit.x, unit.y), (other.x, other.y)) < 180.0]
        if unit.team != "neutral" and unit.word is not None:
            threats = [other for other in nearby if other.team not in (unit.team, "neutral") and other.word is not None and type_beats(other.word.battle_type, unit.word.battle_type)]
            prey = [other for other in nearby if other.team == "neutral" or (other.team not in (unit.team, "neutral") and other.word is not None and type_beats(unit.word.battle_type, other.word.battle_type))]
            target_list = threats if threats else prey
            if target_list:
                target = min(target_list, key=lambda other: math.dist((unit.x, unit.y), (other.x, other.y)))
                direction = -1.0 if threats else 1.0
                distance = max(1.0, math.dist((unit.x, unit.y), (target.x, target.y)))
                steer_x += direction * (target.x - unit.x) / distance * 1.4
                steer_y += direction * (target.y - unit.y) / distance * 1.4
        magnitude = max(0.001, math.hypot(steer_x, steer_y))
        unit.vx = steer_x / magnitude * speed
        unit.vy = steer_y / magnitude * speed

    def _resolve_nearby_contacts(self) -> None:
        grid = self._make_grid(PUBLISHER_SPAWN_RADIUS * 2.0)
        checked: set[tuple[int, int]] = set()
        for unit in list(self.units.values()):
            for other in self._neighbors(unit, grid, PUBLISHER_SPAWN_RADIUS * 2.0, radius_cells=1):
                if other.unit_id <= unit.unit_id:
                    continue
                pair = (unit.unit_id, other.unit_id)
                if pair in checked or math.dist((unit.x, unit.y), (other.x, other.y)) > PUBLISHER_SPAWN_RADIUS * 2.0:
                    continue
                checked.add(pair)
                if self.time_s >= self.last_contact_s.get(pair, -1.0):
                    self.contact_units(*pair)
                    self._separate(unit, other)

    def _separate(self, first: Unit, second: Unit) -> None:
        dx, dy = second.x - first.x, second.y - first.y
        distance = max(0.001, math.hypot(dx, dy))
        if distance >= PUBLISHER_SPAWN_RADIUS * 2.0:
            return
        nx, ny = dx / distance, dy / distance
        overlap = PUBLISHER_SPAWN_RADIUS * 2.0 - distance
        first.x -= nx * overlap * 0.5
        first.y -= ny * overlap * 0.5
        second.x += nx * overlap * 0.5
        second.y += ny * overlap * 0.5
        first.vx, first.vy = -nx * math.hypot(first.vx, first.vy), -ny * math.hypot(first.vx, first.vy)
        second.vx, second.vy = nx * math.hypot(second.vx, second.vy), ny * math.hypot(second.vx, second.vy)
        self._reflect_at_edges(first)
        self._reflect_at_edges(second)

    def _reflect_at_edges(self, unit: Unit) -> None:
        if unit.x < 0.0 or unit.x > self.width:
            unit.vx = -unit.vx
            unit.x = min(self.width, max(0.0, unit.x))
        if unit.y < 0.0 or unit.y > self.height:
            unit.vy = -unit.vy
            unit.y = min(self.height, max(0.0, unit.y))

    def _record_trend(self) -> None:
        sample_time = round(self.time_s, 2)
        if self.trend and float(self.trend[-1]["time_s"]) == sample_time:
            return
        counts = self.faction_counts()
        self.trend.append({
            "time_s": sample_time,
            "pk": round(self.pk, 3),
            "player": counts["player"],
            "opponent": counts["opponent"],
            "neutral": counts["neutral"],
            "player_words": self.player_word_count,
            "opponent_words": self.opponent_word_count,
        })


def build_experiment_configs() -> list[ExperimentConfig]:
    """使用单因素对照，避免把多个改动的影响混在一起。"""
    base = ExperimentConfig(config_id="base", varied_parameter="baseline")
    return [
        base,
        ExperimentConfig("k_low", "pk_k", pk_k=0.55),
        ExperimentConfig("k_high", "pk_k", pk_k=1.15),
        ExperimentConfig("pop_low", "population", population_cap=72),
        ExperimentConfig("pop_high", "population", population_cap=120),
        ExperimentConfig("chance_low", "infection_chance", infection_chances=(0.10, 0.22, 0.35)),
        ExperimentConfig("chance_high", "infection_chance", infection_chances=(0.30, 0.50, 0.70)),
        ExperimentConfig("life_short", "natural_lifetime", natural_lifetime_mean_s=45.0),
        ExperimentConfig("life_long", "natural_lifetime", natural_lifetime_mean_s=85.0),
        ExperimentConfig("cooldown_fast", "speech_cooldowns", player_cooldown_s=3.5, opponent_cooldown_s=8.0),
        ExperimentConfig("cooldown_slow", "speech_cooldowns", player_cooldown_s=7.0, opponent_cooldown_s=15.0),
    ]


def build_slow_balanced_candidate() -> ExperimentConfig:
    """把两个单因素较有希望的结果组合成下一轮待验证配置。"""
    return ExperimentConfig(
        config_id="candidate_slow_balanced",
        varied_parameter="combined_candidate",
        pk_k=0.55,
        population_cap=96,
        infection_chances=(0.10, 0.22, 0.35),
        natural_lifetime_mean_s=45.0,
        player_cooldown_s=5.0,
        opponent_cooldown_s=11.5,
    )


def build_moderate_candidate() -> ExperimentConfig:
    """降低低速组合的僵持风险，同时保留低感染率和短寿命带来的控雪效果。"""
    return ExperimentConfig(
        config_id="candidate_moderate",
        varied_parameter="combined_candidate",
        pk_k=0.70,
        population_cap=96,
        infection_chances=(0.10, 0.22, 0.35),
        natural_lifetime_mean_s=45.0,
        player_cooldown_s=5.0,
        opponent_cooldown_s=11.5,
    )


def build_candidate_configs() -> dict[str, ExperimentConfig]:
    candidates = [build_slow_balanced_candidate(), build_moderate_candidate()]
    return {candidate.config_id: candidate for candidate in candidates}


def _config_columns(config: ExperimentConfig) -> dict[str, object]:
    row = asdict(config)
    row["infection_chances"] = "/".join(f"{value:.2f}" for value in config.infection_chances)
    return row


def run_single_replay(config_id: str, strategy: str, seed: int, output_dir: Path = OUTPUT_DIR) -> MatchResult:
    """重放一场选定配置/策略/seed，写出逐段阵营趋势 JSON。"""
    configs = {config.config_id: config for config in build_experiment_configs()}
    configs.update(build_candidate_configs())
    if config_id not in configs:
        raise ValueError(f"unknown config_id: {config_id}")
    if strategy not in STRATEGIES:
        raise ValueError(f"unknown strategy: {strategy}")
    result = Match(configs[config_id], seed, strategy).run()
    output_dir.mkdir(parents=True, exist_ok=True)
    replay_path = output_dir / "experiment_replay.json"
    replay_path.write_text(json.dumps({
        "classification": "model_only_not_godot_or_human_playtest",
        "assumptions": {"opponent_first_additional_word_delay_s": 0.0, "time_step_s": DT},
        "config": asdict(result.config),
        "seed": result.seed,
        "strategy": result.strategy,
        "result": asdict(result),
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    return result


def run_candidate_suite(
    seed_count: int = 10,
    output_dir: Path = OUTPUT_DIR,
    candidate_id: str = "candidate_slow_balanced",
) -> list[MatchResult]:
    """用相同固定 seeds 对组合候选四种路线做一次小型复核。"""
    config = build_candidate_configs().get(candidate_id)
    if config is None:
        raise ValueError(f"unknown candidate_id: {candidate_id}")
    seeds = [20261017 + index for index in range(seed_count)]
    results = [Match(config, seed, strategy).run() for strategy in STRATEGIES for seed in seeds]
    output_dir.mkdir(parents=True, exist_ok=True)
    run_fields = [
        "evidence_type", "config_id", "varied_parameter", "strategy", "seed", "pk_k", "population_cap", "infection_chances",
        "natural_lifetime_mean_s", "natural_lifetime_sd_s", "player_cooldown_s", "opponent_cooldown_s",
        "opponent_first_additional_word_delay_s", "outcome", "model_seconds", "min_pk", "max_pk",
        "sampled_pk_midpoint_crossings", "longest_neutral_shortage_s", "max_team_share",
        "max_sampled_pk_change_pp_per_30s", "peak_words_published_per_30s", "final_pk",
        "player_count", "opponent_count", "neutral_count", "player_words", "opponent_words",
        "contact_resolutions", "legal_infection_attempts", "conversions", "relays", "equal_type_bounces",
        "faction_trend_json",
    ]
    filename_suffix = "" if candidate_id == "candidate_slow_balanced" else "_" + candidate_id.removeprefix("candidate_")
    runs_path = output_dir / f"candidate{filename_suffix}_runs.csv"
    summary_path = output_dir / f"candidate{filename_suffix}_summary.csv"
    with runs_path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=run_fields)
        writer.writeheader()
        for result in results:
            row: dict[str, object] = _config_columns(result.config)
            row.update({
                "evidence_type": "model_only",
                "strategy": result.strategy,
                "seed": result.seed,
                "opponent_first_additional_word_delay_s": 0.0,
                "outcome": result.outcome,
                "model_seconds": result.model_seconds,
                "min_pk": result.min_pk,
                "max_pk": result.max_pk,
                "sampled_pk_midpoint_crossings": result.sampled_pk_midpoint_crossings,
                "longest_neutral_shortage_s": result.longest_neutral_shortage_s,
                "max_team_share": result.max_team_share,
                "max_sampled_pk_change_pp_per_30s": result.max_sampled_pk_change_pp_per_30s,
                "peak_words_published_per_30s": result.peak_words_published_per_30s,
                "final_pk": result.final_pk,
                "player_count": result.player_count,
                "opponent_count": result.opponent_count,
                "neutral_count": result.neutral_count,
                "player_words": result.player_words,
                "opponent_words": result.opponent_words,
                "contact_resolutions": result.contact_resolutions,
                "legal_infection_attempts": result.legal_infection_attempts,
                "conversions": result.conversions,
                "relays": result.relays,
                "equal_type_bounces": result.equal_type_bounces,
                "faction_trend_json": json.dumps(result.trend, ensure_ascii=False, separators=(",", ":")),
            })
            writer.writerow(row)
    summaries: list[dict[str, object]] = []
    for strategy in STRATEGIES:
        group = [result for result in results if result.strategy == strategy]
        summaries.append({
            **_config_columns(config),
            "evidence_type": "model_only",
            "strategy": strategy,
            "n": len(group),
            "player_100_count": sum(result.outcome == "player_100" for result in group),
            "opponent_0_count": sum(result.outcome == "opponent_0" for result in group),
            "censored_240_count": sum(result.outcome == "censored_240s" for result in group),
            "median_duration_s": round(statistics.median(result.model_seconds for result in group), 2),
            "mean_min_pk": round(statistics.fmean(result.min_pk for result in group), 3),
            "mean_max_pk": round(statistics.fmean(result.max_pk for result in group), 3),
            "mean_sampled_pk_midpoint_crossings": round(statistics.fmean(result.sampled_pk_midpoint_crossings for result in group), 2),
            "mean_longest_neutral_shortage_s": round(statistics.fmean(result.longest_neutral_shortage_s for result in group), 2),
            "mean_max_team_share": round(statistics.fmean(result.max_team_share for result in group), 4),
            "mean_max_sampled_pk_change_pp_per_30s": round(statistics.fmean(result.max_sampled_pk_change_pp_per_30s for result in group), 3),
            "mean_peak_words_published_per_30s": round(statistics.fmean(result.peak_words_published_per_30s for result in group), 2),
            "mean_player_words": round(statistics.fmean(result.player_words for result in group), 2),
            "mean_opponent_words": round(statistics.fmean(result.opponent_words for result in group), 2),
        })
    with summary_path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(summaries[0].keys()))
        writer.writeheader()
        writer.writerows(summaries)
    return results


def run_suite(seed_count: int = 10, output_dir: Path = OUTPUT_DIR) -> tuple[list[MatchResult], list[dict[str, object]]]:
    """重跑固定种子并保存逐局 CSV 与按策略聚合的对比 CSV。"""
    seeds = [20261017 + index for index in range(seed_count)]
    results: list[MatchResult] = []
    started = time.perf_counter()
    for config in build_experiment_configs():
        for strategy in STRATEGIES:
            for seed in seeds:
                results.append(Match(config, seed, strategy).run())
    wall_s = time.perf_counter() - started
    output_dir.mkdir(parents=True, exist_ok=True)
    runs_path = output_dir / "experiment_runs.csv"
    run_fields = [
        "config_id", "varied_parameter", "strategy", "seed", "pk_k", "population_cap",
        "infection_chances", "natural_lifetime_mean_s", "natural_lifetime_sd_s",
        "player_cooldown_s", "opponent_cooldown_s", "opponent_first_additional_word_delay_s",
        "outcome", "model_seconds",
        "min_pk", "max_pk", "sampled_pk_midpoint_crossings", "longest_neutral_shortage_s", "max_team_share",
        "max_sampled_pk_change_pp_per_30s", "peak_words_published_per_30s", "final_pk", "player_count", "opponent_count", "neutral_count",
        "player_words", "opponent_words", "contact_resolutions", "legal_infection_attempts",
        "conversions", "relays", "equal_type_bounces", "faction_trend_json",
    ]
    with runs_path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=run_fields)
        writer.writeheader()
        for result in results:
            row = _config_columns(result.config)
            row.update({
                "strategy": result.strategy,
                "seed": result.seed,
                "opponent_first_additional_word_delay_s": 0.0,
                "outcome": result.outcome,
                "model_seconds": result.model_seconds,
                "min_pk": result.min_pk,
                "max_pk": result.max_pk,
                "sampled_pk_midpoint_crossings": result.sampled_pk_midpoint_crossings,
                "longest_neutral_shortage_s": result.longest_neutral_shortage_s,
                "max_team_share": result.max_team_share,
                "max_sampled_pk_change_pp_per_30s": result.max_sampled_pk_change_pp_per_30s,
                "peak_words_published_per_30s": result.peak_words_published_per_30s,
                "final_pk": result.final_pk,
                "player_count": result.player_count,
                "opponent_count": result.opponent_count,
                "neutral_count": result.neutral_count,
                "player_words": result.player_words,
                "opponent_words": result.opponent_words,
                "contact_resolutions": result.contact_resolutions,
                "legal_infection_attempts": result.legal_infection_attempts,
                "conversions": result.conversions,
                "relays": result.relays,
                "equal_type_bounces": result.equal_type_bounces,
                "faction_trend_json": json.dumps(result.trend, ensure_ascii=False, separators=(",", ":")),
            })
            writer.writerow(row)

    grouped: dict[tuple[str, str], list[MatchResult]] = {}
    for result in results:
        grouped.setdefault((result.config.config_id, result.strategy), []).append(result)
    summary_rows: list[dict[str, object]] = []
    for (config_id, strategy), group in grouped.items():
        first = group[0].config
        durations = [result.model_seconds for result in group]
        summary_rows.append({
            **_config_columns(first),
            "strategy": strategy,
            "n": len(group),
            "opponent_first_additional_word_delay_s": 0.0,
            "player_100_count": sum(result.outcome == "player_100" for result in group),
            "opponent_0_count": sum(result.outcome == "opponent_0" for result in group),
            "censored_240_count": sum(result.outcome == "censored_240s" for result in group),
            "median_duration_s": round(statistics.median(durations), 2),
            "mean_min_pk": round(statistics.fmean(result.min_pk for result in group), 3),
            "mean_max_pk": round(statistics.fmean(result.max_pk for result in group), 3),
            "mean_sampled_pk_midpoint_crossings": round(statistics.fmean(result.sampled_pk_midpoint_crossings for result in group), 2),
            "mean_longest_neutral_shortage_s": round(statistics.fmean(result.longest_neutral_shortage_s for result in group), 2),
            "mean_max_team_share": round(statistics.fmean(result.max_team_share for result in group), 4),
            "mean_max_sampled_pk_change_pp_per_30s": round(statistics.fmean(result.max_sampled_pk_change_pp_per_30s for result in group), 3),
            "mean_peak_words_published_per_30s": round(statistics.fmean(result.peak_words_published_per_30s for result in group), 2),
            "mean_player_words": round(statistics.fmean(result.player_words for result in group), 2),
            "mean_opponent_words": round(statistics.fmean(result.opponent_words for result in group), 2),
            "mean_conversions": round(statistics.fmean(result.conversions for result in group), 2),
            "mean_relays": round(statistics.fmean(result.relays for result in group), 2),
            "mean_equal_type_bounces": round(statistics.fmean(result.equal_type_bounces for result in group), 2),
        })
    summary_path = output_dir / "experiment_summary.csv"
    with summary_path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(summary_rows[0].keys()))
        writer.writeheader()
        writer.writerows(summary_rows)

    metadata_path = output_dir / "experiment_metadata.json"
    metadata_path.write_text(json.dumps({
        "classification": "model_only_not_godot_or_human_playtest",
        "fixed_seeds": seeds,
        "configuration_count": len(build_experiment_configs()),
        "strategy_count": len(STRATEGIES),
        "run_count": len(results),
        "dt_s": DT,
        "opponent_first_additional_word_delay_s": 0.0,
        "duration_cap_s": MAX_SECONDS,
        "reversal_indicator": "sampled 50-point crossings at 30-second trend points; brief reversals between samples can be missed",
        "wall_runtime_s": round(wall_s, 2),
        "replay_command": "python tests/plan_b/experiment_model.py --seed-count 10",
        "single_replay_command": "python tests/plan_b/experiment_model.py --config-id base --strategy tactical --seed 20261017",
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    return results, summary_rows


def postprocess_reversal_metrics(output_dir: Path = OUTPUT_DIR) -> None:
    """给已有趋势 CSV 补充 50 点交叉计数，便于重算旧批次。"""
    runs_path = output_dir / "experiment_runs.csv"
    with runs_path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        fields = list(reader.fieldnames or [])
        rows = list(reader)
    derived_run_fields = [
        "opponent_first_additional_word_delay_s",
        "sampled_pk_midpoint_crossings",
        "longest_neutral_shortage_s",
        "max_team_share",
        "max_sampled_pk_change_pp_per_30s",
        "peak_words_published_per_30s",
    ]
    for field_name in derived_run_fields:
        if field_name not in fields:
            fields.append(field_name)
    trend_metrics_by_group: dict[tuple[str, str], list[dict[str, float | int]]] = {}
    for row in rows:
        trend = json.loads(row.get("faction_trend_json", "[]"))
        trend_metrics = summarize_sampled_trend(trend)
        row["opponent_first_additional_word_delay_s"] = 0.0
        row["sampled_pk_midpoint_crossings"] = count_sampled_pk_midpoint_crossings(trend)
        for field_name, value in trend_metrics.items():
            row[field_name] = value
        key = (row["config_id"], row["strategy"])
        trend_metrics_by_group.setdefault(key, []).append({
            "longest_neutral_shortage_s": float(trend_metrics["longest_neutral_shortage_s"]),
            "max_team_share": float(trend_metrics["max_team_share"]),
            "max_sampled_pk_change_pp_per_30s": float(trend_metrics["max_sampled_pk_change_pp_per_30s"]),
            "peak_words_published_per_30s": int(trend_metrics["peak_words_published_per_30s"]),
            "sampled_pk_midpoint_crossings": int(row["sampled_pk_midpoint_crossings"]),
        })
    with runs_path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    summary_path = output_dir / "experiment_summary.csv"
    run_groups: dict[tuple[str, str], list[int]] = {}
    for row in rows:
        key = (row["config_id"], row["strategy"])
        run_groups.setdefault(key, []).append(int(row["sampled_pk_midpoint_crossings"]))
    with summary_path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        summary_fields = list(reader.fieldnames or [])
        summaries = list(reader)
    derived_summary_fields = [
        "opponent_first_additional_word_delay_s",
        "mean_sampled_pk_midpoint_crossings",
        "mean_longest_neutral_shortage_s",
        "mean_max_team_share",
        "mean_max_sampled_pk_change_pp_per_30s",
        "mean_peak_words_published_per_30s",
    ]
    for field_name in derived_summary_fields:
        if field_name not in summary_fields:
            summary_fields.append(field_name)
    for row in summaries:
        key = (row["config_id"], row["strategy"])
        values = run_groups.get(key, [])
        metrics = trend_metrics_by_group.get(key, [])
        row["opponent_first_additional_word_delay_s"] = 0.0
        row["mean_sampled_pk_midpoint_crossings"] = round(statistics.fmean(values), 2) if values else 0.0
        row["mean_longest_neutral_shortage_s"] = round(statistics.fmean(item["longest_neutral_shortage_s"] for item in metrics), 2) if metrics else 0.0
        row["mean_max_team_share"] = round(statistics.fmean(item["max_team_share"] for item in metrics), 4) if metrics else 0.0
        row["mean_max_sampled_pk_change_pp_per_30s"] = round(statistics.fmean(item["max_sampled_pk_change_pp_per_30s"] for item in metrics), 3) if metrics else 0.0
        row["mean_peak_words_published_per_30s"] = round(statistics.fmean(item["peak_words_published_per_30s"] for item in metrics), 2) if metrics else 0.0
    with summary_path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=summary_fields)
        writer.writeheader()
        writer.writerows(summaries)

    metadata_path = output_dir / "experiment_metadata.json"
    if metadata_path.exists():
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        metadata["opponent_first_additional_word_delay_s"] = 0.0
        metadata["reversal_indicator"] = "sampled 50-point crossings at 30-second trend points; brief reversals between samples can be missed"
        metadata["shortage_indicator"] = "neutral count <= 3 for consecutive 30-second trend samples"
        metadata["snowball_indicator"] = "maximum of player/opponent count divided by total at 30-second trend samples"
        metadata["single_replay_command"] = "python tests/plan_b/experiment_model.py --config-id base --strategy tactical --seed 20261017"
        metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Plan B V0 deterministic balancing model (not Godot runtime).")
    parser.add_argument("--seed-count", type=int, default=10, help="每种配置和策略的固定种子数量")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    candidate_configs = build_candidate_configs()
    config_ids = [config.config_id for config in build_experiment_configs()] + list(candidate_configs.keys())
    parser.add_argument("--config-id", choices=config_ids)
    parser.add_argument("--strategy", choices=STRATEGIES)
    parser.add_argument("--seed", type=int, help="与 --config-id 和 --strategy 一起使用，重放单场")
    parser.add_argument("--candidate-sweep", action="store_true", help="对组合候选四种策略各跑固定种子批次")
    parser.add_argument("--candidate-id", choices=list(candidate_configs.keys()), default="candidate_slow_balanced")
    parser.add_argument("--postprocess-only", action="store_true", help="从已有趋势 CSV 重算 50 点交叉指标")
    args = parser.parse_args()
    if args.candidate_sweep:
        if any(value is not None for value in (args.config_id, args.strategy, args.seed)):
            parser.error("candidate sweep cannot be combined with single-replay arguments")
        results = run_candidate_suite(args.seed_count, args.output_dir, args.candidate_id)
        filename_suffix = "" if args.candidate_id == "candidate_slow_balanced" else "_" + args.candidate_id.removeprefix("candidate_")
        print(f"PASS candidate sweep: runs={len(results)}, config={args.candidate_id}")
        print(f"CSV: {(args.output_dir / f'candidate{filename_suffix}_runs.csv').resolve()}")
        print(f"CSV: {(args.output_dir / f'candidate{filename_suffix}_summary.csv').resolve()}")
        return
    if args.postprocess_only:
        postprocess_reversal_metrics(args.output_dir)
        print(f"PASS sampled reversal metric: {(args.output_dir / 'experiment_summary.csv').resolve()}")
        return
    replay_args = (args.config_id, args.strategy, args.seed)
    if any(value is not None for value in replay_args):
        if not all(value is not None for value in replay_args):
            parser.error("single replay requires --config-id, --strategy, and --seed")
        result = run_single_replay(args.config_id, args.strategy, args.seed, args.output_dir)
        print(f"PASS model replay: config={args.config_id}, strategy={args.strategy}, seed={args.seed}, outcome={result.outcome}, seconds={result.model_seconds}")
        print(f"Replay JSON: {(args.output_dir / 'experiment_replay.json').resolve()}")
        print("Classification: model-only; do not cite as Godot runtime or human acceptance evidence.")
        return
    results, summary = run_suite(args.seed_count, args.output_dir)
    print(f"PASS model experiment: runs={len(results)}, summaries={len(summary)}")
    print(f"CSV: {(args.output_dir / 'experiment_runs.csv').resolve()}")
    print(f"CSV: {(args.output_dir / 'experiment_summary.csv').resolve()}")
    print("Classification: model-only; do not cite as Godot runtime or human acceptance evidence.")


if __name__ == "__main__":
    main()
