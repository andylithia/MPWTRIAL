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
//      full_add.v
//
// Author:
//      Robert J. Weinstein
//      patently.obvious.2021@gmail.com
//      
// Title:
//      HP-35 Project:  Full Adder
//
// Description:
//      This module is a standard binary full adder circuit that is used in
//      the following blocks:
//        - Serial Adder/Subtractor 64 within the Control and Timing circuit 16 
//        - Serial Adder 84 within the Arithmetic and Register circuit 20
//
// IncludeFiles : None
//
// Conventions:
//      Port names are 'lower' case.
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

module full_add(
    output  reg sum = 1'b0, // Sum
    output  reg co  = 1'b0, // Carry out
    input       x,          // Augend
    input       y,          // Addend
    input       ci          // Carry In
);

    always @* begin : proc_fa
        sum <= x ^ y ^ ci;
        co  <= x & y | x & ci | y & ci;
    end

endmodule 

