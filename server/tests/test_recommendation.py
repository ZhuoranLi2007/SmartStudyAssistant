import pytest

from server.services.recommendation_service import calculate_level


@pytest.mark.parametrize(
    ("score", "expected"),
    [
        (59, "基础巩固型"), (60, "中等提升型"), (79, "中等提升型"),
        (80, "拔高拓展型"), (100, "拔高拓展型"),
    ],
)
def test_score_boundaries(score, expected):
    assert calculate_level(score) == expected
