module UART_rcv(rx_data, rdy, clk, rst_n, RX, clr_rdy);

input clk, rst_n, RX, clr_rdy;
output logic [7:0] rx_data;
output logic rdy;           // High when output is ready and hasn't been read yet (clr_rdy)

typedef enum reg [1:0] { IDLE, START, RECV } state_t;
state_t state, nxt_state;   // State registers

reg [3:0] bit_cnt;          // Number of bits read in
reg [6:0] baud_cnt;         // Baud counter
reg [7:0] tmp_rx_data;      // Temporary register for received data
reg shift;                  // Sample RX and shift temporary rx register
reg RX_ff1, RX_ff2;         // flops for RX metastability
reg receiving, start, done; // Internal SM registers

// Double flop RX for metastability purposes
always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
				RX_ff1 <= 1'b0;
				RX_ff2 <= 1'b0;
		end else begin
		    RX_ff1 <= RX;
		    RX_ff2 <= RX_ff1;
		end
end

// State flops
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end

// Bit counter
always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
				bit_cnt <= 4'h0;
    else if (start)
        bit_cnt <= 4'h0;
    else if (shift)
        bit_cnt <= bit_cnt + 1;
end

// Baud counter
always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
        baud_cnt <= 7'h00;
    else if (start)
        baud_cnt <= 7'h00; // wait 1.5 baud periods upon start
    else if(shift)
        baud_cnt <= 7'h16; // wait 1 baud period (0x40 - 0x2A = 0x16)
    else if (receiving)
        baud_cnt <= baud_cnt + 1;
end

// Enter received frame into temporary register
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        tmp_rx_data <= 8'h00;
		else if(start)
				tmp_rx_data <= 8'h00;
    else if (shift && bit_cnt <= 4'h7) // Don't sample the stop bit
        tmp_rx_data <= { RX_ff2, tmp_rx_data[7:1]};
end

// Baud rate = 1 / 921,600 * 40 MHz - 1 = 42
// Starting shift = baud rate * 1.5 = 43*1.5-1 = 64 = 0x40
assign shift = (baud_cnt == 7'h40);

// Control rdy output
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        rdy = 1'b0;
		else if(clr_rdy || receiving)
        rdy = 1'b0;
    else if(done)
        rdy = 1'b1;
end

always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
				rx_data = 8'h00;
		else if(done && !receiving)
				rx_data = tmp_rx_data;
end

always_comb begin
    // Default values
    nxt_state = IDLE;
    start = 1'b0;
    done = 1'b0;
    receiving = 1'b0;
    case (state)
        IDLE : begin
            if(!RX_ff2) begin // start bit detected
                start = 1;
                nxt_state = START;
            end
        end
        START : begin // initialize everything
            receiving = 1'b1;
            if(shift)
                nxt_state = RECV;
            else
                nxt_state = START;
        end
        RECV : begin
            receiving = 1'b1;
            if(bit_cnt == 4'h9) begin // reached stop bit
                done = 1'b1; // rdy should go high
                receiving = 1'b0; // necessary for rdy to work correctly
                nxt_state = IDLE;
            end
            else // continue receiving
                nxt_state = RECV;
        end
    endcase
end

endmodule
