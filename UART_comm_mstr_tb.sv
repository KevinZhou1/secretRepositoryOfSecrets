module UART_comm_mstr_tb();

reg clk, rst_n;
reg [23:0] cmd;
reg RX; // UART input
reg clr_resp_rdy, send_cmd;
wire TX, resp_rdy;
wire [7:0] resp;
wire cmd_sent; // UART output
reg fail;

assign RX = TX;

UART_comm_mstr iDUT(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .cmd(cmd),
                    .send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy),
                    .resp(resp), .clr_resp_rdy(clr_resp_rdy));

initial clk = 0;
always
    #2 clk = ~clk; // 500 MHz clock

initial begin
    // Send command
    rst_n = 1;
    cmd = 24'h55aa34;
    send_cmd = 0;
    fail = 0;
    clr_resp_rdy = 0;
    @(posedge clk);
    send_cmd = 1;
    @(posedge clk);
    send_cmd = 0;
    @(posedge resp_rdy);
    if(resp !== 8'h55) // Check first byte
        fail = 1;
    @(posedge resp_rdy);
    if(resp !== 8'haa) // Check second byte
        fail = 1;
    @(posedge resp_rdy);
    if(resp !== 8'h34) // Check third byte
        fail = 1;
    @(posedge cmd_sent);
    clr_resp_rdy = 1'b1;
    @(posedge clk);
    clr_resp_rdy = 1'b0;
    @(posedge clk);
    if(resp_rdy) // Check that clr_resp_rdy works
        fail = 1;
    @(posedge clk);
    // Check that rst_n works properly
    rst_n = 0;
    @(posedge clk);
    send_cmd = 1;
    @(posedge clk);
    send_cmd = 0;
    repeat(2) @(posedge clk);
    // Check that state is still idle
    if(iDUT.state)
        fail = 1;
    $stop;
end

endmodule
