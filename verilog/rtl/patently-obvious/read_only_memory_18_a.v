//-----------------------------------------------------------------------
// OpenBSD License
// 
// Copyright (c) 2022 Robert J. Weinstein
// 
// Permission to use, copy, modify, and distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// SPDX-License-Identifier: ISC
//
//-----------------------------------------------------------------------
//
// FileName:
//      read_only_memory_18.v
//
// Author:
//      Robert J. Weinstein
//      patently.obvious.2021@gmail.com
//      
// Title:
//      HP-35 Project:  Read-Only Memory Circuit 18
//
// Description:
//      This module is an RTL implementation of the "Read-Only Memory Circuit"
//      block described in patent US 4,001,569 which discloses the HP-45
//      calculator.  
// 
//      Some passages of US 4,001,569 are quoted verbatim as comments in this
//      module and are indicated like this:
//         '569 (col): "<quoted text>"
//      Where "col" is the column number in the patent document.
//
// Acknowledgments:
//      From the Hewlett Packard Journal, June 1972:
//      
//         Chung C. Tung 
//         Chung Tung received his BS degree in electrical 
//         engineering from National Taiwan University in 1961, and 
//         his MSEE degree from the University of California at 
//         Berkeley in 1965. Late in 1965 he joined HP Laboratories. 
//         He was involved in the design of the 91OOA Calculator and 
//         was responsible for the design and development of two 
//         of the MOS/LSI circuits in the HP-35 Pocket Calculator: 
//         the control and timing chip and the read-only-memory 
//         chips. Now working for his PhD at Stanford University, 
//         Chung still manages to find time now and then to relax with 
//         swimming or table tennis.  
//
//         David S. Cochran 
//         Dave Cochran is HP Laboratories' top algorithm designer 
//         and microprogrammer, having now performed those 
//         functions for both the 9100A and HP-35 Calculators. He 
//         was project leader for the HP-35. Since 1956 when he 
//         came to HP, Dave has helped give birth to the 204B Audio 
//         Oscillator, the 3440A Digital Voltmeter, and the 9120A 
//         Printer, in addition to his work in calculator architecture. 
//         He holds nine patents on various types of circuits and has 
//         authored several papers. IEEE member Cochran is a 
//         graduate of Stanford University with BS and MS degrees 
//         in electrical engineering, received in 1958 and 1960. 
//         His ideal vacation is skiing in the mountains of Colorado.  
//         
// Parameters:
//      RomNum - ROM Number.  Identifies this ROM's position within the HP-35
//      address space as follows:
//      
//          0 = ROM0 (addresses 0 to 255) 
//          1 = ROM1 (addresses 256 to 511)
//          2 = ROM2 (addresses 512 to 767)
//
//      RomFilename - The filename of binary file to be loaded into the ROM
//      array for this instance of ROM.  Currently, the binary ROM files are
//      as follows:
//       
//          romfiles/35<id>_rom0_binary.txt (for ROM0)
//          romfiles/35<id>_rom1_binary.txt (for ROM1)
//          romfiles/35<id>_rom2_binary.txt (for ROM2)
//
//          where <id> could be one of several identifiers indicating the source
//          of the ROM object file.
//
// Conventions:
//      Port names are 'UPPER' case.
//      Internal wires and registers are 'lower' case.
//      Parameters are first character 'Upper' case.
//      Active low signals are identified with '_n' or '_N'
//      appended to the wire, register, or port name.
//       
//      Uses Verilog 2001 Features
// 
// Drawing:
//    RJW2022 - HP-35 Read Only Memory 18 - Logic and Timing Diagrams
//    RJW2024 - HP-35 Read Only Memory - Word Select Output Simulation Results
//
// ----------------------------------------------------------------------
// Revision History
// ----------------------------------------------------------------------
//
// 14-Feb-2022 rjw
//    Released as open-source.
//
// 30-May-2022 AL
//    Decomposed the tristate line for integration
//
// ----------------------------------------------------------------------
`timescale 1ns / 1ps

module read_only_memory_18_a #(
    parameter       RomNum = 0     // Rom Number.  0 = ROM0, 1 = ROM1, 2 = ROM2.

)
(
    // Bidirectional Ports
    // inout           is_out,             // ('569 item 28) Serial Instruction. Active ROM Output.
                                    //    Inactive ROM input.
    output          is_active,
    output          is_out,
    input           is_in,
    
    // Output Ports
    output          ws_out,         // ('569 item 30) Word Select.  Active ROM Output.
    output          ws_active,
    output reg      TP_ROE,         // Test point for ROM Output Enable (ROE) flip-flop 70.
    // Input Ports                  
    input           PHI1,           // Bit-Rate Clock Input, Phase 1.  Not used here.
    input           PHI2,           // Bit-Rate Clock Input, Phase 2.
    input           PWO,            // ('569 item 36) PoWer On pulse.  "As the system power comes
                                    //    on, the PWO signal is held at logic l for at least 20
                                    //    milliseconds."
    input           SYNC,           // ('569 item 26) Word Cycle Sync
    input           IA,             // ('569 item 32) Serial ROM Address

    // SKY130 SRAM Interface
    // 1rw1r type
    output [7:0]  sraddr,       // 8bit SRAM Address
    input  [31:0] srdata,       // 32bit SRAM Data
    output        srprelatch,   // The signal indicating latch
    input         dbg_force_data,   // when asserted, the parallel input data is generated by caravel
    input  [9:0]  forcedata         //  /

);

// =================================================================================================
// Signal Declarations
// =================================================================================================

    integer     fd;                             // File Descriptor for loading ROM contents.
//    string      RomFile = "../../src/35v2.obj"; // ROM dump file.
//    string      RomFile = "../../src/35_rom_brian_nemetz.obj"; // ROM dump file.
    //string      RomFile = "35_rom_brian_nemetz.obj"; // ROM dump file.
    integer     i, j;                           // Iteration variables.

    wire        is_out;             // This is driven onto the IS port when this ROM is active.
    wire        is_in;              // This is raw input from the IS port whether active or not.
    wire        isi;                // Same as is_in but gated low when this ROM is active.

    reg         ws_out;             // The word select output register.  
    reg         ws_oe;              // The word select output enable register.

    reg         syncr  = 1'b0;      // Delayed version of SYNC to facilitate edge detection.
    wire        syncfe;             // Pulse indicating falling edge of SYNC.
    reg [5:0]   bnext;              // 56 state counter 72.
    reg         b11, b43, b44;      // Decoded signals from the state counter 72.
    reg         b50, b54, b55;      //    ditto...
    reg         areg_open = 1'b0;   // Shift enable that "opens" the input to the address register
                                    //    at bit time b19 through bit time b26.
    reg [7:0]   areg = 'b0;         // Address Register 74.
    assign sraddr = areg;
    // reg [9:0]   rom [0:255];        // ROM 17.
    reg [9:0]   rom;
    reg [9:0]   is_reg = 'b0;       // Instruction Register 76.

    wire        rom_number_0;       // Asserted when the "masking option" for this ROM idientifies
                                    //    it as "main ROM 0".
    wire        romsel;             // Asserted when the ten bits in Instruction Register 76 are
                                    //    decoding a ROM SELECT instruction.
    wire        this_rom;           // Asserted when "the least significant three bits of the IS
                                    //    register 76" match this ROM's number, i.e., ROM 0, ROM 1,
                                    //    or ROM 2.
    reg         roe_master = 1'b0;  // "Master" part of ROM Output Enable (ROE) flip-flop 70.
    reg         roe_slave = 1'b0;   // "Slave" part of ROM Output Enable (ROE) flip-flop 70.
    wire        active;             // Indicates that this ROM's ROE is active.
    reg         isr1, isr2, isr3, isr4, isr5;   // The shift register part of Word Select Register
                                                // 80.
    reg         wsrq;               // "Master" part of the word select request.
    reg         ws_req;             // "Slave" part of the word select request.
    reg [2:0]   wsc;                // "Master" part of Word Select Register 80.
    reg [2:0]   ws_code;            // "Slave" part of Word Select Register 80.
                                    // 
    reg [3:0]   ws_begin;           // Specifies the digit number at which to BEGIN the Word Select
                                    //    sequence in the next word cycle.  Assigned in a
                                    //    combinational process.
    reg [3:0]   ws_end;             // Specifies the digit number at which to END the Word Select
                                    //    sequence in the next word cycle.  Assigned in a
                                    //    combinational process.
    reg         set_ws;             // Pulse sets the WS output at the first bit of the digit
                                    //    specified by ws_begin.  Assigned in a combinational
                                    //    process.
    reg         clr_wsd;            // Pulse indicates when to clear the WS output at the last bit
                                    //    of the digit specified by ws_end.  Must be delayed by one
                                    //    bit period.  Assigned in a combinational process.
    reg         clr_ws;             // Delayed version of clr_wsd.

// =================================================================================================
// Initialize ROM
// =================================================================================================
    // This initial block reads a ROM dump file containing the contents of all three HP-35 ROMs and
    // stores the appropriate third of the file (256 words) into this ROM's array.  The contents are
    // read from Peter Monta's "New ROM dump of HP-35 version 2: 35v2.obj" located at his website
    // <www.pmonta.com/calculators/hp-35>  He says, "The three ROM chips included in this dump have
    // part numbers 1818-0006, 1818-0017, and 1818-0020".
    // 
    // The ROM dump is an ASCII file containing all three ROMs.  The first few lines are:
    //
    //    0000:0335
    //    0001:1377
    //    0002:1044
    //     .
    //     .
    //     .
    // 
    // Each line represents a 10-bit instruction word.  The first four digits are the address in
    // octal and the last four digits are the 10-bit instruction word in octal.
    // 
    // The following initial block employs two nested for loops, the outer loop steps through each
    // of the three ROMs (0, 1, 2) while the inner loop steps through 256 instruction words.  Each
    // pass through the inner loop reads one line of the file and if that line belongs to the ROM
    // specified by the parameter RomNum, then the instruction value contained in that line is
    // written to the array 'rom[i]'.  If the line doesn't belong to RomNum, then the line is
    // ignored.

// Moved the formatted octal ROM file read process to a special utility called 'file_convert'
// because SynplifyPro doesn't allow the initial block to do anything other than $readmemb/h.
//    initial begin
//        fd = $fopen(RomFilename, "r");
//        for (j = 0; j <= 2; j = j + 1) begin          // For each ROM...
//            for (i = 0; i <= 255; i = i + 1) begin    //    for each instruction word in a single ROM...
//                if (j == RomNum)                      //       if we're indexing this ROM, then...
//                    $fscanf(fd, "%*o:%o", rom[i]);    //          write the indexed instruction into the ROM array,
//                else                                  //       otherwise we're indexing one of the other ROMs, so...
//                    $fscanf(fd, "%*o:%*o");           //          read the line but don't save it.
//            end
//        end
//        $fclose(fd);
//    end
/*
    initial begin
        $readmemb(RomFilename, rom);
    end
*/

// **** Right now, the SKY130A flow doesn't support ROM synthesis
// **** The solution is to build a rom using one 32x256 rom
// D = {2'bxx, ROM2, ROM1, ROM0};
/*
    initial begin
        if(RomNum==0) begin
            $readmemb("./romfiles/35v2_rom0_binary.txt", rom); // Using the rom version with ln2.02 bug
        end else if (RomNum==1) begin
            $readmemb("./romfiles/35v2_rom1_binary.txt", rom); 
        end else if (RomNum==2) begin
            $readmemb("./romfiles/35v2_rom2_binary.txt", rom); 
        end else begin
            $display("ERROR: Unknown ROM Page%d\n", RomNum);
        end
    end
    */
    wire [9:0] romd;
    assign romd = srdata[10*(RomNum+1)-1:10*(RomNum)];
    always @* begin
        if(dbg_force_data) rom = forcedata;
        else               rom = romd;
    end

// =================================================================================================
// RTL Begins Here:
// =================================================================================================

    assign active = roe_slave;
    assign is_active = active;

    assign syncfe = ~SYNC & syncr;  // Falling edge detect.

    // '569 (8):  "ROM's 0-7 output a 1 bit-time pulse on Is buss 28 at bit time b11 to denote the
    // exponent minus sign time. This pulse is used in the display decoder of arithmetic and
    // register circuit 20 to convert a 9 into a displayed minus sign. The time location of this
    // pulse is a mask option on the ROM."
    assign is_out = (SYNC & is_reg[0]) | b11;
    // assign IS     = (active)? is_out : 1'bz;
    assign isi    = is_in & ~active;

    // '569 (8):  "The output WS signal is gated by ROE flip-flop 70 so only the active ROM can
    // output on WS line 30, which is OR-tied with all other ROM's and also control and timing
    // circuit 16."
    assign ws_active     = (active & ws_oe);

    assign rom_number_0  = (RomNum == 0);               // Asserted when the "masking option" for
                                                        //    this ROM idientifies it as "main ROM
                                                        //    0".
    assign romsel        = (is_reg[6:0] == 7'b0010000); // Asserted when the ten bits in Instruction
                                                        // Register 76 are decoding a ROM SELECT
                                                        // instruction.                    
    assign this_rom      = (is_reg[9:7] == RomNum);     // Asserted when "the least significant
                                                        //    three bits of the IS register 76"
                                                        //    match this ROM's number, i.e., ROM 0,
                                                        //    ROM 1, or ROM 2.

    // ---------------------------------------------------------------------------------------------
    // Test points - not in patent.
    // ---------------------------------------------------------------------------------------------
    always@(posedge PHI2) begin : proc_tp
        TP_ROE <= roe_slave;
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (7):  "The serial nature of the calculator circuits requires careful synchronization.
    // This synchronization is provided by the SYNC pulse, generated in control and timing circuit
    // 16 and lasting for bit times b45-b54.  Each ROM has its own 56-state counter 72, synchronized
    // to the system counter 42 in control and timing circuit 16.  Decoded signals from this state
    // counter 72 open the input to the address register 74 at bit time b19, clock Is out at bit
    // time b45 and provide other timing control signals."
    // 
    // In this design, the synchronization counter indicates the bit time of the NEXT clock cycle.
    // That's why the count register is named "bnext".  This allows all the logic based on the
    // synchronization counter to be generated using edge-sensitive D-type flip-flops clocked with
    // PHI2, resulting in a registered-synchronous implementation.
    // 
    // The following process implements Synchronization Counter 72.
    // ---------------------------------------------------------------------------------------------
    always@(posedge PHI2) begin : proc_sync_counter_72
        syncr <= SYNC;
        //
        if (syncfe)                 // If SYNC falling edge is detected (we're in the last bit time
                                    // of the word cycle), then... 
            bnext <= 6'd1;          //    on the rising edge of PHI2 we'll be in bit time b0 so set
                                    //    bnext to 1 because bnext indicates the bit time of the
                                    //    NEXT clock cycle;
        else if (bnext == 6'd55)    // otherwise we're not synchronizing but if the counter has
                                    // reached its terminal count, then...
            bnext <= 6'd0;          //    wrap the counter;
        else                        // else no special cases are present, so...
            bnext <= bnext + 1;     //    increment the counter.
        //
        b11 <= (bnext == 6'd11);
        b43 <= (bnext == 6'd43);
        b44 <= b43;
        b50 <= (bnext == 6'd50);
        b54 <= (bnext == 6'd54);
        b55 <= b54;
        //
        if (bnext == 6'd19)         // '569 (7):  "Decoded signals from state counter 72 open the
            areg_open <= 1'b1;      //    input to the address register 74 at bit time b19..."
        else if (bnext == 6'd27)    // Eight bit times later...                   
            areg_open <= 1'b0;      //    close the input to the address register.
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (8):  "FIG. 7 shows the important timing points for a typical addressing sequence.
    // During bit times b19-b26 the address is received serially from control and timing circuit 16
    // and loaded into address register 74 via Ia line 32.  This address is decoded and at bit time
    // b44 the selected instruction is gated in parallel into the Is register 76.  During bit times
    // b45-b54 the instruction is read serially onto Is buss 28 from the active ROM (i.e., the ROM
    // with the ROM enable flip-flop set)."
    // 
    // The following process implements:
    //    Address Register 74, Instruction Register 76, and Read Only Memory 17.
    // ---------------------------------------------------------------------------------------------
    assign srprelatch = b43;
    always@(posedge PHI2) begin : proc_rom
        if (areg_open)                  // '569 (8):  "During bit times b19-b26 ...
            areg <= {IA, areg[7:1]};    //    the address is received serially from control and
                                        //    timing circuit 16 and loaded into address register 74
                                        //    via Ia line 32."
        //
        // In this design, the Instruction Register 76 comprises edge-sensitive D flip-flops rather
        // than the gated latches that the patent seems to describe.  The inputs to the D flip-flops
        // must be valid at bit time b43 in order for the addressed ROM contents to be clocked into
        // the Instruction Register and available for use at bit time b44.
        if (b43 & active)                   // '569 (8):  "This address is decoded and at bit time 
            // is_reg <= rom[areg];            //    [b43] the selected instruction is [clocked] in
            is_reg <= rom;            //    [b43] the selected instruction is [clocked] in
                                            //    parallel into the Is register 76."
        else if (SYNC)                      // '569 (8):  "During bit times b45-b54 the instruction 
            is_reg <= {isi, is_reg[9:1]};   //    is read serially onto Is buss 28 from the active
                                            //    ROM..."
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (8):  "Control is transferred between ROM�s by a ROM SELECT instruction. Effectively
    // this instruction will turn off ROE flip-flop 70 on the active ROM and turn on ROE flip-flop
    // 70 on the selected ROM. Implementation is dependent upon the ROE flip-flop being a master-
    // slave flip-flop."
    //    "In the inactive ROM's the instruction is read serially into the Is register 76 during bit
    // times b45-b54 and then decoded, and [if the instruction is a ROM SELECT for this ROM] the ROE      
    // flip-flop 70 is set at bit time b55 in the selected ROM."
    //    "In the active ROM, the ROM SELECT instruction is decoded by a ROM select decoder 78 at
    // bit time 44, and the master portion of ROE flip-flop 70 is [reset]. The slave portion of ROE
    // flip-flop 70 is not [reset] until the end of the word bit time (b55)."  
    // 
    // The following process implements ROE Flip-Flop 70.
    // ---------------------------------------------------------------------------------------------
    always@(posedge PHI2) begin : proc_roe_ff_70
        if (PWO) begin                              // '569 (7):  "As the system power comes on, the
            roe_master <= rom_number_0;             //    PWO signal is held at 0 volts (logic 1)   
            roe_slave  <= rom_number_0;             //    for at least 20 milliseconds. The PWO 
        end                                         //    signal is wired (via a masking 
                                                    //    option) to set ROM Output Enable
                                                    //    (ROE) flip-flop 70 on main ROM 0 and
                                                    //    reset it on all other ROM�s. Thus
                                                    //    when operation begins, ROM 0 will be
                                                    //    the only active ROM."                                 
        else if (b55)                               //           
            if (~roe_slave) begin                   // At bit time b55 in the inactive ROM,
                roe_master <= romsel & this_rom;    //    if the instruction that has been shifted
                roe_slave  <= romsel & this_rom;    //    into the IS register is a ROM SELECT for
            end                                     //    this ROM, then both master and slave
                                                    //    portions of ROE flip-flop 70 are set.
            else begin                              // At bit time b55 in the active ROM,
//              roe_master <= roe_master;           //    the master is unchanged and
                roe_slave  <= roe_master;           //    the slave gets the value of the master.
            end                                     //
        else if (b44)                               //
            if (roe_slave)                          // At bit time b44 in the active ROM,
                roe_master <= ~romsel;              //    if the addressed instruction is a ROM
                                                    //    SELECT, then the master portion of ROE
                                                    //    flip-flop 70 is reset.  The slave portion
                                                    //    will become reset at the next b55.
    end                                             
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (8):  "The six secondary word-select signals are generated in the main ROM�s 0-7. Only
    // the two word-select signals dependent upon the POINTER come from control and timing circuit
    // 16. The word select of the instruction is retained in the word select register 80 (also a
    // master-slave). If the first two bits are 01, the instruction is of the arithmetic type for
    // which the ROM must generate a word select gating signal. At bit time b55 the next three bits
    // are gated to the slave and retained for the next word time to be decoded into one of six
    // signals."
    // 
    // The following process implements Word Select Register 80.
    // ---------------------------------------------------------------------------------------------
    always@(posedge PHI2) begin : proc_ws_reg_80
        // Sample the ROM's outgoing serial instruction, IS, as follows:
        //       IS -> isr1 -> isr2 -> isr3 -> isr4 -> isr5
        // 
        {isr1, isr2, isr3, isr4, isr5} <= {is_reg[0], isr1, isr2, isr3, isr4};
        //
        // At bit time b50, if the first two bits are 01 (isr5 = 0, isr4 = 1) then the instruction
        // is a Type 2 Arithmetic instruction and the next three bits will hold the Word Select code
        // that specifies the word select sequence.
        //
        //  | isr1 | isr2 | isr3 | isr4 | isr5 | 
        //  +------+------+------+------+------+ At bit time b50, isr1-isr5 each hold    
        //  | 5th  | 4th  | 3rd  | 2nd  | 1st  | the nth bit of the IS stream as indicated.
        //  +------+------+------+------+------+                    
        //  |  Word Select Code  |  1   |  0   | Contents of the shifter at bit time b50 if the
        //  +------+------+------+------+------+ instruction is a Type 2 Arithmetic instruction.
        //                          |______|
        //                              |
        //                          Arithmetic

        if (b50) begin 
            // 'wsrq' is the "master" part of the word select request.  At bit time b50, this
            // register is asserted only if the instruction is a Type 2 Arithmetic instruction and
            // the next three bits of the instruction, the Word Select code, specifiy one of the six
            // ROM-generated word select sequences.
            wsrq <= (~isr5 & isr4) & (isr3 | isr2);
            //
            // 'wsc' is the "master" part of Word Select Register 80.  At bit time b50 this register
            // latches the next three bits of the instruction, the Word Select code.
            wsc  <= {isr1, isr2, isr3};
        end
        if (b54) begin
            // 'ws_req' is the "slave" part of the word select request.  At bit time b54, this
            // register latches the value of 'wsrq'.  This signal remains valid from bit time b55
            // through the following word cycle's bit time b54.
            ws_req  <= wsrq;
            //
            // 'ws_code' is the "slave" part of Word Select Register 80.  "At bit time [b54] the
            // next three bits [of the instruction] are gated to the slave [this register] and
            // retained for the next word time to be decoded into one of six [word select
            // sequences]."
            ws_code <= wsc;
        end
    end
    // ---------------------------------------------------------------------------------------------

    // * Huh... I thought that the WS signal is controlled only by the CTC
    // * It turns out being more clever that I thought, Interesting
    // * The only down side is that all three ROM chips has to contain their own WS generators
    // * Which sounds like a lot of additional duplicated hardware.
    // * Technology limitation in its puriest form that is.
    // ---------------------------------------------------------------------------------------------
    // '569 (8):  "The synchronization counter 72 provides timing information to the word select
    // decoder 82.  The output WS signal is gated by ROE flip-flop 70 so only the active ROM can
    // output on WS line 30, which is OR-tied with all other ROM's and also control and timing
    // circuit 16.  As discussed above, the WS signal goes to arithmetic and register circuit 20 to
    // control the portion of a word time an instruction is active."
    //    "The six ROM generated word select signals used in the calculator are shown in FIG. 9."
    // 
    // Note that Figure 9 in the '569 patent shows the 3-bit CODE in serial order: I2, I3, I4, 
    // whereas the 'ws_code' signal in this implementation has the most significant bit on the left.
    // The following is a reproduction of the '569 patent's Figure 9 showing its original CODE side-
    // by-side with this implementation's 'ws_code'.
    // 
    //                 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |                                                                          
    //                                                                                CODE | ws_code | Driver
    //                              ___ Pointer at 3                                 ------+---------+--------
    // Pointer Only     ___________|   |___________________________________________   000  |  000    | CTC
    //                  _______________                                                    |         |
    // Up to Pointer                   |___________________________________________   001  |  100    | CTC
    //                  ___________                                                        |         |
    // Exponent                    |_______________________________________________   010  |  010    | ROM
    //                          ___                                                        |         |
    // Exponent Sign    _______|   |_______________________________________________   011  |  110    | ROM
    //                              __________________________________________             |         |
    // Mantissa Only    ___________|                                          |____   100  |  001    | ROM
    //                              _______________________________________________        |         |
    // Mantissa w/Sign  ___________|                                                  101  |  101    | ROM
    //                  ___________________________________________________________        |         |
    // Entire Word                                                                    110  |  011    | ROM
    //                                                                         ____        |         |
    // Mantissa Sign    ______________________________________________________|       111  |  111    | ROM
    // 
    //                 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
    //                                         Digit Number
    // 
    //                                           Figure 9
    // 
    // The following pair of processes implement Word Select Decoder 82.
    // ---------------------------------------------------------------------------------------------
    always@(*) begin : comb_proc_ws_dec_82
        case (ws_code)                                              // Field Select           | Digits 
            3'b010  : begin ws_begin = 4'd0;    ws_end = 4'd2;  end // Exponent [X]           | 0 - 2
            3'b110  : begin ws_begin = 4'd2;    ws_end = 4'd2;  end // Exponent Sign [XS]     |   2
            3'b001  : begin ws_begin = 4'd3;    ws_end = 4'd12; end // Mantissa Only [M]      | 3 - 12
            3'b101  : begin ws_begin = 4'd3;    ws_end = 4'd13; end // Mantissa and Sign [MS] | 3 - 13
            3'b011  : begin ws_begin = 4'd0;    ws_end = 4'd13; end // Entire Word [W]        | 0 - 13
            3'b111  : begin ws_begin = 4'd13;   ws_end = 4'd13; end // Mantissa Sign Only [S] |  13
            default : begin ws_begin = 4'd15;   ws_end = 4'd15; end // Not ROM-generated word selects.
        endcase
        // Note that the following word select begin and end logic is all based on synchronization
        // counter 72 that, in this design, indicates the bit time of the NEXT clock cycle.  That's
        // why the count register is named "bnext".  This allows the final WS output to be driven
        // with an edge-sensitive flip-flop clocked with PHI2 and be aligned exactly with the word
        // cycle boundary.
        if (bnext[5:2] == ws_begin && bnext[1:0] == 2'b00)  // When the synchronization counter 72
                                                            //    reaches the first bit of the digit
                                                            //    specified by 'ws_begin', then ...
            set_ws = 1'b1;                                  //    assert the 'set' pulse,
        else                                                // otherwise,
            set_ws = 1'b0;                                  //    deassert the pulse.
        //---
        if (bnext[5:2] == ws_end && bnext[1:0] == 2'b11)    // When the synchronization counter 72
                                                            //    reaches the last bit of the digit
                                                            //    specified by 'ws_end', then ...
            clr_wsd = 1'b1;                                 //    assert the 'clr' pulse,            
        else                                                // otherwise,                          
            clr_wsd = 1'b0;                                 //    deassert the pulse.              
        //---
    end

    // The following process is clocked, providing the final output register for WS.
    always@(posedge PHI2) begin : reg_proc_ws_dec_82
        clr_ws <= clr_wsd;          // Delay 'clr_wsd' by one clock so that 'clr_ws' will allow WS
                                    // to remain asserted during the last bit time of the last digit
                                    // of the WS duration.
        if (set_ws)                 // 
            ws_out <= 1'b1;         // Set WS.
        else if (clr_ws)            //
            ws_out <= 1'b0;         // Clear WS.

        ws_oe  <= ws_req;           // Delay 'ws_req' by one clock so that WS will be driven during
                                    // the entire duration of the following word cycle, bit times b0
                                    // through b55.
    end
    // ---------------------------------------------------------------------------------------------

endmodule /* read_only_memory_18_a */

