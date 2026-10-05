module spi_peripheral (
    // Internal system signals
    input wire clk,
    input wire rst_n,

    // External SPI signals
    input wire sclk,
    input wire copi,
    input wire ncs,

    // Registers sent to PWM module
    output reg [7:0] en_reg_out_7_0,
    output reg [7:0] en_reg_out_15_8,
    output reg [7:0] en_reg_pwm_7_0,
    output reg [7:0] en_reg_pwm_15_8,
    output reg [7:0] pwm_duty_cycle
);

    reg [4:0] bit_count; // Number of bits captured (0 to 16)
    reg [15:0] shift_reg; // Shift register to store 16 bit transaction

    // Two-FF synchronizer chain registers
    reg sclk_sync1, sclk_sync2;
    reg copi_sync1, copi_sync2;
    reg ncs_sync1, ncs_sync2;
    
    // Previous synchronized values for edge detection
    reg sclk_prev;
    reg ncs_prev;

    // Edge detection pulses
    wire sclk_rising;
    wire ncs_rising, ncs_falling;

    assign sclk_rising = !sclk_prev && sclk_sync2;
    assign ncs_rising = !ncs_prev && ncs_sync2;
    assign ncs_falling = ncs_prev && !ncs_sync2;

    // Validate transaction: 
    //  - All 16 bits received
    //  - R/W bit = 1 (ignore 0 for Read)
    wire transaction_valid;
    assign transaction_valid = (bit_count == 5'd16) && shift_reg[15];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync1 <= 1'b0;
            sclk_sync2 <= 1'b0;
            copi_sync1 <= 1'b0;
            copi_sync2 <= 1'b0;
            ncs_sync1 <= 1'b1; // transaction start when ncs = 0
            ncs_sync2 <= 1'b1;

            sclk_prev <= 1'b0;
            ncs_prev <= 1'b1;

            bit_count <= 5'd0;
            shift_reg <= 16'b0;
            
            en_reg_out_7_0 <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0 <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle <= 8'h00;
        end else begin
            // 2-FF synchronizer chain for: sclk, copi, ncs
            sclk_sync1 <= sclk;
            sclk_sync2 <= sclk_sync1;
            sclk_prev <= sclk_sync2;

            copi_sync1 <= copi;
            copi_sync2 <= copi_sync1;
            
            ncs_sync1 <= ncs;
            ncs_sync2 <= ncs_sync1;
            ncs_prev <= ncs_sync2;

            // Clear transaction storage
            if (ncs_falling) begin
                shift_reg <= 16'b0;
                bit_count <= 5'd0;

            // Capture next bit while SCLK rises and nCS is low 
            end else if  (sclk_rising && !ncs_sync2 && bit_count < 5'd16) begin
                shift_reg <= {shift_reg[14:0], copi_sync2};
                bit_count <= bit_count + 5'd1;
            
            // Validate transaction before updating register
            end else if (ncs_rising && transaction_valid) begin
                // Update the appropriate register based on address (shift_reg[14:8]). Case statement also handles address validation
                case (shift_reg[14:8])
                    7'h00: en_reg_out_7_0 <= shift_reg[7:0];
                    7'h01: en_reg_out_15_8 <= shift_reg[7:0];
                    7'h02: en_reg_pwm_7_0 <= shift_reg[7:0];
                    7'h03: en_reg_pwm_15_8 <= shift_reg[7:0];
                    7'h04: pwm_duty_cycle <= shift_reg[7:0];
                    default: begin end
                endcase
            end
        end
    end
endmodule