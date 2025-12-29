`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/10/2025 08:20:14 PM
// Design Name: 
// Module Name: mb_audio_looper
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


module mb_audio_looper(
    input logic clk,
    input logic rstn, 
    input logic record_en,
    input logic pcm_valid,
    input logic [15:0] pcm_in,
    
    //Inputs for Pitch Control ---
    input logic [11:0] pitch_val, //From Potentiometer (0-4095)
    input logic pitch_enable, // 0 = Normal, 1 = Potentiometer access good
    output logic [15:0] pcm_out
);


    // SMOOTHING LOGIC Fixes Static
    logic [15:0] prev_sample;
    logic sample_toggle;
   
    
    always_ff @(posedge clk) begin
        if (pcm_valid) begin
            if (sample_toggle == 0) begin
                prev_sample <= pcm_in; // Store first sample
                sample_toggle <= 1;
            end else begin
                sample_toggle <= 0;    // Ready for next pair
            end
        end
    end
    
    // Calculate the Average: (Sample 1 + Sample 2) / 
    wire signed [15:0] averaged_sample = ($signed(prev_sample) + $signed(pcm_in)) >>> 1;

    // Trigger write only on the second sample (when toggle was 1)
    wire slow_tick = pcm_valid & (sample_toggle == 1);
    
    // -------------------------------------------
    
    
    //Variable Audio Speed Logic using Phase Accumulator
    //[28:12] = Integer Address (17 bits) is The actual RAM address
    // [11:0] = Fractional Address (12 bits) happening "Between" samples
    logic [28:0] phase_acc;
    
    //Calculate Speed Step
    logic [12:0] speed_step;
    

    assign speed_step = pitch_enable ? (pitch_val << 1) : 13'd4096;
    
    //---AI helped with looper speed control
    always_ff @(posedge clk) begin
        if (!rstn) begin
            phase_acc <= 0;
        end else if (slow_tick) begin
            if (record_en) begin
                // Always 1.0x speed 
                if (phase_acc[28:12] < 131000) 
                    phase_acc <= phase_acc + 13'd4096;
                else 
                    phase_acc <= 0;
            end else begin
                // Use the variable speed_step
                if (phase_acc[28:12] < 131000) 
                    phase_acc <= phase_acc + speed_step;
                else 
                    phase_acc <= 0;
            end
        end
    end
    //---End AI helped section
    
    // The actual RAM address is just the top integer part
    wire [16:0] addr_ptr = phase_acc[28:12];
    
    logic [15:0] bram_out;
    
    blk_mem_gen_0 u_bram (
        .clka (clk),
        .wea (record_en & slow_tick), //Write only if recording and if slow_tick on 
        .addra (addr_ptr),
        .dina (averaged_sample),
        
        .clkb (clk),
        .addrb (addr_ptr),
        .doutb (bram_out)    
    );
    
    //If recording, pass mic audio through to speakers
    //Else if playing, Play the loop from BRAM
    assign pcm_out = record_en ? pcm_in : bram_out;
endmodule
