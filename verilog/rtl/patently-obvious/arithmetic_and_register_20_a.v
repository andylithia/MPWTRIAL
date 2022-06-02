//------------------------------------------------------------------------------
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
//------------------------------------------------------------------------------
//
// FileName:
//      arithmetic_and_register_20.v
//
// Author:
//      Robert J. Weinstein
//      patently.obvious.2021@gmail.com
//      
// Title:
//      HP-35 Project:  Arithmetic & Register Circuit
//
// Description:
//      This module performs the functionality of the "Arithmetic & Register 20"
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
//         France Rode
//         France Rode came to HP in 1962, designed counter 
//         circuits for two years, then headed the group that 
//         developed the arithmetic unit of the 5360 Computing 
//         Counter. He left HP in 1969 to join a small new company, 
//         and in 1971 he came back to HP Laboratories. For the 
//         HP-35, he designed the arithmetic and register circuit 
//         and two of the special bipolar chips. France holds the 
//         degree Deploma Engineer from Ljubljana University in 
//         Yugoslavia. In 1962 he received the MSEE degree from 
//         Northwestern University. When he isn't designing logic 
//         circuits he likes to ski, play chess, or paint. 
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
// Drawings:
//    RJW2039 - HP-35 Arithmetic and Register Circuit 20 - Logic and Timing Diagrams 
//    RJW2014 - HP-35 Arithmetic and Register Circuit - Display Operation Logic and Timing Diagrams
//    RJW2015 - HP-35 Display Operation Animation
//    RJW2021 - HP-35 Arithmetic and Register Circuit - Testbench Logic Diagram
//    RJW2070 - HP-35 Arithmetic and Register Circuit - Testbench for Serial Adder 84 
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

module arithmetic_and_register_20_a #(
    parameter       NewArch = 0     // 1 = Use new architecture, 0 = Like the patent.
)
(
    // Output Ports
    output reg      A = 1'b0,       // ('569 item 38) Partially decoded LED segment sequence, bit A.
    output reg      B = 1'b0,       //                    "        "     "    "        "    , bit B.
    output reg      C = 1'b0,       //                    "        "     "    "        "    , bit C.
    output reg      D = 1'b0,       //                    "        "     "    "        "    , bit D.
    output reg      E = 1'b0,       //                    "        "     "    "        "    , bit E.
    output reg      START,          // ('569 item 40) Word synchronization pulse for digit scanner in Cathode Driver.
    output          CARRY,          // ('569 item 34) Status of the carry output of this block's adder, sent to the Control & Timing block.

    // Debug Outputs
    output          dbg_dsbf3,
    output          dbg_dsbf2,
    output          dbg_dsbf1,
    output          dbg_dsbf0,
    output          dbg_dsbf_dp,
    output          dbg_t1,       // t1, debug output.  Timing should match rjw2014b, page 3.
//    output          dbg_t2,       // t2, ...
//    output          dbg_t3,       // t3, ...
    output          dbg_t4,       // t4, ...
    output          dbg_regA1,
    output          dbg_regB1,

    // Input Ports                  
//  input           PHI1,           // Bit-Rate Clock Input, Phase 1
    input           PHI2,           // Bit-Rate Clock Input, Phase 2
    input           IS,             // ('569 item 28) Serial Instruction from ROM Output
    input           WS,             // ('569 item 30) ROM Word Select
    input           SYNC,           // ('569 item 26) Word Cycle Sync
    // inout           BCD,            // ('569 item 35) BCD input/output line 35 to auxiliary data storage circuit 25.
    input           bcd_in,
    output          bcd_active,
    output          bcd_out,
    input           dummy           // Dummy input to preload registers to prevent inferring RAM.
);

// -----------------------------------------------------------------------------
// Signal Declarations
// 
    reg [9:0]   isbuf   = 10'd0;    // Is Buffer 91
    reg [9:4]   isreg   = 6'd0;     // Is Register 90
    reg         istype2 = 1'b0;     // Instruction is Type 2
    reg         istype5 = 1'b0;     // Instruction is Type 5

    reg         syncr   = 1'b0;     // Registered version of SYNC for edge detection.
    reg         wsr     = 1'b0;     // Registered version of WS for edge detection.
    reg         ws2     = 1'b0;     // Rising edge of WS delayed by 1 bit period.
    reg         ws3     = 1'b0;     //   "     "   "  "     "    "  2 bit periods.
    reg         ws4     = 1'b0;     //   "     "   "  "     "    "  3 bit periods.

    wire        ws1;                // Asserted during the first bit period of the Word Select cycle (rising edge detect).
    wire        ds1;                // Asserted during the first digit period of WS.
    wire        dsn1;               // Asserted during all digit periods of WS other than the first.

    // -------------------------------------------------------------------------
    // Instruction Decoder outputs:
    // -- BCD adder/subtractor controls
    wire        sub, c_in, a2x, c2x, b2y, c2y;
    // -- Multiplexer controls for register A
    wire        a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld;
    // -- Multiplexer controls for register B
    wire        b2b, a2b, c2b, srb;
    // -- Multiplexer controls for register C
    wire        c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src;
    // -- Multiplexer controls for register D
    wire        d2d, c2d, e2d;
    // -- Multiplexer controls for register E
    wire        e2e, d2e, f2e;
    // -- Multiplexer controls for register F
    wire        f2f, c2f, e2f;
    // -- Multiplexer controls for register M
    wire        m2m, c2m;
    // -- Display toggle, display off        
    wire        dspt, dspn;
    // -------------------------------------------------------------------------

    reg         t1 = 1'b0, t2 = 1'b0, t3 = 1'b0, t4 = 1'b0;
    reg [3:0]   dsbf = 4'b0000;         // Display Buffer digit.
    reg         dsbf_dp = 1'b0;         // Display Buffer decimal point.
    reg         a, b, c, d, e, f, g;    // 7-segment decoder output.

    // Inputs to Serial Adder 84
    reg     x_in = 1'b0;    // input        // Bit-serial augend when adding.  Bit-serial minuend when subtracting.
    reg     y_in = 1'b0;    // input        // Bit-serial addend when adding.  Bit-serial subtrahend when subtracting.
//  reg     c_in = 1'b0;    // input        // Carry/borrow input (active high in both cases) from previous word cycle.
//  reg     ws1 = 1'b0;     // input        // Indicates the first bit period of the Word Select cycle.  When asserted, C_IN is included in sum.
//  reg     sub = 1'b0;     // input        // Add/Subtract control input.  0 = add, 1 = subtract.
//  reg     t1 = 1'b0;      // input        // One-hot T-state counter indicating the active bit in the current digit.  T1 = LSbit, T4 = MSbit.
//  reg     t2 = 1'b0;      // input        //  "
//  reg     t3 = 1'b0;      // input        //  "
//  reg     t4 = 1'b0;      // input        //  "
//  reg     PHI2 = 1'b0;    // input        // Bit-Rate Clock Input, Phase 2.

    // Output from Serial Adder 84
    wire    sum1;           // output       // Serial sum or difference.  Sum = X_IN + Y_IN + C_IN.  Difference = X_IN - Y_IN - C_IN.
    wire    sum2;           // output       // Corrected sum (SUM1 + 6).
    wire    use_sum2;       // output reg   // Asserted during T4 if the corrected sum should be used.
    wire    sa_carry;       // output reg   // ('569 item 34) Carry out when adding, borrow out when subtracting (active high in both cases). Valid during T4 of each digit time.  Sent to the Control & Timing block.

    // '569 (9): "Arithmetic and register circuit 16 contains seven, fourteen-digit (56 bit) dynamic
    // registers A-F and M ..."
    // Note the registers are 1-based because the '569 patent says this:  "... the end bit (B01) of
    // the B register ..."
    reg [60:1]  regA /* synthesis syn_ramstyle="registers" */;   // Extra four bits [60:57] for 4-bit Holding Register 86.
    reg [56:1]  regB /* synthesis syn_ramstyle="registers" */;
    reg [60:1]  regC /* synthesis syn_ramstyle="registers" */;   // Extra four bits [60:57] for register C's 4-bit Holding Register.
    reg [56:1]  regD /* synthesis syn_ramstyle="registers" */; 
    reg [56:1]  regE /* synthesis syn_ramstyle="registers" */;
    reg [56:1]  regF /* synthesis syn_ramstyle="registers" */;       
    reg [56:1]  regM /* synthesis syn_ramstyle="registers" */;       

    // '569 (23):  "The display flip-flop in arithmetic and register circuit 20 controls blanking of
    // all the LED�s. When it is reset, the 1111 code is set into the display buffer 96, which is
    // decoded so that no segments are on. There is one instruction to reset this flip-flop
    // I9 I8 I7 = (100) and another to toggle it (000). The toggle feature is convenient for
    // blinking the display."                           
    reg         display_ff;             
                                        
    // '569 (4): A BCD input/output line 35 interconnects the auxiliary data storage circuit 25 and
    // the C register of arithmetic and register circuit 20. This line always outputs the contents
    // of the C register of arithmetic and register circuit 20 unless a specific instruction to
    // input to the C register of the arithmetic and register circuit is being executed.
    // ---
    // This wire is the input side of BCD line 35.  Note that the BCD line is present in the HP-45
    // and newer but is not implemented in the HP-35.  It's only included here to be faithful to the
    // '569 patent and may be used in a future implementation. 
    wire        bcd_in;

    // Combinational versions of the partially decoded LED segment sequence outputs.  These are
    // subsequently registered using PHI2 prior to exiting this device so that START will be
    // coincident with T4 during display digit 14.
    reg         muxA;
    reg         muxB;
    reg         muxC;
    reg         muxD;
    reg         muxE;

// =================================================================================================
// RTL Begins Here:
// =================================================================================================

    // ---------------------------------------------------------------------------------------------
    // Debug outputs - to be removed when complete.

    assign dbg_dsbf3    = dsbf[3];
    assign dbg_dsbf2    = dsbf[2];
    assign dbg_dsbf1    = dsbf[1];
    assign dbg_dsbf0    = dsbf[0];
    assign dbg_dsbf_dp = dsbf_dp;
    assign dbg_t1   = t1;
//    assign dbg_t2   = t2;
//    assign dbg_t3   = t3;
    assign dbg_t4   = t4;
    assign dbg_regA1    = regA[1];
    assign dbg_regB1    = regB[1];

    // ---------------------------------------------------------------------------------------------
    // '569 (4):  The carry line 34 transmits the status of the carry output of the adder in
    // arithmetic and register circuit 20 to control and timing circuit 16. The control and timing
    // circuit uses this information to make conditional branches, dependent upon the numerical
    // value of the contents of the registers in arithmetic and register circuit 20.
    assign CARRY = sa_carry;

    // ---------------------------------------------------------------------------------------------
    // '569 (4):  "A BCD input/output line 35 interconnects the auxiliary data storage circuit 25
    // and the C register of arithmetic and register circuit 20. This line always outputs the
    // contents of the C register of arithmetic and register circuit 20 unless a specific
    // instruction to input to the C register of the arithmetic and register circuit is being
    // executed."
    // assign BCD = (bcd2c)? 1'bz : regC[1];
    // assign bcd_in = BCD;
    assign bcd_out    = regC[1];
    assign bcd_active = ~bcd2c; 

    // ---------------------------------------------------------------------------------------------
    // '569 (11):  "Display decoder 94 also applies a START signal to line 40. This signal is a word
    // synchronization pulse, which resets the digit scanner in the cathode driver of output
    // display unit 14 to assure that the cathode driver will select digit 1 when the digit 1
    // information is on outputs A, B, C, D, and E. The timing for this signal is shown in FIG. 14." 
    always@(posedge PHI2) begin : proc_start
        syncr <= SYNC;
        START <= ~SYNC & syncr;     // Falling edge.
        if (~SYNC & syncr) begin
            t1 <= 1'b1;
            t2 <= 1'b0;
            t3 <= 1'b0;
            t4 <= 1'b0;
        end
        else begin
            t1 <= t4;
            t2 <= t1;
            t3 <= t2;
            t4 <= t3;
        end
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // The ROMs provide the Word Select signal, WS, for arithmetic instructions whereas the Control
    // & Timing chip provides WS for pointer instructions.  WS indicates what part of the 56-bit
    // word is affected by the given instruction.  The Arithmetic & Register logic needs to further
    // sub-divide WS to identify the first bit period, the first digit period, and all digit periods
    // other than the first.  The following process provides those subdivisions.  An example timing
    // diagram is shown here.  Note in this diagram, WS is shown with an arbitrary duration of four
    // digit periods for example purposes only.  In operation, WS can take on any of the durations
    // depicted in the '569 patent.
    //        __   __   __   __   __   __   __   __   __   __   __   __   __   __   __   __   __
    // PHI2 _|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_|  |_
    //      _ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____
    // t    _|_t1_|_t2_|_t3_|_t4_|_t1_|_t2_|_t3_|_t4_|_t1_|_t2_|_t3_|_t4_|_t1_|_t2_|_t3_|_t4_|_t1_
    //        _______________________________________________________________________________
    // WS   _|                                                                               |____
    //        ____
    // ws1  _|    |_______________________________________________________________________________
    //        ___________________
    // ds1  _|                   |________________________________________________________________
    //                            ___________________________________________________________
    // dsn1 _____________________|                                                           |____
    // 
    // 
    always@(posedge PHI2) begin : proc_wsreg
        wsr <= WS;
        ws2 <= ws1;
        ws3 <= ws2;
        ws4 <= ws3;
    end
    // ---------------------------------------------------------------------------------------------

    assign ws1  = WS & (~wsr | START);      // Asserted during the first bit period of WS.  It's
                                            // generated by either the rising edge of WS or the
                                            // first bit period of the word cycle in which WS is
                                            // asserted.  Why is START used here?  Because if WS is
                                            // asserted during the first digit of the current word
                                            // cycle and it was also asserted during the last digit
                                            // of the previous word cycle, then there will be no
                                            // rising edge to detect; in that case START provides
                                            // the needed pulse. 

    assign ds1  = ws1 | ws2 | ws3 | ws4;    // Asserted during the first digit period of WS.
    assign dsn1 = WS & ~ds1;                // Asserted during all digit periods of WS other than
                                            // the first.

    // ---------------------------------------------------------------------------------------------
    // '569 (10):  "Arithmetic and register circuit 20 receives the instruction during bit times
    // b45-b54.  Of the ten types of instructions hereinafter described, arithmetic and register
    // circuit must respond to only two types (namely, ARITHMETIC & REGISTER instructions and DATA
    // ENTRY/DISPLAY instructions).  ARITHMETIC & REGISTER instructions are coded by a 10 in the
    // least significant two bits of Is <strike>register 90</strike> buffer 91. When this
    // combination is detected, the most significant five bits are saved in Is register 90 and
    // decoded by instruction decoder 92 into one of 32 instructions."
    always@(posedge PHI2) begin : proc_isbuf_isreg
        isbuf <= {IS, isbuf[9:1]};      // IS Buffer 91, shift right.
        if (~SYNC & syncr) begin
            isreg[9:4]  <= isbuf[9:4];  // IS Register 90.
            istype5     <= (isbuf[3:0] == 4'b1000)? 1'b1 : 1'b0;
            istype2     <= (isbuf[1:0] == 2'b10)?   1'b1 : 1'b0;
        end
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (9):  "The seven registers A-F and M can be divided into three groups: the working
    // registers A, B, and C with C also being the bottom register of a four-register stack; the
    // next three registers D, E, and F in the stack; and a separate storage register M
    // communicating with the other registers through register C only.  In FIG. 11, which shows the
    // data paths connecting all the registers A-F and M, each circle represents the 56 bit register
    // designated by the letter in the circle.  In the idle state (when no instruction is being
    // executed in arithmetic and register circuit 20) each register continually circulates since
    // with dynamic MOS registers information is represented by a charge on a parasitic capacitance
    // and must be continually refreshed or lost."
    // 
    // '569 (4):  "When WS buss 30 is low, the contents of the registers in arithmetic and register
    // circuit 20 are recirculated unchanged."
    // ---------------------------------------------------------------------------------------------
    // Note that the dummy preload in the RTL code below prevents synthesis from implementing these
    // shift registers using inferred RAM, instead forcing the use of flip-flops as originally
    // intended.  
    // 
    // Without the dummy preload, Synplify-Pro synthesizes these registers as RAM shifters, which
    // should be okay, but they don't work properly.  Logic analyzer captures revealed that the RAM
    // shifters circulated 60 bits in a 56-bit register which is seemingly impossible and resulted
    // in nonsensical operation.  Forcing synthesis to use registers fixes the problem.  The
    // syn_ramstyle="registers" attribute had no effect on the RAM inference so I used the brute
    // force approach, i.e., the dummy preload.
    //
    // Register A including its data multiplexers
    always@(posedge PHI2) begin : proc_regA
        if (dummy)
            regA  <= 60'hafeedfacebeef;                         // Dummy preload to prevent inferring RAM.
        else begin
            regA[60]    <= (regA[1]   & a2hld)                  // Recirculate from bit 1 when performing Left Shift operation.
                        |  (sum2      & s22hld);                // Store corrected adder result in holding register.
            regA[59:57] <=  regA[60:58];                        
            //                                                  
            regA[56]    <= (regA[1]   & a2a)                    // A -> A, normal recirculation.
                        |  (IS        & is2a)                   // Load IS into A.
                        |  (regB[1]   & b2a)                    // B -> A.
                        |  (regC[1]   & c2a)                    // C -> A.
                        |  (regD[1]   & d2a)                    // D -> A.
                        |  (sum1      & ~use_sum2 & res2a)      // Use normal adder result.
                        |  (sum2      &  use_sum2 & res2a)      // Use corrected adder result.
                        |  (regA[57]  & hld2a);                 // Recirculate from 4-bit holding register when performing Left Shift operation.
            //
            regA[55]    <= (regA[56]  & ~(use_sum2 & res2a))    // Normal circulation.
                        |  (regA[60]  &   use_sum2 & res2a);    // Load corrected adder result from holding register.
            //                                                  
            regA[54]    <= (regA[55]  & ~(use_sum2 & res2a))    // Normal circulation.
                        |  (regA[59]  &   use_sum2 & res2a);    // Load corrected adder result from holding register.
            //                                                  
            regA[53]    <= (regA[54]  & ~(use_sum2 & res2a))    // Normal circulation.
                        |  (regA[58]  &   use_sum2 & res2a);    // Load corrected adder result from holding register.
            //                                                  
            regA[52]    <= (regA[53]  & ~sra)                   // Normal circulation.
                        |  (regA[1]   &  sra);                  // Recirculate from bit 1 when performing Right Shift operation.

            regA[51:1]  <=  regA[52:2];
        end
    end

    // Register B including its data multiplexers
    always@(posedge PHI2) begin : proc_regB
        if (dummy)
            regB  <= 56'hfeedfacebeef;                          // Dummy preload to prevent inferring RAM.
        else begin
            regB[56]    <= (regB[1]   & b2b)                    // B -> B, normal recirculation.
                        |  (regA[1]   & a2b)                    // A -> B.
                        |  (regC[1]   & c2b);                   // C -> B.
            regB[55:53] <=  regB[56:54];                        
            regB[52]    <= (regB[53]  & ~srb)                   // Normal circulation.
                        |  (regB[1]   &  srb);                  // Recirculate from bit 1 when performing Right Shift operation.
            regB[51:1]  <=  regB[52:2];
        end
    end

    // Register C including its data multiplexers
    always@(posedge PHI2) begin : proc_regC
        if (dummy)
            regC  <= 60'hafeedfacebeef;                         // Dummy preload to prevent inferring RAM.
        else begin
            regC[60]    <= sum2;                                // Store corrected adder result in holding register.
            regC[59:57] <= regC[60:58];                         // Shift.  Note that bit 57 is unused and synthesis might give a warning.
            regC[56]    <= (regC[1]   & c2c)                    // C -> C, normal recirculation.
                        |  (isreg[9]  & con2c & t4)             // Load constant into C.
                        |  (bcd_in    & bcd2c)                  // Load BCD into C.
                        |  (regA[1]   & a2c)                    // A -> C.
                        |  (regB[1]   & b2c)                    // B -> C.
                        |  (regD[1]   & d2c)                    // D -> C.
                        |  (regM[1]   & m2c)                    // M -> C.
                        |  (sum1      & ~use_sum2 & res2c)      // Use normal adder result.
                        |  (sum2      &  use_sum2 & res2c);     // Use corrected adder result.
            regC[55]    <= (regC[56]  & ~(use_sum2 & res2c))    // Normal circulation.
                        |  (regC[60]  &   use_sum2 & res2c)     // Load corrected adder result from holding register.
                        |  (isreg[8]  & con2c & t4);            // Load constant into C.
            regC[54]    <= (regC[55]  & ~(use_sum2 & res2c))    // Normal circulation.
                        |  (regC[59]  &   use_sum2 & res2c)     // Load corrected adder result from holding register.
                        |  (isreg[7]  & con2c & t4);            // Load constant into C.
            regC[53]    <= (regC[54]  & ~(use_sum2 & res2c))    // Normal circulation.
                        |  (regC[58]  &   use_sum2 & res2c)     // Load corrected adder result from holding register.
                        |  (isreg[6]  & con2c & t4);            // Load constant into C.
            regC[52]    <= (regC[53]  & ~src)                   // Normal circulation.
                        |  (regC[1]   &  src);                  // Recirculate from bit 1 when performing Right Shift operation.
            regC[51:1]  <= regC[52:2];
        end
    end

    // Register D including its data multiplexers
    always@(posedge PHI2) begin : proc_regD
        if (dummy)
            regD  <= 56'hfeedfacebeef;                          // Dummy preload to prevent inferring RAM.
        else begin
            regD[56]    <= (regD[1]   & d2d)                    // D -> D, normal recirculation.
                        |  (regC[1]   & c2d)                    // C -> D.
                        |  (regE[1]   & e2d);                   // E -> D.
            regD[55:1] <= regD[56:2];      
        end
    end

    // Register E including its data multiplexers
    always@(posedge PHI2) begin : proc_regE
        if (dummy)
            regE  <= 56'hfeedfacebeef;                      // Dummy preload to prevent inferring RAM.
        else begin
            regE[56]    <= (regE[1]   & e2e)                // E -> E, normal recirculation.
                        |  (regD[1]   & d2e)                // D -> E.
                        |  (regF[1]   & f2e);               // F -> E.
            regE[55:1]  <=  regE[56:2];      
        end
    end

    // Register F including its data multiplexers
    always@(posedge PHI2) begin : proc_regF
        if (dummy)
            regF  <= 56'hfeedfacebeef;                      // Dummy preload to prevent inferring RAM.
        else begin
            regF[56]    <= (regF[1]   & f2f)                // F -> F, normal recirculation.
                        |  (regC[1]   & c2f)                // C -> F.
                        |  (regE[1]   & e2f);               // E -> F.
            regF[55:1]  <=  regF[56:2];      
        end
    end

    // Register M including its data multiplexers
    always@(posedge PHI2) begin : proc_regM
        if (dummy)
            regM  <= 56'hfeedfacebeef;                      // Dummy preload to prevent inferring RAM.
        else begin
            regM[56]    <= (regM[1]   & m2m)                // M -> M, normal recirculation.
                        |  (regC[1]   & c2m);               // C -> M.
            regM[55:1] <= regM[56:2];      
        end
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // Combinational input multiplexers for the serial adder.
    always@* begin : proc_add_mux
        x_in    = regA[1] & a2x     // Apply register A to adder's X input.
                | regC[1] & c2x;    //   "      "     C "    "     "   "
        //
        y_in    = regB[1] & b2y     // Apply register B to adder's Y input.
                | regC[1] & c2y;    //   "      "     C "    "     "   "   
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (11):  "The display blanking is handled as follows. At time T4 the BCD digit is gated 
    // from register A into display buffer 96. If this digit is to be blanked, register B will
    // contain a 9 (1001) so that at T4 the end bit (B01) of the B register will be a 1 (an 8 would
    // therefore also work).  The input to display buffer 96 is OR-ED with B01 and will be set to
    // 1111 if the digit is to be blanked.  The decimal point is handled in a similar way.  A 2
    // (0010) is placed in register B at the decimal point location.  At time T2 the decimal point
    // buffer flip-flop is set by B01. Any digit with a one in the second position will set the
    // decimal point (i.e., 2, 3, 6, or 7).
    //     One other special decoding feature is required. A minus sign is represented in tens
    // complement notation or sign and magnitude notation by the digit 9 in the sign location.
    // However, the display must show only a minus sign (i.e., segment g).  The digit 9 in register
    // A in digit position 2 (exponent sign) or position 13 (mantissa sign) must be displayed as
    // minus.  The decoding circuitry uses the pulse on Is buss 28 at bit time b11 (see FIG. 3) to
    // know that the digit 9 in digit position 2 of register A should be a minus and uses the SYNC
    // pulse to know that the digit 9 in digit position 13 of register A should also be a minus.
    // The pulse on Is buss 28 at bit time b11 can be set by a mask option, which allows the minus
    // sign of the exponent to appear in other locations for other uses of the calculator circuits."
    //
    // '569 (23):  "The display flip-flop in arithmetic and register circuit 20 controls blanking of
    // all the LED�s. When it is reset, the 1111 code is set into the display buffer 96, which is
    // decoded so that no segments are on. There is one instruction to reset this flip-flop
    // I9 I8 I7 = (100) and another to toggle it (000). The toggle feature is convenient for
    // blinking the display."                           
    // 
    always@(posedge PHI2) begin : proc_display_buffer_96
        if (!SYNC && syncr)                             // If we've reached the last clock period of the execution cycle, then...
            if (dspn)                                   //    If the Display Off instruction is issued, then...
                display_ff <= 1'b0;                     //       reset the Display flip-flop.
            else if (dspt)                              //    Otherwise, if the Display Toggle instruction is issued, then...
                display_ff <= ~display_ff;              //       toggle the Display flip-flop.
        //
        if (t2)                                         // If at time t2, then...
            dsbf_dp <= (regB[1] & display_ff);          //    set the decimal point buffer flip-flop only if the current digit in register B holds a '2' and the Display flip-flop is set. 
        //
        if (t4) begin                                   // If at time t4, then...
            if (regB[1] || ~display_ff)                 //    If the current digit in register B holds a '9' or the display flip-flop is reset, then...
                dsbf <= 4'b1111;                        //       blank the digit.
            else if (!SYNC && (IS || syncr))            //    Otherwise, if the current digit is in one of the two sign positions, then...
               if ({regA[1],regA[56:54]} == 4'b1001)    //       if the current digit in register A holds a '9', then...
                   dsbf <= 4'b1110;                     //          select the "minus" sign.
               else                                     //       Otherwise (the current digit in register A isn't a '9'), so...
                   dsbf <= 4'b1111;                     //          blank the digit.
            else                                        //    Otherwise (the current digit in register B isn't a '9' AND the display flip-flop isn't reset AND the current digit isn't one of the two sign positions), so...
                dsbf <= {regA[1],regA[56:54]};          //       send the current digit in register A to the display decoder 94.
        end
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (10):  "For increased power savings display decoder 94 is partitioned to partially
    // decode the BCD data into seven segments and a decimal point in arithmetic and register
    // circuit 20 by using only five output lines (A-E) 38 with time as the other parameter.
    // Information for seven segments (a-g) and a decimal point (dp) are time shared on the five
    // output lines A-E.  The output wave forms for output lines A-E are shown in FIG. 12. For
    // example, output line D carries the segment e information during T1 (the first bit time of
    // each digit time) and the segment d information during T2 (the second bit time of each digit
    // time); and output E carries the segment g information during T1, the segment F information
    // during T2, and the decimal point (dp) during T4."
    always @* begin : proc_display_decoder_94
        case (dsbf)
            4'b0000 : {a, b, c, d, e, f, g} = 7'b1111110;   // BCD 0
            4'b0001 : {a, b, c, d, e, f, g} = 7'b0110000;   // BCD 1
            4'b0010 : {a, b, c, d, e, f, g} = 7'b1101101;   // BCD 2
            4'b0011 : {a, b, c, d, e, f, g} = 7'b1111001;   // BCD 3
            4'b0100 : {a, b, c, d, e, f, g} = 7'b0110011;   // BCD 4
            4'b0101 : {a, b, c, d, e, f, g} = 7'b1011011;   // BCD 5
            4'b0110 : {a, b, c, d, e, f, g} = 7'b1011111;   // BCD 6
            4'b0111 : {a, b, c, d, e, f, g} = 7'b1110000;   // BCD 7
            4'b1000 : {a, b, c, d, e, f, g} = 7'b1111111;   // BCD 8
            4'b1001 : {a, b, c, d, e, f, g} = 7'b1111011;   // BCD 9
            4'b1110 : {a, b, c, d, e, f, g} = 7'b0000001;   // BCD E = Minus sign.  This is not specified as BCD E in the patent.
            4'b1111 : {a, b, c, d, e, f, g} = 7'b0000000;   // BCD F = Blanking code.
            default : {a, b, c, d, e, f, g} = 7'b0000000;
        endcase

        case (1'b1)
            t1 : begin
                muxA = a;       // During T1, output line A carries the segment 'a' information.
                muxB = 1'b0;    //   "    T1,   "     "   B is always zero.
                muxC = c;       //   "    T1,   "     "   C carries the segment 'c' information.
                muxD = e;       //   "    T1,   "     "   D    "     "    "     'e'      "     .
                muxE = g;       //   "    T1,   "     "   E    "     "    "     'g'      "     .
            end
            t2 : begin
                muxA = a;       // During T2, output line A carries the segment 'a' information.
                muxB = b;       //   "    T2,   "     "   B    "     "    "     'b'      "     .
                muxC = c;       //   "    T2,   "     "   C    "     "    "     'c'      "     .
                muxD = d;       //   "    T2,   "     "   D    "     "    "     'd'      "     .
                muxE = f;       //   "    T2,   "     "   E    "     "    "     'f'      "     .
            end
            t3 : begin
                muxA = 1'b0;    // During T3, output line A is always zero.                    
                muxB = b;       //   "    T3,   "     "   B carries the segment 'b' information.
                muxC = c;       //   "    T3,   "     "   C    "     "    "     'c'      "     .
                muxD = 1'b0;    //   "    T3,   "     "   D is always zero.
                muxE = 1'b0;    //   "    T3,   "     "   E is always zero.
            end
            t4 : begin
                muxA = 1'b0;    // During T4, output line A is always zero.
                muxB = dsbf_dp; //   "    T4,   "     "   B carries the decimal point.
                muxC = c;       //   "    T4,   "     "   C carries the segment 'c' information.
                muxD = 1'b0;    //   "    T4,   "     "   D is always zero.
                muxE = dsbf_dp; //   "    T4,   "     "   E carries the decimal point.
            end
            default : {muxA, muxB, muxC, muxD, muxE} = 5'b00000;   // Should always be in T1 - T4 but include default for latch mitigation.
        endcase
    end
    // ---------------------------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // Registered output lines (A-E) 38.
    always@(posedge PHI2) begin : proc_abcde_reg
         {A, B, C, D, E} <=  {muxA, muxB, muxC, muxD, muxE};
    end
    // ---------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------
// Instances

    // -------------------------------------------------------------------------
    // '569 (10): "Arithmetic and register circuit 20 receives the instruction
    // during bit times b45-b54.  Of the ten types of instructions herein-
    // after described, arithmetic and register circuit must respond to
    // only two types (namely, ARITHMETIC & REGISTER instructions and DATA
    // ENTRY/DISPLAY instructions).
    instruction_decoder_92 inst_instruction_decoder (
        // ---------------------------------------------------------------------
        // BCD adder/subtractor controls.
        .sub        (sub),      // output reg       // Add/Subtract control input.  0 = add, 1 = subtract. 
        .c_in       (c_in),     // output reg       // Carry/borrow input (active high in both cases) from previous word cycle.
        .a2x        (a2x),      // output reg       // Steers register A to adder/subtractor's X_IN input.
        .c2x        (c2x),      // output reg       //   "       "     C "    "        "       X_IN   "
        .b2y        (b2y),      // output reg       //   "       "     B "    "        "       Y_IN   "
        .c2y        (c2y),      // output reg       //   "       "     C "    "        "       Y_IN   "
        // ---------------------------------------------------------------------
        // Multiplexer controls for register A
        // -- these signals steer one of eight sources into register A's bit [56] input:
        .a2a        (a2a),      // output reg       // (1) LSB of Register A (recirculate)
        .is2a       (is2a),     // output reg       // (2) Serial instruction bus, IS
        .b2a        (b2a),      // output reg       // (3) LSB of Register B (transfer)
        .c2a        (c2a),      // output reg       // (4) LSB of Register D (transfer)
        .d2a        (d2a),      // output reg       // (5) LSB of Register D (transfer)
        .res2a      (res2a),    // output reg       // (6 or 7) Result from adder/subtractor.  If no carry then use sum1 (6), else use sum2 (7) and also transfer holding register contents into A[55:53]
        .hld2a      (hld2a),    // output reg       // (8) LSB of 4-bit holding register 86
        // -- this selects the source of register A's bit [52] input:
        .sra        (sra),      // output reg       // 1 = Recirculate LSB of Register A to bit [52] for right shift; 0 = normal circulation.
        // -- these signals steer one of two sources into the MSB of 4-bit holding register 86:
        .a2hld      (a2hld),    // output reg       // (1) LSB of Register A (for left shift instruction).
        .s22hld     (s22hld),   // output reg       // (2) sum2 (BCD adder/subtractor's corrected sum).
        // ---------------------------------------------------------------------
        // Multiplexer controls for register B
        // -- these signals steer one of three sources into register B's bit [56] input:
        .b2b        (b2b),      // output reg       // (1) LSB of Register B (recirculate)
        .a2b        (a2b),      // output reg       // (2) LSB of Register A (transfer)
        .c2b        (c2b),      // output reg       // (3) LSB of Register C (transfer)
        // -- this selects the source of register B's bit [52] input:
        .srb        (srb),      // output reg       // 1 = Recirculate LSB of Register B to bit [52] for right shift; 0 = normal circulation.
        // ---------------------------------------------------------------------
        // Multiplexer controls for register C
        // -- these signals steer one of nine sources into register C's bit [56] input:
        .c2c        (c2c),      // output reg       // (1) LSB of Register C (recirculate)
        .con2c      (con2c),    // output reg       // (2) 4-bit constant from instruction register (LOAD CONSTANT instruction)
        .bcd2c      (bcd2c),    // output reg       // (3) Input from data storage circuit (BCD)
        .a2c        (a2c),      // output reg       // (4) LSB of Register A (transfer)
        .b2c        (b2c),      // output reg       // (5) LSB of Register B (transfer)
        .d2c        (d2c),      // output reg       // (6) LSB of Register D (transfer)
        .m2c        (m2c),      // output reg       // (7) LSB of Register M (transfer)
        .res2c      (res2c),    // output reg       // (8 or 9) Result from adder/subtractor.  If no carry then use sum1 (8), else use sum2 (9) and also transfer holding register contents into C[55:53]
        // -- this selects the source of register C's bit [52] input:
        .src        (src),      // output reg       // 1 = Recirculate LSB of Register C to bit [52] for right shift; 0 = normal circulation.
        // ---------------------------------------------------------------------
        // Multiplexer controls for register D
        // -- these signals steer one of three sources into register D's bit [56] input:
        .d2d        (d2d),      // output reg       // (1) LSB of Register D (recirculate)
        .c2d        (c2d),      // output reg       // (2) LSB of Register C (transfer)
        .e2d        (e2d),      // output reg       // (3) LSB of Register D (transfer)
        // ---------------------------------------------------------------------
        // Multiplexer controls for register E
        // -- these signals steer one of three sources into register E's bit [56] input:
        .e2e        (e2e),      // output reg       // (1) LSB of Register E (recirculate)
        .d2e        (d2e),      // output reg       // (2) LSB of Register D (transfer)   
        .f2e        (f2e),      // output reg       // (3) LSB of Register F (transfer)   
        // ---------------------------------------------------------------------
        // Multiplexer controls for register F
        // -- these signals steer one of three sources into register F's bit [56] input:
        .f2f        (f2f),      // output reg       // (1) LSB of Register F (recirculate)
        .c2f        (c2f),      // output reg       // (2) LSB of Register C (transfer)   
        .e2f        (e2f),      // output reg       // (3) LSB of Register E (transfer)   
        // ---------------------------------------------------------------------
        // Multiplexer controls for register M
        // -- these signals steer one of two sources into register M's bit [56] input:
        .m2m        (m2m),      // output reg       // (1) LSB of Register M (recirculate)
        .c2m        (c2m),      // output reg       // (2) LSB of Register C (transfer)   
        // ---------------------------------------------------------------------
        // Display toggle and display off        
        .dspt       (dspt),     // output reg       // Toggle the display flip-flop
        .dspn       (dspn),     // output reg       // Turn off the display flip-flop
        // ---------------------------------------------------------------------
        // Input Ports                  
        .isreg      (isreg),    // input wire [9:4] // ('569 item 90) IS Register.
        .istype2    (istype2),  // input wire       // Instruction is Type 2.
        .istype5    (istype5),  // input wire       // Instruction is Type 5.
        .WS         (WS),       // input wire       // ('569 item 30) ROM Word Select
        .ws1        (ws1),      // input wire       // Asserted during the first bit period, T1, of WS.
        .ds1        (ds1),      // input wire       // Asserted during the first digit period of WS.
        .dsn1       (dsn1)      // input wire       // Asserted during all digit periods of WS other than the first.
    );
    // End instruction_decoder_92 
    // -------------------------------------------------------------------------

    // ---------------------------------------------------------------------------------------------
    // '569 (9):  "In serial decimal adder/subtractor 84 a correction (addition of 6) to a BCD sum
    // must be made if the sum exceeds nine (a similar correction for subtraction is necessary).  It
    // is not known if a correction is needed until the first three bits of the sum have been
    // generated. This is accomplished by adding a four-bit holding register 86 (A60 - A57) and
    // inserting the corrected sum into a portion 88 (A56 - A53) of register A if a carry is
    // generated.  This holding register 86 is also required for the SHIFT A LEFT instruction.  One
    // of the characteristics of a decimal adder is that non-BCD codes (i.e. 1101) are not allowed.
    // They will be modified if circulated through the adder.  The adder logic is minimized to save
    // circuit area.  If four-bit codes other than 0000-1001 are processed, they will be modified.
    // This is no constraint for applications involving only numeric data (however, if ASClI codes,
    // for instance, are operated upon, incorrect results will be obtained)."
    // 
    serial_adder_84 #(
        .NewArch    (0)             // parameter    // 1 = Use new architecture, 0 = Like the patent.
    )
    inst_serial_adder (
        // Output Ports
        .SUM1       (sum1),         // output       // Serial sum or difference.  Sum = X_IN + Y_IN + C_IN.  Difference = X_IN - Y_IN - C_IN.
        .SUM2       (sum2),         // output       // Corrected sum (SUM1 + 6).
        .USE_SUM2   (use_sum2),     // output reg   // Asserted during T4 if the corrected sum should be used.
        .CARRY      (sa_carry),     // output reg   // ('569 item 34) Carry out when adding, borrow out when subtracting (active high in both cases). Valid during T4 of each digit time.  Sent to the Control & Timing block.
        // Input Ports                  
        .X_IN       (x_in),         // input        // Bit-serial augend when adding.  Bit-serial minuend when subtracting.
        .Y_IN       (y_in),         // input        // Bit-serial addend when adding.  Bit-serial subtrahend when subtracting.
        .C_IN       (c_in),         // input        // Carry/borrow input (active high in both cases) from previous word cycle.
        .FIRST_BIT  (ws1),          // input        // Indicates the first bit period of the word cycle.  When asserted, C_IN is included in sum.
        .SUB        (sub),          // input        // Add/Subtract control input.  0 = add, 1 = subtract.
        .T1         (t1),           // input        // One-hot T-state counter indicating the active bit in the current digit.  T1 = LSbit, T4 = MSbit.
        .T2         (t2),           // input        //  "
        .T3         (t3),           // input        //  "
        .T4         (t4),           // input        //  "
        .PHI2       (PHI2)          // input        // Bit-Rate Clock Input, Phase 2.
    );
    // End serial_adder_84
    // ---------------------------------------------------------------------------------------------

endmodule 

