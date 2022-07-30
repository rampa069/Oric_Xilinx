module keyboard (
	clk_sys,
	key_pressed,
	key_extended,
	key_strobe,
	key_code,
	row,
	col,
	key_hit,
	swrst,
	swnmi
);
	input clk_sys;
	input key_pressed;
	input key_extended;
	input key_strobe;
	input [7:0] key_code;
	input [2:0] row;
	input [7:0] col;
	output wire key_hit;
	output reg swrst;
	output reg swnmi;
	reg sw0 = 1'b0;
	reg sw1 = 1'b0;
	reg sw2 = 1'b0;
	reg sw3 = 1'b0;
	reg sw4 = 1'b0;
	reg sw5 = 1'b0;
	reg sw6 = 1'b0;
	reg sw7 = 1'b0;
	reg sw8 = 1'b0;
	reg sw9 = 1'b0;
	reg swa = 1'b0;
	reg swb = 1'b0;
	reg swc = 1'b0;
	reg swd = 1'b0;
	reg swe = 1'b0;
	reg swf = 1'b0;
	reg swg = 1'b0;
	reg swh = 1'b0;
	reg swi = 1'b0;
	reg swj = 1'b0;
	reg swk = 1'b0;
	reg swl = 1'b0;
	reg swm = 1'b0;
	reg swn = 1'b0;
	reg swo = 1'b0;
	reg swp = 1'b0;
	reg swq = 1'b0;
	reg swr = 1'b0;
	reg sws = 1'b0;
	reg swt = 1'b0;
	reg swu = 1'b0;
	reg swv = 1'b0;
	reg sww = 1'b0;
	reg swx = 1'b0;
	reg swy = 1'b0;
	reg swz = 1'b0;
	reg swU = 1'b0;
	reg swD = 1'b0;
	reg swL = 1'b0;
	reg swR = 1'b0;
	reg swrs = 1'b0;
	reg swls = 1'b0;
	reg swsp = 1'b0;
	reg swcom = 1'b0;
	reg swdot = 1'b0;
	reg swret = 1'b0;
	reg swfs = 1'b0;
	reg sweq = 1'b0;
	reg swfcn = 1'b0;
	reg swdel = 1'b0;
	reg swrsb = 1'b0;
	reg swlsb = 1'b0;
	reg swbs = 1'b0;
	reg swdsh = 1'b0;
	reg swsq = 1'b0;
	reg swsc = 1'b0;
	reg swesc = 1'b0;
	reg swctl = 1'b0;
	reg swf1 = 1'b0;
	reg swf2 = 1'b0;
	reg swf3 = 1'b0;
	reg swf4 = 1'b0;
	reg swf5 = 1'b0;
	reg swf6 = 1'b0;
	always @(posedge clk_sys)
		if (key_strobe)
			casex (key_code)
				'h45: sw0 <= key_pressed;
				'h16: sw1 <= key_pressed;
				'h1e: sw2 <= key_pressed;
				'h26: sw3 <= key_pressed;
				'h25: sw4 <= key_pressed;
				'h2e: sw5 <= key_pressed;
				'h36: sw6 <= key_pressed;
				'h3d: sw7 <= key_pressed;
				'h3e: sw8 <= key_pressed;
				'h46: sw9 <= key_pressed;
				'h1c: swa <= key_pressed;
				'h32: swb <= key_pressed;
				'h21: swc <= key_pressed;
				'h23: swd <= key_pressed;
				'h24: swe <= key_pressed;
				'h2b: swf <= key_pressed;
				'h34: swg <= key_pressed;
				'h33: swh <= key_pressed;
				'h43: swi <= key_pressed;
				'h3b: swj <= key_pressed;
				'h42: swk <= key_pressed;
				'h4b: swl <= key_pressed;
				'h3a: swm <= key_pressed;
				'h31: swn <= key_pressed;
				'h44: swo <= key_pressed;
				'h4d: swp <= key_pressed;
				'h15: swq <= key_pressed;
				'h2d: swr <= key_pressed;
				'h1b: sws <= key_pressed;
				'h2c: swt <= key_pressed;
				'h3c: swu <= key_pressed;
				'h2a: swv <= key_pressed;
				'h1d: sww <= key_pressed;
				'h22: swx <= key_pressed;
				'h35: swy <= key_pressed;
				'h1a: swz <= key_pressed;
				'hx75: swU <= key_pressed;
				'hx72: swD <= key_pressed;
				'hx6b: swL <= key_pressed;
				'hx74: swR <= key_pressed;
				'h59: swrs <= key_pressed;
				'h12: swls <= key_pressed;
				'h29: swsp <= key_pressed;
				'h41: swcom <= key_pressed;
				'h49: swdot <= key_pressed;
				'h5a: swret <= key_pressed;
				'h4a: swfs <= key_pressed;
				'h55: sweq <= key_pressed;
				'h11: swfcn <= key_pressed;
				'hx66: swdel <= key_pressed;
				'hx71: swdel <= key_pressed;
				'h5b: swrsb <= key_pressed;
				'h54: swlsb <= key_pressed;
				'h5d: swbs <= key_pressed;
				'h4e: swdsh <= key_pressed;
				'h52: swsq <= key_pressed;
				'h4c: swsc <= key_pressed;
				'h76: swesc <= key_pressed;
				'h14: swctl <= key_pressed;
				'h78: swrst <= key_pressed;
				'h9: swnmi <= key_pressed;
				'h5: swf1 <= key_pressed;
				'h6: swf2 <= key_pressed;
				'h4: swf3 <= key_pressed;
				'hc: swf4 <= key_pressed;
				'h3: swf5 <= key_pressed;
				'hb: swf6 <= key_pressed;
			endcase
	reg [7:0] pressed;
	always @(posedge clk_sys)
		case (row)
			3'b000: pressed <= ~{sw3, swx, sw1, swf6, swv, sw5, swn, sw7};
			3'b001: pressed <= ~{swd, swq, swesc, swf5, swf, swr, swt, swj};
			3'b010: pressed <= ~{swc, sw2, swz, swctl, sw4, swb, sw6, swm};
			3'b011: pressed <= ~{swsq, swbs, swf3, swf4, swdsh, swsc, sw9, swk};
			3'b100: pressed <= ~{swR, swD, swL, swls, swU, swdot, swcom, swsp};
			3'b101: pressed <= ~{swlsb, swrsb, swdel, swfcn, swp, swo, swi, swu};
			3'b110: pressed <= ~{sww, sws, swa, swf2, swe, swg, swh, swy};
			3'b111: pressed <= ~{sweq, swf1, swret, swrs, swfs, sw0, swl, sw8};
		endcase
	assign key_hit = (pressed | col) != 8'hff;
endmodule
