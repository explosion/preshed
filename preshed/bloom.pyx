# cython: infer_types=True
# cython: cdivision=True
#
from libc.string cimport memcpy
from libcpp.algorithm cimport copy as cpp_copy
from murmurhash.mrmr cimport hash128_x86
import math
import struct

try:
    import copy_reg
except ImportError:
    import copyreg as copy_reg


cdef struct BloomStruct:
    vector[key_t] bitfield
    key_t hcount # hash count, number of hash functions
    key_t length
    uint32_t seed


cdef str FORMAT = "<QQQQL"
# this can't be in the enum because it depends on a string
cdef uint32_t STRUCT_SIZE = struct.calcsize(FORMAT)

cdef enum:
    KEY_BITS = 8 * sizeof(key_t)
    VERSION = 1
    LEGACY_UNIT_SIZE = 8
    LEGACY_OFFSET = 24 # 8 * 3
    LEGACY_WINDOWS_UNIT_SIZE = 4
    LEGACY_WINDOWS_OFFSET = 12 # 4 * 3


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
        assert size > 0, "Size must be greater than zero"
        assert hash_funcs > 0, "Hash function count must be greater than zero"
        self.c_bloom = make_unique[BloomStruct]()
        bloom_init(self.c_bloom.get(), hash_funcs, size, seed)

    @classmethod
    def from_error_rate(cls, members, error_rate=1E-4):
        params = calculate_size_and_hash_count(members, error_rate)
        return cls(*params)

    def add(self, key_t item):
        bloom_add(self.c_bloom.get(), item)

    def __contains__(self, item):
        return bloom_contains(self.c_bloom.get(), item)

    cdef inline bint contains(self, key_t item) nogil:
        return bloom_contains(self.c_bloom.get(), item)

    def to_bytes(self):
        return bloom_to_bytes(self.c_bloom.get())

    def from_bytes(self, bytes byte_string):
        bloom_from_bytes(self.c_bloom.get(), byte_string)
        return self


cdef bytes bloom_to_bytes(const BloomStruct* bloom):
    cdef key_t pad = 0 # to differentiate new from old data format
    cdef key_t buflen
    prefix = struct.pack(FORMAT, pad, VERSION, bloom.hcount, bloom.length, bloom.seed)
    # note that the modulus check is only required for data that has come from
    # legacy deserialization - otherwise length is always a multiple of
    # KEY_BITS.
    buflen = bloom.length // KEY_BITS
    if bloom.length % KEY_BITS > 0:
        buflen += 1
    buffer = (<const char*>bloom.bitfield.data())[0:buflen * sizeof(key_t)]
    return prefix + buffer


cdef void bloom_from_bytes(BloomStruct* bloom, bytes data):
    # new-style memory structure (each unit is a key_t/64 bits):
    # - pad1: 0 (not valid in old data)
    # - VERSION: 1 (can be raised later if necessary
    # (following values are same as old-style, except length semantics changed)
    # - hcount: number of hashes
    # - length: bitfield length in bits
    # - seed: seed value for hashes

    if len(data) < STRUCT_SIZE:
        # unlikely but possible with old data
        bloom_from_bytes_legacy(bloom, data)
        return
    pad, ver, hcount, length, seed = struct.unpack(FORMAT, data[0:STRUCT_SIZE])
    if pad != 0:
        bloom_from_bytes_legacy(bloom, data)
        return
    if ver != VERSION:
        raise ValueError("Unknown serialization version")

    bloom.hcount = hcount
    bloom.length = length
    # Technically overflow is possible here, but in valid data nothing will be
    # lost.
    bloom.seed = <uint32_t>seed

    cdef key_t buflen = length // KEY_BITS
    if length % KEY_BITS > 0:
        buflen += 1
    assert buflen > 0, "Tried to allocate an empty buffer"

    contents = data[STRUCT_SIZE:]
    cdef key_t* contents_c = <key_t*><char*>contents
    bloom.bitfield = vector[key_t](buflen)
    bloom.bitfield.assign(contents_c, contents_c + buflen)


cdef void bloom_from_bytes_legacy(BloomStruct* bloom, bytes data):
    # Older versions of this library used the array module with type L for
    # serialization. Types in array guarantee a minimum size, not an actual
    # size, and it turns out L is 8 bytes on Linux and most platforms, but 4 on
    # Windows. 

    # As a separate issue, due to bits/bytes confusion, each container in the
    # serialized data has only one byte actually used.

    # The code in this function reads in data in the old format and converts it
    # to the current format losslessly. It also packs the actually used bytes into
    # contiguous memory.

    # on non-Windows platforms
    unit = "Q"
    unit_size = LEGACY_UNIT_SIZE # size of container in bytes
    cdef uint32_t offset = LEGACY_OFFSET

    hcount, length, seed = struct.unpack("<QQQ", data[0:offset])

    if length != len(data) - LEGACY_OFFSET:
        # This can happen if the data was serialized on Windows, where the units
        # were 32bit rather than 64bit.
        unit = "L"
        unit_size = LEGACY_WINDOWS_UNIT_SIZE
        offset = LEGACY_WINDOWS_OFFSET
        hcount, length, seed = struct.unpack("<LLL", data[0:offset])

        # The length was the number of bytes in memory. But because of the
        # platform size issue, the actual serialized bytes is half that.
        assert length // 2 == len(data) - offset, "Length is invalid"

    # This is the same in either case because the Windows code was written
    # without being aware of the difference in size between Windows and
    # non-Windows.
    decode_len = length // LEGACY_UNIT_SIZE

    bloom.hcount = hcount
    bloom.length = length
    bloom.seed = <uint32_t>seed

    # This is tricky - to remove empty space we're going to map bytes into
    # containers. On Windows or Linux, length is both the number of actually
    # used bits in the bitfield and the number of bytes when the bitfield was
    # in memory in the old format. In our output, length will be the bitfield
    # length in bits.

    buflen = length // KEY_BITS
    if length % KEY_BITS > 0:
        buflen += 1
    contents = struct.unpack(f"<{decode_len}{unit}", data[offset:])
    assert buflen > 0, "Tried to allocate an empty buffer"
    bloom.bitfield = vector[key_t](buflen, 0)

    # Each item in contents provides one actually used byte, so we'll copy it
    # into the containers.
    for i in range(len(contents)):
        block = i // sizeof(key_t)
        idx = i % sizeof(key_t)
        bloom.bitfield[block] |= contents[i] << (8 * idx)


cdef void bloom_init(BloomStruct* bloom, key_t hcount, key_t length, uint32_t seed) except *:
    # size should be a multiple of the container size - round up
    if length % KEY_BITS:
        length = ((length // KEY_BITS) + 1) * KEY_BITS
    bloom.length = length # this is a bit value
    bloom.hcount = hcount
    buflen = length // KEY_BITS
    assert buflen > 0, "Tried to allocate an empty buffer"
    bloom.bitfield = vector[key_t](buflen, 0)
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
