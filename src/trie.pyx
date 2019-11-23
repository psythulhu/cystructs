# distutils: language = c++
from cython.operator cimport dereference as deref
from libcpp.unordered_map cimport unordered_map
from libcpp.vector cimport vector
from libcpp cimport bool

from libc.limits cimport UCHAR_MAX as MAX_ITEM_REF
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t
from cymem.cymem cimport Pool
from libc.string cimport memset
from libc.string cimport strncpy

# Branching factor is 16
ctypedef struct EntryRef:
    uint8_t target_size
    uint32_t group
    uint8_t item

ctypedef struct Entry:
    uint8_t cpoint

cdef entry_size(EntryRef e):
    return sizeof(Entry) + (sizeof(EntryRef) * e.target_size)`

cdef class EntryPool:

    cdef Pool mem
    cdef vector[ vector[uint8_t*]* ] sized_blocks
    cdef vector[ vector[EntryRef]* ] empty_refs
    cdef vector[uint32_t] headsize

    def __init__(self):
        pass

    def __cinit__(self):
        cdef uint8_t i=0
        self.mem = Pool()

        for i in range(18):
            self.sized_blocks.push_back( new vector[void*]() )
            self.empty_refs.push_back( new vector[uint64_t]() )
            self.headsize.push_back( 0 )

        self.add_group()
        

    cdef void add_group(self, uint8_t target_size):
        cdef uint8_t * group
        cdef uint64_t n_bytes = sizeof(Entry.cpoint) + (target_size * sizeof(EntryRef))
        
        group = <uint8_t*> self.mem.alloc(1 + MAX_ITEM_REF, n_bytes) 
        memset(<void*> group, 0, n_bytes)
        
        self.sized_blocks[target_size].push_back( group )
        self.headsize[target_size] = 0

    cdef EntryRef add_child(self, EntryRef * node, uint8_t cpoint):
        cdef uint32_t i = 0
        cdef uint16_t new_size = node.target_size + 1
        
        cdef Entry * kid = NULL
        cdef Entry * old_entry = self.get_entry(deref(node))
        cdef EntryRef * old_kids = <EntryRef*> ((<uint8_t*> old_entry)+1)
        
        cdef EntryRef new_ref = self.add(new_size)
        cdef Entry * new_entry = self.get_entry(new_ref)
        cdef EntryRef * new_kids = <EntryRef*> ((<uint8_t*> new_entry)+1)

        cdef EntryRef child_ref = self.add(0)
        cdef Entry * child_entry = self.get_entry(child_ref)

        child_entry.cpoint = cpoint & 0b01111111

        self.empty_refs[node.target_size].push_back(deref(node))
        
        # Copy over old node
        new_entry.cpoint = old_entry.cpoint | 0b1000000
        i=0
        while i < node.target_size:
            kid = self.get_entry( old_kids[i] )
            if kid.cpoint >= cpoint:
                new_kids[i] = child_ref
                while i < new_size:
                    new_kids[i+1] = old_kids[i]
                break
            else:
                new_kids[i] = old_kids[i]
        
            i += 1

        if i < new_size:
            new_kids[i] = child_ref

        # Reset the node pointer inplace
        node.target_size = new_ref.target_size
        node.group = new_ref.group
        node.item = new_ref.item

    cdef EntryRef add(self, uint8_t target_size):
        cdef EntryRef e = EntryRef(target_size, 0, 0)

        if self.empty_refs[target_size].size() > 0:
            e = deref(self.empty_refs[target_size].back())
            self.empty_refs[target_size].pop_back()
            return e
        else:

            if self.headsize[target_size] >= MAX_ITEM_REF:
                self.add_group(target_size)

            self.headsize[target_size] += 1

            e.group = self.sized_blocks[target_size].size()-1
            e.item = self.headsize[target_size] - 1

            return e

    cdef Entry * get_entry(self, EntryRef ref):
        cdef esize = entry_size(ref)
        return <Entry *> ((<uint8_t*> self.sized_blocks[ref.target_size][ref.group]) + (ref.item * esize))

cdef class Trie:
    cdef EntryPool pool
    cdef uint64_t size

    def __init__(self):
        self.mem = Pool()

    def __cinit__(self):
        cdef void * first_block = self.mem.alloc(1 << block_size, sizeof(Entry))
        self.blocks = new vector[void *]()
        self.size = 0
        memset(first_block, 0, (1<<block_size) * sizeof(Entry))
        self.blocks.push_back(first_block)

    def __del__(self):
        del self.blocks

    cdef Entry * get_new_entry(self):
        cdef uint64_t new_id = self.size

        self.size += 1

    cdef add_child(self, Entry * parent, Entry * node, uint8_t child):
        
        

    cpdef uint64_t add(self, char * item, uint32_t item_len):
        
        cdef vector[void *] * blocks = self.blocks
        cdef void * block;
        cdef Pool mem = self.mem
        cdef uint32_t in_block = 0
        cdef uint64_t ref_index = 0
        cdef uint64_t ref_block = 0
        cdef uint32_t i = 0
        cdef uint8_t child_num = 0
        cdef uint8_t b = <uint8_t> item[0]
        cdef Entry *e = <Entry *> self.blocks[0][0]

        # e is now the root of the Trie
        for i in range(item_len):
            # High
            child_num = <uint8_t> item[i] & 0xf0
            if entry_child(e, child_num) == 0:
                ref_index = self.size & ((1 << block_size)-1)
                ref_block = self.size >> block_size

                while ref_block >= blocks.size():
                    block = mem.alloc(1 << block_size, sizeof(Entry))
                    memset(block, 0, (1<<block_size) * sizeof(Entry))
                    blocks.push_back( block )

                e = <Entry *> &block[ ref_index ]
                
                self.size += 1








