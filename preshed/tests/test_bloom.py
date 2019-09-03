from __future__ import division
import pytest

from preshed.bloom import BloomFilter

def test_contains():
    bf = BloomFilter()
    assert 23 not in bf
    bf.add(23)
    assert 23 in bf

    bf.add(5)
    bf.add(42)
    bf.add(1002)
    assert 5 in bf
    assert 42 in bf
    assert 1002 in bf

def test_no_false_negatives():
    bf = BloomFilter(size=100, hash_funcs=2)
    for ii in range(0,1000,20):
        bf.add(ii)

    for ii in range(0,1000,20):
        assert ii in bf

