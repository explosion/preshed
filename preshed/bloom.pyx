# cython: infer_types=True
# cython: cdivision=True
#
from murmurhash.mrmr cimport hash128_x86
import math
import struct

try:
    import copy_reg
except ImportError:
    import copyreg as copy_reg

# TODO better way to declare constant?
cdef key_t KEY_BITS = 8 * sizeof(key_t)

def calculate_size_and_hash_count(members, error_rate):
    """Calculate the optimal size in bits and number of hash functions for a
    given number of members and error rate.  
    """
    base = math.log(1 / (2 ** math.log(2)))
    bit_count = math.ceil((members * math.log(error_rate)) / base)
    hash_count = math.floor((bit_count / members) * math.log(2))
    return (bit_count, hash_count)


cdef class BloomFilter:
    """Bloom filter that allows for basic membership tests.
    
    Only integers are supported as keys.
    """
    def __init__(self, key_t size=(2 ** 10), key_t hash_funcs=23, uint32_t seed=0):
        self.mem = Pool()
        self.c_bloom = <BloomStruct*>self.mem.alloc(1, sizeof(BloomStruct))
        bloom_init(self.mem, self.c_bloom, hash_funcs, size, seed)

    @classmethod
    def from_error_rate(cls, members, error_rate=1E-4):
        params = calculate_size_and_hash_count(members, error_rate)
        return cls(*params)

    def add(self, key_t item):
        bloom_add(self.c_bloom, item)

    def __contains__(self, item):
        return bloom_contains(self.c_bloom, item)

    cdef inline bint contains(self, key_t item) nogil:
        return bloom_contains(self.c_bloom, item)

    def to_bytes(self):
        return bloom_to_bytes(self.c_bloom)

    def from_bytes(self, bytes byte_string):
        bloom_from_bytes(self.mem, self.c_bloom, byte_string)
        return self


cdef bytes bloom_to_bytes(const BloomStruct* bloom):
    cdef key_t pad = 0 # to differentiate new from old data format
    cdef key_t version = 1 # hardcoded, can be incremented
    prefix = struct.pack("<QQQQQ", pad, version, bloom.hcount, bloom.length, bloom.seed)
    buflen = bloom.length // KEY_BITS
    contents = [bloom.bitfield[i] for i in range(buflen)]
    buffer = struct.pack(f"<{buflen}Q", *contents)
    return prefix + buffer


cdef void bloom_from_bytes(Pool mem, BloomStruct* bloom, bytes data):
    # new-style memory structure (each unit is a key_t/64 bits):
    # - pad1: 0 (not valid in old data)
    # - ver: 1 (can be raised later if necessary
    # (following values are same as old-style, except length semantics changed)
    # - hcount: number of hashes
    # - length: bitfield length in bits
    # - seed: seed value for hashes

    if len(data) < 40:
        # unlikely but possible with old data
        bloom_from_bytes_legacy(mem, bloom, data)
        return
    pad, ver, hcount, length, seed = struct.unpack("<QQQQQ", data[0:40])
    if pad !=0:
        bloom_from_bytes_legacy(mem, bloom, data)
        return
    assert ver == 1, "Unknown serialization version"

    bloom.hcount = hcount
    bloom.length = length
    bloom.seed = seed
    buflen = length // KEY_BITS
    contents = struct.unpack(f"<{buflen}Q", data[40:])
    bloom.bitfield = <key_t*>mem.alloc(buflen, sizeof(key_t))
    for i in range(buflen):
        bloom.bitfield[i] = contents[i]


cdef void bloom_from_bytes_legacy(Pool mem, BloomStruct* bloom, bytes data):
    hcount, length, seed = struct.unpack("<QQQ", data[0:24])
    bloom.hcount = hcount
    bloom.length = length # in bits
    bloom.seed = seed

    # on non-Windows platforms
    unit = "Q"
    offset = 24
    # legacy check
    if length != len(data) - 24:
        # This can happen if the data was serialized on Windows, where the units
        # were 32bit rather than 64bit.
        hcount, length, seed = struct.unpack("<LLL", data[0:12])
        # data includes the prefix and bitfield, so add 3
        assert (length // 4) + 3 == len(data), "Length is invalid"

        bloom.hcount = hcount
        bloom.length = length
        bloom.seed = seed

        # change params to work with Windows data
        unit = "L"
        offset = 12

    # This is tricky - to remove empty space we're going to map bytes into
    # containers.
    buflen = length // KEY_BITS
    contents = struct.unpack(f"<{buflen}{unit}", data[offset:])
    bloom.bitfield = <key_t*>mem.alloc(buflen, sizeof(key_t))
    for i in range(len(contents)):
        block = i // 8
        idx = i % 8
        bloom.bitfield[block] |= contents[i] << (8 * idx)


cdef void bloom_init(Pool mem, BloomStruct* bloom, key_t hcount, key_t length, uint32_t seed) except *:
    # size should be a multiple of the container size - round up
    if length % KEY_BITS:
        length = math.ceil(length / KEY_BITS) * KEY_BITS
    bloom.length = length # this is a bit value
    bloom.hcount = hcount
    bloom.bitfield = <key_t*>mem.alloc(length // KEY_BITS, sizeof(key_t))
    bloom.seed = seed


# Instead of calling MurmurHash with a different seed for each hash function, this
# generates two initial hash values and then combines them to create the correct
# number of hashes. This technique is faster than just doing MurmurhHash
# repeatedly and has been shown to work as well as full hashing.

# For details see "Less Hashing, Same Performance: Building a Better Bloom
# Filter", Kirsch & Mitzenmacher.

# https://www.semanticscholar.org/paper/Less-hashing%2C-same-performance%3A-Building-a-better-Kirsch-Mitzenmacher/65c43afbfc064705bdc40d3473f32518e9306429
# The choice of seeds is arbitrary.


cdef void bloom_add(BloomStruct* bloom, key_t item) nogil:
    cdef key_t hv
    cdef key_t[2] keys
    cdef key_t one = 1 # We want this explicitly typed, because bits
    hash128_x86(&item, sizeof(key_t), 0, &keys)
    for hiter in range(bloom.hcount):
        hv = (keys[0] + (hiter * keys[1])) % bloom.length # length is in BITS
        #bloom.bitfield[hv // sizeof(key_t)] |= one << (hv % sizeof(key_t))
        bloom.bitfield[hv // KEY_BITS] |= one << (hv % KEY_BITS)


cdef bint bloom_contains(const BloomStruct* bloom, key_t item) nogil:
    cdef key_t hv
    cdef key_t[2] keys
    cdef key_t one = 1 # We want this explicitly typed, because bits
    hash128_x86(&item, sizeof(key_t), 0, &keys)
    for hiter in range(bloom.hcount):
        hv = (keys[0] + (hiter * keys[1])) % bloom.length # length is in BITS
        if not (bloom.bitfield[hv // KEY_BITS] & one << (hv % KEY_BITS)):
            return False
    return True


def pickle_bloom(BloomFilter bloom):
    return unpickle_bloom, (bloom.to_bytes(),)


def unpickle_bloom(byte_string):
    return BloomFilter().from_bytes(byte_string)


copy_reg.pickle(BloomFilter, pickle_bloom, unpickle_bloom)
