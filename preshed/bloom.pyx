# cython: infer_types=True
# cython: cdivision=True
#
cimport cython

from murmurhash.mrmr cimport hash128_x86
import math

def calculate_size_and_hash_count(members, error_rate):
    """Calculate the optimal size in bits and number of hash functions for a
    given number of members and error rate.  
    """
    base = math.log(1 / (2 ** math.log(2)))
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

"""
Instead of calling MurmurHash with a different seed for each hash function, this
generates two initial hash values and then combines them to create the correct
number of hashes. This technique is faster than just doing MurmurhHash
repeatedly and has been shown to work as well as full hashing.

For details see "Less Hashing, Same Performance: Building a Better Bloom
Filter", Kirsch & Mitzenmacher.

https://www.semanticscholar.org/paper/Less-hashing%2C-same-performance%3A-Building-a-better-Kirsch-Mitzenmacher/65c43afbfc064705bdc40d3473f32518e9306429

The choice of seeds is arbitrary.
"""

cdef void bloom_add(BloomStruct* bloom, key_t item) nogil:
    cdef key_t hv
    cdef key_t[2] keys
    hash128_x86(&item, sizeof(key_t), 0, &keys)
    for hiter in range(bloom.hcount):
        hv = (keys[0] + (hiter * keys[1])) % bloom.length
        bloom.bitfield[hv // sizeof(key_t)] |= 1 << (hv % sizeof(key_t))

@cython.boundscheck(False)
@cython.wraparound(False)
cdef bint bloom_contains(BloomStruct* bloom, key_t item) nogil:
    cdef key_t hv
    cdef key_t[2] keys
    hash128_x86(&item, sizeof(key_t), 0, &keys)
    for hiter in range(bloom.hcount):
        hv = (keys[0] + (hiter * keys[1])) % bloom.length
        if not (bloom.bitfield[hv // sizeof(key_t)] & 
           1 << (hv % sizeof(key_t))):
            return False
    return True
