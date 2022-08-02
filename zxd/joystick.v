//-------------------------------------------------------------------------------------------------
module joystick
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       ce,

	output reg [ 7:0] joy1,
	output reg [ 7:0] joy2,

	output wire       joyS,
	output reg        joyCk,
	output reg        joyLd,
	input  wire       joyD
);
//-------------------------------------------------------------------------------------------------

initial joy1 = 8'h00;
initial joy2 = 8'h00;
initial joyCk = 1'b0;

reg[15:0] joyQ = 16'hFFFF;

//joya <= "11" & joy1fire2 & joy1fire1 & joy1right & joy1left & joy1down & joy1up;
//joyb <= "11" & joy2fire2 & joy2fire1 & joy2right & joy2left & joy2down & joy2up;

always @(posedge clock) if(ce)
if(joyQ[15:14] == 2'b00)
begin
	joyCk <= 1'b0;
	joyLd <= 1'b0;
	joyQ <= 16'hFFFF;
	joy1 <= { 2'b00, joyQ[ 5], joyQ[ 4], joyQ[3], joyQ[2], joyQ[ 1], joyQ[ 0] };
	joy2 <= { 2'b00, joyQ[13], joyQ[12], joyQ[11],joyQ[10],joyQ[ 9], joyQ[ 8] };
end
else
begin
	joyCk <= ~joyCk;
	if(!joyLd) joyLd <= 1'b1;
	if(joyCk) joyQ <= { joyQ[14:0], ~joyD };
end

//-------------------------------------------------------------------------------------------------

assign joyS = 1'b1;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
