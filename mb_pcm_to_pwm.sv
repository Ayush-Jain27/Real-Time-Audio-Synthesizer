`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/10/2025 08:24:45 PM
// Design Name: 
// Module Name: mb_pcm_to_pwm
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


module mb_pcm_to_pwm #(
    parameter integer PWM_BITS = 8       // PWM resolution (e.g., 8 ? 256 steps)
)(
    input  logic        pwm_clk,
    input  logic        rstn,            // active-low
    input  logic [15:0] pcm_in,          // signed 16-bit PCM in PWM domain
    input  logic        pcm_valid,       // single-cycle strobe (PWM domain)
    output logic        pwm_out
);

    // Duty target and carrier counter
    logic [PWM_BITS-1:0] duty_target;
    logic [PWM_BITS-1:0] pwm_cnt;

    always_ff @(posedge pwm_clk or negedge rstn) begin
        if (!rstn) begin
            pwm_cnt     <= '0;
            duty_target <= (1 << (PWM_BITS-1));  // midscale duty (e.g., 128/256)
            pwm_out     <= 1'b0;
        end else begin
            pwm_cnt <= pwm_cnt + 1;

            if (pcm_valid) begin
                // compute unsigned biased value and downscale to PWM_BITS in one expression
                //---Exact calculation was assisted with AI ---
                duty_target <= ( ( {1'b0, pcm_in} + 17'd32768 ) >> (16 - PWM_BITS) );
                //END AI section
            end

            // Comparator generates PWM
            pwm_out <= (pwm_cnt < duty_target);
        end
    end

endmodule
