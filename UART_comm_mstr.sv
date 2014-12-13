module UART_comm_mstr(clk, rst_n, RX, TX, cmd, send_cmd, cmd_sent, resp_rdy,
                 resp, clr_resp_rdy);
input clk, rst_n;
input [23:0] cmd;
input RX; // UART input
input clr_resp_rdy, send_cmd;
output TX, resp_rdy;
output [7:0] resp;
output logic cmd_sent; // UART output

typedef enum reg [2:0] { IDLE, START, LOAD, WAIT, WRITE, WRITE2 } state_t;
state_t state, nxt_state;   // State registers

reg [1:0] cmd_byte_count; // Current cmd byte index
reg trmt; // Enable a write of a byte of cmd
reg load, shift;
reg [23:0] buffer;
reg [7:0] tx_data;
wire tx_done;
assign write = trmt;

UART uart(.RX(RX), .clr_rdy(clr_resp_rdy), .trmt(trmt), .clk(clk), .rst_n(rst_n), 
          .tx_data(tx_data), .TX(TX), .tx_done(tx_done), .rdy(resp_rdy), .rx_data(resp));

// State flops
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end

// Write command
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        buffer <= 24'h000000;
    else if(send_cmd)
        buffer <= cmd;
    else if(load && !cmd_byte_count) // Write first byte
        tx_data <= cmd[23:16];
    else if(load && cmd_byte_count[0]) // Write second byte
        tx_data <= buffer[15:8];
    else if(load && cmd_byte_count[1]) // Write third byte
        tx_data <= buffer[7:0];
end

// Control cmd byte index
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        cmd_byte_count <= 2'b00;
    else if(send_cmd || cmd_sent)
        cmd_byte_count <= 2'b00;
    else if(shift) // Read in next byte of command
        cmd_byte_count <= cmd_byte_count + 1;
end

// State machine
always_comb begin
    // Default values
    load = 1'b0;
    shift = 1'b0;
    trmt = 1'b0;
    cmd_sent = 1'b0;
    nxt_state = IDLE;
    case (state)
        IDLE : begin
            cmd_sent = 1'b1;
            if(send_cmd) begin // Begin writing command
                nxt_state = START;
            end
        end
        START : begin
            load = 1'b1;
            nxt_state = LOAD;
        end
        LOAD : begin
            trmt = 1'b1;
            nxt_state = WAIT;
        end
        WAIT : begin
            if(tx_done) begin
                shift = 1'b1;
                nxt_state = WRITE;
            end
            else
                nxt_state = WAIT;
        end
        WRITE : begin
            if(cmd_byte_count == 2'b11)
                nxt_state = IDLE;
            else begin
                load = 1'b1;
                nxt_state = WRITE2;
            end
        end
        WRITE2 : begin
            trmt = 1'b1; // write next byte
            nxt_state = WAIT;
        end
    endcase
end

endmodule
