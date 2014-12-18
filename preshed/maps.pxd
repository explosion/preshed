cimport cython

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


@cython.cdivision
cdef inline Cell* _find_cell(const Cell* cells, const size_t size, const key_t key) nogil:
    # Modulo for powers-of-two via bitwise &
    cdef size_t i = (key & (size - 1))
    while cells[i].key != 0 and cells[i].key != key:
        i = (i + 1) & (size - 1)
    return &cells[i]

cdef inline void* map_get(const MapStruct* map_, const key_t key) nogil:
    cdef Cell* cell = _find_cell(map_.cells, map_.length, key)
    return cell.value


cdef void map_set(Pool mem, MapStruct* map_, key_t key, void* value) except *

cdef void map_init(Pool mem, MapStruct* pmap, size_t length) except *

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
