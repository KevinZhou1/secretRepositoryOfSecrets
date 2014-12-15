///////////////////////////
// Define command bytes //
/////////////////////////
localparam DUMP_CH  = 8'h01;		// Channel to dump specified in low 2-bits of second byte
localparam CFG_GAIN = 8'h02;		// Gain setting in bits [4:2], and channel in [1:0] of 2nd byte
localparam TRIG_LVL = 8'h03;		// Set trigger level, lower byte specifies value (46,201) is valid
localparam TRIG_POS = 8'h04;		// Set the trigger position. This is a 13-bit number, samples after capture
localparam SET_DEC  = 8'h05;		// Set decimator, lower nibble of 3rd byte. 2^this value is decimator
localparam TRIG_CFG = 8'h06;		// Write trig config.  2nd byte 00dettcc.  d=done, e=edge,
localparam TRIG_RD  = 8'h07;		// Read trig config register
localparam EEP_WRT  = 8'h08;		// Write calibration EEP, 2nd byte is address, 3rd byte is data
localparam EEP_RD   = 8'h09;		// Read calibration EEP, 2nd byte specifies address
assign resp = resp_rcv;

task gen_init;
    begin
    rst_n = 1'b0;
    repeat(2) @(posedge clk);
    rst_n = 1'b1;
    end
endtask

task init_UART_comm_mstr;
    begin
    $display("begin UART init...");
    cmd_snd = 24'h000000;
    send_cmd = 1'b0;
    clr_resp_rdy = 1'b1;
    repeat(2) @(posedge clk);
    clr_resp_rdy = 1'b0;
    end
endtask

task send_UART_mstr_cmd;
    input [23:0] temp_cmd;
    begin
    cmd_snd = temp_cmd;
    send_cmd = 1'b1;
    clr_resp_rdy = 1'b0;
    @(posedge clk);
    send_cmd = 1'b0;
    @(posedge cmd_sent);
    end
endtask

task send_cfg_gain_cmd;
    input [2:0] ggg; // analog gain value
    input [1:0] cc;  // channel select
    input valid;     //check for positive or negative ack?
    begin
    $display("begin send cfg_gain_cmd...");
    send_UART_mstr_cmd({CFG_GAIN, 3'h0, ggg, cc, 8'hxx});
    if(valid)
        check_UART_pos_ack();
    else
        check_UART_neg_ack();
    end
endtask

task send_trig_lvl_cmd;
    input [7:0] LL; // trigger level value
    input valid;
    begin
    $display("begin send_trig_lvl_cmd...");
    send_UART_mstr_cmd({TRIG_LVL, 8'hxx, LL});
    if(valid)
        check_UART_pos_ack();
    else
        check_UART_neg_ack();
    end
endtask

task send_trig_pos_cmd;
    input [8:0] ULL; // trigger position value
    input valid;
    begin
    $display("begin send_trig_pos_cmd...");
    send_UART_mstr_cmd({TRIG_POS, 7'h00, ULL});
    if(valid)
        check_UART_pos_ack();
    else
        check_UART_neg_ack();
    if(iDUT.idig_core.trig_pos !== ULL)
        $display("Expected trig_pos = 0x%h, actual 0x%h", ULL,
                 iDUT.idig_core.trig_pos);
    end
endtask

task send_set_dec_cmd;
    input [3:0] L; // decimator
    input valid;
    begin
    $display("begin set_dec_cmd...");
    send_UART_mstr_cmd({SET_DEC, 8'hxx, 4'h0, L});
    if(valid)
        check_UART_pos_ack();
    else
        check_UART_neg_ack();
    if(iDUT.idig_core.decimator !== L)
        $display("Expected decimator value = 0x%h, actual 0x%h", L,
                 iDUT.idig_core.decimator);
    end
endtask

task send_trig_cfg_cmd;
    input d; // capture_done
    input e; // edge type, 1 == positive edge, 0 == negative edge
    input [1:0] tt; // trigger type, 10 = auto roll, 01 = normal, 00 = off
    input [1:0] cc; // channel select, 00 = channel 1, 01 = channel
    input valid;
    begin
    $display("begin send_trig_cfg_cmd...");
    send_UART_mstr_cmd({TRIG_CFG, 2'b00, d, e, tt, cc, 8'hxx});
    if(valid)
        check_UART_pos_ack();
    else
        check_UART_neg_ack();
    if(iDUT.idig_core.trig_cfg !== {2'b00, d, e, tt, cc})
        $display("Expected trig_cfg value = 0x%h, actual 0x%h", L,
                 iDUT.idig_core.trig_cfg);
    end
endtask

task send_rd_trig_cfg_cmd;
    input d; // expected capture_done
    input e; // expected edge type, 1 == positive edge, 0 == negative edge
    input [1:0] tt; // expected trigger type, 10 = auto roll, 01 = normal, 00 = off
    input [1:0] cc; // expected channel select, 00 = channel 1, 01 = channel
    begin
    $display("begin send_rd_trig_cfg_cmd...");
    send_UART_mstr_cmd({TRIG_RD, 16'hxxxx});
    check_UART_resp({2'b00, d, e, tt, cc});
    end
endtask

task send_eep_wrt_cmd;
    input [5:0] aaaaaa; // calibration address
    input [7:0] VV; // EEPROM calibration data
    input valid;
    begin
    $display("begin send_eep_wrt_cmd...");
    send_UART_mstr_cmd({EEP_WRT, 2'h0, aaaaaa, VV});
    if(valid)
        check_UART_pos_ack();
    else
        check_UART_neg_ack();
    end
endtask

task send_eep_rd_cmd;
    input [5:0] aaaaaa;
    input [7:0] expected;
    begin
    $display("begin send_eep_rd_cmd...");
    send_UART_mstr_cmd({EEP_RD, 2'h0, aaaaaa, 8'h00});
    check_UART_resp(expected);
    end
endtask

task check_UART_pos_ack;
    begin
    @(posedge resp_rdy);
    if(resp_rcv === 8'hEE)
        $display("DIG UART sent a neg ack (you want a pos ack) :(\n");
    else if(resp_rcv !== 8'hA5)
        $display("DIG UART sent 0x%h instead of pos ack\n", resp);
    clr_resp_rdy = 1'b1;
    @(posedge clk);
    clr_resp_rdy = 1'b0;
    @(posedge clk);
    if(resp_rdy !== 1'b0)
        $display("DIG UART resp_rdy didn't clear");
    end
endtask

task check_UART_neg_ack;
    begin
    @(posedge resp_rdy);
    if(resp_rcv === 8'hA5)
        $display("DIG UART sent a pos ack (you want a neg ack) :(\n");
    else if(resp_rcv !== 8'hEE)
        $display("DIG UART sent 0x%h instead of neg ack\n", resp);
    clr_resp_rdy = 1'b1;
    @(posedge clk);
    clr_resp_rdy = 1'b0;
    @(posedge clk);
    if(resp_rdy !== 1'b0)
        $display("DIG UART resp_rdy didn't clear");
    end
endtask

task check_UART_resp;
    input [7:0] expected;
    begin
    @(posedge resp_rdy);
    if(resp_rcv === 8'hEE)
        $display("DIG UART sent a neg ack :(\n");
    else if(resp_rcv !== expected)
        $display("DIG UART gave you output 0x%h. You want output 0x%h\n", resp, expected);
    clr_resp_rdy = 1'b1;
    @(posedge clk);
    clr_resp_rdy = 1'b0;
    @(posedge clk);
    if(resp_rdy !== 1'b0)
        $display("DIG UART resp_rdy didn't clear");
    end
endtask