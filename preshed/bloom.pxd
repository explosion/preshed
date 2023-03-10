from libc.stdint cimport uint64_t, uint32_t
from libcpp.memory cimport make_unique, unique_ptr
from libcpp.vector cimport vector

ctypedef uint64_t key_t

cdef struct BloomStruct


cdef class BloomFilter:
    cdef unique_ptr[BloomStruct] c_bloom
    cdef inline bint contains(self, key_t item) nogil

