from libc.string cimport memcpy

from cymem.cymem cimport Address


cdef class SequenceIndex:
    """Map numeric arrays to sequential unsigned integers, starting from 1. 0
    indicates that the array was not found.
    """
    def __init__(self, idx_t offset=0):
        self.mem = Pool()
        self.tree = <Node*>self.mem.alloc(1, sizeof(Node))
        # Value of 0 set aside for special use by the parent code, whatever that
        # might be.
        self.i = 1 + offset
        assert self.tree.nodes is NULL

    def __getitem__(self, feature):
        try:
            len(feature)
        except TypeError:
            feature = (feature,)
        cdef Address mem = array_from_seq(feature)
        return self.get(<feat_t*>mem.ptr, len(feature))

    def __call__(self, *feature):
        cdef Address mem = array_from_seq(feature)
        return self.index(<feat_t*>mem.ptr, len(feature))

    cdef idx_t get(self, feat_t* feature, size_t n) except *:
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

    cdef idx_t index(self, feat_t* feature, size_t n) except 0:
        assert n >= 1
        cdef Node* node = self.tree
        cdef idx_t i
        cdef feat_t f
        cdef size_t node_addr
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
            node_addr = <size_t>&(node.nodes[f - node.offset])
            node = &(node.nodes[f - node.offset])
        if node.value == 0:
            node.value = self.i
            self.i += 1
        return node.value

    def revalue(self, list new_values):
        assert len(new_values) == self.i
        cdef Address table_mem = array_from_seq(new_values)
        cdef feat_t* table = <feat_t*>table_mem.ptr
        cdef Address stack_mem = Address(self.i, sizeof(Node*))
        stack = <Node**>stack_mem.ptr
        stack[0] = self.tree
        cdef int i = 1
        cdef Node* node
        while i != 0:
            i -= 1
            # Pop a node from the stack
            node = stack[i]
            # Replace value
            node.value = table[node.value]
            # Push the children onto the stack
            for j in range(node.length):
                stack[i] = &node.nodes[j]; i += 1
                # Should not be possible to have more nodes than in total trie
                assert i < self.i


cdef Address array_from_seq(object seq):
    cdef Address mem = Address(len(seq), sizeof(feat_t))
    array = <feat_t*>mem.ptr
    cdef int i
    cdef feat_t f
    for i, f in enumerate(seq):
        array[i] = f
    return mem


cdef Node* array_prepend(Pool mem, Node* old, size_t length, size_t to_add) except NULL:
    cdef size_t i, j
    cdef Node* new = <Node*>mem.alloc(length + to_add, sizeof(Node))
    memcpy(&new[to_add], old, length * sizeof(Node))
    mem.free(old)
    return new
