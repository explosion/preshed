# cython: infer_types=True
# cython: cdivision=True
#
cimport cython

from murmurhash.mrmr cimport hash64
import math

def optimal_params(members, error_rate):
    """Calculate the optimal size in bits and number of hash functions for a
    given number of members and error rate.  
    """
    base = math.log(1 / (2 ** math.log2))
    bit_count = math.ceil((members * math.log(error_rate)) / base)
    hash_count = math.floor((bit_count / members) * math.log(2))
    return dict(size=bit_count, hash_funcs=hash_count)

cdef class BloomFilter:
    """Bloom filter that allows for basic membership tests.
    
    Only integers are supported as keys.
    """
    def __init__(self, key_t size=(2 ** 10), key_t hash_funcs=23):
        self.mem = Pool()

        self.c_bloom = <BloomStruct*>self.mem.alloc(1, sizeof(BloomStruct))
        bloom_init(self.mem, self.c_bloom, hash_funcs, size)

    def add(self, key_t item):
        bloom_add(self.c_bloom, item)

    def __contains__(self, item):
        return bloom_contains(self.c_bloom, item)

    cdef inline bint contains(self, key_t item) nogil:
        return bloom_contains(self.c_bloom, item)

cdef void bloom_init(Pool mem, BloomStruct* bloom, key_t hcount, key_t length):
    # size should be a multiple of the container size - round up
    if length % sizeof(key_t):
        length = math.ceil(length / sizeof(key_t)) * sizeof(key_t)
    bloom.length = length
    bloom.hcount = hcount
    bloom.bitfield = <key_t*>mem.alloc(length // sizeof(key_t), sizeof(key_t))

cdef void bloom_add(BloomStruct* bloom, key_t item):
    cdef key_t hv
    for seed in range(bloom.hcount):
        hv = hash64(&item, sizeof(key_t), seed) % bloom.length
        bloom.bitfield[hv // sizeof(key_t)] |= 1 << (hv % sizeof(key_t))

@cython.boundscheck(False)
@cython.wraparound(False)
cdef bint bloom_contains(BloomStruct* bloom, key_t item) nogil:
    cdef key_t hv
    for seed in range(bloom.hcount):
        hv = hash64(&item, sizeof(key_t), seed) % bloom.length
        if not (bloom.bitfield[hv // sizeof(key_t)] & 
           1 << (hv % sizeof(key_t))):
            return False
    return True
