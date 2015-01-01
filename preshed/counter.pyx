"""Count occurrences of uint64-valued keys."""

cdef class PreshCounter:
    def __init__(self, initial_size=8):
        assert initial_size != 0
        assert initial_size & (initial_size - 1) == 0
        self.mem = Pool()
        self.c_map = <MapStruct*>self.mem.alloc(1, sizeof(MapStruct))
        map_init(self.mem, self.c_map, initial_size)

    property length:
        def __get__(self):
            return self.c_map.length

    def __len__(self):
        return self.c_map.length

    def __iter__(self):
        cdef int i
        for i in range(self.c_map.length):
            if self.c_map.cells[i].key != 0:
                yield (self.c_map.cells[i].key, <count_t>self.c_map.cells[i].value)

    def __getitem__(self, key_t key):
        return <count_t>map_get(self.c_map, key)

    cpdef int inc(self, key_t key, count_t inc) except -1:
        cdef count_t c = <count_t>map_get(self.c_map, key)
        c += inc
        map_set(self.mem, self.c_map, key, <void*>c)


