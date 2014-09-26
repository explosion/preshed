Cython Hash Table for Pre-Hashed Keys
-------------------------------------

trustyc provides a hash table to map 64-bit pre-hashed keys to memory
addresses. It trusts that the keys are fully randomized, and that if the user
stores a number, it is safe to cast it to a memory address.

The main use is via Cython. See the murmurhash package for a good way to
generate keys.
