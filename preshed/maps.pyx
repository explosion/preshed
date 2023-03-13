# cython: infer_types=True
# cython: cdivision=True
#
cimport cython
from cython.operator import dereference as deref
from libcpp.memory cimport make_unique


DEF EMPTY_KEY = 0
DEF DELETED_KEY = 1


# Note: will not be needed with Cython 3.
cdef extern from "<utility>" namespace "std" nogil:
    void swap[T](T& a, T& b)


cdef class PreshMap:
    """Hash map that assumes keys come pre-hashed. Maps uint64_t --> uint64_t.
    Uses open addressing with linear probing.

    Usage
        map = PreshMap() # Create a table
        map = PreshMap(initial_size=1024) # Create with initial size (efficiency)
        map[key] = value # Set a value to a key
        value = map[key] # Get a value given a key
        for key, value in map.items(): # Iterate over items
        len(map) # Get number of inserted keys
    """
    def __init__(self, size_t initial_size=8):
        # Size must be power of two
        if initial_size == 0:
            initial_size = 8
        if initial_size & (initial_size - 1) != 0:
            power = 1
            while power < initial_size:
                power *= 2
            initial_size = power
        self.c_map = make_unique[MapStruct]()
        map_init(self.c_map.get(), initial_size)

    property capacity:
        def __get__(self):
            return deref(self.c_map).cells.size()

    def items(self):
        cdef key_t key
        cdef void* value
        cdef int i = 0
        while map_iter(self.c_map.get(), &i, &key, &value):
            yield key, <size_t>value

    def keys(self):
        for key, _ in self.items():
            yield key

    def values(self):
        for _, value in self.items():
            yield value

    def pop(self, key_t key, default=None):
        cdef Result result = map_get_unless_missing(self.c_map.get(), key)
        map_clear(self.c_map.get(), key)
        if result.found:
            return <size_t>result.value
        else:
            return default

    def __getitem__(self, key_t key):
        cdef Result result = map_get_unless_missing(self.c_map.get(), key)
        if result.found:
            return <size_t>result.value
        else:
            return None

    def __setitem__(self, key_t key, size_t value):
        map_set(self.c_map.get(), key, <void*>value)

    def __delitem__(self, key_t key):
        map_clear(self.c_map.get(), key)

    def __len__(self):
        return deref(self.c_map).filled

    def __contains__(self, key_t key):
        cdef Result result = map_get_unless_missing(self.c_map.get(), key)
        return True if result.found else False

    def __iter__(self):
        for key in self.keys():
            yield key

    cdef inline void* get(self, key_t key) nogil:
        return map_get(self.c_map.get(), key)

    cdef void set(self, key_t key, void* value) except *:
        map_set(self.c_map.get(), key, <void*>value)


cdef void map_init(MapStruct* map_, size_t length) except *:
    map_.filled = 0
    map_.cells.resize(length)


cdef void map_set(MapStruct* map_, key_t key, void* value) except *:
    cdef vector[Cell].iterator cell
    if key == EMPTY_KEY:
        map_.value_for_empty_key = value
        map_.is_empty_key_set = True
    elif key == DELETED_KEY:
        map_.value_for_del_key = value
        map_.is_del_key_set = True
    else:
        cell = _find_cell_for_insertion(&map_.cells, key)
        if deref(cell).key == EMPTY_KEY:
            map_.filled += 1
        deref(cell).key = key
        deref(cell).value = value
        if (map_.filled + 1) * 5 >= (map_.cells.size() * 3):
            _resize(map_)


cdef void* map_get(const MapStruct* map_, const key_t key) nogil:
    if key == EMPTY_KEY:
        return map_.value_for_empty_key
    elif key == DELETED_KEY:
        return map_.value_for_del_key
    cdef Cell cell = _find_cell(map_.cells, key)
    return cell.value


cdef Result map_get_unless_missing(const MapStruct* map_, const key_t key) nogil:
    cdef Result result
    cdef Cell cell
    result.found = 0
    result.value = NULL
    if key == EMPTY_KEY:
        if map_.is_empty_key_set:
            result.found = 1
            result.value = map_.value_for_empty_key
    elif key == DELETED_KEY:
        if map_.is_del_key_set:
            result.found = 1
            result.value = map_.value_for_del_key
    else:
        cell = _find_cell(map_.cells, key)
        if cell.key == key:
            result.found = 1
            result.value = cell.value
    return result


cdef void* map_clear(MapStruct* map_, const key_t key) nogil:
    if key == EMPTY_KEY:
        value = map_.value_for_empty_key if map_.is_empty_key_set else NULL
        map_.is_empty_key_set = False
        return value
    elif key == DELETED_KEY:
        value = map_.value_for_del_key if map_.is_del_key_set else NULL
        map_.is_del_key_set = False
        return value
    else:
        cell = _find_cell(map_.cells, key)
        cell.key = DELETED_KEY
        # We shouldn't decrement the "filled" value here, as we're not actually
        # making "empty" values -- deleted values aren't quite the same.
        # Instead if we manage to insert into a deleted slot, we don't increment
        # the fill rate.
        return cell.value


cdef void* map_bulk_get(const MapStruct* map_, const key_t* keys, void** values,
                        int n) nogil:
    cdef int i
    for i in range(n):
        values[i] = map_get(map_, keys[i])


cdef bint map_iter(const MapStruct* map_, int* i, key_t* key, void** value) nogil:
    '''Iterate over the filled items, setting the current place in i, and the
    key and value.  Return False when iteration finishes.
    '''
    cdef const Cell* cell
    while i[0] < map_.cells.size():
        cell = &map_.cells[i[0]]
        i[0] += 1
        if cell[0].key != EMPTY_KEY and cell[0].key != DELETED_KEY:
            key[0] = cell[0].key
            value[0] = cell[0].value
            return True
    # Remember to check for cells keyed by the special empty and deleted keys
    if i[0] == map_.cells.size():
        i[0] += 1
        if map_.is_empty_key_set:
            key[0] = EMPTY_KEY
            value[0] = map_.value_for_empty_key
            return True
    if i[0] == map_.cells.size() + 1:
        i[0] += 1
        if map_.is_del_key_set:
            key[0] = DELETED_KEY
            value[0] = map_.value_for_del_key
            return True
    return False


@cython.cdivision
cdef inline Cell _find_cell(const vector[Cell]& cells, const key_t key) nogil:
    # Modulo for powers-of-two via bitwise &
    cdef key_t i = (key & (cells.size() - 1))
    while cells[i].key != EMPTY_KEY and cells[i].key != key:
        i = (i + 1) & (cells.size() - 1)
    return cells[i]


@cython.cdivision
cdef inline vector[Cell].iterator _find_cell_for_insertion(vector[Cell]* cells, const key_t key) nogil:
    """Find the correct cell to insert a value, which could be a previously
    deleted cell. If we cross a deleted cell and the key is in the table, we
    mark the later cell as deleted, and return the earlier one."""
    cdef vector[Cell].iterator deleted = cells.end()
    # Modulo for powers-of-two via bitwise &
    cdef key_t i = (key & (cells.size() - 1))
    while deref(cells)[i].key != EMPTY_KEY and deref(cells)[i].key != key:
        if deref(cells)[i].key == DELETED_KEY:
            deleted = cells.begin() + i
        i = (i + 1) & (cells.size() - 1)
    if deleted != cells.end():
        if deref(deleted).key == key:
            # We need to ensure we don't end up with the key in the table twice.
            # If we're using a deleted cell and we also have the key, we mark
            # the later cell as deleted.
            deref(cells)[i].key = DELETED_KEY
        return deleted
    return cells.begin() + i


cdef void _resize(MapStruct* map_) except *:
    # Allocate memory for new cells and swap out.
    cdef vector[Cell] old_cells = vector[Cell](map_.cells.size() * 2)
    swap(old_cells, map_.cells)

    map_.filled = 0

    cdef size_t i
    for i in range(old_cells.size()):
        if old_cells[i].key != EMPTY_KEY and old_cells[i].key != DELETED_KEY:
            map_set(map_, old_cells[i].key, old_cells[i].value)
