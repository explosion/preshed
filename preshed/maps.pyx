# cython: profile=True
cimport cython


cdef class PreshMap:
    """Hash map that assumes keys come pre-hashed. Uses open addressing with
    linear probing.
    """
    def __init__(self, size_t initial_size=8):
        # Size must be power of two
        assert initial_size != 0
        assert initial_size & (initial_size - 1) == 0
        self.mem = Pool()
        self.c_map = <MapStruct*>self.mem.alloc(1, sizeof(MapStruct))
        map_init(self.mem, self.c_map, initial_size)

    property length:
        def __get__(self):
            return self.c_map.length

    def __getitem__(self, key_t key):
        assert key != 0
        cdef void* value = map_get(self.c_map, key)
        return <size_t>value if value != NULL else None

    def __setitem__(self, key_t key, size_t value):
        assert key != 0 and value != 0
        map_set(self.mem, self.c_map, key, <void*>value)

    cdef inline void* get(self, key_t key) nogil:
        return map_get(self.c_map, key)

    cdef void set(self, key_t key, void* value) except *:
        map_set(self.mem, self.c_map, key, <void*>value)


cdef class PreshMapArray:
    """An array of hash tables that assume keys come pre-hashed.  Each table
    uses open addressing with linear probing.
    """
    def __init__(self, size_t length, size_t initial_size=8):
        self.mem = Pool()
        self.length = length
        self.maps = <MapStruct*>self.mem.alloc(length, sizeof(MapStruct))
        for i in range(length):
            map_init(self.mem, &self.maps[i], initial_size)

    cdef inline void* get(self, size_t i, key_t key) nogil:
        return map_get(&self.maps[i], key)

    cdef void set(self, size_t i, key_t key, void* value) except *:
        map_set(self.mem, &self.maps[i], key, <void*>value)


cdef void map_init(Pool mem, MapStruct* map_, size_t length) except *:
    map_.length = length
    map_.filled = 0
    map_.cells = <Cell*>mem.alloc(length, sizeof(Cell))


cdef void* map_get(MapStruct* map_, key_t key) nogil:
    cdef Cell* cell = _find_cell(map_.cells, map_.length, key)
    return cell.value


cdef void map_set(Pool mem, MapStruct* map_, key_t key, void* value) except *:
    cdef Cell* cell
    cell = _find_cell(map_.cells, map_.length, key)
    if cell.key == 0:
        cell.key = key
        map_.filled += 1
    cell.value = value
    if (map_.filled + 1) * 4 >= (map_.length * 3):
        _resize(mem, map_)


cdef void _resize(Pool mem, MapStruct* map_) except *:
    cdef size_t new_size = map_.length * 2
    cdef Cell* old_cells = map_.cells
    cdef size_t old_size = map_.length

    map_.length = new_size
    map_.filled = 0
    map_.cells = <Cell*>mem.alloc(new_size, sizeof(Cell))
    
    cdef size_t i
    cdef size_t slot
    for i in range(old_size):
        if old_cells[i].key != 0:
            assert old_cells[i].value != NULL, i
            map_set(mem, map_, old_cells[i].key, old_cells[i].value)
    mem.free(old_cells)


@cython.cdivision
cdef inline Cell* _find_cell(Cell* cells, size_t size, key_t key) nogil:
    # Modulo for powers-of-two via bitwise &
    cdef size_t i = (key & (size - 1))
    while cells[i].key != 0 and cells[i].key != key:
        i = (i + 1) & (size - 1)
    return &cells[i]
