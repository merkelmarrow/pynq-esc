`timescale 1ns / 1ps


module rc_pwm_capture #(
    parameter C_COUNTER_WIDTH = 32
)(
    input wire clk, // 100 MHz PL clock
    input wire rst_n, // active low synchronous reset
    input wire rc_pwm_in,
    output reg [C_COUNTER_WIDTH-1:0] pulse_width, // last width in clock cycles
    output reg new_data // "data is ready" pulse
    );
    
    // three-FF synchroniser
    reg[2:0] sync;
    always @(posedge clk) begin
        sync <= {sync[1:0], rc_pwm_in};
    end
    wire pwm_sync = sync[2];
    
    // two cycle latency
    wire rising = (sync[2:1] == 2'b01);
    wire falling = (sync[2:1] == 2'b10);
    
    // free-running counter
    // overflow at ~43 s at 100 MHz
    reg[C_COUNTER_WIDTH-1:0] counter;
    always @(posedge clk) begin
        counter <= counter + 1'b1;
        if (!rst_n) counter <= {C_COUNTER_WIDTH{1'b0}};
    end
    
    reg [C_COUNTER_WIDTH-1:0] t_start;
    
    always @(posedge clk) begin
        new_data <= 1'b0; // default
        if (!rst_n) begin
            pulse_width <= 0;
            t_start <= 0;
        end else begin
            if (rising) begin
                t_start <= counter;
            end
            if (falling) begin
                // wraparound 2's comp subtraction stays valid
                pulse_width <= counter - t_start;
                new_data <= 1'b1;
            end
        end
    end
endmodule
