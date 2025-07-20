`timescale 1ns / 1ps


module rc_pwm_capture #(
    parameter C_COUNTER_WIDTH = 32,
    parameter C_CLK_FREQ_HZ = 125_000_000 // self documentation
)(
    input wire sysclk, // 125 MHz PL clock
    input wire rst_n, // active low synchronous reset
    input wire rc_pwm_in,
    output reg [C_COUNTER_WIDTH-1:0] pulse_width, // last width in clock cycles
    output reg new_data // "data is ready" pulse
    );
    
    // three-FF synchroniser
    (* ASYNC_REG = "TRUE", IOB = "TRUE" *) reg sync_0;
    (* ASYNC_REG = "TRUE" *) reg sync_1;
    (* ASYNC_REG = "TRUE" *) reg sync_2;
    
    always @(posedge sysclk) begin
        if (!rst_n) begin
            sync_0 <= 1'b0;
            sync_1 <= 1'b0;
            sync_2 <= 1'b0;
        end else begin
            sync_0 <= rc_pwm_in;
            sync_1 <= sync_0;
            sync_2 <= sync_1;
        end
    end

    // syncd input
    wire pwm_sync = sync_2;
    
    // register delayed version of pwm_sync for clean edge detection
    reg pwm_sync_d;
    always @(posedge sysclk) begin
        if (!rst_n)
            pwm_sync_d <= 1'b0;
        else
            pwm_sync_d <= pwm_sync;
    end
    
    // detect edges on syncd signal
    wire rising = pwm_sync & ~pwm_sync_d;
    wire falling = ~pwm_sync & pwm_sync_d;
    
    // free-running counter (wrap @ 2^C_COUNTER_WIDTH)
    // 32-bit wraps @ 34.36 s
    reg[C_COUNTER_WIDTH-1:0] counter;
    always @(posedge sysclk) begin
        if (!rst_n)
            counter <= {C_COUNTER_WIDTH{1'b0}};
        else
            counter <= counter + 1'b1;
    end
    
    reg [C_COUNTER_WIDTH-1:0] t_start;
    
    always @(posedge sysclk) begin
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
