`timescale 1ns / 1ps

module sorting_system(
    input wire clk,             // 125MHz Clock
    input wire rst_n,           // BTN0 (Reset)
    
    // Nút test thủ công
    input wire btn_manual_1,    // BTN1 (Test Servo 1)
    input wire btn_manual_2,    // BTN2 (Test Servo 2)
    
    // --- TCS3200 (Pmod JA) ---
    input wire sensor_out,      
    output wire s0, s1,         
    output wire s2, s3,         
    output wire led_r, led_g, led_b,
    
    // --- HỆ THỐNG PHÂN LOẠI (Pmod JB) ---
    input wire ir_sensor,       // 1 CẢM BIẾN IR DUY NHẤT
    output wire servo_pwm_1,    // Servo 1 (Gạt Đỏ)
    output wire servo_pwm_2,    // Servo 2 (Gạt Xanh)
    output wire led_ir_status   // LD3 (Sáng khi IR có vật)
);

    // --- 1. XỬ LÝ MÀU SẮC (V3 - Tìm xa & Nhớ màu) ---
    wire [1:0] detected_color; // 1:Red, 2:Green, 3:Blue
    
    tcs3200_core_v3 color_sensor_inst (
        .clk(clk), .rst_n(rst_n),
        .sensor_out(sensor_out),
        .s0(s0), .s1(s1), .s2(s2), .s3(s3),
        .color_id(detected_color),
        .led_r(led_r), .led_g(led_g), .led_b(led_b)
    );

    // --- 2. LOGIC PHÂN LOẠI TRUNG TÂM ---
    reg ir_s1, ir_s2;
    wire ir_edge;
    
    // Đồng bộ tín hiệu IR và phát hiện cạnh xuống (Vật đi vào)
    always @(posedge clk) begin
        ir_s1 <= ir_sensor; 
        ir_s2 <= ir_s1; 
    end
    assign ir_edge = (ir_s2 == 1'b1 && ir_s1 == 1'b0);
    assign led_ir_status = ~ir_s2; // Debug đèn

    // Logic chia tín hiệu cho 2 Servo
    reg trig_1, trig_2;

    always @(posedge clk) begin
        if (rst_n) begin
            trig_1 <= 0;
            trig_2 <= 0;
        end else begin
            trig_1 <= 0;
            trig_2 <= 0;
            
            if (ir_edge) begin
                // Nếu là MÀU ĐỎ (ID=1) -> Kích Servo 1
                if (detected_color == 2'd1) trig_1 <= 1;
                
                // Nếu là MÀU XANH LÁ (ID=2) -> Kích Servo 2
                else if (detected_color == 2'd2) trig_2 <= 1;
            end
        end
    end

    // --- 3. ĐIỀU KHIỂN SERVO (CẤU HÌNH THỜI GIAN KHÁC NHAU) ---

    // SERVO 1: Trễ 2.1 giây rồi gạt, Giữ 0.24 giây 
    servo_core #(
        .START_DELAY(262500000),          // Trễ 2.1 giây
        .HOLD_TIME(30000000)     // Giữ 0.24 giây (30 triệu xung)
    ) servo_1_inst (
        .clk(clk), .rst_n(rst_n),
        .activate(trig_1 | btn_manual_1),
        .pwm_out(servo_pwm_1)
    );

    // SERVO 2: CHỜ 4 GIÂY mới gạt, Giữ 0.24 giây
    servo_core #(
        .START_DELAY(500000000),  // Chờ 4 giây mới bắt đầu chạy
        .HOLD_TIME(30000000)     // Giữ 0.24 giây (30 triệu xung)
    ) servo_2_inst (
        .clk(clk), .rst_n(rst_n),
        .activate(trig_2 | btn_manual_2),
        .pwm_out(servo_pwm_2)
    );

endmodule


// =============================================================================
// MODULE MÀU V3 (GIỮ NGUYÊN)
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
// MODULE SERVO LINH HOẠT (Có DELAY + HOLD)
// =============================================================================
module servo_core #(
    parameter START_DELAY = 0,      // Thời gian chờ trước khi gạt
    parameter HOLD_TIME = 125000000 // Thời gian giữ
)(
    input clk, rst_n, activate,
    output reg pwm_out
);
    parameter MIN_PULSE = 62500;     // 0 độ
    parameter TARGET_PULSE = 145833; // 45 độ

    reg [31:0] cnt = 0;
    reg [31:0] duty = 62500;
    
    // Máy trạng thái mới: IDLE -> WAIT_DELAY -> MOVE -> HOLD -> RETURN
    localparam IDLE=0, WAIT_DELAY=1, MOVE=2, HOLD=3, RETURN=4;
    reg [2:0] state = IDLE;
    reg [31:0] general_timer = 0; // Dùng chung cho cả Delay và Hold

    always @(posedge clk) begin
        if (rst_n) begin
            state <= IDLE; duty <= MIN_PULSE; general_timer <= 0;
        end else begin
            // Tạo xung PWM
            if (cnt < 2500000) cnt <= cnt + 1; else cnt <= 0;
            pwm_out <= (cnt < duty) ? 1 : 0;
            
            case(state)
                IDLE: begin
                    duty <= MIN_PULSE; 
                    general_timer <= 0;
                    if (activate) begin
                        if (START_DELAY > 0) state <= WAIT_DELAY; // Nếu có delay thì chờ
                        else state <= MOVE;                       // Nếu không thì chạy luôn
                    end
                end
                
                WAIT_DELAY: begin
                    // Chờ hết thời gian delay (ví dụ 4 giây cho Servo 2)
                    if (general_timer < START_DELAY) begin
                        general_timer <= general_timer + 1;
                    end else begin
                        general_timer <= 0; // Reset timer để dùng cho bước sau
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
                    // Giữ vị trí (ví dụ 4 giây)
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