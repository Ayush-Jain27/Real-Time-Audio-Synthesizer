`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/10/2025 08:25:11 PM
// Design Name: 
// Module Name: mb_distortion
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


module mb_distortion(
    input logic clk, 
    input logic enable, //Switch to turn effect on or off
    
    input logic [15:0] pcm_in, //Incoming pulse code signal
    output logic [15:0] pcm_out //Outgoing pulse code signal
    );
    
    //Threshold for clipping; Lower Value means more distortion
    localparam LIMIT = 16'd1000;
    
    //Use 32 bits to hold the "boosted" value so it doesn't
    //wrap around we multiply stuff
    logic signed [31:0] boosted;
    
    always_comb begin
        //Sign-extend 16-bit input to 32 bit, then multiply by 4
        //---AI assisted with mathematics here---
        boosted = {{15{pcm_in[15]}}, pcm_in} << 4;
        //---END AI section
        
        if (enable) begin
            if (boosted > $signed(LIMIT)) begin
                pcm_out = LIMIT;
            end else if (boosted < -$signed(LIMIT)) begin
                pcm_out = -LIMIT;
            end else begin
                //If within range, output boosted signal
                pcm_out = boosted[15:0];
            end         
        end else begin
            //If not, just pass audio through unchanged
            pcm_out = pcm_in;
        end
        
    
    end
    

endmodule
