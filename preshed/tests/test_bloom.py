from __future__ import division
import pytest
import pickle
import threading

from concurrent.futures import ThreadPoolExecutor
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

def test_from_error():
    bf = BloomFilter.from_error_rate(1000)
    for ii in range(0,1000,20):
        bf.add(ii)

    for ii in range(0,1000,20):
        assert ii in bf

def test_to_from_bytes():
    bf = BloomFilter(size=100, hash_funcs=2)
    for ii in range(0,1000,20):
        bf.add(ii)
    data = bf.to_bytes()
    bf2 = BloomFilter()
    for ii in range(0,1000,20):
        assert ii not in bf2
    bf2.from_bytes(data)
    for ii in range(0,1000,20):
        assert ii in bf2
    assert bf2.to_bytes() == data

def test_bloom_pickle():
    bf = BloomFilter(size=100, hash_funcs=2)
    for ii in range(0,1000,20):
        bf.add(ii)
    data = pickle.dumps(bf)
    bf2 = pickle.loads(data)
    for ii in range(0,1000,20):
        assert ii in bf2


def test_multithreaded_sharing():
    bf = BloomFilter(size=2**16)
    n_threads = 8
    vals = list(range(0, 10000, 10))
    n_vals = len(vals)
    chunk_size = n_vals//n_threads
    assert chunk_size * n_threads == n_vals
    chunks = []
    for i in range(0, n_vals, chunk_size):
        chunks.append(vals[i: i + chunk_size])

    b = threading.Barrier(n_threads)

    def worker(chunk):
        b.wait()
        for ii in chunk:
            # exercises __contains__, add, and to_bytes
            # all are supposed to be thread-safe
            assert ii not in bf
            bf.add(ii)
            assert ii in bf
            bf._roundtrip()

    with ThreadPoolExecutor(max_workers=n_threads) as tpe:
        futures = []
        for i, chunk in enumerate(chunks):
            futures.append(tpe.submit(worker, chunk))
        [f.result() for f in futures]
