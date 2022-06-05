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
//      microprogrammed_controller_46.v
//
// Author:
//      Robert J. Weinstein
//      patently.obvious.2021@gmail.com
//      
// Title:
//      HP-35 Project:  Microprogrammed Controller
//
// Notes:
//      Some passages of US 4,001,569 are quoted verbatim as comments in this
//      module and are indicated like this:
//         '569 (col): "<quoted text>"
//      Where "col" is the column number in the patent document.
// 
// Description:
//      This module implements the "Microprogrammed Controller 46" function
//      within the "Control & Timing 16" block described in patent US 4,001,569
//      which discloses the HP-45 calculator.
//      
//      The patent discloses much of the calculator's logic in minute detail,
//      however, it's silent on the internal details of the Microprogrammed
//      Controller 46.  Here's what the patent has to say about this module: 
// 
//         '569 (5):  "The control unit of control and timing circuit 16 is a
//         microprogrammed controller 46 comprising a 58 word (25 bits per word)
//         control ROM, which receives qualifier or status conditions from
//         throughout the calculator and sequentially outputs signals to control
//         the flow of data. Each bit in this control ROM either corresponds to
//         a signal control line or is part of a group of N bits encoded into
//         2^N mutually exclusive control lines and decoded external to the
//         control ROM. At each phase 2 clock, a word is read from the control
//         ROM as determined by its present address. Part of the output is fed
//         back to become the next address."
//         
//         '569 (5)  "Several types of qualifiers are checked. Since most
//         commands are issued only at certain bit times during the word cycle,
//         timing qualifiers are necessary. This means the control ROM may sit
//         in a wait loop until the appropriate timing qualifier comes true,
//         then move to the next address to issue a command. Other qualifiers
//         are the state of the pointer register, the PWO (power on) line, the
//         CARRY flip flop, and the state of each of the 12 status bits."
// 
//      I can only assume that Hewlett Packard considered the Microprogrammed
//      Controller's functional details to be this calculator's "secret sauce"
//      and purposely chose not to disclose them.  In order to discover this
//      functionality, I started by drawing a series of detailed timing
//      diagrams, one for every instruction type, depicting the Is and Ia lines
//      during each clock period in the word cycle then adding the contents of
//      the main 28-bit shift register, in which I used three different fill
//      colors to identify the contents of the three registers, ROM Address 58,
//      Status Bits 62, and Return Address 60.  In these drawings, I show time
//      advancing from top to bottom and the shift register contents stepping to
//      the right on each clock cycle resulting in diagonally advancing stripes
//      of color depicting the recirculating registers within the 28-bit shift
//      register.  The visual result is not unlike a barber pole so I refer to
//      these as the "barber-pole timing diagrams".  
//      
//      Since a microprogrammed controller is an optimized implementation of a
//      finite state machine,  I decided to start by designing the state machine
//      using the Algorithmic State Machine (ASM) technique that Tom Osborne
//      pioneered during his time at HP and is very likely the same approach
//      that the designers of this calculator employed.  Osborne's ASM
//      techniques were collected, organized, and expanded by HP's Christopher
//      Clare in the following book:
//      
//          C. R. Clare, Designing Logic Systems Using State Machines, McGraw-
//          Hill, NY, 1973
//
//      At this stage, the barber-pole timing diagrams showed how the bits had
//      to move between Is, the shift register, the adder/subtractor, the
//      pointer, the address buffer, the key-code buffer, the carry flip-flop,
//      and Ia to perform each instruction type.  To this, I added a column to
//      the diagrams in which I partitioned the word cycle into states showing
//      what needed to be done during each time interval to perform the steps
//      required for each instruction type.  Once I had the states worked out,
//      I sketched the state transition diagrams using the ASM techniques in
//      Clare's book.  Finally, I coded the resulting ASM in this module.
//
//      My dad used to say, "The perfect is the enemy of the good."  Heeding
//      his advice, I left this module coded as a finite state machine and I
//      have not yet converted it to a true ROM-based microprogrammed
//      controller as described in '569.
// 
// IncludeFiles : state_names.v
//
// Conventions:
//    - UPPER case for signals described in the '569 patent.  Since many of the
//      control lines are described in the patent, UPPER case is extended to all
//      control line outputs from this module.
//    - Internal wires and registers are 'lower' case.
//    - State name parameters are camelCase starting with a lower case 's',
//      e.g., 'sIdle'.
//    - Other parameters are first letter 'Upper'.
//       
//      Uses Verilog 2001 Features
// 
// Drawings:
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

module microprogrammed_controller_46 #(
    parameter   UseASM = 1          // 1 = Use Algorithmic State Machine, 0 = Like the patent.
)
(
    // Output Ports (Control Lines)
    output reg      JSB,            // Control Line, (JSB in '569 Fig. 4), Jump Subroutine
    output reg      BRH,            // Control Line, (BRH in '569 Fig. 4), Conditional Branch
    output reg      PTONLY,         // Control Line, Arithmetic Instruction with WS = Pointer-Only 
    output reg      UP2PT,          // Control Line, Arithmetic Instruction with WS = Up-to-Pointer
    output reg      ARITHW,         // Control Line, Arithmetic Instruction Wait for A&R Chip
    output reg      ISTW,           // Control Line, Interrogate Status Wait for Shifter
    output reg      STDECN,         // Control Line, Status Instruction, Decrement Counter from N
    output reg      SST,            // Control Line, Set Status Bit
    output reg      RST,            // Control Line, Reset Status Bit
    output reg      IST,            // Control Line, (IST in '569 Fig. 4), Interrogate Status Bit
    output reg      SPT,            // Control Line, Set Pointer to P
    output reg      IPTR,           // Control Line, (IPT in '569 Fig. 4), Interrogate Pointer, Reset Carry
    output reg      IPTS,           // Control Line, (IPT in '569 Fig. 4), Interrogate Pointer, Set Carry
    output reg      PTD,            // Control Line, Pointer Decrement
    output reg      PTI,            // Control Line, Pointer Increment
    output reg      TKR,            // Control Line, (TKR in '569 Fig. 4), Keyboard Entry 
    output reg      RET,            // Control Line, (RET in '569 Fig. 4), Return from Subroutine
    output [1:62]   tp_state,       // Test point, state vector.
    // Clock Input
    input           PHI2,           // System Clock
    // Qualifier Inputs
    input           pwor,           // Qualifier, (PWO 36 in '569 Fig. 4), Power On, Registered Copy
    input           IS,             // Qualifier, (Is 28 in '569 Fig. 4), Serial Instruction from ROM
    input           b5,             // Qualifier, (from TIMING DECODER in '569 Fig. 4) System Counter 42 at Bit Time b5
    input           b14,            // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b14
    input           b18,            // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b18
    input           b26,            // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b28
    input           b35,            // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b35
    input           b45,            // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b45
    input           b54,            // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b54
    input           b55,            // Qualifier, ( "     "       "    "    "   "   ")   "       "    "  "   "   "   b55
    input           CARRY_FF,       // Qualifier, (CARRY Flip-Flop 66 in '569 Fig. 4), Carry Flip-Flop 66
    input           stqzero,        // Qualifier, Status Bit N has shifted to the Right-Most Position of 28-bit Shift Register.
    input           is_eq_ptr       // Qualifier, Interrogate Pointer Instruction's P Field (in Is) is Equal to Pointer
);

    // Include the parameter that defines the state names:
    `include "state_names.v"
//    `include "../../state_names.v"

    // State Registers for One-hot Arithmetic State Machine (in lieu of the patent's "Microprogrammed Controller 46"):
    reg [1:62]  state, next;

// -----------------------------------------------------------------------------
// Begin RTL 
// -----------------------------------------------------------------------------

    // Test point:
    assign tp_state = state;

    // A two-always-block one-hot state machine based on Cliff Cummings paper:
    //    
    //    Clifford E. Cummings, "The Fundamentals of Efficient Synthesizable FSM Design using
    //    NC-Verilog and BuildGates", International Cadence User's Group 2002, Rev 1.2, July
    //    2002
    // 
    // The sequential state register process: 
    always @ (posedge PHI2 or posedge pwor) begin : proc_state_reg
        if (pwor) begin
            state           <= 'b0;
            state[sIdle]    <= 1'b1;
        end
        else state <= next;
    end

    // The combinational next-state process: 
    always @* begin : proc_next_comb
        next    = 'b0;      // Ensure only the bit selected in the case statement is active.
        JSB     = 1'b0;
        BRH     = 1'b0;
        PTONLY  = 1'b0;
        UP2PT   = 1'b0;
        ARITHW  = 1'b0;
        STDECN  = 1'b0;
        SST     = 1'b0;
        RST     = 1'b0;
        ISTW    = 1'b0;
        IST     = 1'b0;
        SPT     = 1'b0;
        IPTR    = 1'b0;
        IPTS    = 1'b0;
        PTD     = 1'b0;
        PTI     = 1'b0;
        TKR     = 1'b0;
        RET     = 1'b0;

        case (1'b1) // synthesis full_case parallel_case
            // Main Instruction Parsing Loop
            state[sIdle]        :   if (b45)                                            // Power On (PWO) state, this bit is set, all others reset.  Test for Type 1.
                                        if (IS)             next[s1x]           = 1'b1; 
                                        else                next[s0x]           = 1'b1;
                                    else                    next[sIdle]         = 1'b1; // Hold here.
            state[s0x]          :   if (IS)                 next[s01x]          = 1'b1; // Test for Type 2.
                                    else                    next[s00x]          = 1'b1;
            state[s00x]         :   if (IS)                 next[s001x]         = 1'b1; // Test for Type 3 or Type 4.
                                    else                    next[s000x]         = 1'b1;
            state[s001x]        :   if (IS)                 next[s0011x]        = 1'b1; // Test for Type 4.
                                    else                    next[s0010x]        = 1'b1;
            state[s000x]        :   if (IS)                 next[s0001x]        = 1'b1; // Test for Type 5.
                                    else                    next[s0000x]        = 1'b1;
            state[s0000x]       :   if (IS)                 next[sType6]        = 1'b1; // Test for Type 6.
                                    else                    next[sNop]          = 1'b1;
            state[sNop]         :   if (b18)                next[sAddrOut]      = 1'b1; // Instruction failed tests for Types 1 through 6, so it's a No Op.
                                    else                    next[sNop]          = 1'b1; // Hold here.
            state[sAddrOut]     :   if (b26)                next[sIdle]         = 1'b1; // Return point for instructions that use the default ROM Address 58.
                                    else                    next[sAddrOut]      = 1'b1; // Hold here.
            // Type 1 (Jump/Branch) Instructions        
            state[s1x]          :   if (IS)                 next[sBrhWait]      = 1'b1; // Decoded a Type 1 instruction so test for JSB or BRH.
                                    else                    next[sJsb]          = 1'b1;
            state[sJsb]         :   begin                                               // Decoded JSB (Jump Subroutine).
                                        JSB = 1'b1;         
                                        if (b54)            next[sJsbWait]      = 1'b1;
                                        else                next[sJsb]          = 1'b1; // Hold here.
                                    end                     
            state[sJsbWait]     :   if (b18)                next[sAddrOut]      = 1'b1; // Wait for completeion of JSB.
                                    else                    next[sJsbWait]      = 1'b1; // Hold here.
            state[sBrhWait]     :   if (b18)                                            // Decoded BRH (Conditional Branch).
                                        if (CARRY_FF)       next[sAddrOut]      = 1'b1;
                                        else                next[sBrhOut]       = 1'b1;
                                    else                    next[sBrhWait]      = 1'b1; // Hold here.
            state[sBrhOut]      :   begin                                               // Drive the captured branch address out Ia.
                                        BRH = 1'b1;         
                                        if (b26)            next[sIdle]         = 1'b1;
                                        else                next[sBrhOut]       = 1'b1; // Hold here.
                                    end
            // Type 2 (Arithmetic) Instructions
            state[s01x]         :   if (IS)                 next[sArithWait]    = 1'b1; // Decoded a Type 2 (Arithmetic) instruction so parse the first Word Select bit.
                                    else                    next[s010x]         = 1'b1;
            state[s010x]        :   if (IS)                 next[sArithWait]    = 1'b1; // Parse the second Word Select bit.
                                    else                    next[s0100x]        = 1'b1;
            state[s0100x]       :   if (IS)                 next[sArithWP]      = 1'b1; // Parse the third Word Select bit.
                                    else                    next[sArithP]       = 1'b1;      
            state[sArithP]      :   begin                                               // Arithmetic Word Select = Is[4:2] = 000 = Pointer Only
                                        PTONLY = 1'b1;      
                                        if (b54)            next[sArithWait]    = 1'b1;   
                                        else                next[sArithP]       = 1'b1; // Hold here.
                                    end                     
            state[sArithWP]     :   begin                                               // Arithmetic Word Select = Is[4:2] = 100 = Up to Pointer
                                        UP2PT = 1'b1;       
                                        if (b54)            next[sArithWait]    = 1'b1;   
                                        else                next[sArithWP]      = 1'b1; // Hold here.
                                    end                     
            state[sArithWait]   :   begin                                               // Executed in A&R, not part of C&T.
                                        ARITHW = 1'b1;      
                                        if (b18)            next[sAddrOut]      = 1'b1;
                                        else                next[sArithWait]    = 1'b1; // Hold here.
                                    end                     
            // Type 3 (Status Flag) Instructions                          
            state[s0010x]       :   if (IS)                 next[s00101x]       = 1'b1; // Decoded a Type 3 (Status) instruction so parse the next two bits to narrow it down.
                                    else                    next[s00100x]       = 1'b1;
            state[s00100x]      :   if (IS)                 next[sRst]          = 1'b1; // Determine whether the instruction is Set Status Flag (F=00) or Reset Status Flag (F=10).
                                    else                    next[sSst]          = 1'b1;
            state[sSst]         :   if (b5)                 next[sSstDecr]      = 1'b1; // Decoded the Set Status Flag instruction.
                                    else                    next[sSst]          = 1'b1; // Hold here.
            state[sSstDecr]     :   begin                                               // Wait for the selected status bit (status bit N) to arrive at the end of the 28-bit shift register.
                                        STDECN = 1'b1;      
                                        if (stqzero)        next[sSstThis]      = 1'b1;     
                                        else                next[sSstDecr]      = 1'b1; // Hold here.
                                    end                     
            state[sSstThis]     :   begin                                               // The selected status bit is now at the end of the 28-bit shift register.
                                        SST = 1'b1;         
                                        if (b18)            next[sAddrOut]      = 1'b1;     
                                        else                next[sStDone]       = 1'b1;
                                    end                     
            //                                              
            state[sRst]         :   if (b5)                 next[sRstDecr]      = 1'b1; // Decoded the Reset Status Flag instruction.
                                    else                    next[sRst]          = 1'b1; // Hold here.
            state[sRstDecr]     :   begin                                               // Wait for the selected status bit (status bit N) to arrive at the end of the 28-bit shift register.
                                        STDECN = 1'b1;      
                                        if (stqzero)        next[sRstThis]      = 1'b1;     
                                        else                next[sRstDecr]      = 1'b1; // Hold here.
                                    end                     
            state[sRstThis]     :   begin                                               // The selected status bit is now at the end of the 28-bit shift register.
                                        RST = 1'b1;         
                                        if (b18)            next[sAddrOut]      = 1'b1;     
                                        else                next[sStDone]       = 1'b1;
                                    end                     
            //                                              
            state[s00101x]      :   if (IS)                 next[sCst]          = 1'b1; // Determine whether the instruction is Interrogate Status Flag (F=01) or Clear All Status Flags (F=11).
                                    else                    next[sIst]          = 1'b1;
            state[sIst]         :   begin                                               // Decoded the Interrogate Status Flag instruction.
                                        ISTW = 1'b1;
                                        if (b5)             next[sIstDecr]      = 1'b1;
                                        else                next[sIst]          = 1'b1; // Hold here.
                                    end
            state[sIstDecr]     :   begin                                               // Wait for the selected status bit (status bit N) to arrive at the end of the 28-bit shift register.
                                        STDECN = 1'b1;
                                        if (stqzero)        next[sIstThis]      = 1'b1;     
                                        else                next[sIstDecr]      = 1'b1; // Hold here.
                                    end                     
            state[sIstThis]     :   begin                                               // The selected status bit is now at the end of the 28-bit shift register.
                                        IST = 1'b1;         
                                        if (b18)            next[sAddrOut]      = 1'b1;     
                                        else                next[sStDone]       = 1'b1;
                                    end                     
            state[sStDone]      :   if (b18)                next[sAddrOut]      = 1'b1; // Wait for the last status bit position.
                                    else                    next[sStDone]       = 1'b1; // Hold here.
            //                                              
            state[sCst]         :   if (b5)                 next[sCstDecr]      = 1'b1; // Decoded the Clear All Status Flags instruction.
                                    else                    next[sCst]          = 1'b1; // Hold here.
            state[sCstDecr]     :   begin                                               // Wait for the selected status bit (status bit N) to arrive at the end of the 28-bit shift register.
                                        STDECN = 1'b1;      
                                        if (stqzero)        next[sCstThis]      = 1'b1;     
                                        else                next[sCstDecr]      = 1'b1; // Hold here.
                                    end                     
            state[sCstThis]     :   begin                                               // The selected status bit is now at the end of the 28-bit shift register so begin clearing to the end of the field.
                                        RST = 1'b1;         
                                        if (b18)            next[sAddrOut]      = 1'b1;     
                                        else                next[sCstThis]      = 1'b1; // Hold here.
                                    end
            // Type 4 (Pointer) Instructions 
            state[s0011x]       :   if (IS)                 next[s00111x]       = 1'b1; // Decoded a Type 4 (Pointer) instruction so parse the next two bits to narrow it down.
                                    else                    next[s00110x]       = 1'b1;
            state[s00110x]      :   if (IS)                 next[sIpt]          = 1'b1; // Determine whether the instruction is Set Pointer (F=00) or Interrogate Pointer (F=10).
                                    else                    next[sSpt]          = 1'b1;
            state[sSpt]         :   begin                                               // Decoded the Set Pointer instruction.
                                        SPT = 1'b1;         
                                        if (b54)            next[sSptDone]      = 1'b1;         
                                        else                next[sSpt]          = 1'b1; // Hold here.
                                    end
            state[sSptDone]     :   if (b18)                next[sAddrOut]      = 1'b1; // Set Pointer is done so wait until it's time to enter the address output state.
                                    else                    next[sSptDone]      = 1'b1; // Hold here.
            //
            state[sIpt]         :   if (is_eq_ptr)                                      // Decoded the Interrogate Pointer instruction.
                                        if (b54)            next[sIptSetC]      = 1'b1;
                                        else                next[sIpt]          = 1'b1;
                                    else                    next[sIptRstC]      = 1'b1;
            state[sIptSetC]       :   begin                                             // If pointer is equal to this instruction's P field then set carry.
                                        IPTS = 1'b1;
                                        if (b18)            next[sAddrOut]      = 1'b1;     
                                        else                next[sIptSetC]      = 1'b1; // Hold here.
                                    end
            state[sIptRstC]      :   begin                                              // If pointer is NOT equal to this instruction's P field then RESET carry.
                                        IPTR = 1'b1;
                                        if (b18)            next[sAddrOut]      = 1'b1;     
                                        else                next[sIptRstC]      = 1'b1; // Hold here.
                                    end
            //
            state[s00111x]      :   if (IS)                 next[sPti]          = 1'b1; // Determine whether the instruction is Decrement Pointer (F=01) or Increment Pointer (F=11).
                                    else                    next[sPtd]          = 1'b1;
            state[sPtd]         :   if (b14)                next[sPtdNow]       = 1'b1; // Decoded the Decrement Pointer instruction.
                                    else                    next[sPtd]          = 1'b1; // Hold here.
            state[sPtdNow]      :   begin                                               // The four clock periods in which the pointer is decremented.
                                        PTD = 1'b1;         
                                        if (b18)            next[sAddrOut]      = 1'b1;         
                                        else                next[sPtdNow]       = 1'b1; // Hold here.
                                    end
            //
            state[sPti]         :   if (b14)                next[sPtiNow]       = 1'b1; // Decoded the Increment Pointer instruction.
                                    else                    next[sPti]          = 1'b1; // Hold here.
            state[sPtiNow]      :   begin                                               // The four clock periods in which the pointer is incremented.
                                        PTI = 1'b1;         
                                        if (b18)            next[sAddrOut]      = 1'b1;         
                                        else                next[sPtiNow]       = 1'b1; // Hold here.
                                    end
            // Type 5 (Data Entry/Display) Instructions 
            state[s0001x]       :   if (IS)                 next[s00011x]       = 1'b1; // Decoded a Type 5 (Data Entry/Display) instruction so parse the next two bits to narrow it down.
                                    else                    next[sType5Wait]    = 1'b1;
            state[s00011x]      :   if (IS)                 next[sType5Wait]    = 1'b1; // Determine whether the instruction is LDC (F=01) or other (F=11).
                                    else                    next[sLdc]          = 1'b1;
            state[sLdc]         :   begin                                               // Decoded the LOAD CONSTANT (LDC) instruction.  Generate Word Select at pointer-only then decrement pointer.
                                        PTONLY = 1'b1;         
                                        if (b54)            next[sPtd]          = 1'b1; // Go decrement the pointer.
                                        else                next[sLdc]          = 1'b1; // Hold here.
                                    end
            state[sType5Wait]   :   if (b18)                next[sAddrOut]      = 1'b1; // All Type 5 instructions other than LDC are executed in the the A&R circuit so wait here for completion.
                                    else                    next[sType5Wait]    = 1'b1; // Hold here.
            // Type 6 (Misc) Instructions
            state[sType6]       :   if (IS)                 next[s000011x]      = 1'b1; // Decoded a Type 6 instruction so parse the next two bits to narrow it down.
                                    else                    next[s000010x]      = 1'b1;
            state[s000010x]     :   if (IS)                 next[s0000101x]     = 1'b1; // Determine whether the instruction is ROM Select (F=00) or one of two Key Entry instructions (F=10).
                                    else                    next[sRomSel]       = 1'b1;
            state[sRomSel]      :   if (b18)                next[sAddrOut]      = 1'b1; // Instruction is ROM Select so wait here while the ROMs execute the function.
                                    else                    next[sRomSel]        = 1'b1; // Hold here.
            state[s0000101x]    :   if (IS)                 next[sKey]          = 1'b1; // Determine whether the instruction is External Key-Code Entry or Keyboard Entry.
                                    else                    next[sExtKey]       = 1'b1;
            state[sExtKey]      :   if (b18)                next[sAddrOut]      = 1'b1; // Decoded the External Key-Code Entry instruction that's not supported in the HP-35 so just wait.
                                    else                    next[sExtKey]       = 1'b1; // Hold here.
            state[sKey]         :   if (b18)                next[sKeyOut]       = 1'b1; // Decoded the Keyboard Entry instruction.
                                    else                    next[sKey]          = 1'b1; // Hold here.
            state[sKeyOut]      :   begin                                               // Shift the contents of the Key-Code Buffer 56 to the address line, Ia.
                                        TKR = 1'b1;                             
                                        if (b26)            next[sIdle]         = 1'b1;
                                        else                next[sKeyOut]       = 1'b1; // Hold here.
                                    end
            state[s000011x]     :   if (IS)                 next[sDataStore]    = 1'b1; // Determine whether the instruction is Return from Subroutine (F=01) or Data Store (F=11).
                                    else                    next[sRet]          = 1'b1;
            state[sRet]         :   if (b18)                next[sRetOut]       = 1'b1; // Decoded the Subroutine Return instruction.
                                    else                    next[sRet]          = 1'b1; // Hold here.
            state[sRetOut]      :   begin                                               // Shift the contents of the Return Address 60 shift register field to the address line, Ia.
                                        RET = 1'b1;                             
                                        if (b26)            next[sIdle]         = 1'b1;
                                        else                next[sRetOut]       = 1'b1; // Hold here.
                                    end
            state[sDataStore]   :   if (b18)                next[sAddrOut]      = 1'b1; // Decoded a Data Storage instruction that's not part of the C&T chip so just wait. (Not supported in the HP-35.)
                                    else                    next[sDataStore]    = 1'b1; // Hold here.
        endcase
    end
endmodule 
    
