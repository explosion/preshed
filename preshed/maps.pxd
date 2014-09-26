from libc.stdint cimport uint64_t
from cymem.cymem cimport Pool


ctypedef uint64_t key_t


cdef struct Cell:
    key_t key
    void* value


cdef struct MapStruct:
    size_t length
    size_t filled
    Cell* cells


cdef void* map_get(MapStruct* map_, key_t key) nogil

cdef void map_set(Pool mem, MapStruct* map_, key_t key, void* value) except *


cdef class PreshMap:
    cdef MapStruct* c_map
    cdef Pool mem

    cdef inline void* get(self, key_t key) nogil
    cdef void set(self, key_t key, void* value) except *


cdef class PreshMapArray:
    cdef Pool mem
    cdef MapStruct* maps
    cdef size_t length

    cdef inline void* get(self, size_t i, key_t key) nogil
    cdef void set(self, size_t i, key_t key, void* value) except *
