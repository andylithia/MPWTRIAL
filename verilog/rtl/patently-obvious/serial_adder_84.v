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
//      serial_adder_84.v
//
// Author:
//      Robert J. Weinstein
//      patently.obvious.2021@gmail.com
//      
// Title:
//      HP-35 Project:  Serial Adder
//
// Notes:
//      Some passages of US 4,001,569 are quoted verbatim as comments in this
//      module and are indicated like this:
//         '569 (col): "<quoted text>"
//      Where "col" is the column number in the patent document.
// 
// Description:
//      This module emulates the "Serial Adder 84" block described in patent
//      US 4,001,569 which discloses the HP-45 calculator.  
//
//      '569 (9): "In serial decimal adder/subtractor 84 a correction (addition
//      of 6) to a BCD sum must be made if the sum exceeds nine (a similar 
//      correction for subtraction is necessary).  It is not known if a 
//      correction is needed until the first three bits of the sum have been 
//      generated. This is accomplished by adding a four-bit holding register 
//      86 (A60 - A57) and inserting the corrected sum into a portion 88 (A56 -
//      A53) of register A if a carry is generated."
//
//      This implementation employs subtraction by minuend complementation [1].
// 
//      [1] G. G. Langdon, Jr.,  Subtraction by Minuend Complementation, IEEE
//      Trans. Computers (Short Notes), vol. C-18, pp. 74-76, January 1969
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
//    RJW2039 - HP-35 Arithmetic and Register Circuit 20 - Logic and Timing Diagrams (page 7)
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

module serial_adder_84 #(
    parameter   NewArch = 0     // 1 = Use new architecture, 0 = Like the patent.
)
(
    // Output Ports
    output      SUM1,           // Serial sum or difference.  Sum = X_IN + Y_IN + previous carry.  Difference = X_IN - Y_IN - previous borrow.
    output      SUM2,           // Corrected sum (SUM1 + 6).
    output reg  USE_SUM2,       // Asserted during T4 if the corrected sum should be used.
    output reg  CARRY,          // ('569 item 34) Carry out when adding, borrow out when subtracting (active high in both cases). Valid during T4 of each digit time.  Sent to the Control & Timing block.
    // Input Ports                  
    input       X_IN,           // Bit-serial augend when adding.  Bit-serial minuend when subtracting.
    input       Y_IN,           // Bit-serial addend when adding.  Bit-serial subtrahend when subtracting.
    input       C_IN,           // Carry/borrow input (active high in both cases) from previous word cycle.
    input       FIRST_BIT,      // Indicates the first bit period of the word cycle.  When asserted, C_IN is included in sum.
    input       SUB,            // Add/Subtract control input.  0 = add, 1 = subtract.
    input       T1,             // One-hot T-state counter indicating the active bit in the current digit.  T1 = LSbit, T4 = MSbit.
    input       T2,             //  "
    input       T3,             //  "
    input       T4,             //  "
    input       PHI2            // Bit-Rate Clock Input, Phase 2.
);

    wire    sum1_int;
    wire    sum2_int;
    wire    co1;
    wire    co2;
        
    reg     ci1 = 1'b0;
//  reg     ci2;
    reg     y_in2 = 1'b0;
    reg     co1_r = 1'b0;
    reg     co2_r = 1'b0;
    
// --------------------------------------------------------------------------------------------
// RTL Begins Here:

    assign SUM1 = sum1_int ^ SUB;
    assign SUM2 = sum2_int ^ SUB;

    // Generate the carry-in for the first adder.
    always @* begin : proc_carry_in1
        if (FIRST_BIT) 
            ci1 <= C_IN;
        else
            ci1 <= co1_r | co2_r & T1 & ~SUB;
    end
    
    // Sequence to add 6 for decimal correction.
    always @* begin : proc_y_in2
        case (1'b1)
            T1 : y_in2 <= 0;
            T2 : y_in2 <= 1;
            T3 : y_in2 <= 1;
            T4 : y_in2 <= 0;
            default : y_in2 <= 0;
        endcase
    end
    
    // Hold each adder's previous carry-out.
    always @(posedge PHI2) begin : proc_carry_flops
        co1_r <= co1;
        co2_r <= co2;
    end

    // Generate the following outputs:
    //   - Signal that selects the output of adder2.
    //   - Carry-out at the completion of each digit.
    // Note that these are identical when using the 
    // minuend complementation approach (Langdon 1969).
    always @* begin : proc_carry
        if (SUB) begin
            USE_SUM2 <= T4 & co1;
            CARRY    <= T4 & co1;
        end
        else begin
            USE_SUM2 <= T4 & (co1 | co2);
            CARRY    <= T4 & (co1 | co2);
        end
    end

    // Instance of the first adder.
    full_add inst_adder1 (
        // Output Ports
        .sum        (sum1_int),     // output reg   // Sum      
        .co         (co1),          // output reg   // Carry out
        // Input Ports                          
        .x          (X_IN ^ SUB),   // input        // Augend   
        .y          (Y_IN),         // input        // Addend   
        .ci         (ci1)           // input        // Carry In
    );

    // Instance of the decimal correction adder.
    full_add inst_adder2 (
        // Output Ports
        .sum        (sum2_int),     // output reg   // Sum      
        .co         (co2),          // output reg   // Carry out
        // Input Ports                          
        .x          (sum1_int),     // input        // Augend   
        .y          (y_in2),        // input        // Addend   
        .ci         (co2_r & ~T1)   // input        // Carry In
    );

endmodule 

