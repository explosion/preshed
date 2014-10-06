from cpython cimport array
from array import array
from libc.string cimport memcpy
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free

cpdef feat_t[:] array_from_tuple(tuple t):
    cdef size_t length = len(t)
    cdef array.array a = array('I', t)
    return a


cdef class SequenceIndex:
    """Map numeric arrays to sequential unsigned integers, starting from 1. 0
    indicates that the array was not found.
    """
    def __init__(self):
        self.mem = Pool()
        self.tree = <Node*>self.mem.alloc(1, sizeof(Node))
        # Value of 0 set aside for special use by the parent code, whatever that
        # might be.
        self.i = 1
        assert self.tree.nodes is NULL

    def __getitem__(self, feature):
        try:
            len(feature)
        except TypeError:
            feature = (feature,)
        cdef array.array a = array('I', feature)
        cdef feat_t[:] feat_array = a
        return self.get(feat_array, len(feature))

    def __call__(self, *feature):
        cdef array.array a = array('I', feature)
        cdef feat_t[:] feat_array = a
        return self.index(feat_array, len(feature))

    cdef idx_t get(self, feat_t[:] feature, size_t n) except *:
        cdef Node* node = self.tree
        cdef idx_t i
        cdef feat_t f
        for i in range(n):
            f = feature[i]
            if node.offset <= f < (node.offset + node.length):
                node = &node.nodes[f - node.offset]
            else:
                return 0
        return node.value

    cdef idx_t index(self, feat_t[:] feature, size_t n) except 0:
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
        if node.value == 0:
            node.value = self.i
            self.i += 1
        return node.value


cdef Node* array_prepend(Pool mem, Node* old, size_t length, size_t to_add) except NULL:
    cdef size_t i, j
    cdef Node* new = <Node*>mem.alloc(length + to_add, sizeof(Node))
    memcpy(&new[to_add], old, length * sizeof(Node))
    mem.free(old)
    return new
