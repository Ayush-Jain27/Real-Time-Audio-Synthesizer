`timescale 1ns / 1ps

module mb_audio_visualizer_top(
    input  logic clk_100m,
    input  logic rstn,          // Button Reset
    
    input logic [3:1] btn, //Button 1 2 and 3 for piano keys
    
    // Switches
    input logic sw_record,      // SW0
    input logic sw_bitcrush,    // SW1
    input logic sw_distortion,  // SW2
    input logic sw_pitch_en,    // SW3 
    input logic sw_ringmod,     //SW4
    
    // Analog
    input wire vp_in, 
    input wire vn_in,

    // Audio Interface
    output logic mic_clk,
    input  logic mic_pdm,
    output logic audio_left,
    output logic audio_right,

    // HDMI Interface
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0] hdmi_tmds_data_n,
    output logic [2:0] hdmi_tmds_data_p,
    
    // UART Interface
    input logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,
    
    output logic [15:0] LED
);

    // =========================================================================
    // 1. CLOCKING & RESET )
    // =========================================================================

    logic clk_pdm;    
    logic clk_pwm;    
    logic clk_locked; 

    localparam BUTTON_ACTIVE_LOW = 0;
    wire rstn_button = rstn;
    // idle(0) -> rstn_active_low(1)
    wire rstn_active_low = BUTTON_ACTIVE_LOW ? rstn_button : ~rstn_button;

    // 1. AUDIO CLOCK WIZARD
    // Receives ~1 = 0 (RUN)
    clk_wiz_0 u_clk_audio (
        .clk_in1 (clk_100m),
        .reset   (~rstn_active_low),      
        .clk_out1(clk_pdm),    
        .clk_out2(clk_pwm),    
        .locked  (clk_audio_locked)
    );
    
    // 2. HDMI CLOCK WIZARD
    // Receives ~1 = 0 (RUN)
    logic clk_25MHz, clk_125MHz, clk_hdmi_locked; // Added clk_hdmi_locked
    
    clk_wiz_hdmi u_clk_hdmi (
        .clk_in1 (clk_100m),
        .reset   (~rstn_active_low), 
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .locked  (clk_hdmi_locked)
    );

    // =========================================================================
    // 2. AUDIO PIPELINE
    // =========================================================================
    
    assign mic_clk = clk_pdm;
    // idle(0) -> rstn_active_low(1) & locked(1) -> 1 (RUN)
    wire rstn_synced = rstn_active_low & clk_audio_locked;
    
    logic [15:0] pcm;
    logic        pcm_v;
    
    mb_pdm_to_pcm u_decim (
        .pdm_clk   (clk_pdm),
        .rstn      (rstn_synced),
        .pdm_in    (mic_pdm),
        .pcm_out   (pcm),
        .pcm_valid (pcm_v)
    );
    
    logic [15:0] adc_raw_data;
    logic        adc_drdy;
    
    xadc_wiz_0 u_adc (
        .daddr_in(7'h03), .den_in(1'b1), .di_in(16'd0), .dwe_in(1'b0), 
        .do_out(adc_raw_data), .drdy_out(adc_drdy), 
        .dclk_in(clk_100m), .reset_in(1'b0),      
        .vp_in(vp_in), .vn_in(vn_in),          
        .channel_out(), .eoc_out(), .alarm_out(), .eos_out(), .busy_out()
    );
    
    logic [11:0] pitch_val;
    assign pitch_val = adc_raw_data[15:4];

    logic [15:0] pcm_mic_final; 
    
    mb_audio_looper u_looper (
        .clk (clk_pdm), .rstn (rstn_synced), .record_en (sw_record), 
        .pcm_valid (pcm_v), .pcm_in (pcm), .pcm_out (pcm_mic_final), 
        .pitch_val (pitch_val), .pitch_enable (sw_pitch_en)
    );
    
    //Synthesizer Path for piano stuff
    logic [15:0] pcm_synth;
    simple_synth u_piano (
        .clk(clk_pdm),
        .buttons({btn[3:1], 1'b0}), //Force last one to be 0
        .pcm_out(pcm_synth)
    );
    
    //Mixer logic 
    logic [15:0] pcm_mixed;
    logic signed [16:0] sum_temp; // 17 bits to catch overflow
    
    always_comb begin
        // Add Mic + Synth 
        sum_temp = $signed(pcm_mic_final) + $signed(pcm_synth);
        
        // Saturation Logic
        if (sum_temp > $signed(17'd32767)) 
            pcm_mixed = 16'd32767;       // Cap at Max Positive
        else if (sum_temp < $signed(-17'd32768))
            pcm_mixed = -16'd32768;      // Cap at Max Negative
        else
            pcm_mixed = sum_temp[15:0];  // Output valid sum
    end
    
    logic [15:0] pcm_distorted;
    mb_distortion u_dist (.clk (clk_pdm), .enable (sw_distortion), .pcm_in (pcm_mixed), .pcm_out (pcm_distorted));
    
    logic [15:0] pcm_crushed;
    mb_bitcrush u_crush (.clk (clk_pdm), .enable (sw_bitcrush), .pcm_in (pcm_distorted), .pcm_out (pcm_crushed));
    
    logic [15:0] ring_modulated;
    ring_modulator u_ring (.clk(clk_pdm), .enable(sw_ringmod), .pcm_in (pcm_crushed), .pcm_out (ring_modulated));

    mb_pcm_to_pwm u_pwm_l (.pwm_clk(clk_100m), .rstn(rstn_synced), .pcm_in(ring_modulated), .pcm_valid(pcm_v), .pwm_out(audio_left));
    mb_pcm_to_pwm u_pwm_r (.pwm_clk(clk_100m), .rstn(rstn_synced), .pcm_in(ring_modulated), .pcm_valid(pcm_v), .pwm_out(audio_right));

    // =========================================================================
    // 3. MICROBLAZE & HDMI stuffffs
    // =========================================================================
    
    logic [15:0] pcm_abs;
    assign pcm_abs = pcm_mixed[15] ? -pcm_mixed : pcm_mixed;
    
    logic [31:0] gpio_gfx_data; 
    
    mb_block_wrapper u_mb_wrapper (
        .clk_100MHz(clk_100m),
        .reset_rtl_0(rstn_active_low),  // <--- 1 = RUN (Active Low Input)
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .gpio_status_tri_i({28'b0, sw_pitch_en, sw_distortion, sw_bitcrush, sw_record}), 
        .gpio_volume_tri_i({16'b0, pcm_abs}), 
        .gpio_gfx_tri_o(gpio_gfx_data)   
    );

    // 4. HDMI Logic
    logic [9:0] drawX, drawY;
    logic hsync, vsync, vde;
    logic [3:0] red, green, blue;

    vga_controller vga (
        .pixel_clk(clk_25MHz), .reset(~rstn_active_low), 
        .hs(hsync), .vs(vsync), .active_nblank(vde), 
        .drawX(drawX), .drawY(drawY)
    );

    hdmi_tx_0 vga_to_hdmi (
        .pix_clk(clk_25MHz), .pix_clkx5(clk_125MHz), 
        .pix_clk_locked(clk_hdmi_locked), .rst(~rstn_active_low),
        .red(red), .green(green), .blue(blue), 
        .hsync(hsync), .vsync(vsync), .vde(vde),
        .aux0_din(4'b0), .aux1_din(4'b0), .aux2_din(4'b0), .ade(1'b0),
        .TMDS_CLK_P(hdmi_tmds_clk_p), .TMDS_CLK_N(hdmi_tmds_clk_n),
        .TMDS_DATA_P(hdmi_tmds_data_p), .TMDS_DATA_N(hdmi_tmds_data_n)
    );

    color_mapper color_instance (
        .DrawX(drawX), .DrawY(drawY),
        .bar_height(gpio_gfx_data[15:0]), 
        
        .is_recording(sw_record),         // SW0
        .sw_bitcrush(sw_bitcrush),        // SW1
        .sw_distortion(sw_distortion),    // SW2
        .sw_pitch_en(sw_pitch_en),        // SW3
        .sw_ringmod(sw_ringmod),          // SW4
        .pitch_val(pitch_val),            // Potentiometer Value
        
        .Red(red), .Green(green), .Blue(blue)
    );
    
    // 5. DEBUG LEDS
    assign LED[15] = clk_hdmi_locked; 
    assign LED[14] = clk_audio_locked;      
    assign LED[13] = ~rstn_active_low; 
    assign LED[0]  = sw_record;

endmodule