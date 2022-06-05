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
//      state_names.v
//
// Author:
//      Robert J. Weinstein
//      patently.obvious.2021@gmail.com
//      
// Title:
//      HP-35 Project:  State Names for Microprogrammed Controller
//
// Notes:
//      Some passages of US 4,001,569 are quoted verbatim as comments in this
//      module and are indicated like this:
//         '569 (col): "<quoted text>"
//      Where "col" is the column number in the patent document.
// 
// Description:
//      This module provides a common list of state names to be included in the
//      microprogrammed_controller_46.v module within the control_and_timing_16.v
//      module.  This file is also included in several testbenches.
// 
// IncludeFiles : None.
//
// Conventions:
//    - State name parameters are camelCase starting with a lower case 's',
//      e.g., 'sIdle'.
//       
//      Uses Verilog 2001 Features
// 
// Drawings:
//    RJW2025 - HP-35 Control and Timing Circuit 16, Logic, State, and Timing Diagrams
//
// ----------------------------------------------------------------------
// Revision History
// ----------------------------------------------------------------------
//
// 14-Feb-2022 rjw
//    Released as open-source.
//
// ----------------------------------------------------------------------

parameter               // List of parameters to provide a friendly name for each bit position of the one-hot state vector.
        sIdle       = 1,    // Power On (PWO) state, this bit is set, all others reset.  Test for Type 1.
        s0x         = 2,    // Test for Type 2.
        s00x        = 3,    // Test for Type 3 or Type 4.
        s001x       = 4,    // Test for Type 4.
        s000x       = 5,    // Test for Type 5.
        s0000x      = 6,    // Test for Type 6.
        sNop        = 7,    // Instruction failed tests for Types 1 through 6, so it's a No Op.
        sAddrOut    = 8,    // Return point for instructions that use the default ROM Address 58.
        // States for Type 1 Instructions:
        s1x         = 9,    // Decoded a Type 1 instruction so test for JSB or BRH.
        sJsb        = 10,   // Decoded JSB (Jump Subroutine).
        sJsbWait    = 11,   // Wait for completeion of JSB.
        sBrhWait    = 12,   // Decoded BRH (Conditional Branch).
        sBrhOut     = 13,   // Drive the captured branch address out Ia.
        // States for Type 2 Instructions:
        s01x        = 14,   // Decoded a Type 2 (Arithmetic) instruction so parse the first Word Select bit.
        s010x       = 15,   // Parse the second Word Select bit.
        s0100x      = 16,   // Parse the third Word Select bit.
        sArithP     = 17,   // Word Select is 'Pointer Only'.
        sArithWP    = 18,   // Word Select is 'Up to Pointer'.
        sArithWait  = 19,   // Wait for arithmetic instruction to complete in the A&R chip.
        // States for Type 3 Instructions:
        s0010x      = 20,   // Decoded a Type 3 (Status) instruction so parse the next two bits to narrow it down.
        s00100x     = 21,   // Determine whether the instruction is Set Status Flag (F=00) or Reset Status Flag (F=10).
        sSst        = 22,   // Decoded the Set Status Flag instruction.
        sSstDecr    = 23,   // Wait for the selected status bit (status bit N) to arrive at the end of the 28-bit shift register.
        sSstThis    = 24,   // The selected status bit is now at the end of the 28-bit shift register.
        sRst        = 25,   // Decoded the Reset Status Flag instruction.                                               
        sRstDecr    = 26,   // Wait for the selected status bit (status bit N) to arrive at the end of the 28-bit shift register.
        sRstThis    = 27,   // The selected status bit is now at the end of the 28-bit shift register.            
        s00101x     = 28,   // Determine whether the instruction is Interrogate Status Flag (F=01) or Clear All Status Flags (F=11).
        sIst        = 29,   // Decoded the Interrogate Status Flag instruction.                                         
        sIstDecr    = 30,   // Wait for the selected status bit (status bit N) to arrive at the end of the 28-bit shift register.
        sIstThis    = 31,   // The selected status bit is now at the end of the 28-bit shift register.            
        sStDone     = 32,   // Wait for the last status bit position.
        sCst        = 33,   // Decoded the Clear All Status Flags instruction.                                   
        sCstDecr    = 34,   // Wait for the selected status bit (status bit N) to arrive at the end of the 28-bit shift register.
        sCstThis    = 35,   // The selected status bit is now at the end of the 28-bit shift register so begin clearing to the end of the field.            
        // States for Type 4 Instructions:
        s0011x      = 36,   // Decoded a Type 4 (Pointer) instruction so parse the next two bits to narrow it down.
        s00110x     = 37,   // Determine whether the instruction is Set Pointer (F=00) or Interrogate Pointer (F=10).
        sSpt        = 38,   // Decoded the Set Pointer instruction.
        sSptDone    = 39,   // Set Pointer is done so wait until it's time to enter the address output state.
        sIpt        = 40,   // Decoded the Interrogate Pointer instruction.
        sIptSetC    = 41,   // If pointer is equal to this instruction's P field then set carry.
        sIptRstC    = 42,   // If pointer is NOT equal to this instruction's P field then RESET carry.
        s00111x     = 43,   // Determine whether the instruction is Decrement Pointer (F=01) or Increment Pointer (F=11).
        sPtd        = 44,   // Decoded the Decrement Pointer instruction.
        sPtdNow     = 45,   // The four clock periods in which the pointer is decremented.
        sPti        = 46,   // Decoded the Increment Pointer instruction.
        sPtiNow     = 47,   // The four clock periods in which the pointer is incremented.
        // States for Type 5 Instructions:
        s0001x      = 48,   // Decoded a Type 5 (Data Entry/Display) instruction so parse the next two bits to narrow it down.
        s00011x     = 49,   // Determine whether the instruction is LDC (F=01) or other (F=11).
        sLdc        = 50,   // Decoded the LOAD CONSTANT (LDC) instruction.  Generate Word Select at pointer-only then decrement pointer.
        sType5Wait  = 51,   // All Type 5 instructions other than LDC are executed in the the A&R circuit so wait here for completion.
        // States for Type 6 Instructions:
        sType6      = 52,   // Decoded a Type 6 instruction so parse the next two bits to narrow it down.
        s000010x    = 53,   // Determine whether the instruction is ROM Select (F=00) or one of two Key Entry instructions (F=10).
        sRomSel     = 54,   // Instruction is ROM Select so wait here while the ROMs execute the function.
        s0000101x   = 55,   // Determine whether the instruction is External Key-Code Entry or Keyboard Entry.
        sExtKey     = 56,   // Decoded the External Key-Code Entry instruction that's not supported in the HP-35 so just wait.
        sKey        = 57,   // Decoded the Keyboard Entry instruction.
        sKeyOut     = 58,   // Shift the contents of the Key-Code Buffer 56 to the address line, Ia.
        s000011x    = 59,   // Determine whether the instruction is Return from Subroutine (F=01) or Data Store (F=11).
        sRet        = 60,   // Decoded the Subroutine Return instruction.
        sRetOut     = 61,   // Shift the contents of the Return Address 60 shift register field to the address line, Ia.
        sDataStore  = 62;   // Decoded a Data Storage instruction that's not part of the C&T chip so just wait. (Not supported in the HP-35.)
