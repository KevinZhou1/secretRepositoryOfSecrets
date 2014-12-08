module UART(tx_done, rx_data, rdy, TX, clk, rst_n, RX, trmt, tx_data, clr_rdy);

input RX, clr_rdy, trmt;
input clk, rst_n;
input [7:0] tx_data;
output TX, tx_done, rdy;
output [7:0] rx_data;

UART_tx tx (.clk(clk), .rst_n(rst_n), .trmt(trmt), .TX(TX), .tx_done(tx_done), .tx_data(tx_data));
UART_rcv rx (.clk(clk), .rst_n(rst_n), .RX(RX), .clr_rdy(clr_rdy), .rx_data(rx_data), .rdy(rdy));

endmodule
