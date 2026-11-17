import pytest

from preshed.maps import PreshMap
from preshed.tests.map_helpers import get_after_clear

# 0 and 1 are EMPTY_KEY and DELETED_KEY, which are stored outside the cells.
KEYS = [0, 1, 2, 2**64 - 1]


@pytest.mark.parametrize("key", KEYS)
def test_map_get_after_clear(key):
    assert get_after_clear(key, 99) == 0


@pytest.mark.parametrize("key", KEYS)
def test_del_then_lookup(key):
    table = PreshMap()
    table[key] = 99
    del table[key]
    assert key not in table
    assert table[key] is None
    table[key] = 100
    assert table[key] == 100
