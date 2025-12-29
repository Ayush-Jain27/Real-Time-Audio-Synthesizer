`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/10/2025 08:23:10 PM
// Design Name: 
// Module Name: mb_pdm_to_pcm
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


module mb_pdm_to_pcm #(
    parameter integer DECIM_FACTOR = 104   // number of PDM bits per PCM sample
)(
    input  logic        pdm_clk,
    input  logic        rstn,           // active-low
    input  logic        pdm_in,         // 1-bit PDM
    output logic [15:0] pcm_out,        // signed 16-bit PCM
    output logic        pcm_valid
);

    // Integrator over the decimation window
    logic signed [15:0] acc;

    // Counter for window length
    //----AI helped come up with these values and assisted me with the Math
    localparam integer CNT_WIDTH = 8;   // supports up to 127
    logic [CNT_WIDTH-1:0] cnt;

    // Parameters for scaling and DC removal
    localparam int SHIFT = 8;           // use <<< 8 based on your measurements
    localparam int SCALED_W = 16 + SHIFT; // width after shift
    localparam int AVG_W = 28;          // DC accumulator width
    localparam int DC_ALPHA = 8;       // 1/2^12 step for slow DC tracking
    localparam signed [15:0] PCM_OFFSET = 16'sd7114; // small deterministic DC correction

    // intermediates
    logic signed [SCALED_W-1:0] raw_scaled;
    logic signed [AVG_W-1:0]    dc_avg;
    logic signed [SCALED_W+8-1:0] diff_ext; // safe intermediate for subtraction
    logic signed [31:0]         dc_removed_ext;
    logic signed [31:0]         sat_ext;
    
    //END AI math help section


    // temps (module scope - do NOT declare these inside the always_ff)
    logic signed [31:0] pcm_after_offset;
    logic signed [31:0] pcm_final_ext;
    
    logic pdm_sync_1, pdm_sync_2;

    always_ff @(posedge pdm_clk or negedge rstn) begin
    if (!rstn) begin
        acc       <= '0;
        cnt       <= '0;
        pcm_out   <= '0;
        pcm_valid <= 1'b0;
        dc_avg    <= '0;
        pcm_after_offset <= 32'sd0;
        pcm_final_ext    <= 32'sd0;
    end else begin
        pdm_sync_1 <= pdm_in;
        pdm_sync_2 <= pdm_sync_1;
        // integrate PDM: +1 for '1', -1 for '0'
        acc <= acc + (pdm_sync_2 ? 16'sd1 : -16'sd1);

        // window counter
        cnt <= cnt + 1;

        if (cnt == DECIM_FACTOR-1) begin
            // scale (signed)
            raw_scaled = $signed(acc) <<< SHIFT;

            // update slow DC estimate (signed subtraction, then IIR)
            diff_ext = $signed(raw_scaled) - $signed(dc_avg);
            dc_avg <= dc_avg + (diff_ext >>> DC_ALPHA);

            // remove DC (signed)
            dc_removed_ext = $signed(raw_scaled) - $signed(dc_avg);

            // saturate to signed 16-bit
            if (dc_removed_ext >  32'sd32767) sat_ext = 32'sd32767;
            else if (dc_removed_ext < -32'sd32768) sat_ext = -32'sd32768;
            else sat_ext = dc_removed_ext;

            // apply deterministic offset and re-clamp to signed 16-bit
            
            pcm_final_ext = sat_ext;

            
            // Threshold: 128 (You can tweak this: Higher = Aggressive, Lower = Sensitive)
            if (pcm_final_ext > -32'sd128 && pcm_final_ext < 32'sd128) begin
                pcm_out <= 16'd0; // Silence!
            end else begin
                pcm_out <= pcm_final_ext[15:0]; // Let the voice through
            end
            pcm_valid <= 1'b1;

            // reset window
            acc <= '0;
            cnt <= '0;
        end else begin
            pcm_valid <= 1'b0;
        end
    end
end


endmodule
