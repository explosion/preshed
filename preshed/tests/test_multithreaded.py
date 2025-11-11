import threading
import sys
from concurrent.futures import ThreadPoolExecutor

from preshed.bloom import BloomFilter
from preshed.maps import PreshMap


def run_threaded(chunks, closure):
    orig_interval = sys.getswitchinterval()
    sys.setswitchinterval(.0000001)
    n_threads = len(chunks)
    with ThreadPoolExecutor(max_workers=n_threads) as tpe:
        futures = []
        b = threading.Barrier(n_threads)
        for i, chunk in enumerate(chunks):
            futures.append(tpe.submit(closure, b, chunk))
        [f.result() for f in futures]
    sys.setswitchinterval(orig_interval)


def test_multithreaded_bloom_sharing():
    bf = BloomFilter(size=2**16)
    n_threads = 8
    vals = list(range(0, 10000, 10))
    n_vals = len(vals)
    chunk_size = n_vals//n_threads
    assert chunk_size * n_threads == n_vals
    chunks = []
    for i in range(0, n_vals, chunk_size):
        chunks.append(vals[i: i + chunk_size])

    def worker(b, chunk):
        b.wait()
        for ii in chunk:
            # exercises __contains__, add, and to_bytes
            # all are supposed to be thread-safe
            assert ii not in bf
            bf.add(ii)
            assert ii in bf
            bf._roundtrip()

    run_threaded(chunks, worker)


def test_multithreaded_map_sharing():
    h = PreshMap()
    n_threads = 8
    keys = list(range(0, 10000, 10))
    vals = list(range(1, 10000, 10))
    n_vals = len(vals)
    chunk_size = n_vals//n_threads
    assert chunk_size * n_threads == n_vals
    chunks = []
    for i in range(0, n_vals, chunk_size):
        chunks.append(zip(keys[i: i + chunk_size], vals[i: i + chunk_size]))
    assert len(chunks) == n_threads

    def worker(b, chunk):
        b.wait()
        for k, v in chunk:
            # __getitem__
            assert h[k] is None
            # __setitem__
            h[k] = v
            # __getitem__ again
            assert h[k] == v
            # items()
            for (kk, vv) in h.items():
                # None if another thread removed it
                assert h[kk] in (vv, None)
            # pop
            assert h.pop(k) == v
            assert h[k] is None
            # __delitem__
            h[k] = v
            assert h[k] == v
            del h[k]
            assert h[k] is None
            h[k] = v

    run_threaded(chunks, worker)
