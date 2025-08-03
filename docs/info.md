<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a Secure SERDES Encryptor that takes two serial input bit streams (a_bit and b_bit), combines them into 8-bit words, and encrypts them using a predefined 128‑bit key.
The encryption works as follows:

1] Serially shift in 8 bits for A and B.

2] Perform an XOR operation between A, B, and the least‑significant byte of the key.

3] Shift the encrypted result out bit‑by‑bit on the output line (uo_out[0]).

4] Once the full encrypted byte is transmitted, the done signal (uo_out[1]) goes high.

This design demonstrates a lightweight encryption method in a serial‑in serial‑out format, suitable for resource‑constrained hardware.

## How to test

1] Apply a reset by driving rst_n low and then high again.

2] Set ui_in[0] = 1 for one clock cycle to start encryption.

3] Provide 8 bits serially on ui_in[1] (a_bit) and ui_in[2] (b_bit), MSB first, one per clock cycle.

4] After 8 bits are loaded, the encryption logic computes the XOR result with the key.

5] The encrypted byte is then shifted out on uo_out[0] (1 bit per cycle).

6] When all 8 bits are output, uo_out[1] asserts high to indicate completion.

7] In simulation, you can monitor tb.vcd (waveform) or check the reconstructed byte from uo_out[0].

## External hardware
1] No external hardware is required.

2] For demo purposes, the cipher_out can be connected to an LED or serial interface to observe the bitstream.

3] The done signal can also be mapped to an LED to indicate completion of one encryption cycle.
