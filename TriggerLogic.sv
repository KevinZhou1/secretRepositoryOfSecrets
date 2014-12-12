//////////////////////////////////
//Jared Pierce and Maggie White//
////////////////////////////////

////////////////////////////////////////////////////////////////////
//Modules in this file:                                          //
//                                                              //
//  triggerModule -- Glorious Trigger Module.                  //
////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//triggerModule -- Glorious Trigger Module.                                                                   //
//                                                                                                           //
//Inputs:                                                                                                   //
//  clk -- The clock.                                                                                      //
//  rst_n -- Active-low reset signal.                                                                     //
//  trig1 -- First analog comparator output from the AFE.                                                //
//  trig2 -- Second analog comparator output from the AFE.                                              //
//  trigSrc -- Selects trigger source. 0 for trigger1, 1 for trigger2.                                 //
//  trigEdge -- Selects whether we are detecting a positive or negative edge from the trigger source. //
//  armed -- Input signal that allows triggered to be set iff at least (512 - trig_pos) have been    //
//           stored in the RAM.                                                                     //
//  trig_en -- Enables the triggering logic when the DSO is in a run mode.                         //
//  set_capture_done -- Clears the SR-flop.                                                       //
//                                                                                               //
//Outputs:                                                                                      //
//  triggered -- Signals that the trigger conditions have been satisfied.                      //
//                                                                                            //
//Notes:                                                                                     //
//  I expect that the Src and Edge selection signals will not change while enabled.         //
//  I do not know if there would be any problems, but I do not think settings should       //
//  be changed once the trigger function is enabled.                                      //
///////////////////////////////////////////////////////////////////////////////////////////
module triggerModule(clk, rst_n, trig1, trig2, trig_cfg, armed, trig_en, set_capture_done, triggered);

  input clk, rst_n;
  input trig1, trig2;
  input [7:0] trig_cfg;
  input armed, trig_en, set_capture_done;
  output logic triggered;

  logic triggerPreFF, trigger_FF1, trigger_FF2, trigger_FF3; 
  logic trigPos, trigNeg;
  logic trigLogic, trig_set;

  assign trigSrc = trig_cfg[0];
  assign trigEdge = trig_cfg[4];
  assign capture_done = trig_cfg[5];
  
  //The SR flop input mechanism and the trigger conditions AND gate.
  //Consider moving SR logic to the flop block.
  assign trigLogic = ~(set_capture_done|~((trig_set&armed&trig_en)|triggered));

  //Edge detection on the selected trigger source.
  assign trigPos = trigger_FF2&(~trigger_FF3);
  assign trigNeg = (~trigger_FF2)&trigger_FF3;

  //Trigger source selection mux.
  assign triggerPreFF = (trigSrc)	?	trig2	:	trig1;

  //Trigger edge selection mux.
  assign trig_set = ((trigEdge)	?	trigPos	:	trigNeg);

  /////////////////////////////////////////////////
  //Meta-stability flopping of trigger inputs.  //
  //Extra flop to use in edge detection logic. //
  //////////////////////////////////////////////
  always @(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
      trigger_FF1 <= 0;
      trigger_FF2 <= 0;
      trigger_FF3 <= 0;
    end else begin
      trigger_FF1 <= triggerPreFF;
      trigger_FF2 <= trigger_FF1;
      trigger_FF3 <= trigger_FF2;
    end
  end

  //////////////////////////////////////////////
  //Flop at the core of the SR-flop logic.   //
  ////////////////////////////////////////////
  always @(posedge clk, negedge rst_n)begin
    if(~rst_n)
      triggered <= 0;
    else
      triggered <= trigLogic;
  end

endmodule

