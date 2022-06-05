//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: Copyright (c) 2022 Robert J. Weinstein
// 
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
//------------------------------------------------------------------------------
//
// FileName:
//      instruction_decoder_92.v
//
// Author:
//      Robert J. Weinstein
//      patently.obvious.2021@gmail.com
//      
// Title:
//      HP-35 Project:  Instruction Decoder for Arithmetic & Register Circuit
//
// Notes:
//      Some passages of US 4,001,569 are quoted verbatim as comments in this
//      module and are indicated like this:
//         '569 (col): "<quoted text>"
//      Where "col" is the column number in the patent document.
// 
// Description:
//      This module emulates the "Instruction Decoder 92" block described in
//      patent US 4,001,569 which discloses the HP-45 calculator.  
// 
//      The '569 patent provides very few implementation details of Instruction
//      Decoder 92.  However, its essential functionality is described as
//      follows:
//      
//          --------------------------------------------------------------------
//          '569 (10): "Arithmetic and register circuit 20 receives the instruc-
//          tion during bit times b45-b54.  Of the ten types of instructions
//          hereinafter described, arithmetic and register circuit must respond
//          to only two types (namely, ARITHMETIC & REGISTER instructions and
//          DATA ENTRY/DISPLAY instructions). ARITHMETIC & REGISTER instructions
//          are coded by a 10 in the least significant two bits of Is register
//          90.  When this combination is detected, the most significant five
//          bits are saved in Is register 90 and decoded by instruction decoder
//          92 into one of 32 instructions.
//             The ARITHMETIC & REGISTER instructions are active or operative
//          only when the Word Select signal (WS) generated in one of the ROM�s
//          0-7 or in control and timing circuit 16 is at logic 1. For instance,
//          suppose the instruction "A+C -> C, mantissa with sign only" is
//          called. Arithmetic and register circuit 20 decodes only A+C -> C. It
//          sets up registers A and C at the inputs to adder 84 and, when WS is
//          high, directs the adder output to register C. Actual addition takes
//          place only during bit times b12 to b55 (digits 3-13) since for the
//          first three digit times the exponent and exponent sign are circulat-
//          ing and are directed unchanged back to their original registers.
//          Thus, the word select signal is an "instruction enable" in arithme-
//          tic and register circuit 20 (when it is at logic 1, instruction exe-
//          cution takes place, and when it is at logic 0, recirculation of all
//          registers continues).
//             The DATA ENTRY/DISPLAY instructions, except for digit entry,
//          affect an entire register (the word select signal generated in the
//          active ROM is at logic 1 for the entire word cycle). Some of these
//          instructions are: up stack, down stack, memory exchange M<->C, and
//          display on or toggle. A detailed description of their execution is
//          given hereinafter."
//          --------------------------------------------------------------------
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
//    RJW2039 - HP-35 Arithmetic and Register Circuit 20 - Logic and Timing Diagrams (pages 14 & 15)
//
// -----------------------------------------------------------------------------
// Revision History
// -----------------------------------------------------------------------------
//
// 14-Feb-2022 rjw
//    Released as open-source.
// 05-Jun-2022 AL
//    Modified for SPDX
//
//
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module instruction_decoder_92 (
    // ---------------------------------------------------------------------
    // BCD adder/subtractor controls.
    output reg          sub,        // Add/Subtract control input.  0 = add, 1 = subtract. 
    output reg          c_in,       // Carry/borrow input (active high in both cases) from previous word cycle.
    output reg          a2x,        // Steers register A to adder/subtractor's X_IN input.
    output reg          c2x,        //   "       "     C "    "        "       X_IN   "
    output reg          b2y,        //   "       "     B "    "        "       Y_IN   "
    output reg          c2y,        //   "       "     C "    "        "       Y_IN   "
    // ---------------------------------------------------------------------
    // Multiplexer controls for register A
    // -- these signals steer one of eight sources into register A's bit [56] input:
    output reg          a2a,        // (1) LSB of Register A (recirculate)
    output reg          is2a,       // (2) Serial instruction bus, IS
    output reg          b2a,        // (3) LSB of Register B (transfer)
    output reg          c2a,        // (4) LSB of Register D (transfer)
    output reg          d2a,        // (5) LSB of Register D (transfer)
    output reg          res2a,      // (6 or 7) Result from adder/subtractor.  If no carry then use sum1 (6), else use sum2 (7) and also transfer holding register contents into A[55:53]
    output reg          hld2a,      // (8) LSB of 4-bit holding register 86
    // -- this selects the source of register A's bit [52] input:
    output reg          sra,        // 1 = Recirculate LSB of Register A to bit [52] for right shift; 0 = normal circulation.
    // -- these signals steer one of two sources into the MSB of 4-bit holding register 86:
    output reg          a2hld,      // (1) LSB of Register A (for left shift instruction).
    output reg          s22hld,     // (2) sum2 (BCD adder/subtractor's corrected sum).
    // ---------------------------------------------------------------------
    // Multiplexer controls for register B
    // -- these signals steer one of three sources into register B's bit [56] input:
    output reg          b2b,        // (1) LSB of Register B (recirculate)
    output reg          a2b,        // (2) LSB of Register A (transfer)
    output reg          c2b,        // (3) LSB of Register C (transfer)
    // -- this selects the source of register B's bit [52] input:
    output reg          srb,        // 1 = Recirculate LSB of Register B to bit [52] for right shift; 0 = normal circulation.
    // ---------------------------------------------------------------------
    // Multiplexer controls for register C
    // -- these signals steer one of nine sources into register C's bit [56] input:
    output reg          c2c,        // (1) LSB of Register C (recirculate)
    output reg          con2c,      // (2) 4-bit constant from instruction register (LOAD CONSTANT instruction)
    output reg          bcd2c,      // (3) Input from data storage circuit (BCD)
    output reg          a2c,        // (4) LSB of Register A (transfer)
    output reg          b2c,        // (5) LSB of Register B (transfer)
    output reg          d2c,        // (6) LSB of Register D (transfer)
    output reg          m2c,        // (7) LSB of Register M (transfer)
    output reg          res2c,      // (8 or 9) Result from adder/subtractor.  If no carry then use sum1 (8), else use sum2 (9) and also transfer holding register contents into C[55:53]
    // -- this selects the source of register C's bit [52] input:
    output reg          src,        // 1 = Recirculate LSB of Register C to bit [52] for right shift; 0 = normal circulation.
    // ---------------------------------------------------------------------
    // Multiplexer controls for register D
    // -- these signals steer one of three sources into register D's bit [56] input:
    output reg          d2d,        // (1) LSB of Register D (recirculate)
    output reg          c2d,        // (2) LSB of Register C (transfer)
    output reg          e2d,        // (3) LSB of Register D (transfer)
    // ---------------------------------------------------------------------
    // Multiplexer controls for register E
    // -- these signals steer one of three sources into register E's bit [56] input:
    output reg          e2e,        // (1) LSB of Register E (recirculate)
    output reg          d2e,        // (2) LSB of Register D (transfer)   
    output reg          f2e,        // (3) LSB of Register F (transfer)   
    // ---------------------------------------------------------------------
    // Multiplexer controls for register F
    // -- these signals steer one of three sources into register F's bit [56] input:
    output reg          f2f,        // (1) LSB of Register F (recirculate)
    output reg          c2f,        // (2) LSB of Register C (transfer)   
    output reg          e2f,        // (3) LSB of Register E (transfer)   
    // ---------------------------------------------------------------------
    // Multiplexer controls for register M
    // -- these signals steer one of two sources into register M's bit [56] input:
    output reg          m2m,        // (1) LSB of Register M (recirculate)
    output reg          c2m,        // (2) LSB of Register C (transfer)   
    // ---------------------------------------------------------------------
    // Display toggle, display off        
    output reg          dspt,       // Toggle the display flip-flop
    output reg          dspn,       // Turn off the display flip-flop
    // ---------------------------------------------------------------------
    // Input Ports                  
    input wire [9:4]    isreg,      // ('569 item 90) IS Register.
    input wire          istype2,    // Instruction is Type 2.
    input wire          istype5,    // Instruction is Type 5.
    input wire          WS,         // ('569 item 30) ROM Word Select
    input wire          ws1,        // Asserted during the first bit period, T1, of WS.
    input wire          ds1,        // Asserted during the first digit period of WS.
    input wire          dsn1        // Asserted during all digit periods of WS other than the first.
);

    // I'll use three underscores to represent a single bit zero because it's
    // easier to see the contrast between ones and zeros in the tables that follow.
    `define ___   1'b0
    //
    // Experiment to replace '___' with 'nil' to see if that has an effect on synthesis.
    `define nil   1'b0

//    string  debug_string;
// -----------------------------------------------------------------------------
// RTL Begins Here:

    // --------------------------------------------------------------------------------------------
    // Instruction Decoder Process
    // 
    always@* begin : proc_instr_dec
        // Insert default outputs here...
        {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};                            // Could be don't cares.
        {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
        {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
        {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
        {d2d, c2d, e2d}                                              = {1'b1, `nil, `nil};                                              // D -> D
        {e2e, d2e, f2e}                                              = {1'b1, `nil, `nil};                                              // E -> E
        {f2f, c2f, e2f}                                              = {1'b1, `nil, `nil};                                              // F -> F
        {m2m, c2m}                                                   = {1'b1, `nil};                                                    // M -> M
        dspt = 1'b0;    // Display toggle
        dspn = 1'b0;    // Display off
        //debug_string = "default value";

        if (istype2) begin
            // Type 2 Instructions -----------------------------------------------------------------------------------------------------------------------------
            // '569 (18):  "Arithmetic and register (Type 2) instructions apply to the arithmetic and register circuit 20 only.  There are 32 arithmetic and
            // register instructions divided into eight classes encoded by the left-hand five bits of the instruction.  Each of these instructions can be
            // combined with any of eight word select signals to give a total capability of 256 instructions."
            // 
            // '569 (19):  "The eight classes of arithmetic and register instructions are:
            //           1. Clear (3);
            //           2. Transfer/Exchange (6);
            //           3. Add/Subtract (7);
            //           4. Compare (6);
            //           5. Complement (2);
            //           6. Increment (2);
            //           7. Decrement (2); and
            //           8. Shift (4)."
            case (isreg[9:5])
                // Class 1) Clear ------------------------------------------------------------------------------------------------------------------------------
                // '569 (19):  "There are three clear instructions.  These instructions are 0 -> A, 0 -> B, and 0 -> C.  They are implemented by simply
                // disabling all the gates entering the designated register.  Since these instructions can be combined with any of the eight word select
                // options, it is possible to clear a portion of a register or a single digit."
                5'b10111 : begin    // Clear A
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};    // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                end
                5'b00001 : begin    // Clear B
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};    // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                    {b2b, a2b, c2b, srb}                                         = { ~WS, `nil, `nil, `nil};
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                end
                5'b00110 : begin    // Clear C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};    // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                end
                // Class 2) Trasfer/Exchange -------------------------------------------------------------------------------------------------------------------
                // '569 (19):  "There are six transfer/exchange instructions. These instructions are A -> B, B -> C, C -> A, A<~> B, B <-> C, and C <-> A.  This
                // variety permits data in registers A, B, and C to be manipulated in many ways.  Again, the power of the instruction must be viewed in
                // conjunction with the word select option.  Single digits can be exchanged or transferred."
                5'b01001 : begin    // Transfer A -> B
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};    // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                    {b2b, a2b, c2b, srb}                                         = { ~WS,   WS, `nil, `nil};
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                end
                5'b00100 : begin    // Transfer B -> C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};    // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil,   WS, `nil, `nil, `nil, `nil};
                end
                5'b01100 : begin    // Transfer C -> A
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};    // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil,  WS, `nil, `nil, `nil, `nil, `nil, `nil};
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                end
                5'b11001 : begin    // Exchange A <-> B
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};    // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil,  WS, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                    {b2b, a2b, c2b, srb}                                         = { ~WS,   WS, `nil, `nil};
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                end
                5'b10001 : begin    // Exchange B <-> C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};    // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};
                    {b2b, a2b, c2b, srb}                                         = { ~WS, `nil,   WS, `nil};
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil,   WS, `nil, `nil, `nil, `nil};
                end
                5'b11101 : begin    // Exchange A <-> C
                    //debug_string = "Exchange A <-> C";
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};    // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil,   WS, `nil, `nil, `nil, `nil, `nil, `nil};
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil,   WS, `nil, `nil, `nil, `nil, `nil};
                end
                // Class 3) Add/Subtract -----------------------------------------------------------------------------------------------------------------------
                // '569 (19):  "There are seven add/subtract instructions which use the adder circuitry 84.  They are A+/-C -> C, A+/-B -> A, A+/-C -> A, and
                // C+C -> C.  The last instruction can be used to divide by five.  This is accomplished by first adding the number to itself via C+C -> C,
                // multiplying by two, then shifting right one digit, and dividing by 10.  The result is a divide by five.  This is used in the square root
                // routine."
                5'b01110 : begin    // A + C -> C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil,   WS, `nil, `nil,   WS};                            // A + C
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil,   WS, `nil};          // result -> C
                end
                5'b01010 : begin    // A - C -> C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, `nil,   WS, `nil, `nil,   WS};                            // A - C
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil,   WS, `nil};          // result -> C     
                end
                5'b11100 : begin    // A + B -> A
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil,   WS, `nil,   WS, `nil};                            // A + B
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil, `nil, `nil,   WS, `nil, `nil, `nil, 1'b1};    // result -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b11000 : begin    // A - B -> A
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, `nil,   WS, `nil,   WS, `nil};                            // A - B
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil, `nil, `nil,   WS, `nil, `nil, `nil, 1'b1};    // result -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b11110 : begin    // A + C -> A
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil,   WS, `nil, `nil,   WS};                            // A + C
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil, `nil, `nil,   WS, `nil, `nil, `nil, 1'b1};    // result -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b11010 : begin    // A - C -> A
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, `nil,   WS, `nil, `nil,   WS};                            // A - C
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil, `nil, `nil,   WS, `nil, `nil, `nil, 1'b1};    // result -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b10101 : begin    // C + C -> C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil,   WS, `nil,   WS};                            // C + C
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil,   WS, `nil};          // result -> C
                end
                // Class 4) Compare ----------------------------------------------------------------------------------------------------------------------------
                // '569 (19):  "There are six compare instructions.  These instructions are always followed by a conditional branch.  They are used to check the
                // value of a register or a single digit in a register and still not modify or transfer the contents.  These instructions may easily be found in
                // the type two instruction table above since there is no transfer arrow present.  They are:
                //      1. 0-B (Compare B to zero);     [if 0 >= B, then there will be no carry, so branch (same as 'if 0 = B then branch')]
                //      2. A-C (Compare A and C);       [if A >= C, then there will be no carry, so branch]
                //      3. C-1 (Compare C to one);      [if C >= 1, then there will be no carry, so branch]
                //      4. 0-C (Compare C to zero);     [if 0 >= C, then there will be no carry, so branch (same as 'if 0 = C then branch')]
                //      5. A-B (Compare A and B); and   [if A >= B, then there will be no carry, so branch]
                //      6. A-1 (Compare A to one).      [if A >= 1, then there will be no carry, so branch]
                // 
                // If, for examp1e, it is desired to branch if B is zero (or any digit or group of digits is zero as determined by WS), the 0-B instruction is
                // followed by a conditional branch.  If B was zero, no carry (or borrow) would be generated and the branch would occur.  The instruction can be
                // read:  IF U >= V THEN BRANCH.  Again it is easy to compare single digits or a portion of a register by appropriate word select options."
                5'b00000 : begin    // 0 - B
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, `nil, `nil, `nil,   WS, `nil};                            // 0 - B
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b01101 : begin    // 0 - C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, `nil, `nil, `nil, `nil,   WS};                            // 0 - C
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b00010 : begin    // A - C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, `nil,   WS, `nil, `nil,   WS};                            // A - C
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b10000 : begin    // A - B
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, `nil,   WS, `nil,   WS, `nil};                            // A - B
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b10011 : begin    // A - 1
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, 1'b1,   WS, `nil, `nil, `nil};                            // A - 1
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b00011 : begin    // C - 1
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, 1'b1, `nil,   WS, `nil, `nil};                            // C - 1
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                // Class 5) Complement -------------------------------------------------------------------------------------------------------------------------
                // '569 (20):  "There are two complement instructions.  The number representation system in the calculator is sign and magnitude notation for
                // the mantissa, and tens complement notation in the exponent field.  Before numbers can be substracted, the subtrahend must be tens-
                // complemented (i.e., 0-C -> C).  Other algorithms require the nines complement (i.e., 0-C-1 -> C)."
                5'b00101 : begin    // 0 - C -> C  (Tens Complement)
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, `nil, `nil, `nil, `nil,   WS};                            // 0 - C
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil,   WS, `nil};          // result -> C
                end
                5'b00111 : begin    // 0 - C - 1 -> C  (Nines Complement)
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, 1'b1, `nil, `nil, `nil,   WS};                            // 0 - C - 1
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil,   WS, `nil};          // result -> C
                end
                // Class 6) Increment --------------------------------------------------------------------------------------------------------------------------
                // '569 (20):  "There are four increment/decrement instructions (two of each).  They are A+/1 -> A and C+/-1 -> C."
                5'b11111 : begin    // A + 1 -> A
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, 1'b1,   WS, `nil, `nil, `nil};                            // A + 1
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil, `nil, `nil,   WS, `nil, `nil, `nil, 1'b1};    // result -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b01111 : begin    // C + 1 -> C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, 1'b1, `nil,   WS, `nil, `nil};                            // C + 1
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil,   WS, `nil};          // result -> C
                end
                // Class 7) Decrement --------------------------------------------------------------------------------------------------------------------------
                // '569 (20):  "There are four increment/decrement instructions (two of each).  They are A+/1 -> A and C+/-1 -> C."
                5'b11011 : begin    // A - 1 -> A
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, 1'b1,   WS, `nil, `nil, `nil};                            // A - 1
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil, `nil, `nil,   WS, `nil, `nil, `nil, 1'b1};    // result -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b01011 : begin    // C - 1 -> C
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {1'b1, 1'b1, `nil,   WS, `nil, `nil};                            // C - 1
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil,   WS, `nil};          // result -> C
                end
                // Class 8) Shift ------------------------------------------------------------------------------------------------------------------------------
                // '569 (20):  "There are four shift instructions.  All three registers A, B, and C can be shifted right, while only A has a shift left
                // capability."
                5'b10110 : begin    // A >> 1 (Shift Right)
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};                            // no-op
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil, dsn1, `nil, `nil};    // When WS: 0 -> A[56]; When dsn1: A[1] -> A[52]; else normal recirculation.
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b10100 : begin    // B >> 1 (Shift Right)
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};                            // no-op
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = { ~WS, `nil, `nil, dsn1};                                        // When WS: 0 -> B[56]; When dsn1: B[1] -> B[52]; else normal recirculation.
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                5'b10010 : begin    // C >> 1 (Shift Right)
                    //debug_string = "C >> 1 (Shift Right)";
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};                            // no-op
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = { ~WS, `nil, `nil, `nil, `nil, `nil, `nil, `nil, dsn1};          // When WS: 0 -> C[56]; When WS & dsn1: C[1] -> C[52]; else normal recirculation.
                end
                5'b01000 : begin    // A << 1 (Shift Left)
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};                            // no-op
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = { ~WS, `nil, `nil, `nil, `nil, `nil, dsn1, `nil,   WS, `nil};    // When ds1: A[1] -> A[60] also 0 -> A[56]; When dsn1: A[1] -> A[60] also A[57] -> A[56]; else normal recirculation.
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
                default : begin
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};                            // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                end
            endcase
        end
        else if (istype5) begin
            // Type 5 Instructions -----------------------------------------------------------------------------------------------------------------------------
            // '569 (22):  "The data entry and display (type 5) instructions are used to enter data into arithmetic and register circuit 20, manipulate the
            // stack and memory registers, and blank the display (16 instructions in this set are not recognized by any of the existing circuits, and are
            // therefore available for other external circuits that might be employed with other embodiments of the calculator)."
            casez (isreg[9:4])
                // 16 Available Instructions -------------------------------------------------------------------------------------------------------------------
                // '569 (23):  "The first set of 16 instructions (I5,I4 = 00) in this table are not used by any of the main MOS circuits.  They may be used by
                // additional circuits or external circuitry listening to the Is line such as may be employed with other embodiments of the calculator."
//              6'b????_00 : begin    // Not Defined.  
//              end
                // Load Constant or Digit Entry ----------------------------------------------------------------------------------------------------------------
                // '569 (23):  "The four bits in I9-I6 will be inserted into the C register at the location of the pointer, and the pointer will be decremented.
                // This allows a constant, such as pi, to be stored in ROM and transfered to arithmetic and register circuit 20.  To transfer a ten digit
                // constant requires only ll instructions (one to preset the pointer).  Several exclusions exist in the use of this instruction.  When used with
                // the pointer in position 13, it cannot be followed by an arithmetic and register instruction (i.e., by Type 2 or 5 instructions as there are
                // problems in common use of the five-bit Is buffer 91 in arithmetic and register circuit 20).  With P=12, LDC can be followed by another LDC
                // but not by any other type 2 or 5 instruction.  When used with the pointer in position 14, the instruction has no effect.  However, when P=12
                // and LDC is followed by a type 2 or 5 instruction, position 13 in register C is modified.  Loading non-digit codes (1010-1111) is not allowed
                // since they will be modified passing through the adder."
                6'b????_01 : begin   // LOAD CONSTANT (LDC) N -> C @ Pointer (post decrement Pointer)
                    //debug_string = "LOAD CONSTANT (LDC)";
                    {c2c, con2c} = {~WS, WS};   // isreg[9:6] -> C
                end
                // Display -------------------------------------------------------------------------------------------------------------------------------------
                // '569 (23):  "The display flip-flop in arithmetic and register circuit 20 controls blanking of all the LED�s.  When it is reset, the 1111 code
                // is set into the display buffer 96, which is decoded so that no segments are on.  There is one instruction to reset this flip-flop I9 I8 I7 =
                // (100) and another to toggle it (000).  The toggle feature is convenient for blinking the display."
                6'b000_01? : begin  // Display Toggle
                    //debug_string = "Display Toggle";
                    dspt = 1'b1;
                end
                6'b100_01? : begin  // Display Off
                    //debug_string = "Display Off";
                    dspn = 1'b1;
                end
                // Memory --------------------------------------------------------------------------------------------------------------------------------------
                // '569 (24):  "The remaining instructions in the type 5 instruction decoding table include two affecting memory (Exchange C <-> M and
                // Recall M -> C), ..."
                6'b001_01? : begin  // Exchange Memory, C -> M -> C
                    //debug_string = "Exchange Memory, C -> M -> C";
                    {m2m, c2m} = {`nil, 1'b1};     // C -> M (Transfer whole word)
                    {c2c, m2c} = {`nil, 1'b1};     // M -> C (Transfer whole word)
                end
                6'b101_01? : begin  // Recall Memory, M -> M -> C
                    //debug_string = "Recall Memory, M -> M -> C";
                    {m2m, c2m} = {1'b1, `nil};     // M -> M (Recirculate whole word)
                    {c2c, m2c} = {`nil, 1'b1};     // M -> C (Transfer whole word)
                end
                // Stack ---------------------------------------------------------------------------------------------------------------------------------------
                // '569 (24):  "The remaining instructions in the type 5 instruction decoding table include ..., three affecting the stack (Up, Down, and Rotate
                // Down ..."
                6'b010_01? : begin  // Up Stack (Push C), C -> C -> D -> E -> F
                    //debug_string = "Up Stack (Push C), C -> C -> D -> E -> F";
                    c2c = 1'b1;                 // C -> C (Recirculate whole word)
                    {d2d, c2d} = {`nil, 1'b1};  // C -> D (Transfer whole word)
                    {e2e, d2e} = {`nil, 1'b1};  // D -> E (Transfer whole word)
                    {f2f, e2f} = {`nil, 1'b1};  // E -> F (Transfer whole word)
                end
                6'b011_01? : begin  // Down Stack (Pop A), F -> F -> E -> D -> A
                    //debug_string = "Down Stack (Pop A), F -> F -> E -> D -> A";
                    f2f = 1'b1;                 // F -> F (Recirculate whole word)
                    {e2e, f2e} = {`nil, 1'b1};  // F -> E (Transfer whole word)
                    {d2d, e2d} = {`nil, 1'b1};  // E -> D (Transfer whole word)
                    {a2a, d2a} = {`nil, 1'b1};  // D -> A (Transfer whole word)
                end
                6'b110_01? : begin  // Rotate Down, C -> F -> E -> D -> C
                    //debug_string = "Rotate Down, C -> F -> E -> D -> C";
                    {f2f, c2f} = {`nil, 1'b1};  // C -> F (Transfer whole word)
                    {e2e, f2e} = {`nil, 1'b1};  // F -> E (Transfer whole word)
                    {d2d, e2d} = {`nil, 1'b1};  // E -> D (Transfer whole word)
                    {c2c, d2c} = {`nil, 1'b1};  // D -> C (Transfer whole word)
                end
                // General Clear -------------------------------------------------------------------------------------------------------------------------------
                // '569 (24):  "The remaining instructions in the type 5 instruction decoding table include ..., one general clear, ..."
                6'b111_01? : begin  // Clear All Registers, 0 -> A, B, C, D, E, F, M
                    //debug_string = "Clear All Registers, 0 -> A, B, C, D, E, F, M";
                    a2a = `nil;     // 0 -> A (Clear whole word)
                    b2b = `nil;     // 0 -> B (  "     "    "  )
                    c2c = `nil;     // 0 -> C (  "     "    "  )
                    d2d = `nil;     // 0 -> D (  "     "    "  )
                    e2e = `nil;     // 0 -> E (  "     "    "  )
                    f2f = `nil;     // 0 -> F (  "     "    "  )
                    m2m = `nil;     // 0 -> M (  "     "    "  )
                end
                // Load Register A from Is ---------------------------------------------------------------------------------------------------------------------
                // '569 (24):  "The Is -> A instruction is designed to allow a key code to be transmitted from a program storage circuit to arithmetic and register
                // circuit 20 for display.  The entire 56 bits are loaded although only two digits of informaton are of interest."
                6'b??_011_? : begin    // Is -> A Register (56 bits)
                    //debug_string = "Is -> A Register (56 bits)";
                    {a2a, is2a} = {`nil, 1'b1}; // Is -> A (Transfer whole word)
                end
                // Load Register C from BCD --------------------------------------------------------------------------------------------------------------------
                // '569 (24):  "The BCD -> C instruction allows data input to arithmetic and register circuit 20 from a data storage circuit or other external
                // source  such as might be employed with other embodiments of the calculator."
                6'b??_111_? : begin    // BCD -> C Register (56 bits)
                    //debug_string = "BCD -> C Register (56 bits)";
                    {c2c, bcd2c} = {`nil, 1'b1};    // BCD -> C (Transfer whole word)
                end
                default : begin
                    {sub, c_in, a2x, c2x, b2y, c2y}                              = {`nil, `nil, `nil, `nil, `nil, `nil};                            // Could be don't cares.
                    {a2a, is2a, b2a, c2a, d2a, res2a, hld2a, sra, a2hld, s22hld} = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};    // A -> A
                    {b2b, a2b, c2b, srb}                                         = {1'b1, `nil, `nil, `nil};                                        // B -> B
                    {c2c, con2c, bcd2c, a2c, b2c, d2c, m2c, res2c, src}          = {1'b1, `nil, `nil, `nil, `nil, `nil, `nil, `nil, `nil};          // C -> C
                    {d2d, c2d, e2d}                                              = {1'b1, `nil, `nil};                                              // D -> D
                    {e2e, d2e, f2e}                                              = {1'b1, `nil, `nil};                                              // E -> E
                    {f2f, c2f, e2f}                                              = {1'b1, `nil, `nil};                                              // F -> F
                    {m2m, c2m}                                                   = {1'b1, `nil};                                                    // M -> M
                    dspt = 1'b0;    // Display toggle
                    dspn = 1'b0;    // Display off
                end
            endcase
        end
    end
    // --------------------------------------------------------------------------------------------


endmodule 

