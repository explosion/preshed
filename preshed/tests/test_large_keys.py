import pytest

from preshed.bloom import BloomFilter
from preshed.counter import PreshCounter
from preshed.maps import PreshMap

# Hash values use the full uint64 range, so keys >= 2**63 are common.
LARGE_KEYS = [2**63, 2**63 + 1, 2**64 - 5, 2**64 - 1]


@pytest.mark.parametrize("key", LARGE_KEYS)
def test_map_large_keys(key):
    table = PreshMap()
    table[key] = 7
    assert key in table
    assert table[key] == 7
    assert list(table.keys()) == [key]
    del table[key]
    assert key not in table
    assert table[key] is None
    table[key] = 8
    assert table.pop(key) == 8


def test_map_rejects_out_of_range_keys():
    table = PreshMap()
    for key in (-1, 2**64):
        with pytest.raises(OverflowError):
            table[key] = 1
        with pytest.raises(OverflowError):
            table[key]


@pytest.mark.parametrize("key", LARGE_KEYS)
def test_counter_large_keys(key):
    counter = PreshCounter()
    counter.inc(key, 3)
    assert counter[key] == 3


@pytest.mark.parametrize("key", LARGE_KEYS)
def test_bloom_large_keys(key):
    bloom = BloomFilter()
    bloom.add(key)
    assert key in bloom
