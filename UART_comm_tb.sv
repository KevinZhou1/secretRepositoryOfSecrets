module UART_comm_tb();

reg clk, rst_n, trmt; // UART, UART_comm inputs
reg RX; // UART input
reg [7:0] tx_data; // UART input
reg clr_cmd_rdy; // UART_comm input
wire TX, tx_done; // UART outputs
wire [23:0] cmd; // UART_comm output
wire cmd_rdy; // UART_comm output
reg fail;

assign RX = TX;

UART_comm iDUT(.cmd_rdy(cmd_rdy), .cmd(cmd), .TX(TX), .tx_done(tx_done),
                .clk(clk), .rst_n(rst_n), .clr_cmd_rdy(clr_cmd_rdy),
                .trmt(trmt), .RX(RX), .tx_data(tx_data));

initial clk = 0;
always
    #2 clk = ~clk; // 500 MHz clock

initial begin
    // Send first byte of command
    rst_n = 1;
    trmt = 0;
    tx_data = 8'h55;
    clr_cmd_rdy = 0;
    fail = 0;
    repeat(2) @(posedge clk);
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    @(posedge tx_done);
    // Send second byte of command
    tx_data = 8'haa;
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    @(posedge tx_done);
    // Send third byte of command
    tx_data = 8'he3;
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    @(posedge cmd_rdy);
    // Check that command was successfully read
    if(cmd != 24'h55aae3)
        fail = 1;
    clr_cmd_rdy = 1;
    @(posedge clk);
    clr_cmd_rdy = 0;
    @(posedge clk);
    if(cmd_rdy)
        fail = 1;
    // Check that rst_n works properly
    rst_n = 0;
    repeat(2) @(posedge clk);
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    repeat(2) @(posedge clk);
    // Check that state is still idle
    if(iDUT.state)
        fail = 1;
    $stop;
end

endmodule
