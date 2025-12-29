`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/11/2025 04:06:32 AM
// Design Name: 
// Module Name: ring_modulator
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


module ring_modulator (
    input  logic clk,           // Use Audio Clock (clk_pdm)
    input  logic enable,
    input  logic [15:0] pcm_in,
    output logic [15:0] pcm_out
);

    //---AI helped come up with these values for the sound ----
    // DALEK FREQUENCY CONFIGURATION
    // (4,800,000 / 30) / 2 = ~80,000 ticks
    localparam TOGGLE_LIMIT = 80000;

    int counter;
    logic carrier_wave;

    // 1. Generate the 30Hz Carrier Wave
    always_ff @(posedge clk) begin
        if (counter >= TOGGLE_LIMIT) begin
            counter <= 0;
            carrier_wave <= ~carrier_wave; // Flip between +1 and -1
        end else begin
            counter <= counter + 1;
        end
    end

    //Multiply Input by Carrier
    always_comb begin
        if (!enable) begin
            pcm_out = pcm_in; // No effect just Pass through
        end else begin
            // If 1 Pass signal Normal
            // If 0 Invert signal 
            if (carrier_wave) 
                pcm_out = pcm_in;
            else 
                pcm_out = (~pcm_in) + 1; //negation
        end
    end
endmodule
