module UART_tx(TX, tx_done, clk, rst_n, tx_data, trmt);

input clk, rst_n, trmt;
input [7:0] tx_data;
output TX;
output logic tx_done;

reg [3:0] bit_cnt;
reg [5:0] baud_cnt;
reg [9:0] tx_shft_reg;
reg load, shift, transmitting;

typedef enum reg [1:0] { IDLE, START, TRANS, STOP } state_t;
state_t state, nxt_state;

always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end

always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
        bit_cnt <= 4'h0;
    else if (load)
        bit_cnt <= 4'h0;
    else if (shift)
        bit_cnt <= bit_cnt + 1;
end

// Increase baud_cnt
always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
        baud_cnt <= 6'h00;
    else if (load || shift)
        baud_cnt <= 6'h00;
    else if (transmitting)
        baud_cnt <= baud_cnt + 1;
end

// Shift every 43-1/0x2A clock cycles
assign shift = (baud_cnt == 6'h2A); // 1 / 921,600 * 40 MHz - 1 = 42

// Either load the transmit register or shift new value into TX
always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
        tx_shft_reg <= 10'h001;
    else if (load)
        tx_shft_reg <= { 1'b1, tx_data, 1'b0 };
    else if (shift)
        tx_shft_reg <= { 1'b1,  tx_shft_reg[9:1] };
end

assign TX = tx_shft_reg[0];

always_comb begin
    load = 1'b0;
    transmitting = 1'b0;
    nxt_state = IDLE;
    tx_done = 1'b1;
    case (state)
        IDLE : begin
            if(trmt)
                nxt_state = START;
        end
        START : begin // load registers with initial values
            load = 1'b1;
            tx_done = 1'b0;
            nxt_state = TRANS;
        end
        TRANS : begin
            transmitting = 1'b1;
            tx_done = 1'b0;
            if (bit_cnt == 9)
                nxt_state = STOP;
            else
                nxt_state = TRANS;
        end
        STOP : begin
            tx_done = 1'b0;
            transmitting = 1'b1;
            if (shift)
                nxt_state = IDLE;
            else
                nxt_state = STOP;
        end
    endcase
end

endmodule
