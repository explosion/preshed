from __future__ import division
import pytest
import pickle

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
    for ii in range(0, 1000, 20):
        bf.add(ii)

    for ii in range(0, 1000, 20):
        assert ii in bf


def test_from_error():
    bf = BloomFilter.from_error_rate(1000)
    for ii in range(0, 1000, 20):
        bf.add(ii)

    for ii in range(0, 1000, 20):
        assert ii in bf


def test_to_from_bytes():
    bf = BloomFilter(size=100, hash_funcs=2)
    for ii in range(0, 1000, 20):
        bf.add(ii)
    data = bf.to_bytes()
    bf2 = BloomFilter()
    for ii in range(0, 1000, 20):
        assert ii not in bf2
    bf2.from_bytes(data)
    for ii in range(0, 1000, 20):
        assert ii in bf2
    assert bf2.to_bytes() == data


def test_bloom_pickle():
    bf = BloomFilter(size=100, hash_funcs=2)
    for ii in range(0, 1000, 20):
        bf.add(ii)
    data = pickle.dumps(bf)
    bf2 = pickle.loads(data)
    for ii in range(0, 1000, 20):
        assert ii in bf2


def test_bloom_from_bytes_legacy():
    # This is the output from the tests in the legacy format
    data = "0200000000000000600000000000000000000000000000003300000000000000e100000000000000b200000000000000da00000000000000e700000000000000e600000000000000ff000000000000004700000000000000e7000000000000004c000000000000003b00000000000000f700000000000000"
    data = bytes.fromhex(data)
    bf = BloomFilter().from_bytes(data)
    for ii in range(0, 1000, 20):
        assert ii in bf
    data2 = bf.to_bytes()
    bf2 = BloomFilter()
    bf2.from_bytes(data2)
    for ii in range(0, 1000, 20):
        assert ii in bf2


def test_bloom_from_bytes_legacy_windows():
    # This is the output from the tests in the legacy Windows format.
    # This is the same as the data in the normal test, but missing the second
    # half of each container.

    data = "02000000600000000000000033000000e1000000b2000000da000000e7000000e6000000ff00000047000000e70000004c0000003b000000f7000000"
    data = bytes.fromhex(data)
    bf = BloomFilter().from_bytes(data)
    for ii in range(0, 1000, 20):
        assert ii in bf
    data2 = bf.to_bytes()
    bf2 = BloomFilter()
    bf2.from_bytes(data2)
    for ii in range(0, 1000, 20):
        assert ii in bf2


def test_bloom_invalid_args():
    with pytest.raises(AssertionError):
        bf = BloomFilter(0, 0)
