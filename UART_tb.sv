`timescale 1ns/1ps
module UART_tb();

reg RX, clr_rdy, trmt;
reg clk, rst_n;
reg [7:0] tx_data;
wire TX, tx_done, rdy;
wire [7:0] rx_data;
reg fail;

assign RX = TX;

UART iDUT(.RX(RX), .clr_rdy(clr_rdy), .trmt(trmt), .clk(clk), .rst_n(rst_n), 
          .tx_data(tx_data), .TX(TX), .tx_done(tx_done), .rdy(rdy), .rx_data(rx_data));

initial clk = 0;
always
    #2 clk = ~clk; // 40 MHz clock

initial begin
    // Check that reset works first
    rst_n = 0;
    trmt = 0;
    tx_data = 8'h55;
    fail = 0;
    clr_rdy = 0;
    repeat(2) @(posedge clk);
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    repeat(2) @(posedge clk);
    // Check that transmission has not started
    if(TX === 0)
        fail = 1;
		@(negedge clk);
    // Check that regular transmission works
    rst_n = 1;
    repeat(2) @(posedge clk);
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    @(posedge rdy);
    if(rx_data !== tx_data)
        fail = 1;
    @(posedge tx_done);
    // Check second consecutive frame
    tx_data = 8'haa;
    trmt = 1;
    @(posedge clk);
    trmt = 0;
    @(posedge rdy);
    if(rx_data !== tx_data)
        fail = 1;
    @(posedge tx_done);
    // Check that clr_rdy clears rdy
    clr_rdy = 1;
    @(posedge clk);
    clr_rdy = 0;
    @(posedge clk);
    if(rdy !== 0)
        fail = 1;
    $stop;
end
    
endmodule
