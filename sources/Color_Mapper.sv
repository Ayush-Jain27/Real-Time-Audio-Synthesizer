module  color_mapper ( 
    input  logic [9:0] DrawX, DrawY,       
    input  logic [15:0] bar_height,        
    
    // UI INPUTS
    input  logic        is_recording,      // SW0
    input  logic        sw_bitcrush,       // SW1
    input  logic        sw_distortion,     // SW2
    input  logic        sw_pitch_en,       // SW3
    input  logic        sw_ringmod,        // SW4
    input  logic [11:0] pitch_val,         
    
    output logic [3:0]  Red, Green, Blue   
);
    
    logic bar_on;
    logic circle_on;
    logic triangle_on;
    logic speed_bar_on;
    
    // --- FONT ROM VARIABLES ---
    logic [10:0] font_addr;
    logic [7:0]  font_data;
    logic        pixel_on;
    logic [6:0]  char_code;      // ASCII code
    logic [3:0]  row_idx;        // Row 0-15
    logic [2:0]  bit_idx;        // Col 0-7

    // Instantiate your uploaded Font ROM
    mb_font_rom u_font (
        .addr(font_addr),
        .data(font_data)
    );


    //--AI was used to help hardcode some ASCII character for the display---
    // ====================================================================
    // 1. TEXT DRAWING LOGIC (The "String Mux")
    // ====================================================================
    // We scan the screen coordinates to decide which letter to ask the ROM for.
    
    always_comb begin
        // Default: Space (0x00 or 0x20)
        char_code = 7'h00;
        row_idx = 4'd0; // Default row mapping
        bit_idx = 3'd0; // Default col mapping
        
        // -----------------------------------------------------------------
        // A. WORD: "PITCH" (X: 20-60, Y: 40-56)
        // -----------------------------------------------------------------
        if (sw_pitch_en && DrawY >= 40 && DrawY < 56 && DrawX >= 20 && DrawX < 60) begin
            row_idx = DrawY - 40;     // Align Y to 0
            bit_idx = (DrawX - 20) & 3'd7;
            
            case ((DrawX - 20) >> 3)  // (X - Start) / 8 = Character Index
                0: char_code = 7'h50; // P
                1: char_code = 7'h49; // I
                2: char_code = 7'h54; // T
                3: char_code = 7'h43; // C
                4: char_code = 7'h48; // H
                default: char_code = 7'h00;
            endcase
        end

        // -----------------------------------------------------------------
        // B. WORD: "RINGMOD" (X: 340-396, Y: 40-56)
        // -----------------------------------------------------------------
        else if (sw_ringmod && DrawY >= 40 && DrawY < 56 && DrawX >= 340 && DrawX < 396) begin
            row_idx = DrawY - 40;
            bit_idx = (DrawX - 340) & 3'd7;
            
            case ((DrawX - 340) >> 3)
                0: char_code = 7'h52; // R
                1: char_code = 7'h49; // I
                2: char_code = 7'h4E; // N
                3: char_code = 7'h47; // G
                4: char_code = 7'h4D; // M
                5: char_code = 7'h4F; // O
                6: char_code = 7'h44; // D
                default: char_code = 7'h00;
            endcase
        end

        // -----------------------------------------------------------------
        // C. WORD: "DISTORT" (X: 420-476, Y: 40-56)
        // -----------------------------------------------------------------
        else if (sw_distortion && DrawY >= 40 && DrawY < 56 && DrawX >= 420 && DrawX < 476) begin
            row_idx = DrawY - 40;
            bit_idx = (DrawX - 420) & 3'd7;
            
            case ((DrawX - 420) >> 3)
                0: char_code = 7'h44; // D
                1: char_code = 7'h49; // I
                2: char_code = 7'h53; // S
                3: char_code = 7'h54; // T
                4: char_code = 7'h4F; // O
                5: char_code = 7'h52; // R
                6: char_code = 7'h54; // T
                default: char_code = 7'h00;
            endcase
        end

        // -----------------------------------------------------------------
        // D. WORD: "BITCRUSH" (X: 500-564, Y: 40-56)
        // -----------------------------------------------------------------
        else if (sw_bitcrush && DrawY >= 40 && DrawY < 56 && DrawX >= 500 && DrawX < 564) begin
            row_idx = DrawY - 40;
            bit_idx = (DrawX - 500) & 3'd7;
            
            case ((DrawX - 500) >> 3)
                0: char_code = 7'h42; // B
                1: char_code = 7'h49; // I
                2: char_code = 7'h54; // T
                3: char_code = 7'h43; // C
                4: char_code = 7'h52; // R
                5: char_code = 7'h55; // U
                6: char_code = 7'h53; // S
                7: char_code = 7'h48; // H
                default: char_code = 7'h00;
            endcase
        end
    end

    // --- ROM LOOKUP ---
    // Address = {ASCII (7 bits), Row (4 bits)}
    assign font_addr = {char_code, row_idx};

    // --- PIXEL CHECK ---
    // Font Data comes out as a byte (e.g., 10100000). 
    // We check the bit corresponding to DrawX % 8.
    // Since bit 7 is usually left-most, we do (7 - col_idx).
    assign pixel_on = (char_code != 0) ? font_data[3'd7 - bit_idx] : 1'b0;
    
    //-----End of AI assisted section ----
    
    // VOLUME BAR
    logic bar_left_on;
    
    logic bar_right_on;
    always_comb begin
    //Left Bar
        if (DrawX >= 220 && DrawX <= 300 && DrawY >= (400 - bar_height) && DrawY <= 400)
            bar_left_on = 1'b1;
        else 
            bar_left_on = 1'b0;
            
     //Right Bar
        if (DrawX >= 340 && DrawX <= 420 && DrawY >= (400 - bar_height) && DrawY <= 400)
            bar_right_on = 1'b1;
        else
            bar_right_on = 1'b0;
         
         bar_on = bar_left_on | bar_right_on;
    end
    
   
    

    // ICONS
    int dist_sq;
    assign dist_sq = (DrawX - 590)*(DrawX - 590) + (DrawY - 30)*(DrawY - 30);
    int y_diff, max_width;
    assign y_diff = (DrawY > 30) ? (DrawY - 30) : (30 - DrawY);
    assign max_width = (600 - DrawX) >> 1;

    always_comb begin
        // Rec Circle (Top Right)
        circle_on = (is_recording && dist_sq <= 100);
        // Play Triangle (Top Right)
        triangle_on = (!is_recording && DrawX >= 580 && DrawX <= 600 && y_diff <= max_width);
        
        // Speed Bar (Cyan) - Visual for Potentiometer
        speed_bar_on = (sw_pitch_en && DrawX >= 20 && DrawX <= (20 + pitch_val[11:4]) && DrawY >= 20 && DrawY <= 30);
    end

    
    always_comb begin
        
        if (pixel_on) begin
            if (sw_pitch_en && DrawX < 100) begin
                Red=4'h0; Green=4'hF; Blue=4'hF;      // Cyan for Pitch
            end
            else if (sw_ringmod && DrawX < 400) begin
                Red=4'h8; Green=4'h0; Blue=4'h8;  // Purple for Ring
            end
            else if (sw_distortion && DrawX < 490) begin
                Red=4'hF; Green=4'h8; Blue=4'h0; // Orange for Dist
            end
            else begin
                Red=4'h4; Green=4'h4; Blue=4'hF; // Blue for Bitcrush
            end
        end
        
        
        else if (circle_on) begin
            Red = 4'hF; Green = 4'h0; Blue = 4'h0;
        end
        else if (triangle_on) begin
            Red = 4'h0; Green = 4'hF; Blue = 4'h0;
        end
        else if (speed_bar_on) begin
            Red = 4'h0; Green = 4'hF; Blue = 4'hF;
        end
        
        else if (bar_on) begin
            if (DrawY < 200) begin Red = 4'hF; Green = 4'h0; Blue = 4'h0; end
            else if (DrawY < 300) begin Red = 4'hF; Green = 4'hF; Blue = 4'h0; end
            else begin Red = 4'h0; Green = 4'hF; Blue = 4'h0; end
        end       
        else begin 
            Red = 4'h1; Green = 4'h1; Blue = 4'h3; 
        end      
    end 
endmodule