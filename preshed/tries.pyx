from cpython cimport array
from array import array
from libc.string cimport memcpy
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free

cpdef feat_t[:] array_from_tuple(tuple t):
    cdef size_t length = len(t)
    cdef array.array a = array('I', t)
    return a


cdef class AddressTree:
    def __init__(self):
        self.mem = Pool()
        self.tree = <Node*>self.mem.alloc(1, sizeof(Node))
        assert self.tree.nodes is NULL

    property first:
        def __get__(self):
            cdef Node* node = self.tree
            cdef void* value
            while node.nodes != NULL:
                node = node.nodes
            return <size_t>node.value

    property last:
        def __get__(self):
            cdef Node* node = self.tree
            while node.nodes != NULL:
                node = &node.nodes[node.length - 1]
            return <size_t>node.value

    property value:
        def __get__(self):
            return <size_t>self.tree.nodes[0].value

    def __getitem__(self, feature):
        cdef size_t length = len(feature)
        cdef array.array a = array('I', feature)
        cdef feat_t[:] feat_array = a
        cdef void* value = self.get(&(feat_array[0]), len(feature))
        if value == NULL:
            return None
        else:
            return <size_t>value

    def __setitem__(self, feature, size_t value):
        cdef feat_t[:] feat_array = array_from_tuple(feature)
        self.set(&(feat_array[0]), len(feature), <void*>value)

    cdef void* get(self, feat_t* feature, size_t n) except *:
        cdef Node* node = self.tree
        cdef idx_t i
        cdef feat_t f
        for i in range(n):
            f = feature[i]
            if node.offset <= f < (node.offset + node.length):
                node = &node.nodes[f - node.offset]
            else:
                return NULL
        return node.value

    cdef void set(self, feat_t* feature, size_t n, void* value) except *:
        cdef Node* node = self.tree
        cdef idx_t i
        cdef feat_t f
        for i in range(n):
            f = feature[i]
            if node.nodes == NULL:
                node.offset = f
                node.length = 1
                node.nodes = <Node*>self.mem.alloc(node.length, sizeof(Node))
            elif f < node.offset:
                node.nodes = array_prepend(self.mem, node.nodes, node.length,
                                           node.offset - f)
                node.length += node.offset - f
                node.offset = f
            elif f >= (node.length + node.offset):
                node.length = f - node.offset + 1
                node.nodes = <Node*>self.mem.realloc(node.nodes, node.length * sizeof(Node))
            node = &(node.nodes[f - node.offset])
        node.value = value
        

cdef Node* array_prepend(Pool mem, Node* old, size_t length, size_t to_add) except NULL:
    cdef size_t i, j
    cdef Node* new = <Node*>mem.alloc(length + to_add, sizeof(Node))
    memcpy(&new[to_add], old, length * sizeof(Node))
    mem.free(old)
    return new
