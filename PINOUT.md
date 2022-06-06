# Pinout

## All Pins

|    | F                        | E                        | D               | C               | B           | A           |
|----|--------------------------|--------------------------|-----------------|-----------------|-------------|-------------|
| 1  | mprj_io[15]              | mprj_io[16]              | mprj_io[18]     | mprj_io[19]     | mprj_io[21] | mprj_io[23] |
| 2  | vccd1                    | mprj_io[14]              | mprj_io[17]     | mprj_io[20]     | mprj_io[22] | vccd2       |
| 3  | mprj_io[12]              | mprj_io[11] flash2_io[1] | mprj_io[13]     | mprj_io[24]     | vssa2       | mprj_io[25] |
| 4  | mprj_io[10] flash2_io[0] | mprj_io[9] flash2_sck    | vdda1           | vddio           | mprj_io[26] | mprj_io[27] |
| 5  | mprj_io[8] flash2_csb    | mprj_io[7] irq           | vssio vssa vssd | vssio vssa vssd | mprj_io[28] | mprj_io[29] |
| 6  | vssd1                    | vssa1                    | vssio vssa vssd | vssio vssa vssd | mprj_io[30] | mprj_io[31] |
| 7  | mprj_io[6] ser_tx        | mprj_io[5] ser_rx        | mprj_io[0] JTAG | vdda2           | vssd2       | mprj_io[32] |
| 8  | mprj_io[4] SCK           | mprj_io[3] CSB           | flash_clk       | mprj_io[33]     | mprj_io[34] | mprj_io[35] |
| 9  | mprj_io[2] SDI           | mprj_io[1] SDO           | flash_io[1]     | clock           | mprj_io[36] | mprj_io[37] |
| 10 | vdda                     | gpio (user_PE)           | flash_io[0]     | flash_csb       | resetb      | vccd        |

## Usable Pins

|    | F           | E              | D           | C           | B           | A           |
|----|-------------|----------------|-------------|-------------|-------------|-------------|
| 1  | mprj_io[15] | mprj_io[16]    | mprj_io[18] | mprj_io[19] | mprj_io[21] | mprj_io[23] |
| 2  |             | mprj_io[14]    | mprj_io[17] | mprj_io[20] | mprj_io[22] |             |
| 3  | mprj_io[12] | mprj_io[11]    | mprj_io[13] | mprj_io[24] |             | mprj_io[25] |
| 4  | mprj_io[10] | mprj_io[9]     |             |             | mprj_io[26] | mprj_io[27] |
| 5  | mprj_io[8]  | _irq_          |             |             | mprj_io[28] | mprj_io[29] |
| 6  |             |                |             |             | mprj_io[30] | mprj_io[31] |
| 7  | _ser tx_    | _ser rx_       | _JTAG_      |             |             | mprj_io[32] |
| 8  | _SCK_       | _CSB_          |             | mprj_io[33] | mprj_io[34] | mprj_io[35] |
| 9  | _SDI_       | _SDO_          |             |             | mprj_io[36] | mprj_io[37] |
| 10 |             |                |             |             |             |             |

[37:8] = 30 Pins

## Pin Assignment
| Global Name        | #  | Type     | Local Name      | Description
|--------------------|----|----------|-----------------|------------------------
| mprj_io[37]        | 1  | ANALOG   | ?               | TDC Power VDD1
| mprj_io[36]        | 1  | ANALOG   | ?               | TDC Power VDD2
| mprj_io[35]        | 1  | ANALOG   | ?               | TDC Start
| mprj_io[34]        | 1  | ANALOG   | ?               | TDC Power VSS2
| mprj_io[33]        | 1  | ANALOG   | ?               | TDC Power VSS1
| mprj_io[32]        | 1  | ANALOG   | ?               | TDC Stop
| mprj_io[31:29]     | 3  | OUT      | q[5:3]          | Keyboard ROW Scanner / CTC State Register
| mprj_io[28:24]     | 5  | IN       | COL[4:0]        | Keyboard COL Reader
| mprj_io[23:19]     | 5  | OUT      | DD[4:0]         | Display Control
| mprj_io[18]        | 1  | OUT      | START           | Display Control
| mprj_io[17]        | 1  | IN       | PWO             | Power-On Reset
| mprj_io[16:15]     | 2  | TRISTATE | PHI[2:1]        | Global Clock I/O
| mprj_io[14]        | 1  | TRISTATE | IS              | Instruction Bus
| mprj_io[13]        | 1  | TRISTATE | WS              | Word Select Bus
| mprj_io[12]        | 1  | TRISTATE | BCD             | Peripheral Bus
| mprj_io[11]        | 1  | TRISTATE | IA              | Address Bus
| mprj_io[10]        | 1  | TRISTATE | CARRY           | Carry Bus
| mprj_io[9]         | 1  | TRISTATE | SYNC            | Global Sync
| mprj_io[8]         | 1  | IN       | external_clk    | External Clock (prediv)
|↑Pin↑   ↓LA↓    |    |          |                 | 
| la_data_in[63:0]   | 32 | READ     | TDC_dout[63:0]  | TDC Parallel Data
| la_data_in[64]     | 1  | READ     | PWO             |
| la_data_in[65]     | 1  | READ     | is_bus          | 
| la_data_in[66]     | 1  | READ     | ws_bus          |
| la_data_in[67]     | 1  | READ     | bcd_bus         |
| la_data_in[68]     | 1  | READ     | ia_bus          |
| la_data_in[69]     | 1  | READ     | carry_bus       |
| la_data_in[70]     | 1  | READ     | sync_bus        |
| la_data_in[74:71]  | 4  | READ     | dbg_dsbf        | ARC Internal Display Buffer
| la_data_in[75]     | 1  | READ     | dbg_arc_t1      | ARC T-State
| la_data_in[76]     | 1  | READ     | dbg_arc_t4      | ARC T-State
| la_data_in[77]     | 1  | READ     | dbg_arc_a1      | ARC Register A
| la_data_in[78]     | 1  | READ     | dbg_arc_b1      | ARC Register B
| la_data_in[81:79]  | 1  | READ     | dbg_rom_roe[2:0]| ROM Internal Enable
| la_data_in[82]     | 1  | READ     | dbg_ctc_state1  | 
| la_data_in[83]     | 1  | READ     | dbg_ctc_kdn     | 
| la_data_in[89:84]  | 6  | READ     | dbg_ctc_q[5:0]  | CTC State Register
| la_data_in[91:90]  | 2  | READ     | PHI[2:1]        | HP35 Clock
| la_data_in[92]     | 1  | READ     | sram_clk1       |
| la_data_in[100:93] | 8  | READ     | sraddr_mux      | SRAM Address Mux
|                    |    |          |                 |
| la_data_out[29:0]  | 30 | WRITE    | sram_din0[29:0] | SRAM Input Data
| la_data_out[30]    | 1  | WRITE    | sram_web0       | Write Enable
| la_data_out[31]    | 1  | WRITE    | sram_csb0       | Chip Select
| la_data_out[32]    | 1  | WRITE    | sram_clk0       | Clock
| la_data_out[40:33] | 8  | WRITE    | sram_addr0[7:0] | Address
| la_data_out[41]    | 1  | WRITE    | dbg_sram_csb1   | 
| la_data_out[42]    | 1  | WRITE    | dbg_enable_arc  |
| la_data_out[43]    | 1  | WRITE    | dbg_enable_ctc  |
| la_data_out[44]    | 1  | WRITE    | dbg_enable_rom  |  
| la_data_out[45]    | 1  | WRITE    | dbg_arc_dummy   | Force ARC Register Init
| la_data_out[46]    | 1  | WRITE    | dbg_force_data  | Force ROM Data
| la_data_out[56:47] | 10 | WRITE    | dbg_romdata[9:0]|
| la_data_out[60:57] | 4  | WRITE    | syclk_div[3:0]  | Synchronous Clock Pre-divider
