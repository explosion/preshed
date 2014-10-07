from libc.stdint cimport uint32_t
from libc.stdint cimport uint64_t

#from thinc.features cimport feat_t
from cymem.cymem cimport Pool
from .maps cimport key_t
from .maps cimport MapStruct


ctypedef uint32_t idx_t
ctypedef uint32_t feat_t


cdef struct Node:
    Node* nodes
    idx_t offset
    idx_t length
    idx_t value


cdef class SequenceIndex:
    cdef Pool mem
    cdef Node* tree
    cdef MapStruct* pmap
    cdef readonly idx_t i
    cdef readonly idx_t longest_node 
    cdef idx_t get(self, feat_t* feat, size_t n) except *
    cdef idx_t index(self, feat_t* feat, size_t n) except 0
