`timescale 1ns / 1ps

module sorting_system(
    input wire clk,             // 125MHz Clock
    input wire rst_n,           // BTN0 (Reset)
    
    // N�t test th? c�ng
    input wire btn_manual_1,    // BTN1 (Test Servo 1)
    input wire btn_manual_2,    // BTN2 (Test Servo 2)
    
    // --- TCS3200 (Pmod JA) ---
    input wire sensor_out,      
    output wire s0, s1,         
    output wire s2, s3,         
    output wire led_r, led_g, led_b,
    
    // --- H? TH?NG PH�N LO?I (Pmod JB) ---
    input wire ir_sensor,       // 1 C?M BI?N IR DUY NH?T
    output wire servo_pwm_1,    // Servo 1 (G?t �?)
    output wire servo_pwm_2,    // Servo 2 (G?t Xanh)
    output wire led_ir_status   // LD3 (S�ng khi IR c� v?t)
);

    // --- 1. X? L? M�U S?C (V3 - T?m xa & Nh? m�u) ---
    wire [1:0] detected_color; // 1:Red, 2:Green, 3:Blue
    
    tcs3200_core_v3 color_sensor_inst (
        .clk(clk), .rst_n(rst_n),
        .sensor_out(sensor_out),
        .s0(s0), .s1(s1), .s2(s2), .s3(s3),
        .color_id(detected_color),
        .led_r(led_r), .led_g(led_g), .led_b(led_b)
    );

    // --- 2. LOGIC PH�N LO?I TRUNG T�M ---
    reg ir_s1, ir_s2;
    wire ir_edge;
    
    // �?ng b? t�n hi?u IR v� ph�t hi?n c?nh xu?ng (V?t �i v�o)
    always @(posedge clk) begin
        ir_s1 <= ir_sensor; 
        ir_s2 <= ir_s1; 
    end
    assign ir_edge = (ir_s2 == 1'b1 && ir_s1 == 1'b0);
    assign led_ir_status = ~ir_s2; // Debug ��n

    // Logic chia t�n hi?u cho 2 Servo
    reg trig_1, trig_2;

    always @(posedge clk) begin
        if (rst_n) begin
            trig_1 <= 0;
            trig_2 <= 0;
        end else begin
            trig_1 <= 0;
            trig_2 <= 0;
            
            if (ir_edge) begin
                // N?u l� M�U �? (ID=1) -> K�ch Servo 1
                if (detected_color == 2'd1) trig_1 <= 1;
                
                // N?u l� M�U XANH L� (ID=2) -> K�ch Servo 2
                else if (detected_color == 2'd2) trig_2 <= 1;
            end
        end
    end

    // --- 3. �I?U KHI?N SERVO (C?U H?NH TH?I GIAN KH�C NHAU) ---

    // SERVO 1: G?t NGAY L?P T?C, Gi? 4 Gi�y 
    servo_core #(
        .START_DELAY(262500000),          // Kh�ng tr?
        .HOLD_TIME(30000000)     // Gi? 4 gi�y (500 tri?u xung)
    ) servo_1_inst (
        .clk(clk), .rst_n(rst_n),
        .activate(trig_1 | btn_manual_1),
        .pwm_out(servo_pwm_1)
    );

    // SERVO 2: CH? 4 GI�Y m?i g?t, Gi? 4 Gi�y
    servo_core #(
        .START_DELAY(500000000),  // Ch? 4 gi�y m?i b?t �?u ch?y
        .HOLD_TIME(30000000)     // Gi? 4 gi�y
    ) servo_2_inst (
        .clk(clk), .rst_n(rst_n),
        .activate(trig_2 | btn_manual_2),
        .pwm_out(servo_pwm_2)
    );

endmodule


// =============================================================================
// MODULE M�U V3 (GI? NGUY�N)
// =============================================================================
module tcs3200_core_v3(
    input clk, rst_n, sensor_out,
    output wire s0, s1, 
    output reg s2, s3,
    output reg [1:0] color_id, 
    output reg led_r, led_g, led_b
);
    assign s0 = 1; assign s1 = 1; // 100% Scaling
    parameter SAMPLE_TIME = 12500000; // 100ms

    localparam RED=0, BLUE=1, GREEN=2;
    reg [1:0] state = RED;
    reg [31:0] timer = 0, counter = 0;
    reg [31:0] r_val, g_val, b_val;
    reg s_in_d, s_in_d2;
    wire s_edge = s_in_d & ~s_in_d2;
    
    always @(posedge clk) begin s_in_d <= sensor_out; s_in_d2 <= s_in_d; end

    always @(posedge clk) begin
        if (rst_n) begin
            state <= RED; timer <= 0; counter <= 0;
            color_id <= 0; led_r<=0; led_g<=0; led_b<=0;
        end else begin
            if (timer < SAMPLE_TIME) begin 
                timer <= timer + 1;
                if (s_edge) counter <= counter + 1;
            end else begin
                timer <= 0; counter <= 0;
                case(state)
                    RED: begin r_val <= counter; state <= BLUE; s2<=0; s3<=1; end
                    BLUE: begin b_val <= counter; state <= GREEN; s2<=1; s3<=1; end
                    GREEN: begin 
                        g_val <= counter; state <= RED; s2<=0; s3<=0;
                        if ((r_val + g_val + b_val) > 1000) begin
                            if(r_val > g_val && r_val > b_val) begin
                                color_id <= 1; led_r<=1; led_g<=0; led_b<=0;
                            end else if(g_val > r_val && g_val > b_val) begin
                                color_id <= 2; led_r<=0; led_g<=1; led_b<=0;
                            end else if(b_val > r_val && b_val > g_val) begin
                                color_id <= 3; led_r<=0; led_g<=0; led_b<=1;
                            end
                        end else begin
                             led_r<=0; led_g<=0; led_b<=0;
                        end
                    end
                endcase
            end
        end
    end
endmodule

// =============================================================================
// MODULE SERVO LINH HO?T (C� DELAY + HOLD)
// =============================================================================
module servo_core #(
    parameter START_DELAY = 0,      // Th?i gian ch? tr�?c khi g?t
    parameter HOLD_TIME = 125000000 // Th?i gian gi?
)(
    input clk, rst_n, activate,
    output reg pwm_out
);
    parameter MIN_PULSE = 62500;     // 0 �?
    parameter TARGET_PULSE = 145833; // 45 �?

    reg [31:0] cnt = 0;
    reg [31:0] duty = 62500;
    
    // M�y tr?ng th�i m?i: IDLE -> WAIT_DELAY -> MOVE -> HOLD -> RETURN
    localparam IDLE=0, WAIT_DELAY=1, MOVE=2, HOLD=3, RETURN=4;
    reg [2:0] state = IDLE;
    reg [31:0] general_timer = 0; // D�ng chung cho c? Delay v� Hold

    always @(posedge clk) begin
        if (rst_n) begin
            state <= IDLE; duty <= MIN_PULSE; general_timer <= 0;
        end else begin
            // T?o xung PWM
            if (cnt < 2500000) cnt <= cnt + 1; else cnt <= 0;
            pwm_out <= (cnt < duty) ? 1 : 0;
            
            case(state)
                IDLE: begin
                    duty <= MIN_PULSE; 
                    general_timer <= 0;
                    if (activate) begin
                        if (START_DELAY > 0) state <= WAIT_DELAY; // N?u c� delay th? ch?
                        else state <= MOVE;                       // N?u kh�ng th? ch?y lu�n
                    end
                end
                
                WAIT_DELAY: begin
                    // Ch? h?t th?i gian delay (v� d? 4 gi�y cho Servo 2)
                    if (general_timer < START_DELAY) begin
                        general_timer <= general_timer + 1;
                    end else begin
                        general_timer <= 0; // Reset timer �? d�ng cho b�?c sau
                        state <= MOVE;
                    end
                end
                
                MOVE: begin
                    if (duty < TARGET_PULSE) duty <= duty + 250; 
                    else begin 
                        duty <= TARGET_PULSE; 
                        general_timer <= 0; // Reset timer
                        state <= HOLD; 
                    end
                end
                
                HOLD: begin
                    // Gi? v? tr� (v� d? 4 gi�y)
                    if (general_timer < HOLD_TIME) general_timer <= general_timer + 1;
                    else state <= RETURN;
                end
                
                RETURN: begin
                    if (duty > MIN_PULSE) duty <= duty - 250;
                    else state <= IDLE;
                end
            endcase
        end
    end
endmodule