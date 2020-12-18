This design is mostly based on the source code from https://github.com/russdill/bch_verilog.
According to my requirements, the source code was packaged as "bch_enc_wrapper" module and "bch_dec_wrapper"
module, their ports are much simpler.\

--"bch_enc_wrapper" --
input the origin data (BCH_DATA_BITS)
output the encoded data(BCH_CODE_BITS)

--"bch_dec_wrapper"--
input the encoded data (BCH_CODE_BITS)  (with error bits)
output the decoded data(BCH_DATA_BITS)  (error bits has been corrected according to error correction width 'T')



The testbench file is also inluded. 
BCH_DATA_BITS  = 128
BCH_CODE_BITS  = 152
T = 3
