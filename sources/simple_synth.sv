`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Alen Daniel
// 
// Create Date: 12/11/2025 04:37:12 PM
// Design Name: 
// Module Name: simple_synth
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module simple_synth (
    input  logic clk,             // Audio Clock (~4.8 MHz)
    input  logic [3:0] buttons,   // BTN0-BTN3 (Mapped to notes)
    output logic [15:0] pcm_out   // Audio Output
);
    // Limit = (4,800,000 / Frequency) / 2
    //---AI helped choose frequency values here----
    localparam C4_LIM = 9160; // 261 Hz (Middle C)
    localparam E4_LIM = 7272; // 329 Hz (Major Third)
    localparam G4_LIM = 6122; // 392 Hz (Perfect Fifth)
    localparam C5_LIM = 4580; // 523 Hz (High C)
    
    //---End AI section---

    int ctr_0, ctr_1, ctr_2, ctr_3;
    logic note_0, note_1, note_2, note_3;

    // generate tones
    always_ff @(posedge clk) begin
   
        // Note 1 Middle C
        if (ctr_0 >= C4_LIM) begin ctr_0 <= 0; note_0 <= ~note_0; end else ctr_0 <= ctr_0 + 1;
        
        // Note 2 Major Third
        if (ctr_1 >= E4_LIM) begin ctr_1 <= 0; note_1 <= ~note_1; end else ctr_1 <= ctr_1 + 1;
        
        // Note 3 perfect fifth
        if (ctr_2 >= G4_LIM) begin ctr_2 <= 0; note_2 <= ~note_2; end else ctr_2 <= ctr_2 + 1;
        
        // Note 4 high c
        if (ctr_3 >= C5_LIM) begin ctr_3 <= 0; note_3 <= ~note_3; end else ctr_3 <= ctr_3 + 1;
    end

    // balance mixing 
    logic signed [15:0] mixed;
    
    localparam VOL = 16'h0400;
    
    always_comb begin
        mixed = 16'd0;
        
        // If button pressed, add the square wave (+Val or -Val)
        if (buttons[0]) mixed = mixed + (note_0 ? VOL : -VOL);
        if (buttons[1]) mixed = mixed + (note_1 ? VOL : -VOL);
        if (buttons[2]) mixed = mixed + (note_2 ? VOL : -VOL);
        if (buttons[3]) mixed = mixed + (note_3 ? VOL : -VOL);
    end
    
    assign pcm_out = mixed;

endmodule
