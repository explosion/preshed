from libc.stdint cimport uint32_t
from libc.stdint cimport uint64_t

#from thinc.features cimport feat_t
from cymem.cymem cimport Pool
from cpython cimport array


ctypedef uint32_t idx_t
ctypedef uint32_t feat_t


cpdef feat_t[:] array_from_tuple(tuple t)


cdef struct Node:
    Node* nodes
    idx_t offset
    idx_t length
    idx_t value


cdef class SequenceIndex:
    cdef Pool mem
    cdef Node* tree
    cdef readonly idx_t i
    cdef idx_t get(self, feat_t[:] feat, size_t n) except *
    cdef idx_t index(self, feat_t[:] feat, size_t n) except 0
