from libc.stdint cimport uint64_t, uint32_t
from libcpp.memory cimport make_unique, unique_ptr
from libcpp.vector cimport vector

ctypedef uint64_t key_t

cdef cppclass BloomStruct:
    vector[key_t] bitfield
    key_t hcount # hash count, number of hash functions
    key_t length
    uint32_t seed


cdef class BloomFilter:
    cdef unique_ptr[BloomStruct] c_bloom
    cdef inline bint contains(self, key_t item) nogil


cdef void bloom_init(BloomStruct* bloom, key_t hcount, key_t length, uint32_t seed) except *

cdef void bloom_add(BloomStruct* bloom, key_t item) nogil

cdef bint bloom_contains(const BloomStruct* bloom, key_t item) nogil

cdef void bloom_add(BloomStruct* bloom, key_t item) nogil
