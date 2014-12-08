module UART_comm(cmd_rdy, clr_rdy, cmd, clk, rst_n, rdy, clr_cmd_rdy, trmt, rx_data);

input [7:0] rx_data;
input rdy, clr_cmd_rdy, trmt;
input clk, rst_n;
output logic cmd_rdy;
output clr_rdy;
output reg [23:0] cmd;

typedef enum reg [1:0] { IDLE, WAIT, WRITE } state_t;
state_t state, nxt_state;   // State registers

reg [1:0] cmd_byte_count; // Current cmd byte index
reg write; // Enable a write of a byte of cmd
reg write_done; // Indicate that reading of one byte is finished
reg start, done;

// We've successfully read the rx values after the write to the cmd
assign clr_rdy = write_done;

// State flops
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end

// Read in command
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        cmd <= 24'h000000;
    else if(clr_cmd_rdy)
        cmd <= 24'h000000;
    else if(write && !cmd_byte_count) // Read in first byte
        cmd[23:16] <= rx_data;
    else if(write && cmd_byte_count[0]) // Read in second byte
        cmd[15:8] <= rx_data;
    else if(write && cmd_byte_count[1]) // Read in third byte
        cmd[7:0] <= rx_data;
end

// Control cmd byte index
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        cmd_byte_count <= 2'b00;
    else if(start || done)
        cmd_byte_count <= 2'b00;
    else if(write_done) // Read in next byte of command
        cmd_byte_count <= cmd_byte_count + 1;
end

// Control cmd_rdy output
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        cmd_rdy <= 1'b0;
    else if(clr_cmd_rdy || start)
        cmd_rdy <= 1'b0;
    else if(done) // Finished reading in command
        cmd_rdy <= 1'b1;
end

// State machine
always_comb begin
    // Default values
    write = 1'b0;
    write_done = 1'b0;
    done = 1'b0;
    start = 1'b0;
    nxt_state = IDLE;
    case (state)
        IDLE : begin
            if(trmt) begin // Begin reading in command
                start = 1'b1;
                nxt_state = WAIT;
            end
        end
        WAIT : begin
            if(rdy) begin
                write = 1'b1;
                nxt_state = WRITE;
            end
            else
                nxt_state = WAIT;
        end
        WRITE : begin
            if(cmd_byte_count == 2'b10) begin
                done = 1'b1;
                nxt_state = IDLE;
            end else begin
                write_done = 1'b1;
                nxt_state = WAIT;
            end
        end
    endcase
end

endmodule
