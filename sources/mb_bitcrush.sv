`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/10/2025 08:24:22 PM
// Design Name: 
// Module Name: mb_bitcrush
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


module mb_bitcrush (
       input logic clk, 
       input logic enable,
       input logic [15:0] pcm_in,
       output logic [15:0] pcm_out
);

    always_comb begin
        if (enable) begin
            // Mask out the bottom 12 bits, keep only top 4 bits
            //digitized Audio
            pcm_out = pcm_in & 16'hF000;
        end else begin
            //Bypass: Pass through no effect
            pcm_out = pcm_in;
        end
    end
endmodule
