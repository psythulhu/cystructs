# distutils: language = c++

from libcpp.unordered_map cimport unordered_map
from libcpp.vector cimport vector
from libcpp cimport bool

from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t
from cymem.cymem cimport Pool
from libc.string cimport memset


cdef uint64_t block_size = 12
cdef uint64_t block_mask = 0xfff
cdef uint64_t high_mask = 0xffffff00000000000
cdef uint64_t low_mask  = 0x000000fffffffffff
(<uint64_t*> (d + (n*5))) 0x000000ffffffffff

# Branching factor is 16
ctypedef struct Entry:
    unsigned char[88] data

cdef uint64_t entry_child(Entry *e, uint8_t n):
    cdef unsigned char * d = <unsigned char *> &e.data
    return (<uint64_t*> (d + (n*5)))[0] & 0x000000ffffffffff

cdef entry_set_ref(Entry *e, uint8_t n, uint64_t to):
    cdef uint64_t v_old = e.data[n*5]
    cdef uint64_t v_new = v_old

cdef uint64_t entry_id(Entry *e):
    return entry_child(e, 16)

cdef uint32_t entry_inc(Entry *e):
    cdef unsigned char * d = <unsigned char *> &e.data
    cdef uint32_t * cnt = <uint32_t *> d
    cnt[0] = cnt[0] + (1 << 8)
    return cnt[0]

cdef Entry * get_entry(Pool &pool, vector[void*] * blocks, uint64_t number):
    cdef uint64_t block_num = number >> block_size
    cdef uint64_t block_index = number  & block_mask
    cdef Entry * block
    cdef void * new_block
    
    while (block_num + 1) >= blocks.size():
        new_block =  self.mem.alloc(1 << block_size, sizeof(Entry))
        memset(new_block, 0, block_size * sizeof(Entry))
        blocks.push_back( new_block )

    block = <Entry *> blocks[0][block_num]
    return block[ block_index ]

cdef class Trie:
    cdef Pool mem
    cdef vector[void *] * blocks
    cdef Entry entry
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








