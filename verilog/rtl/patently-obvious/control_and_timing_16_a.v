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
//      control_and_timing_16.v
//
// Author:
//      Robert J. Weinstein
//      patently.obvious.2021@gmail.com
//      
// Title:
//      HP-35 Project:  Control & Timing Circuit 16
//
// Notes:
//      Some passages of US 4,001,569 are quoted verbatim as comments in this
//      module and are indicated like this:
//         '569 (col): "<quoted text>"
//      Where "col" is the column number in the patent document.
// 
// Description:
//      This module emulates the "Control & Timing 16" block described in patent
//      US 4,001,569 which discloses the HP-45 calculator.  
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
// IncludeFiles : None
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
//    RJW2025 - HP-35 Control and Timing Circuit 16 - Logic and Timing Diagrams
//    RJW2026 - HP-35 Control and Timing Circuit - Detailed Timing for All Instructions
//    RJW2027 - HP-35 Control and Timing Circuit - Barber-Pole Timing for JSB-RET Instructions
//    RJW2028 - HP-35 Control and Timing Circuit - Barber-Pole Timing for BRH Instruction
//    RJW2029 - HP-35 Control and Timing Circuit - Barber-Pole Timing for Status Operations
//    RJW2030 - HP-35 Control and Timing Circuit - Barber-Pole Timing for Pointer Operations
//    RJW2031 - HP-35 Control and Timing Circuit - Barber-Pole Timing for KEY-ENTRY Instruction
//    RJW2032 - HP-35 Control and Timing Circuit - Barber-Pole Timing for Arithmetic Instructions
//    RJW2033 - HP-35 Control and Timing Circuit - Key Entry Timing
//
// ----------------------------------------------------------------------
// Revision History
// ----------------------------------------------------------------------
//
// 14-Feb-2022 rjw
//    Released as open-source.
//
// ----------------------------------------------------------------------
`timescale 1ns / 1ps

module control_and_timing_16_a #(
    parameter       NewArch = 0     // 1 = Use new architecture, 0 = Like the patent.
)
(
    // Output Ports
    output          ia_out,         // ('569 item 32) Serial ROM Address
    input           ws_in,          // ('569 item 30) Pointer Word Select
    output          ws_out,
    output          ws_active,
    output reg      SYNC,           // ('569 item 26) Word Cycle Sync
    output reg      ROW0,           // ('569 item 50) Keyboard Row Driver 0
    output reg      ROW1,           //                   "      "    "    1
    output reg      ROW2,           //                   "      "    "    2
    output reg      ROW3,           //                   "      "    "    3
    output reg      ROW4,           //                   "      "    "    4
    output reg      ROW5,           //                   "      "    "    5
    output reg      ROW6,           //                   "      "    "    6
    output reg      ROW7,           //                   "      "    "    7
    output reg      tp_tiny_pin2,   // Test point.
    output          dbg_ctc_kdn,
    // Input Ports                  
//  input           PHI1,           // Bit-Rate Clock Input, Phase 1, not used here.
    input           PHI2,           // Bit-Rate Clock Input, Phase 2
    input           PWO,            // ('569 item 36) PoWer On pulse.  '569 (7) "As the system
                                    //    power comes on, the PWO signal is held at
                                    //    logic l for at least 20 milliseconds."
    input           IS,             // ('569 item 28) Serial Instruction from ROM Output
    input           CARRY,          // ('569 item 34) Carry flag from Arithmetic & Register block.
    input           COL0,           // ('569 item 54) Keyboard Column Input 0
    input           COL2,           //                   "       "      "   2
    input           COL3,           //                   "       "      "   3
    input           COL4,           //                   "       "      "   4
    input           COL6,           //                   "       "      "   6
    output [5:0]    dbg_q
);

    // Debug signals
    wire debug_lfsr_fb_xnor;
    wire debug_lfsr_fb_xor;
    wire [1:62] tp_state;

    reg         pwor        = 1'b0;
    reg [5:0]   q           = 'b0;
    assign dbg_q = q;
    reg         T1          = 1'b0;
    reg         T2          = 1'b0;
    reg         T3          = 1'b0;
    reg         T4          = 1'b0;
    reg         b5          = 1'b0;
    reg         b11         = 1'b0; // Debug only.
    reg         b14         = 1'b0;
    reg         b18         = 1'b0;
    reg         b26         = 1'b0;
    reg         b35         = 1'b0;
    reg         b43         = 1'b0; // Debug only.
    reg         b45         = 1'b0;
    reg         b54         = 1'b0;
    reg         b55         = 1'b0;
    reg         b19_b26     = 1'b0;    
    reg         stepaddr    = 1'b0;    

    reg         kdn         = 1'b0;
    reg         keydown     = 1'b0;
    reg         newkey      = 1'b0;
    wire        keyset_s0;
    reg [5:0]   keybuf      = 'b0;

    // Outputs from Microprogrammed Controller 46
    wire        JSB;            // output reg   // Control Line, (JSB in '569 Fig. 4), Jump Subroutine                             
    wire        BRH;            // output reg   // Control Line, (BRH in '569 Fig. 4), Conditional Branch                          
    wire        PTONLY;         // output reg   // Control Line, Arithmetic Instruction with WS = Pointer-Only                     
    wire        UP2PT;          // output reg   // Control Line, Arithmetic Instruction with WS = Up-to-Pointer                    
    wire        ARITHW;         // output reg   // Control Line, Arithmetic Instruction Wait for A&R Chip                          
    wire        ISTW;           // output reg   // Control Line, Interrogate Status Wait for Shifter                               
    wire        STDECN;         // output reg   // Control Line, Status Instruction, Decrement Counter from N                             
    wire        SST;            // output reg   // Control Line, Set Status Bit                                                    
    wire        RST;            // output reg   // Control Line, Reset Status Bit                                                  
    wire        IST;            // output reg   // Control Line, (IST in '569 Fig. 4), Interrogate Status Bit                      
    wire        SPT;            // output reg   // Control Line, Set Pointer to P                                                  
    wire        IPTR;           // output reg   // Control Line, (IPT in '569 Fig. 4), Interrogate Pointer, Reset Carry            
    wire        IPTS;           // output reg   // Control Line, (IPT in '569 Fig. 4), Interrogate Pointer, Set Carry              
    wire        PTD;            // output reg   // Control Line, Pointer Decrement                                                 
    wire        PTI;            // output reg   // Control Line, Pointer Increment                                                 
    wire        TKR;            // output reg   // Control Line, (TKR in '569 Fig. 4), Keyboard Entry                              
    wire        RET;            // output reg   // Control Line, (RET in '569 Fig. 4), Return from Subroutine                      

    // Main registers:
    reg [28:1]  sr              = 'b0;  // The 28-bit shift register comprising ROM Address 58, Status Bits 62, and Return Address 60.
    reg [8:1]   abuf            = 'b0;  // Address Buffer 68.
    reg [4:1]   ptr             = 'b0;  // Pointer 44.
    reg         CARRY_FF        = 1'b0; // Carry flip-flop 66.

    // Combinational Multiplexers:
    reg         dSr28;      // Input to the main 28-bit shift register.
    reg         iamux;      // Output to the Ia line.
    reg         dPtr4;      // Input to the 4-bit Pointer shift register.

    // State Machine output decode (Adder/Subtractor controls):
    wire        sum2sr;     // Selects Adder/Subtractor sum to 28-bit shift register input.
    wire        sr2sr;      // Selects 28-bit shift register output to recirculate back to input.
    wire        makesum;    // Asserted during entire serial word when a sum is needed.
    reg         makesum_r;  // Registered version.
    wire        chgstat;    // (a)  Forces sum2sr during Status Bit modifications.
    wire        sr2x;       // (b)  Selects 28-bit shift register to drive Adder/Subtractor's 'x' input.
    wire        p2x;        // (c)  Selects pointer to drive Adder/Subtractor's 'x' input.
    wire        pn2x;       // (d)  Selects negated pointer to drive Adder/Subtractor's 'x' input.
    wire        one2y;      // (e)  Selects a logic '1' to drive Adder/Subtractor's 'y' input during first bit (LSbit) of sum calculation.
    wire        srn2y;      // (f)  Selects negated 28-bit shift register to drive Adder/Subtractor's 'y' input.
    wire        sr2y;       // (g)  Selects 28-bit shift register to drive Adder/Subtractor's 'y' input.
    wire        sr2ci;      // (h)  Selects 28-bit shift register to drive Adder/Subtractor's 'ci' input during Status Bit interrogations.
    wire        co2ci;      // (k)  Selects a logic '1' to drive Adder/Subtractor's 'ci' input during all but the first bit of sum calculation.
    wire        sum2p;      // (m)  Selects Adder/Subtractor sum output to drive pointer input.
    wire        sumn2p;     // (n)  Selects negated Adder/Subtractor sum output to drive pointer input.

    // Word select logic:
    reg [3:0]   pwq             = 'b0;  // Pointer Word Select counter.
    reg         ld_dig0         = 1'b0; // Sets Word Select at digit position 0 for up-to-pointer operations.
    wire        set_ws;                 // Sets the Word Select flip-flop.
    reg         clr_ws          = 1'b0; // Clears the Word Select flip-flop.
    reg         ws_out          = 1'b0; // The Word Select flip-flop.
    reg         ws_req          = 1'b0; // Word Select output enable request.
    reg         ws_oe           = 1'b0; // Word Select output enable.
    wire        ws_in;                  // Word Select input.

    // Registers not described in the patent:
    reg [3:0]   stq;                    // Status bit position counter.
    wire        stqzero;                // Status Bit N has shifted to Right-Most Position of 28-bit Shift Register.
    reg         arith_cyc       = 1'b0; // Asserted during entire word cycle of any Type 2 arithmetic instruction.
    reg         ipt_cyc         = 1'b0; // Asserted during entire word cycle of the Interrogate Pointer instruction.
    reg         ist_cyc         = 1'b0; // Asserted during entire word cycle of the Interrogate Status instruction.

    // Signals that set or reset carry flip-flop 66 (CARRY_FF)...
    //      ...in response to any arithmetic instruction.
    wire        arith_cset;
    wire        arith_crst;
    //      ...in response to an interrogate status (IST) instruction.
    wire        ist_cset;
    wire        ist_crst;
    //      ...in response to an interrogate pointer (IPT) instruction.
    wire        ipt_cset;
    wire        ipt_crst;

    // Multiplexer Inputs to Adder/Subtractor 64
    reg     x_in = 1'b0;    // input        // Bit-serial augend when adding.  Bit-serial minuend when subtracting.
    reg     y_in = 1'b0;    // input        // Bit-serial addend when adding.  Bit-serial subtrahend when subtracting.
    reg     c_in = 1'b0;    // input        // Carry/borrow input (active high in both cases) from previous word cycle.

    // Output from Adder/Subtractor 64
    wire    sum;            // output       // Serial sum or difference.  Sum = X_IN + Y_IN + C_IN.  Difference = X_IN - Y_IN - C_IN.
    wire    co;             // output       // Carry out when adding, borrow out when subtracting.
    reg     cor;            // output       // Registered version of carry out provides the carry from the previous bit time.

// -----------------------------------------------------------------------------
// Begin RTL 
// -----------------------------------------------------------------------------

//    assign SYNC = sync_int;

    // ---------------------------------------------------------------------------------------------
    // Test points
    always@(posedge PHI2) begin : proc_tp
//        tp_tiny_pin2 <= JSB;
        tp_tiny_pin2 <= tp_state[1];    // Does it enter sIdle when reset?
    end

    // ---------------------------------------------------------------------------------------------
    // '569 (4):  "The Ia line 32 serially carries the addresses of the instructions to be read from
    // ROM�s 0-7. These addresses originate from control and timing circuit 16, which contains an
    // instruction address register that is incremented each word time unless a JUMP SUBROUTINE or a
    // BRANCH instruction is being executed.  Each address is transferred to ROM�s 0-7 during bit
    // times b19-b26, and is stored in an address register of each ROM. However, only one ROM is
    // active at a time, and only the active ROM responds to an address by outputting an instruction
    // on the Is line 28."
    //
    // Multiplexer Output to the Ia Line
    always @* begin : proc_iamux
        iamux   = keybuf[0] & TKR                   // Select keybuf[0] when TKR is asserted,
                | abuf[5]   & BRH                   // select abuf[5] when BRH is asserted,
                | sr[9]     & RET                   // select sr[9] when RET is asserted,
                | sr[1]     & (~TKR & ~BRH & ~RET); // otherwise, recirculate when none of the above are asserted.
    end
    //
//    assign IA   = iamux & b19_b26;
    //
    // Add two extra pulses outside the address window to allow the logic analyzer's serial-to-
    // parallel tool to sync.  The extra pulses are at b43 and b11.
    //
    assign ia_out   = (iamux & b19_b26) | b43 | b11;
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (7):  "The control and timing circuit word-select output 30 is or-tied with the ROM
    // word-select output 30 and transmitted to arithmetic and register circuit 20."
    // assign WS       = ws_oe? ws_out : 1'bz;
    // assign ws_in    = WS;
    assign ws_active = ws_oe;
    // ---------------------------------------------------------------------------------------------

    assign debug_lfsr_fb_xnor = ~^q[1:0]; 
    assign debug_lfsr_fb_xor = ^q[1:0]; 

    // ---------------------------------------------------------------------------------------------
    // '569 (6):  "A 28 bit shift register which circulates twice each 56 bit word time, is employed
    // in control and timing circuit 16. These 28 bits are divided into three functional groups: the
    // main ROM address register 58 (eight bits), the subroutine return address register 60 (eight
    // bits), and the status register 62 (l2 bits)."
    //
    // '569 (6):  "Gating is employed to interrupt the 28 bits circulating in the shift register 58-
    // 62 for insertion of addresses at the proper time as indicated by the JSB control signal in
    // FIG. 4."
    // 
    // '569 (8):  "As the system power comes on, the PWO signal is held at 0 volts (logic 1) for at
    // least 20 milliseconds. ... In addition, control and timing circuit 16 inhibits the address
    // output start-up so that the first ROM address will be zero."
    //
    // '569 (16-17):  "As discussed above, control and timing circuit 16 contains a 28-bit shift
    // register 58-62 which holds the current eight-bit ROM address and also has eight bits of
    // storage for one return address (see FIG. 4).  During bit times b47-b54 the current ROM
    // address flows through the adder 64 and is incremented by one. Normally, this address is
    // updated each word time. However, if the first two bits of the instruction, which arrive at
    // bit times b45-b46 are 10, the incremented current address is routed to the return address
    // portion 60 of the 28-bit shift register and the remaining eight bits of the instruction,
    // which are the subroutine address, are inserted into the address portion 58. These data paths
    // with the JSB control line are shown in FIG. 4. In this way the return address has been saved
    // and the jump address is ready to be transmitted to the ROM at bit times b19-b26 of the next
    // word time."
    //
    // Multiplexer Input to the Main 28-bit Shift Register
    always @* begin : proc_sr28_inmux
        dSr28   = IS        & JSB                   // Select IS when JSB is asserted,
                | sum       & sum2sr                // select sum when sum2sr is asserted,
                | iamux     & (~JSB & ~sum2sr);     // otherwise, recirculate when neither of the above is asserted.
    end
    // 28-bit Shift Register
    always@(posedge PHI2) begin : proc_shiftreg
        if (pwor)                                       // If the power on signal is asserted, then...
            sr  <= {1'b0, sr[28:2]};                    //    fill the shifter with zeros;
        else if (JSB)                                   // JSB "gating" to insert the return address at the proper time...
            sr  <= {dSr28, sr[28:10], sum, sr[8:2]};    //    sr[28] gets dSR28 and sr[8] gets sum, all others shift right.
        else                                            // otherwise...
            sr  <= {dSr28, sr[28:2]};                   //    sr[28] gets dSR28 and all others shift right.  Normal circulation.
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (7):  "... during the BRANCH instruction...  The branch address is retained in an eight-
    // bit address buffer 68 and gated to Ia line 32 by the BRH control signal."
    //
    // The 10-bit Is value is shifted into the 8-bit Address Buffer 68 during the SYNC pulse.  The
    // first 2 bits fall off the end, leaving only the last 8 bits in the buffer when SYNC goes back
    // low.  When SYNC is low, the 8 bits circulate.  If the 10 bits shifted in during the SYNC
    // pulse was a Conditional Branch instruction then the 8-bit branch address is what circulates.
    always@(posedge PHI2) begin : proc_abuf
        if (SYNC)                           // During the SYNC pulse...
            abuf <= {IS, abuf[8:2]};        //    the 10-bit Is value is shifted in;
        else                                // when SYNC is low...
            abuf <= {abuf[1], abuf[8:2]};   //    the most recent 8 bits circulate.
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (6):  "An important feature of the calculator system is the capability of select and
    // operate upon a single digit or a group of digits (such as the exponent field) from the 14
    // digit registers. This feature is implemented through the use of a four-bit pointer 44 which
    // points at the digit of interest. Instructions are available to set, increment, decrement, and
    // interrogate pointer 44. The pointer is incremented or decremented by the same serial adder/
    // subtracter 64 used for addresses. A yes answer to the instruction "is pointer /= N" will set
    // carry flip-flop 66 via control signal IPT in FIG. 4."
    //
    // Multiplexer Input to the 4-bit Pointer Shift Register
    always @* begin : proc_ptr4_inmux
        dPtr4   =  sum      & sum2p                         // Select sum when sum2p is asserted,
                | ~sum      & sumn2p                        // Select not(sum) when sumn2p is asserted,
                | IS        & SPT                           // Select Is when SPT is asserted,
                | ptr[1]    & (~sum2p & ~sumn2p & ~SPT);    // otherwise, recirculate when none of the above are asserted.
    end
    // 4-bit Pointer Shift Register
    always@(posedge PHI2) begin : proc_ptr
        ptr <= {dPtr4, ptr[4:2]};
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (6):  "The word select feature was discussed above in connection with FIGS. 2 and 3.
    // Some of the word select signals are generated in control and timing circuit 16, namely those
    // dependent on pointer 44, and the remainder in the main ROM�s 0-7. The pointer word select
    // options are (1) pointer position only and (2) pointer position and all less significant
    // digits."
    //
    always@(posedge PHI2) begin : proc_wsel
        if (b54 & (PTONLY | UP2PT)) 
            pwq <= {ptr[1], ptr[4:2]};
        else if (T3 & (pwq != 15))
            pwq <= pwq-1;
        //
        ld_dig0 <= b54 & UP2PT;
        //
        if (b54 && (PTONLY | UP2PT)) 
            ws_req <= 1'b1;
        else if (b54 && !(PTONLY | UP2PT)) 
            ws_req <= 1'b0;
        //
        clr_ws <= T3 & (pwq == 0);
        //
        if (T4 && (pwq == 0) || ld_dig0) 
            ws_out <= 1'b1;
        else if (clr_ws)
            ws_out <= 1'b0;
        //
        ws_oe <= ws_req;
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (5):  "System counter 42 is also employed as a keyboard scanner as shown in FIG. 5. The
    // most significant three bits of system counter 42 go to a one-of-eight decoder 48, which
    // sequentially selects one of the keyboard row lines 50. The least significant three bits of
    // the system counter count modulo seven and go to a one-of-eight multiplexor 52, which
    // sequentially selects one of the keyboard column lines 54 (during 16 clock times no key is
    // scanned)."
    // 
    // The patent doesn't explicity specify the count sequence of the "modulo seven" counter so I'm
    // using a linear feedback shift register that naturally counts modulo seven in the seqeunce
    // 0-1-3-6-5-2-4.  The relationship between the word cycle bit time and the counter value, q, is
    // as follows:
    //
    //          0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 5 5 5 5 5 5
    // Bit Time 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 
    //
    //   q[5:3] 0 0 0 0 0 0 0 1 1 1 1 1 1 1 2 2 2 2 2 2 2 3 3 3 3 3 3 3 4 4 4 4 4 4 4 5 5 5 5 5 5 5 6 6 6 6 6 6 6 7 7 7 7 7 7 7
    //   q[2:0] 0 1 3 6 5 2 4 0 1 3 6 5 2 4 0 1 3 6 5 2 4 0 1 3 6 5 2 4 0 1 3 6 5 2 4 0 1 3 6 5 2 4 0 1 3 6 5 2 4 0 1 3 6 5 2 4
    // 
    always@(posedge PHI2) begin : proc_syscount
        pwor <= PWO;    // Synchronize to PHI2.

        T1 <= ~pwor & (T4 | (q == 6'o74)); // Synchronize T1 to assert when q = all zeros.
        T2 <= T1;
        T3 <= T2;
        T4 <= T3;

        if (q[2:0] == 3'b111)               // All 1's is an illegal state for an XNOR-based
                                            // LFSR-3, so if it's detected, then...
            q[2:0] <= 3'b000;               //    force the LFSR to all 0's,
        else                                // otherwise...
            q[2:0] <= {q[1:0], ~^q[2:1]};   //    count in modulo 7 using the XNOR-based LFSR-3
                                            //    function (0-1-3-6-5-2-4).

        if (q[2:0] == 3'b100)               // If the least significant three bits of the system
                                            // counter have reached the last count in the LFSR-3
                                            // sequence, then...
            q[5:3] <= q[5:3] + 1;           //    increment the most significant three bits of the
                                            //    system counter in natural binary (modulo 8).

        // Decode 'bit time' pulses.
        b5  <= (q == 6'o05);
        b14 <= (q == 6'o14);
        b18 <= (q == 6'o26);
        b26 <= (q == 6'o35);
        b35 <= (q == 6'o44);
        b45 <= (q == 6'o63);
        b54 <= (q == 6'o75);
        b55 <= b54;

        // Extra pulses only used for debug.  To be removed at completion.
        b11 <= (q == 6'o16);
        b43 <= (q == 6'o60);
        
        // Ia is driven out during b19-b26.
        if (q == 6'o25)         
            b19_b26 <= 1'b1;    
        else if (q == 6'o32)    
            b19_b26 <= 1'b0;    
        
        // stepaddr is asserted during b47-b54.
        if (q == 6'o65)         
            stepaddr <= 1'b1;    
        else if (q == 6'o72)    
            stepaddr <= 1'b0;    
        
        // SYNC is asserted during b45-b54.
        if (q == 6'o63)         
            SYNC <= 1'b1;    
        else if (q == 6'o72)    
            SYNC <= 1'b0;    

    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // The keyboard matrix is connected as follows:
    //   
    //                                                   keydown
    //                                                     ^
    //                                                     |
    //                                 ----------------------------------------
    //                               /                                          \
    //  System Counter 42 q[2:0]--> /   110      100      011      010      000  \ 
    //                             /   COL6     COL4     COL3     COL2     COL0   \
    //                             ------------------------------------------------
    //    ----------------------         ^        ^        ^        ^        ^ 
    //                          |        |        |        |        |        |
    //              000 -> ROW0 |->----[x^y]----[log]----[ln]-----[e^x]----[clr]   
    //                          |        |        |        |        |        |
    //              101 -> ROW5 |->--[sqrt(x)]--[arc]----[sin]----[cos]----[tan]   
    //                          |        |        |        |        |        |
    //              001 -> ROW1 |->----[1/x]---[x<->y]--[roll]----[sto]----[rcl]   
    //                          |        |        |        |        |        |
    //    System    111 -> ROW7 |->---[Enter]-----|------[chs]----[eex]----[clx]   
    //  Counter 42              |        |        |        |        |        |
    //    q[5:3]    110 -> ROW6 |->---[Minus]----[7]------[8]------[9]-------|-  
    //                          |        |        |        |        |        |
    //              010 -> ROW2 |->---[Plus]-----[4]------[5]------[6]-------|-
    //                          |        |        |        |        |        |
    //              011 -> ROW3 |->---[Mult]-----[1]------[2]------[3]-------|-
    //                          |        |        |        |        |        |
    //              100 -> ROW4 |->--[Divide]----[0]------[.]-----[pi]-------|-
    //                          |
    //    ---------------------- 
    //   
    // '569 (5) "The most significant three bits of system counter 42 go to a one-of-eight decoder
    // 48, which sequentially selects one of the keyboard row lines 50." 
    always @* begin : proc_row_col
        ROW0 <= (q[5:3] == 3'b000) ? 1'b1 : 1'b0;
        ROW1 <= (q[5:3] == 3'b001) ? 1'b1 : 1'b0;
        ROW2 <= (q[5:3] == 3'b010) ? 1'b1 : 1'b0;
        ROW3 <= (q[5:3] == 3'b011) ? 1'b1 : 1'b0;
        ROW4 <= (q[5:3] == 3'b100) ? 1'b1 : 1'b0;
        ROW5 <= (q[5:3] == 3'b101) ? 1'b1 : 1'b0;
        ROW6 <= (q[5:3] == 3'b110) ? 1'b1 : 1'b0;
        ROW7 <= (q[5:3] == 3'b111) ? 1'b1 : 1'b0;
        //
        // '569 (5) "The least significant three bits of the system counter count modulo seven and
        // go to a one-of-eight multiplexor 52, which sequentially selects one of the keyboard
        // column lines 54 (during 16 clock times no key is scanned).  The multiplexor output is
        // called the key down signal."
        case (q[2:0])
            3'b000 : keydown = COL0;
            3'b001 : keydown = 1'b0;    // There are no keys in column 1.
            3'b010 : keydown = COL2;
            3'b011 : keydown = COL3;
            3'b100 : keydown = COL4;
            3'b101 : keydown = 1'b0;    // There are no keys in column 5.
            3'b110 : keydown = COL6;
            default : keydown = 'bx;
        endcase
        // '569 (5) "If a contact is made at any intersection point in the five-by-eight matrix (by
        // depressing a key), the key down signal will become high for one state of system counter
        // 42 (i.e., when the appropriate row and column lines are selected). The key down signal
        // will cause that state of the system counter to be saved in key code buffer 56."
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // Because key presses are asynchronous, sample the keydown signal with a falling edge of PHI2
    // to mitigate dynamic hazard effects.
    assign dbg_ctc_kdn = kdn;
    always@(negedge PHI2) begin : proc_kdn
        kdn <= keydown;
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (5) "This six-bit code is then transferred to the ROM address register 58 [in response
    // to the KEYS -> ROM ADDRESS instruction] and becomes a starting address for the program which
    // services the key that was down (two leading 0 bits are added by hardware so an eight-bit
    // address exists). Thus, during each state of system counter 42, the decoder-multiplexor
    // combination 48 and 52 is looking to see if a specific key is down. If it is, the state of the
    // system counter becomes a starting address for execution of that key function (noted that 16
    // of the 56 states are not used for key codes)."
    always@(posedge PHI2) begin : proc_keybuf
        if (kdn) 
            newkey <= 1'b1;
        else if (b35)
            newkey <= 1'b0;
        //
        if (TKR)                                // If the instruction 'KEYS -> ROM ADDRESS' is executed, then...
            keybuf[5:0] <= {1'b0, keybuf[5:1]}; //    shift the key buffer contents to the right,
        else if (kdn)                           // otherwise if a key is pressed, then...
            keybuf <= q;                        //    load the key buffer with the system counter value.
    end

    // '569 (21) "Status bit 0 is set when a key is depressed. If cleared it will be set every word
    // time as long as the key is down."
    assign keyset_s0 = newkey & b35;   
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // Combinational Input Multiplexers for Adder/Subtractor 64.
    //
    // '569 (6) "This [ROM] address circulates through a serial adder/subtractor 64 and is
    // incremented during bit times b47-b54 (except in the case of branch and jump-subroutine
    // instructions..."
    // 
    // '569 (6) "The pointer is incremented or decremented by the same serial adder/subtracter 64
    // used for addresses."
    // 
    // '569 (6) "Any status bit can be set, reset, or interrogated while circulating through the
    // adder 64 in response to the appropriate instruction." 
    // 
    // A traditional full adder is used for bit-serial add and subtract.
    // Additon is performed for:
    //    - Normal ROM address increment (Increment the Program Counter)
    //    - Increment Pointer instruction
    // Subtraction is only performed for:
    //    - Decrement Pointer instruction 
    // Special adder manipulation is performed for:
    //    - Set Status Flag instruction 
    //    - Reset Status Flag instruction 
    //    - Interrogate Status Flag instruction
    //    
    // Adder/Subtractor operation is enumerated in the following table:
    // 
    //                           |       Full Adder Inputs          | Full Adder Outputs   | 
    // Instruction or Operation  |  x_in   |  y_in   |     c_in     |  sum     |    co     | Note                                 |
    // --------------------------|---------|---------|--------------|----------|-----------|--------------------------------------|
    // Increment ROM Address     |   sr[1] |    1    |   co(n-1)    |  sr+1    | co(sr+1)  | sr[1] + 1 -> Normal sum and carry.   |
    //                           |         | @ LSbit | @ other bits |          |           | Adds 1 at the LS bit position.       |
    // --------------------------|---------|---------|--------------|----------|-----------|--------------------------------------|
    // Increment Pointer         |  ptr[1] |    1    |   co(n-1)    |  ptr+1   | co(ptr+1) | ptr[1] + 1 -> Normal sum and carry.  |
    //                           |         | @ LSbit | @ other bits |          |           | Adds 1 at the LS bit position.       |
    // --------------------------|---------|---------|--------------|----------|-----------|--------------------------------------|
    // Decrement Pointer         | ~ptr[1] |    1    |   co(n-1)    | ~(ptr-1) | bo(ptr-1) | ~ptr[1] + 1 -> Negated difference,   |
    //                           |         | @ LSbit | @ other bits |          |           | active-high borrow.  Adds 1 at the   |
    //                           |         |         |              |          |           | LS bit position but employs "minuend |
    //                           |         |         |              |          |           | complementation" resulting in a      |
    //                           |         |         |              |          |           | negated difference output (sum) and  |
    //                           |         |         |              |          |           | active-high borrow output (co).      |
    //                           |         |         |              |          |           | Difference output must be inverted   |
    //                           |         |         |              |          |           | before writing back into Pointer     |
    //                           |         |         |              |          |           | shift register.  See ref [1].        |
    // --------------------------|---------|---------|--------------|----------|-----------|--------------------------------------|
    // Set Status Flag N         |  sr[1]  |  ~sr[1] |      0       |    1     |     0     | Sum is 1 regardless of sr[1], carry  |
    //                           |         |         |              |          |           | not used.                            |
    // --------------------------|---------|---------|--------------|----------|-----------|--------------------------------------|
    // Reset Status Flag N       |  sr[1]  |   sr[1] |      0       |    0     |   sr[1]   | Sum is 0 regardless of sr[1], carry  |
    //                           |         |         |              |          |           | not used.                            |
    // --------------------------|---------|---------|--------------|----------|-----------|--------------------------------------|
    // Interrogate Status Flag N |  sr[1]  |   sr[1] |    sr[1]     |  sr[1]   |   sr[1]   | Sum and carry are both same as       |
    //                           |         |         |              |          |           | sr[1].                               |
    // --------------------------|---------|---------|--------------|----------|-----------|--------------------------------------|
    //
    // [1] G. G. Langdon, Jr.,  Subtraction by Minuend Complementation, IEEE
    // Trans. Computers (Short Notes), vol. C-18, pp. 74-76, January 1969
    //
    always@* begin : proc_add_mux
        // Drive the following into the adder's X input:
        x_in    =   sr[1] & sr2x    // rightmost bit from shift register
                |  ptr[1] & p2x     // rightmost bit from pointer       
                | ~ptr[1] & pn2x;   // negated rightmost bit from pointer   
        // Drive the following into the adder's Y input:
        y_in    =    1'b1 & one2y   // a one             
                |  ~sr[1] & srn2y   // negated rightmost bit from shift register
                |   sr[1] & sr2y;   // rightmost bit from shift register    
        // Drive the following into the adder's Carry input:
        c_in    =   sr[1] & sr2ci   // rightmost bit from shift register    
                |    cor & co2ci;   // previous carry out
    end
    // Full adder instance for Adder/Subtractor 64.
    full_add inst_adder (
        // Output Ports
        .sum        (sum),      // output reg   // Sum      
        .co         (co),       // output reg   // Carry out
        // Input Ports                          
        .x          (x_in),     // input        // Augend   
        .y          (y_in),     // input        // Addend   
        .ci         (c_in)      // input        // Carry In
    );
    // Store the carry out from the previous bit time.
    always@(posedge PHI2) begin : proc_addsub_carry
        cor <= co;  // cor holds co(n-1).
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // Carry Flip-Flop 66
    //   
    // '569 (6):  "A yes answer to a status interrogation will set the carry flip-flop 66 as
    // indicated by control signal IST in FIG. 4."
    // 
    // '569 (6):  "A yes answer to the instruction "is pointer /= N" will set carry flip-flop 66 via
    // control signal IPT in FIG. 4."
    // 
    // What's not said in '569 is that carry flip-flop 66 must be cleared if we get a 'no' answer to
    // the instruction "is pointer /= N".  Why?  Because an arithmetic instruction that leaves carry
    // set might precede the Interrogate Pointer instruction.  Alternatively, we could always clear
    // carry flip-flop 66 upon decoding the Interrogate Pointer instruction and subsequently set it
    // if the set condition is met. 
    //
    // '569 (7):  "Any carry signal out of the adder in arithmetic and register circuit 20, with
    // word select, also high, will set carry flip-flop 66."
    //
    // '569 (17):  "There are three ways the carry flip-flop 66 can be set: (1) by a carry generated
    // in the arithmetic and register circuit 20; (2) by a successful interrogation of the pointer
    // position; and (3) by a successful interrogation of one of the 12 status bits."
    // 
    // '569 (18):  "The carry flip-flop 66 is reset during execution of every instruction except
    // arithmetic (type 2) and interrogation of pointer or status (types 3 and 4). Since only
    // arithmetic and interrogation instructions can set the carry flip-flop 66, the constraint is
    // not severe."
    //--- 
    // Set or reset carry flip-flop 66 (CARRY_FF) in response to any arithmetic instruction.  Carry
    // line 34 (CARRY) from arithmetic and register circuit 20 should only set or reset CARRY_FF
    // when word select (ws_in) is active.  Carry line 34 can toggle during each bit period in a
    // given digit so its state should only be considered during the last bit period of each digit
    // (T4).  During execution of an arithmetic instruction, CARRY_FF might toggle between set and
    // reset as each digit is calculated.  In this way, the carry result of the last bit of the last
    // digit of the Word Select interval determines the final state of CARRY_FF.
    assign arith_cset   =  CARRY & ws_in & T4 & arith_cyc;
    assign arith_crst   = ~CARRY & ws_in & T4 & arith_cyc;
    //---
    // Set or reset carry flip-flop 66 (CARRY_FF) in response to an interrogate status (IST)
    // instruction.  '569 says, "Any status bit can be ... interrogated while circulating through
    // the adder 64 in response to the appropriate instruction."  In this implementation, the carry
    // output (co) from adder/subtractor 64 is used to set or reset CARRY_FF during IST.
    assign ist_cset     = IST &  co;
    assign ist_crst     = IST & ~co;
    //---
    // Set or reset carry flip-flop 66 (CARRY_FF) in response to an interrogate pointer (IPT)
    // instruction.  During the IPT fetch cycle, the microprogrammed controller 46 determines
    // whether to set or reset and asserts either IPTS or IPTR accordingly.  Because the IPT fetch
    // cycle might overlap an arithmetic execution cycle with its attendant carry result, we must
    // wait for the IPT execution cycle to start before setting or resetting CARRY_FF (using an
    // existing decode of system counter 42, arbitrarily chosen at bit-time b18).
    assign ipt_cset     = IPTS & b18;   // Set carry flip-flop in IPT execution cycle.
    assign ipt_crst     = IPTR & b18;   // Reset carry flip-flop in IPT execution cycle.
    //---
    always@(posedge PHI2) begin : proc_carry_ff
        if (b55) begin
            // Asserted during the entire word cycle (bit times b0 through b55) for the following
            // instructions:
            arith_cyc   <= ARITHW;      // Any Type 2 Arithmetic Instuction
            ipt_cyc     <= IPTS | IPTR; // Interrogate Pointer Instruction 
            ist_cyc     <= ISTW;        // Interrogate Status Instruction
            // The above are used to prevent reset of the carry flip-flop at the end of those
            // instructions.
        end
        //
        if (arith_cset || ist_cset || ipt_cset) 
            CARRY_FF <= 1'b1;
        else if (arith_crst || ist_crst || ipt_crst || b55 && !(arith_cyc || ipt_cyc || ist_cyc)) 
            CARRY_FF <= 1'b0;
        //
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // Status Bit Position Index Counter (not described in '569) 
    // 
    // The 10-bit Is value is shifted into the 4-bit down counter during the SYNC pulse.  The first
    // 6 bits fall off the end, leaving only the last 4 bits in the counter when SYNC goes low.
    // When SYNC goes low, the 4 bits are held.  If the instruction is any of the Type 3 Status
    // Operations then the 4-bit value will be decremented to zero to identify the status bit or
    // bits on which to operate. 
    // 
    always@(posedge PHI2) begin : proc_status_bit_counter
        if (SYNC)                   // During the 10-bit SYNC pulse...
            stq <= {IS, stq[3:1]};  //    shift 10-bit Is into 4-bit counter (only last 4 bits are
                                    //    held).
        else if (STDECN)            // Parsing any of the Type 3 Status instructions...
            stq <= stq - 1;         //    decrement to find bit N.
    end
    //
    // Asserted during status instructions when the status bit specified by N in the instruction
    // word has shifted to the rightmost position of the 28-bit shift register.
    assign stqzero = (stq == 4'b0000)? 1'b1 : 1'b0;
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // Instance of the Micro-Programmed Controller 46
    //
    // '569 (5):  "The control unit of control and timing circuit 16 is a microprogrammed controller
    // 46 comprising a 58 word (25 bits per word) control ROM, which receives qualifier or status
    // conditions from throughout the calculator and sequentially outputs signals to control the
    // flow of data. Each bit in this control ROM either corresponds to a signal control line or is
    // part of a group of N bits encoded into 2N mutually exclusive control lines and decoded
    // external to the control ROM. At each phase 2 clock, a word is read from the control ROM as
    // determined by its present address. Part of the output is fed back to become the next
    // address."
    //
    // '569 (5)  "Several types of qualifiers are checked. Since most commands are issued only at
    // certain bit times during the word cycle, timing qualifiers are necessary. This means the
    // control ROM may sit in a wait loop until the appropriate timing qualifier comes true, then
    // move to the next address to issue a command. Other qualifiers are the state of the pointer
    // register, the PWO (power on) line, the CARRY flip flop, and the state of each of the 12
    // status bits."
    // 
    microprogrammed_controller_46 inst_mpc (
        // Output Ports (Control Lines)
        .JSB        (JSB),          // output reg   // Control Line, (JSB in '569 Fig. 4), Jump Subroutine                             
        .BRH        (BRH),          // output reg   // Control Line, (BRH in '569 Fig. 4), Conditional Branch                          
        .PTONLY     (PTONLY),       // output reg   // Control Line, Arithmetic Instruction with WS = Pointer-Only                     
        .UP2PT      (UP2PT),        // output reg   // Control Line, Arithmetic Instruction with WS = Up-to-Pointer                    
        .ARITHW     (ARITHW),       // output reg   // Control Line, Arithmetic Instruction Wait for A&R Chip                          
        .ISTW       (ISTW),         // output reg   // Control Line, Interrogate Status Wait for Shifter                               
        .STDECN     (STDECN),       // output reg   // Control Line, Status Instruction, Decrement Counter from N                             
        .SST        (SST),          // output reg   // Control Line, Set Status Bit                                                    
        .RST        (RST),          // output reg   // Control Line, Reset Status Bit                                                  
        .IST        (IST),          // output reg   // Control Line, (IST in '569 Fig. 4), Interrogate Status Bit                      
        .SPT        (SPT),          // output reg   // Control Line, Set Pointer to P                                                  
        .IPTR       (IPTR),         // output reg   // Control Line, (IPT in '569 Fig. 4), Interrogate Pointer, Reset Carry            
        .IPTS       (IPTS),         // output reg   // Control Line, (IPT in '569 Fig. 4), Interrogate Pointer, Set Carry              
        .PTD        (PTD),          // output reg   // Control Line, Pointer Decrement                                                 
        .PTI        (PTI),          // output reg   // Control Line, Pointer Increment                                                 
        .TKR        (TKR),          // output reg   // Control Line, (TKR in '569 Fig. 4), Keyboard Entry                              
        .RET        (RET),          // output reg   // Control Line, (RET in '569 Fig. 4), Return from Subroutine                      
        .tp_state   (tp_state),     // output       // Test point, state vector.
        // Clock Input                                                                                                                 
        .PHI2       (PHI2),         // input        // System Clock                                                                     
        // Qualifier Inputs                                                                                                            
        .pwor       (pwor),         // input        // Qualifier, (PWO 36 in '569 Fig. 4), Power On, Registered Copy
        .IS         (IS),           // input        // Qualifier, (Is 28 in '569 Fig. 4), Serial Instruction from ROM                      
        .b5         (b5),           // input        // Qualifier, (from TIMING DECODER in '569 Fig. 4) System Counter 42 at Bit Time b5   
        .b14        (b14),          // input        // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b14  
        .b18        (b18),          // input        // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b18  
        .b26        (b26),          // input        // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b28  
        .b35        (b35),          // input        // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b35  
        .b45        (b45),          // input        // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b45  
        .b54        (b54),          // input        // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b54  
        .b55        (b55),          // input        // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b55  
        .CARRY_FF   (CARRY_FF),     // input        // Qualifier, (CARRY Flip-Flop 66 in '569 Fig. 4), Carry Flip-Flop 66                        
        .stqzero    (stqzero),      // input        // Qualifier, Status Bit N has shifted to the Right-Most Position of 28-bit Shift Register.
        .is_eq_ptr  (IS == ptr[1])  // input        // Qualifier, Interrogate Pointer Instruction's P Field (in Is) is Equal to Pointer
    );
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // Decoding Outputs of Microprogrammed Controller 46
    //
    always@(posedge PHI2) begin : proc_dly_mksum
        makesum_r <= makesum;                       // Delay for edge detect.
    end
    assign sum2sr   = chgstat | (~JSB & stepaddr);  // Selects Adder/Subtractor sum to drive 28-bit shift register input.      
    assign sr2sr    = ~JSB & ~sum2sr;               // Selects 28-bit shift register output to recirculate back to its input.
    assign makesum  = stepaddr | PTI | PTD;         // Asserted during entire serial word when a sum is needed.
    assign chgstat  = keyset_s0 | SST | RST | IST;  // (a)  Forces sum2sr during Status Bit modifications.                                                                  
    assign sr2x     = chgstat | stepaddr;           // (b)  Selects 28-bit shift register to drive Adder/Subtractor's 'x' input.                                            
    assign p2x      = PTI;                          // (c)  Selects pointer to drive Adder/Subtractor's 'x' input.                                                          
    assign pn2x     = PTD;                          // (d)  Selects negated pointer to drive Adder/Subtractor's 'x' input.                                                  
    assign one2y    = makesum & ~makesum_r;         // (e)  Selects a logic '1' to drive Adder/Subtractor's 'y' input during first bit (LSbit) of sum calculation.          
    assign srn2y    = keyset_s0 | SST;              // (f)  Selects negated 28-bit shift register to drive Adder/Subtractor's 'y' input.                                    
    assign sr2y     = RST | IST;                    // (g)  Selects 28-bit shift register to drive Adder/Subtractor's 'y' input.                                            
    assign sr2ci    = IST;                          // (h)  Selects 28-bit shift register to drive Adder/Subtractor's 'ci' input during Status Bit interrogations.
    assign co2ci    = makesum & makesum_r;          // (k)  Selects a logic '1' to drive Adder/Subtractor's 'ci' input during all but the first bit of sum calculation.     
    assign sum2p    = PTI;                          // (m)  Selects Adder/Subtractor sum output to drive pointer input.                                                     
    assign sumn2p   = PTD;                          // (n)  Selects negated Adder/Subtractor sum output to drive pointer input.                                             
    // ---------------------------------------------------------------------------------------------


endmodule 
    
