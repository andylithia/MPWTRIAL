// hp 35 wrapper
// The Display chips are excluded
// Compared to the original source code written by R. J. Weinstein, 
// the only major change is that the inout ports are replaced by MUX counterparts
module hp35_core(
    output [7:0] ROW,       // Keyboard Scan ROW,     Output from CTC
    input  [4:0] COL,       // Keyboard Scan COL,     Input to CTC
    input        PHI1,      // Global Clock Signal,   Input from External
    input        PHI2,      // Global Clock Signal,   Input from External
    input        PWO,       // CTC PWO Reset Control, Input from External
    output [4:0] DD,        // Display Bus,           Output from ARC
    output       START,     // Display Start Control, Output from ARC
    
    input        is_in,     // Instruction Bus,       Input to CTC
    output       is_bus,    // Instruction Bus,       Output from Internal ROM
    output       is_oe,     // Instruction Bus,       Output Control from Internal ROM
    
    input        ws_in,     // Word Select Bus,  from CTC or ROM to ARC
    output       ws_bus,    // Word Select Bus,  from 
    output       ws_oe,     //
    
    input        bcd_in,    // BCD Peripheral Bus, from RAM to ARC
    output       bcd_bus,   // BCD Peripheral Bus, from ARC to RAM
    output       bcd_oe,    // BCD Bus Enable,     from ARC to RAM
    
    input        ia_in,     // Address Bus,           Only useful when the CTC is disabled
    output       ia_bus,    // Address Bus,           Output from CTC
    output       carry_bus, // Carry,       from ARC to CTC
    input        carry_in,  // Carry input, used when the ARC is disabled
    output       sync_bus,  // Global SYNC, from CTC to all
    input        sync_in,   // Global SYNC input, used when the CTC is disable

    // When any of the following signals is not asserted,
    // The correosponding bus connection will be disabled, 
    // For the non-tristate design, it means that the MUX bus is now owned by the IO port
    input        dbg_enable_arc,
    input        dbg_enable_ctc,
    input        dbg_enable_rom,
    input        dbg_arc_dummy,
    output [4:0] dbg_dsbf,          // The internal display buffer
    output       dbg_arc_t1,        // T-State
    output       dbg_arc_t4,        // /
    output       dbg_arc_a1,        // Register A
    output       dbg_arc_b1,        // Register B
    output [2:0] dbg_rom_roe,       // 
    output       dbg_ctc_state1,    // 
    output       dbg_ctc_kdn        // Any Keydown?
);

// Controls
reg  carry_bus;
reg  sync_bus;
wire sync_drive_ctc;
wire carry_drive_arc;

// Peripheral Bus
wire       bcd_internal_active;
wire       bcd_internal_drive;
reg        bcd_bus;
reg        bcd_oe;

// Address Bus
reg        ia_bus;  // Always driven by CTC, Loaded by the ROMs
wire       ia_internal_drive;

// Instruction Bus
wire [2:0] is_internal_active;  // Driven by ROM, Loaded by ARC / CTC
wire [2:0] is_internal_drive;   // Driven by ROM, Loaded by ARC / CTC
reg        is_bus;
reg        is_oe;

// Word Select Bus
wire [2:0] ws_internal_active;      // Driven by the ROMs, Loaded by ARC
wire [2:0] ws_internal_drive;       // Driven by the ROMs, Loaded by ARC
wire       ws_internal_active_ctc;  // Driven by CTC, Loaded by ARC
wire       ws_internal_drive_ctc;   // Driven by CTC, Loaded by ARC
reg        ws_bus;
reg        ws_oe;

// Debug Connectors (To be connected to the Caravel LA interface)
wire       dbg_enable_ctc;
wire       dbg_enable_arc;
wire       dbg_enable_rom;
wire [2:0] dbg_rom_roe;
wire       dbg_ctc_state1;
wire [4:0] dbg_dsbf;
wire       dbg_arc_t1;
wire       dbg_arc_t4;
wire       dbg_arc_a1;
wire       dbg_arc_b1;
wire       dbg_arc_dummy;
wire       dbg_ctc_kdn;


// ** A R C
arithmetic_and_register_20_a u_ARC(
    .A(DD[0]),.B(DD[1]),.C(DD[2]),.D(DD[3]),.E(DD[4]),  // Display Bus
    .START      (START              ),  // Display Control
    .CARRY      (carry_drive_arc    ),  // From ARC to CTC                  
    .dbg_dsbf3  (dbg_dsbf[3]        ),  // Internal Display Buffer 
    .dbg_dsbf2  (dbg_dsbf[2]        ),  // |
    .dbg_dsbf1  (dbg_dsbf[1]        ),  // |
    .dbg_dsbf0  (dbg_dsbf[0]        ),  // |
    .dbg_dsbf_dp(dbg_dsbf[4]        ),  // /
    .dbg_t1     (dbg_arc_t1         ),  // Timing Register
    .dbg_t4     (dbg_arc_t4         ),  // Timing Register
    .dbg_regA1  (dbg_arc_a1         ),  // Register A
    .dbg_regB1  (dbg_arc_b1         ),  // Register B
    .PHI2       (PHI2               ),  // Global Clock
    .IS         (is_bus             ),  // From CTC/ROM to ARC
    .WS         (ws_bus             ),  // From CTC/ROM to ARC
    .SYNC       (sync_bus           ),  // Global SYNC Signal, from CTC
    .bcd_in     (bcd_in             ),  // Tristate Bus, ARC <-> RAM
    .bcd_active (bcd_internal_active),  // |
    .bcd_out    (bcd_internal_drive ),  // /
    .dummy      (dbg_arc_dummy      )   // When asserted, preload regA with 60'hHAFEEDFACEBEEF to prevent inferring RAM
);

// ** C T C
control_and_timing_16_a u_CTC(
    .ia_out      (ia_internal_drive     ),  // Address Bus
    .ws_in       (ws_bus                ),  // Word Select Bus
    .ws_out      (ws_internal_drive_ctc ),  // |
    .ws_active   (ws_internal_active_ctc),  // /
    .SYNC        (sync_drive_ctc        ),  // Global SYNC
    .tp_tiny_pin2(dbg_ctc_state1        ),  // Does it enter sIdle when Reset ?
    .dbg_ctc_kdn (dbg_ctc_kdn           ),
    .PHI2        (PHI2                  ),  // Global Clock
    .PWO         (PWO                   ),  // Global RST
    .IS          (is_bus                ),  // Instruction bus, Driven by ROMs 
    .CARRY       (carry_bus             ),  // Driven by ARC
    .ROW0(ROW[0]),.ROW1(ROW[1]),.ROW2(ROW[2]),.ROW3(ROW[3]),.ROW4(ROW[4]),.ROW5(ROW[5]),.ROW6(ROW[6]),.ROW7(ROW[7]),
    .COL0(COL[0]),.COL2(COL[1]),.COL3(COL[2]),.COL4(COL[3]),.COL6(COL[4])
);

// ** R O M
genvar gi;
generate
    for(gi=0;gi<3;gi=gi+1) begin : gen_ROM_instances
        read_only_memory_18_a #(.RomNum(gi)) u_ROM(
            .is_active(is_internal_active[gi]),
            .is_out   (is_internal_drive [gi]),
            .is_in    (is_bus                ),  // The three Tri-State buses
            .ws_out   (ws_internal_drive[gi] ),
            .ws_active(ws_internal_active[gi]),
            .IA       (ia_bus                ),
            .PHI1(PHI1),.PHI2(PHI2),.PWO(PWO),.SYNC(sync_bus),
            .TP_ROE   (dbg_rom_roe[gi]       )
        );
    end
endgenerate

// Implementation of the buses
// Use MUX instead of Tri-state buffers 
reg ws_mux1;
wire ws_internal_active_rom = |ws_internal_active;
always @* begin
    // Word Select Bus (Can be driven by either the ROMs or the CTC)
    casex ({ws_internal_active})
        3'b1xx:  ws_mux1 = ws_internal_drive[2];
        3'b01x:  ws_mux1 = ws_internal_drive[1];
        3'b001:  ws_mux1 = ws_internal_drive[0];
        default: ws_mux1 = 1'bx;
    endcase

    casex ({dbg_enable_ctc, dbg_enable_rom, ws_internal_active_ctc, ws_internal_active_rom})
        4'b111x: {ws_oe, ws_bus} = {1'b1, ws_internal_drive_ctc};   // CTC is in control
        4'b1101: {ws_oe, ws_bus} = {1'b1, ws_mux1};                 // ROM is in control
        4'b101x: {ws_oe, ws_bus} = {1'b1, ws_internal_drive_ctc};
        4'b0101: {ws_oe, ws_bus} = {1'b1, ws_mux1};
        default: {ws_oe, ws_bus} = {1'b0, ws_in};
    endcase

    // BCD Bus (Peripheral)
    casex ({dbg_enable_arc, bcd_internal_active})
        2'b0x:   {bcd_oe, bcd_bus} = {1'b0, bcd_in};                // External ARC
        2'b11:   {bcd_oe, bcd_bus} = {1'b1, bcd_internal_drive};    // ARC is in control
        default: {bcd_oe, bcd_bus} = {1'b0, bcd_in};                // Nobody is in control
    endcase

    // Instruction Bus
    casex ({dbg_enable_rom,is_internal_active})
        4'b0xxx:  {is_oe, is_bus} = {1'b0, is_in               };    // External ROM
        4'b1100:  {is_oe, is_bus} = {1'b1, is_internal_drive[2]};    // ROM 2 in control
        4'b1010:  {is_oe, is_bus} = {1'b1, is_internal_drive[1]};    // ROM 1 in control
        4'b1001:  {is_oe, is_bus} = {1'b1, is_internal_drive[0]};    // ROM 0 in control
        default:  {is_oe, is_bus} = {1'b0, is_in               };    // Essentially nobody is in control
    endcase

    // Single-Drive Signals
    case ({dbg_enable_ctc})
        1'b1:    {sync_bus, ia_bus} = {sync_drive_ctc, ia_internal_drive};
        default: {sync_bus, ia_bus} = {sync_in,        ia_in};
    endcase

    case ({dbg_enable_arc})
        1'b1:     carry_bus = carry_drive_arc;
        default:  carry_bus = carry_in;
    endcase

end



endmodule /* hp35_core */