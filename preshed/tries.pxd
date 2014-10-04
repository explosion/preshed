from libc.stdint cimport uint32_t
from libc.stdint cimport uint64_t

#from thinc.features cimport feat_t
from cymem.cymem cimport Pool
from cpython cimport array

ctypedef uint32_t idx_t
ctypedef uint32_t feat_t


cpdef feat_t[:] array_from_tuple(tuple t)


cdef struct Node:
    idx_t offset
    idx_t length
    Node* nodes
    void* value


cdef class AddressTree:
    cdef Pool mem
    cdef Node* tree
    cdef void* get(self, feat_t* feat, size_t n) except *
    cdef void set(self, feat_t* feat, size_t n, void* value) except *
