#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""策划数据 XLSX → 分系统 CSV → 已接入的 Godot Resource。标准库 + openpyxl。"""
from __future__ import annotations

import argparse
import csv
import io
import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parents[1]
SHEET_NAMES = (
    "01_身份配置", "02_主播关卡", "03_普通词库", "04_矛盾内容", "05_关卡生成",
    "06_战斗数值", "07_特性参数", "08_Tier档位", "09_直播数据", "10_复读配置",
    "11_矛盾参数", "12_神谕参数", "13_吞并奖励", "14_败者卡", "15_神降临",
    "16_结局配置", "17_音频事件", "18_表现资产",
)
# 原字段名是唯一输入契约；这里只约束当前已确认的主键、核心字段、类型和合法枚举。
RULES = {
    "01_身份配置": ("identity_id", ("identity_id", "display_name", "tendency")),
    "02_主播关卡": ("level_id", ("level_id", "level_order", "streamer_id")),
    "03_普通词库": ("word_id", ("word_id", "text", "tendency", "strength", "weight", "pool_id", "enabled")),
    "04_矛盾内容": ("contradiction_id", ("contradiction_id", "set_id", "streamer_id", "type", "text")),
    "05_关卡生成": ("level_id", ("level_id",)),
    "06_战斗数值": ("param_id", ("param_id", "value")),
    "06_生命周期": ("barrage_type", ("barrage_type", "base_lifetime_s")),
    "06_基础参数": ("param_id", ("param_id", "value")),
    "07_特性参数": ("trait_id", ("trait_id",)),
    "08_Tier档位": ("tier", ("tier", "pk_up_threshold", "spawn_batch_mult", "spawn_frequency_mult", "move_speed_mult", "lifetime_mult", "pullback_mult", "repeat_count", "repeat_lifetime_s")),
    "09_直播数据": ("rule_id", ("rule_id",)),
    "10_复读配置": ("param_id", ("param_id",)),
    "11_矛盾参数": ("level_id", ("level_id",)),
    "12_神谕参数": ("param_id", ("param_id",)),
    "13_吞并奖励": ("reward_id", ("reward_id",)),
    "14_败者卡": ("card_id", ("card_id",)),
    "15_神降临": ("param_id", ("param_id",)),
    "16_结局配置": (None, ("config_type", "primary_tendency")),
    "17_音频事件": ("event_id", ("event_id",)),
    "18_表现资产": ("asset_id", ("asset_id",)),
}
# 显式数值/布尔类型边界，避免将 ID 中的前导零、文本中的标点意外转换。
NUMERIC = {
    "02_主播关卡": {"level_order": "int"},
    "03_普通词库": {"strength": "int", "weight": "float"},
    "05_关卡生成": {"base_batch_count": "int", "spawn_interval_s": "float", "move_speed_px_s": "float", "normal_screen_cap": "int", "word_weight_multiplier": "float"},
    "06_生命周期": {"base_lifetime_s": "float"},
    "07_特性参数": {"lifetime_override_s": "float", "split_child_count": "int"},
    "08_Tier档位": {"tier": "int", "pk_up_threshold": "float", "pk_down_threshold": "float", "spawn_batch_mult": "float", "spawn_frequency_mult": "float", "move_speed_mult": "float", "lifetime_mult": "float", "pullback_mult": "float", "repeat_count": "int", "repeat_lifetime_s": "float"},
    "09_直播数据": {"viewer_value": "float", "like_value": "float", "comment_delta": "float", "fan_value": "float"},
    "11_矛盾参数": {"time_limit_s": "float", "shot_limit": "int", "silence_transition_s": "float"},
    "13_吞并奖励": {"inherited_weight": "float"},
    "17_音频事件": {"volume_db": "float", "pitch_min": "float", "pitch_max": "float"},
}
BOOL_FIELDS = {"default_selected", "enabled", "inheritable", "loop", "affected_by_tier_lifetime_mult"}
ENUMS = {
    ("01_身份配置", "tendency"): {"orthodox", "heretical", "heresy", "absurd"},
    ("03_普通词库", "tendency"): {"orthodox", "heretical", "heresy", "absurd", "neutral"},
    ("04_矛盾内容", "type"): {"true", "false"},
}
# 进入现有 Resource 时唯一允许的字段重命名，游戏层不用猜策划的列名。
SPEECH_TO_GODOT = {
    "word_id": "original_sentence_id", "text": "text", "tendency": "tendency_id",
    "strength": "strength", "weight": "appearance_weight",
}
TIER_TO_GODOT = {
    "pk_up_threshold": "upgrade_threshold",
    "pk_down_threshold": "downgrade_threshold",
    "spawn_batch_mult": "generation_count_multiplier",
    "spawn_frequency_mult": "generation_frequency_multiplier",
    "move_speed_mult": "movement_speed_multiplier",
    "lifetime_mult": "lifetime_multiplier",
    "pullback_mult": "opponent_pullback_multiplier",
    "repeat_count": "repeat_count_per_hit",
}
BASIC_TO_GODOT = {"spawn_interval_s": "base_spawn_interval_seconds"}
PK_PERCENT_POINT_SCALE = 0.01  # 策划 0.12 个百分点 → Godot 0.0012。


def value_text(value: object) -> str:
    """保留文本原貌；仅将 Excel 原生数字和布尔值转换为稳定可读的 CSV 字符串。"""
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return format(value, ".15g") if math.isfinite(value) else str(value)
    return str(value)


def is_header(row: list[str], required: tuple[str, ...]) -> bool:
    """按照真实字段名匹配表头，避免误把区块标题当作记录。"""
    filled = [s.strip() for s in row if s.strip()]
    return bool(filled) and len(filled) == len(set(filled)) and all(f in filled for f in required)


def xlsx_rows(ws) -> list[tuple[int, list[str]]]:
    """读取物理行号；对空行保留行号，保证错误可追溯到 Excel。"""
    result = []
    for n, cells in enumerate(ws.iter_rows(values_only=True), 1):
        row = [value_text(cell) for cell in cells]
        while row and not row[-1]:
            row.pop()
        result.append((n, row))
    return result


def bool_text(text: str) -> str | None:
    """只接受明确的布尔文本；不把未知值默认为真。"""
    return {"true": "true", "false": "false", "1": "true", "0": "false", "yes": "true", "no": "false"}.get(text.strip().lower())


class Report:
    """汇总精确位置及分类；警告允许导出，错误会终止本轮写入。"""
    def __init__(self):
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.stats: list[tuple[str, int, int, int]] = []

    def add(self, level: str, sheet: str, row: int, field: str, why: str) -> None:
        line = f"{sheet} 第{row}行 [{field}] {why}"
        (self.errors if level == "错误" else self.warnings).append(line)


def parse_sheet(sheet: str, rows: list[tuple[int, list[str]]], report: Report, start: int = 0, end: int | None = None):
    """提取一块字段结构固定的表；只过滤明确的示例/说明/全空行。"""
    key, required = RULES[sheet]
    block = rows[start:end]
    header_idx = next((i for i, (_, row) in enumerate(block) if is_header(row, required)), None)
    if header_idx is None:
        report.add("错误", sheet, 1, "表头", "缺少正式表头或必填列：" + ", ".join(required))
        return [], []
    header_row_no, header = block[header_idx]
    if len(header) != len(set(header)) or any(not f.strip() for f in header):
        report.add("错误", sheet, header_row_no, "表头", "字段名为空或重复")
        return [], []
    records: list[tuple[int, dict[str, str]]] = []
    blanks = examples = 0
    for line, row in block[header_idx + 1:]:
        if not row or not any(s.strip() for s in row):
            blanks += 1
            continue
        if row[0].startswith("【") or is_header(row, required):
            report.add("警告", sheet, line, "区块", "跳过重复标题或表头")
            continue
        # 02 表底部有逐列的“填写……”说明，按照说明型文案而非位置识别。
        guide_count = sum(s.strip().startswith(("填写", "给每", "根据", "仅在", "选择")) for s in row)
        if row[0].strip().startswith(("填写", "给每个")) and guide_count >= 1:
            examples += 1
            report.add("警告", sheet, line, "说明行", "已跳过字段填写说明")
            continue
        record = {field: row[i] if i < len(row) else "" for i, field in enumerate(header)}
        primary = record.get(key, "") if key else ""
        if primary.upper().startswith("EXAMPLE_") or record.get("notes", "").strip().startswith("示例行"):
            examples += 1
            report.add("警告", sheet, line, key or "notes", "已跳过明确标记的示例行")
            continue
        if len(row) > len(header) and any(s.strip() for s in row[len(header):]):
            report.add("错误", sheet, line, "列数", "记录超出了字段表头长度")
        records.append((line, record))
    report.stats.append((sheet, len(records), blanks, examples))
    return header, records


def numeric(text: str, kind: str) -> bool:
    """验算数值合法性：整数不接受 1.5；浮点必须有限。"""
    try:
        number = float(text)
        if not math.isfinite(number):
            return False
        return kind != "int" or number.is_integer()
    except ValueError:
        return False


def validate(tables: dict, report: Report) -> None:
    """集中检查必填、类型、枚举、稳定 ID 和已具备双方来源的关联。"""
    for name, (header, records) in tables.items():
        key, required = RULES[name]
        seen: set[str] = set()
        for line, record in records:
            for f in required:
                if record.get(f, "").strip():
                    continue
                # 允许未完成参数以警告形式保留空值；稳定 ID、台词内容仍为硬错误。
                severity = "错误" if f == key or (name == "03_普通词库" and f in ("text", "tendency", "strength", "weight", "pool_id", "enabled")) else "警告"
                report.add(severity, name, line, f, "必填内容尚未填写")
            if key:
                identity = record.get(key, "").strip()
                if identity:
                    if identity in seen:
                        report.add("错误", name, line, key, f"稳定 ID 重复：{identity}")
                    seen.add(identity)
            for f, kind in NUMERIC.get(name, {}).items():
                raw = record.get(f, "").strip()
                if raw and not numeric(raw, kind):
                    report.add("错误", name, line, f, f"需要{kind}类型，实际为 {raw!r}")
            for f in header:
                raw = record.get(f, "").strip()
                if f in BOOL_FIELDS and raw:
                    parsed = bool_text(raw)
                    if parsed is None:
                        report.add("错误", name, line, f, f"非法布尔值：{raw!r}")
                    else:
                        record[f] = parsed
                allowed = ENUMS.get((name, f))
                if allowed and raw and raw not in allowed:
                    report.add("错误", name, line, f, f"枚举值 {raw!r} 不在 {sorted(allowed)}")
                if f not in ("text", "notes", "description", "clue_text") and raw.startswith(("待填写", "填写", "TODO", "TBD")):
                    report.add("警告", name, line, f, "策划占位，尚待填写")
            # 只报告已确认应填写的配置空值；未完工内容保留空白，绝不造数。
            pending_fields = {
                "05_关卡生成": ("base_batch_count", "spawn_interval_s", "move_speed_px_s", "normal_screen_cap"),
                "10_复读配置": ("value",),
                "15_神降临": ("value",),
                "17_音频事件": ("asset_path_or_id",),
            }.get(name, ())
            for f in pending_fields:
                if f in header and not record.get(f, "").strip():
                    report.add("警告", name, line, f, "正式值尚待策划或资产交付")
            if name == "03_普通词库":
                strength = record.get("strength", "")
                weight = record.get("weight", "")
                if numeric(strength, "int") and int(float(strength)) not in (1, 2, 3):
                    report.add("错误", name, line, "strength", "强度只能为 1、2、3")
                if numeric(weight, "float") and float(weight) <= 0:
                    report.add("错误", name, line, "weight", "出现权重必须大于 0")
    for child, field, parent, target in (
        ("05_关卡生成", "level_id", "02_主播关卡", "level_id"),
        ("11_矛盾参数", "level_id", "02_主播关卡", "level_id"),
        ("04_矛盾内容", "streamer_id", "02_主播关卡", "streamer_id"),
        ("07_特性参数", "penalty_param_id", "06_战斗数值", "param_id"),
        ("02_主播关卡", "word_pool_id", "03_普通词库", "pool_id"),
        ("13_吞并奖励", "streamer_id", "02_主播关卡", "streamer_id"),
    ):
        if child not in tables or parent not in tables:
            continue
        source = {r.get(target, "") for _, r in tables[parent][1] if r.get(target)}
        if not source:
            for line, row in tables[child][1]:
                if row.get(field, "").strip():
                    report.add("警告", child, line, field, f"{parent} 目前没有正式记录，关联 ID 暂无法核验")
            continue
        for line, row in tables[child][1]:
            ref = row.get(field, "").strip()
            if ref and ref not in source:
                report.add("错误", child, line, field, f"关联 ID {ref!r} 未出现在 {parent}.{target}")
    # 表格的 Tier 数值单位是 PK 百分点，Godot 阈值使用 [0,1]；这里同时验算趋势。
    if "08_Tier档位" not in tables:
        return
    ts = tables["08_Tier档位"][1]
    if len(ts) != 6 or {r["tier"] for _, r in ts} != set("012345"):
        report.add("错误", "08_Tier档位", 1, "tier", "需要完整 Tier 0～5 各一条")
    previous = -1.0
    for line, r in ts:
        up, down = r["pk_up_threshold"], r.get("pk_down_threshold", "")
        if not numeric(up, "float"):
            continue
        upper = float(up)
        if not (0 < upper <= 100 and upper > previous):
            report.add("错误", "08_Tier档位", line, "pk_up_threshold", "升档阈值需递增，范围 (0,100]")
        previous = upper
        if r["tier"] != "0" and (not down or not numeric(down, "float")):
            report.add("错误", "08_Tier档位", line, "pk_down_threshold", "Tier 1～5 必须填写降档阈值")
        if down and numeric(down, "float") and not (0 <= float(down) < upper):
            report.add("错误", "08_Tier档位", line, "pk_down_threshold", "降档阈值须低于本档升档阈值")
        for f in ("spawn_batch_mult", "spawn_frequency_mult", "move_speed_mult", "lifetime_mult", "pullback_mult"):
            if numeric(r.get(f, ""), "float") and float(r[f]) <= 0:
                report.add("错误", "08_Tier档位", line, f, "倍率必须大于 0")
        if numeric(r["repeat_count"], "int") and int(float(r["repeat_count"])) < 0:
            report.add("错误", "08_Tier档位", line, "repeat_count", "复读数量不可为负")
        if numeric(r["repeat_lifetime_s"], "float") and numeric(r["lifetime_mult"], "float"):
            expected = 3.0 * float(r["lifetime_mult"])
            if abs(float(r["repeat_lifetime_s"]) - expected) > 0.001:
                report.add("错误", "08_Tier档位", line, "repeat_lifetime_s", f"应等于 3s×lifetime_mult={expected:g}")


def csv_body(header: list[str], records: list) -> str:
    """CSV 使用标准引号转义、UTF-8、固定换行；重复导出字节稳定。"""
    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(header)
    for _, record in records:
        writer.writerow([record.get(f, "") for f in header])
    return output.getvalue()


def gd_string(s: str) -> str:
    """Godot 资源文本以 JSON 规则转义引号、反斜杠和换行。"""
    return json.dumps(s, ensure_ascii=False)


def make_speech_pools(records: list, report: Report) -> dict[str, str]:
    """按 pool_id 生成 LevelSpeech 的真实 Resource 子资源；停用行仍留在 CSV。"""
    grouped: dict[str, list] = defaultdict(list)
    for line, r in records:
        if r.get("enabled", "").lower() != "true":
            continue
        pool = r["pool_id"]
        if not re.fullmatch(r"[A-Za-z0-9_-]+", pool):
            report.add("错误", "03_普通词库", line, "pool_id", "Resource 文件名只允许英文、数字、_ 和 -")
            continue
        grouped[pool].append(r)
    results = {}
    for pool, rows in grouped.items():
        parts = [
            f'[gd_resource type="Resource" script_class="LevelSpeechPool" load_steps={len(rows)+3} format=3]',
            "",
            '[ext_resource type="Script" path="res://data/level_configuration/level_speech_pool.gd" id="1_pool"]',
            '[ext_resource type="Script" path="res://data/level_configuration/level_speech.gd" id="2_speech"]',
            "",
        ]
        ref_ids = []
        for i, r in enumerate(rows, 1):
            rid = f"Speech_{i}"
            ref_ids.append(f'SubResource("{rid}")')
            parts.extend([
                f'[sub_resource type="Resource" script_class="LevelSpeech" id="{rid}"]',
                'script = ExtResource("2_speech")',
                f'original_sentence_id = {gd_string(r["word_id"])}',
                f'text = {gd_string(r["text"])}',
                f'tendency_id = {gd_string("heretical" if r["tendency"] == "heresy" else r["tendency"])}',
                f'strength = {int(float(r["strength"]))}',
                f'appearance_weight = {format(float(r["weight"]), ".15g")}',
                "",
            ])
        parts.extend([
            "[resource]", 'script = ExtResource("1_pool")',
            f"pool_id = {gd_string(pool)}",
            'speeches = Array[ExtResource("2_speech")]([' + ", ".join(ref_ids) + "])",
            "",
        ])
        results[f"data/generated/level_configuration/{pool}.tres"] = "\n".join(parts)
    return results


def make_tier_resource(records: list, report: Report) -> str:
    """用已有正式 .tres 作为模板，只替换 Sheet 已覆盖的字段，保留 Neutral 与立绘状态。"""
    template_path = ROOT / "data/combat_stage/tier_catalog.tres"
    source = template_path.read_text(encoding="utf-8")
    for line, row in records:
        tier = row["tier"]
        if not numeric(tier, "int"):
            continue
        tier = str(int(float(tier)))
        pattern = re.compile(r'(\[sub_resource type="Resource" id="Tier' + tier + r'"\]\r?\n)(.*?)(?=\r?\n\[(?:sub_resource|resource)\]|\Z)', re.S)
        match = pattern.search(source)
        if match is None:
            report.add("错误", "08_Tier档位", line, "tier", f"现有 Tier{tier} Resource 不存在")
            continue
        body = match.group(2)
        for from_field, to_field in TIER_TO_GODOT.items():
            raw = row.get(from_field, "")
            if not raw and from_field == "pk_down_threshold" and tier == "0":
                raw = "0"
            if not numeric(raw, "float"):
                continue
            val = float(raw) * (PK_PERCENT_POINT_SCALE if from_field.startswith("pk_") else 1.0)
            replacement = str(int(val)) if from_field == "repeat_count" else format(val, ".15g")
            expr = re.compile(r"(?m)^" + re.escape(to_field) + r" = [^\r\n]*")
            if expr.search(body) is None:
                report.add("错误", "08_Tier档位", line, from_field, f"正式模板缺字段 {to_field}")
                continue
            body = expr.sub(to_field + " = " + replacement, body, count=1)
        source = source[:match.start(2)] + body + source[match.end(2):]
    return source


def main() -> int:
    parser = argparse.ArgumentParser(description="一次性导出全部策划 Sheet 至分系统 CSV + 已接入的 Godot Resource")
    parser.add_argument("--input", type=Path, required=True, help="Google Sheets 下载的 .xlsx")
    parser.add_argument("--csv-only", action="store_true", help="仅导出 CSV，不更新已接入的 Resource")
    args = parser.parse_args()
    source = args.input.expanduser().resolve()
    if not source.is_file():
        print(f"错误：找不到输入 XLSX：{source}", file=sys.stderr)
        return 2
    report = Report()
    workbook = load_workbook(source, read_only=True, data_only=True)
    tables: dict[str, tuple[list[str], list]] = {}
    for sheet in SHEET_NAMES:
        if sheet not in workbook.sheetnames:
            report.add("错误", sheet, 1, "Sheet", "缺少工作表")
            continue
        rows = xlsx_rows(workbook[sheet])
        if sheet == "06_战斗数值":
            # 三个独立字段区块，标题与第二/第三个表头均不能作为数据输出。
            cut1 = next((i for i, (_, r) in enumerate(rows) if r and r[0].strip() == "【生命周期】"), -1)
            cut2 = next((i for i, (_, r) in enumerate(rows) if r and r[0].strip() == "【系统案补充基础参数】"), -1)
            if not (0 < cut1 < cut2):
                report.add("错误", sheet, 1, "区块", "缺少或排列错误：生命周期、系统案补充基础参数")
                continue
            for name, start, end in (
                ("06_战斗数值", 0, cut1), ("06_生命周期", cut1 + 1, cut2), ("06_基础参数", cut2 + 1, None),
            ):
                tables[name] = parse_sheet(name, rows, report, start, end)
        else:
            tables[sheet] = parse_sheet(sheet, rows, report)
    workbook.close()
    validate(tables, report)
    outputs: dict[str, str] = {}
    for name, (header, records) in tables.items():
        if header:
            outputs[f"data/source_tables/{name}.csv"] = csv_body(header, records)
    if not args.csv_only and "03_普通词库" in tables and "08_Tier档位" in tables and not report.errors:
        outputs.update(make_speech_pools(tables["03_普通词库"][1], report))
        outputs["data/generated/combat_stage/tier_catalog.tres"] = make_tier_resource(tables["08_Tier档位"][1], report)
    for sheet, n, blanks, examples in report.stats:
        print(f"[表] {sheet}：{n} 条，空行 {blanks}，跳过说明/示例 {examples}")
    for warning in report.warnings:
        print("[警告]", warning)
    for error in report.errors:
        print("[错误]", error, file=sys.stderr)
    if report.errors:
        print(f"导表失败：{len(report.errors)} 个错误；未写入生成文件。", file=sys.stderr)
        return 1
    # 校验全部通过后才覆盖工具拥有的文件；同名之外的仓库资源绝不修改。
    for relative, content in outputs.items():
        dest = ROOT / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists() and dest.read_text(encoding="utf-8") == content:
            print("[未变化]", relative)
        else:
            dest.write_text(content, encoding="utf-8", newline="\n")
            print("[写入]", relative)
    print(f"导表完成：{len(tables)} 张结构表，{len(outputs)} 个文件，"
          f"{len(report.warnings)} 条警告，0 个错误。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
