import pytest

from server.services.recommendation_service import calculate_level


@pytest.mark.parametrize(
    ("score", "expected"),
    [(59, "基础巩固型"), (60, "中等提升型"), (84, "中等提升型"), (85, "拔高拓展型")],
)
def test_score_boundaries(score, expected):
    level, _rules = calculate_level(score, ["应用题"], "提高成绩")
    assert level == expected


def test_three_weak_points_downgrade():
    level, rules = calculate_level(90, ["应用题", "百分数", "几何"], "提高成绩")
    assert level == "中等提升型"
    assert any("下调" in rule for rule in rules)


def test_foundation_goal_caps_level():
    level, _rules = calculate_level(95, [], "巩固基础")
    assert level == "基础巩固型"
