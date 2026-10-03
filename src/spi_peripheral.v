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

    // Max address
    localparam [6:0] MAX_ADDRESS = 7'h04;

    // FSM states   
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] RECEIVE = 2'b01;
    localparam [1:0] VALIDATE = 2'b10;
    localparam [1:0] UPDATE = 2'b11;
    reg [1:0] state;
    reg [1:0] next_state;

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
    //  - Register address is valid
    wire transaction_valid;
    assign transaction_valid = (bit_count == 5'd16) && 
                               shift_reg[15] &&
                               (shift_reg[14:8] <= MAX_ADDRESS);

    // Combinational FSM next-state logic
    always @(*) begin
        next_state = state;

        case (state) 
            IDLE: begin
                if (ncs_falling)
                    next_state = RECEIVE;
            end

            RECEIVE: begin 
                if (ncs_rising)
                    next_state = VALIDATE;
            end

            VALIDATE: begin
                // Check if transaction is valid
                if (transaction_valid)
                    next_state = UPDATE;
                else
                    // Transition to IDLE state to prevent updating registers
                    next_state = IDLE; 
            end

            UPDATE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

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

            state <= IDLE;

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

            state <= next_state;

            case (state)
                IDLE: begin
                    if (ncs_falling) begin
                        shift_reg <= 16'b0;
                        bit_count <= 5'd0;
                    end
                end

                RECEIVE: begin
                    if (sclk_rising && !ncs_sync2 && bit_count < 5'd16) begin
                        shift_reg <= {shift_reg[14:0], copi_sync2};
                        bit_count <= bit_count + 5'b1;
                    end
                end

                VALIDATE: begin
                    // Validation is handled in the next-state logic
                end

                UPDATE: begin
                    // Update the appropriate register based on address (shift_reg[14:8])
                    case (shift_reg[14:8])
                        7'h00: en_reg_out_7_0 <= shift_reg[7:0];
                        7'h01: en_reg_out_15_8 <= shift_reg[7:0];
                        7'h02: en_reg_pwm_7_0 <= shift_reg[7:0];
                        7'h03: en_reg_pwm_15_8 <= shift_reg[7:0];
                        7'h04: pwm_duty_cycle <= shift_reg[7:0];
                        default: begin end
                    endcase
                end

                default: begin
                    // Back to IDLE
                end
            endcase
            
        end
    end
endmodule