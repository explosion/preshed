import ujson

from libc.string cimport memcpy

from murmurhash.mrmr cimport hash64
from cymem.cymem cimport Address

from .maps cimport map_init, map_get, map_set


DEF MAX_TRIE_VALUE = 100000


cdef class SequenceIndex:
    """Map numeric arrays to sequential unsigned integers, starting from 1. 0
    indicates that the array was not found.
    """
    def __init__(self, idx_t offset=0):
        self.mem = Pool()
        self.tree = <Node*>self.mem.alloc(1, sizeof(Node))
        self.pmap = <MapStruct*>self.mem.alloc(1, sizeof(MapStruct))
        map_init(self.mem, self.pmap, 8)
        # Value of 0 set aside for special use by the parent code, whatever that
        # might be.
        self.i = 1 + offset
        self.longest_node = 0
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
        # First, check we don't have any over-size values
        cdef idx_t i
        cdef key_t hashed
        cdef Node* node = self.tree
        cdef feat_t f
        for i in range(n):
            f = feature[i]
            if f >= MAX_TRIE_VALUE:
                hashed = hash64(feature, n * sizeof(feat_t), 0)
                return <idx_t>map_get(self.pmap, hashed)
            elif node.offset <= f < (node.offset + node.length):
                node = &node.nodes[f - node.offset]
            else:
                return 0
        return node.value

    cdef idx_t index(self, feat_t* feature, size_t n) except 0:
        assert n >= 1
        cdef key_t hashed
        cdef idx_t i
        for i in range(n):
            if feature[i] >= MAX_TRIE_VALUE:
                hashed = hash64(feature, n * sizeof(feat_t), 0)
                map_set(self.mem, self.pmap, hashed, <void*>self.i)
                self.i += 1
                return self.i - 1

        cdef Node* node = self.tree
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
            if node.length > self.longest_node:
                self.longest_node = node.length
            node = &(node.nodes[f - node.offset])
        if node.value == 0:
            node.value = self.i
            self.i += 1
        return node.value

    def revalue(self, list new_values):
        assert len(new_values) == self.i
        cdef Address table_mem = array_from_seq(new_values)
        cdef feat_t* table = <feat_t*>table_mem.ptr
        cdef NodeIterator nodes = NodeIterator(self)
        cdef size_t addr
        cdef Node* node
        for _ in nodes:
            nodes.node.value = table[nodes.node.value]
        for i in range(self.pmap.length):
            if self.pmap.cells[i].key != 0:
                self.pmap.cells[i].value = <void*>table[<feat_t>self.pmap.cells[i].value]

    def dump(self, file_):
        for i in range(self.pmap.length):
            if self.pmap.cells[i].key != 0:
                file_.write(_fmt_line(<idx_t>self.pmap.cells[i].value,
                                      [self.pmap.cells[i].key]))
        for address, value in NodeIterator(self):
            if value == 0:
                continue
            file_.write(_fmt_line(value, address))

    def load(self, file_):
        for line in file_:
            value, address = _parse_line(line)
            if not address:
                continue
            self.i = value
            self(*address)


def _fmt_line(value, address):
    return ujson.dumps((value, (address,)))

def _parse_line(line):
    return ujson.loads(line)


cdef class NodeIterator:
    cdef Pool mem
    cdef Node* node
    cdef Node** stack
    cdef size_t* offsets
    cdef idx_t i
    def __init__(self, SequenceIndex trie):
        self.mem = Pool()
        self.stack = <Node**>self.mem.alloc(trie.i, sizeof(Node*))
        self.offsets = <size_t*>self.mem.alloc(trie.i, sizeof(size_t))
        self.stack[0] = trie.tree
        self.i = 1

    def __iter__(self):
        """Iterate over the keys and values in the trie.
        """
        cdef Node* node
        cdef Node* parent
        cdef size_t i
        while self.i != 0:
            self.i -= 1
            node = self.stack[self.i]
            key = []
            i = self.i
            # In parallel to the stack, we note the offset of the node's parent in
            # the stack, so that we can always find the parent of stack-node i at
            # self.stack[i - self.offsets[i]].
            while i != 0:
                parent = self.stack[i - self.offsets[i]]
                key.insert(0, parent.offset + self.offsets[i])
                if self.offsets[i] == 0:
                    i -= 1
                else:
                    i -= self.offsets[i]
            # Push the children onto the stack
            for i in range(node.length):
                self.stack[self.i] = &node.nodes[i]
                self.offsets[self.i] = i    
                self.i += 1
            self.node = node
            yield key, node.value


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
