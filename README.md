# cache.associative4ways.lruLAOCII

4-way associative, 256 cache lines, 4 words block size, 16 bits word, pseudo LRU

## Bit guide
`
address:
	block_offset ~2 bits~ 
	index ~8 bits~
	tag ~22 bit~
	
	=> |tag  |index|block_offset| ~32 bits~
	    31 10 9   2 1          0
cache_line:

	block => |word1|word2|word3|word4| ~64 bits~
	set => |vality|dirty|tag|block| ~88 bits~
	
	=> |set1|set2|set3|set4| ~352 bits~
	
cache_line's structure bits:
	set1:
	|vality|dirty|tag    |block  |
	 351      350 349 328 327 264
		block:
		|word1  |word2  |word3  |word4  |
		 327 312 311 296 295 280 279 264
	set2:
	|vality|dirty|tag    |block  |
	 263      262 261 240 239 176
		block:
		|word1  |word2  |word3  |word4  |
		 239 224 223 208 207 192 191 176
	set3:
	|vality|dirty|tag    |block  |
	 175      174 173 152 151  88
		block:
		|word1  |word2  |word3  |word4 |
		 151 136 135 120 119 104 103 88
	set4:
	|vality|dirty|tag    |block  |
	 87        86 85   64 63    0
	   block:
		|word1|word2|word3|word4|
		 63 48 47 32 31 16 15 0
` 
# Diagrams
Logisim project:
ComputerArchQntApproach, Hennesey and Patterson:
Quartus II RTL:
