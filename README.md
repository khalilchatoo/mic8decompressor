mic8decompressor
================

#### Hardware Implementation of an Image Decompressor (Incomplete)

This was submitted for the final project of Dr. Nicola Nicolici's Digital Systems Design course at McMaster University. It takes a .mic8 file (McMaster Image Compression Revision 8) and decompresses it into a .ppm file.  
  
Coded in Verilog and intended for the Altera DE2 board.

#### Included: 
>Working Colourspace Conversion and Interpolation, with a constraint of a maximum of two multipliers per state (fastest theoretical run-time of 8.448 ms, actual run-time ~8.5 ms, achieved 100% utilzation) **[M1.v]**

>Working Inverse Signal Transform **[M2.v]**

#### Missing:
>Dequantization

>Lossless Decoding
