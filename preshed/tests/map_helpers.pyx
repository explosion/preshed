from ..maps cimport PreshMap, key_t, map_clear


def get_after_clear(key_t key, size_t value):
    """Set key, clear it, and return what the C-level map_get sees."""
    cdef PreshMap table = PreshMap()
    table.set(key, <void*>value)
    map_clear(table.c_map, key)
    return <size_t>table.get(key)
