module Oric (
	CLOCK_27,
	VGA_R,
	VGA_G,
	VGA_B,
	VGA_HS,
	VGA_VS,
	LED,
	TAPE_IN,
	UART_RX,
	UART_TX,
	AUDIO_L,
	AUDIO_R,
	DAC_L,
	DAC_R,
	SPI_SCK,
	SPI_DO,
	SPI_DI,
	SPI_SS2,
	SPI_SS3,
	CONF_DATA0,
	SDRAM_A,
	SDRAM_DQ,
	SDRAM_DQML,
	SDRAM_DQMH,
	SDRAM_nWE,
	SDRAM_nCAS,
	SDRAM_nRAS,
	SDRAM_nCS,
	SDRAM_BA,
	SDRAM_CLK,
	SDRAM_CKE
);
	input CLOCK_27;
	output wire [5:0] VGA_R;
	output wire [5:0] VGA_G;
	output wire [5:0] VGA_B;
	output wire VGA_HS;
	output wire VGA_VS;
	output wire LED;
	input TAPE_IN;
	input UART_RX;
	output wire UART_TX;
	output wire AUDIO_L;
	output wire AUDIO_R;
	output wire [15:0] DAC_L;
	output wire [15:0] DAC_R;
	input SPI_SCK;
	output wire SPI_DO;
	input SPI_DI;
	input SPI_SS2;
	input SPI_SS3;
	input CONF_DATA0;
	output wire [12:0] SDRAM_A;
	inout [15:0] SDRAM_DQ;
	output wire SDRAM_DQML;
	output wire SDRAM_DQMH;
	output wire SDRAM_nWE;
	output wire SDRAM_nCAS;
	output wire SDRAM_nRAS;
	output wire SDRAM_nCS;
	output wire [1:0] SDRAM_BA;
	output wire SDRAM_CLK;
	output wire SDRAM_CKE;
	localparam CONF_STR = {"ORIC;;", "S0,DSK,Mount Drive A:;", "O3,ROM,Oric Atmos,Oric 1;", "O6,FDD Controller,Off,On;", "O7,Drive Write,Allow,Prohibit;", "O45,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;", "O89,Stereo,Off,ABC (West Europe),ACB (East Europe);", "T0,Reset;", "V,v2.2-EDSK."};
	wire clk_72;
	wire clk_24;
	wire pll_locked;
	wire key_pressed;
	wire [7:0] key_code;
	wire key_strobe;
	wire key_extended;
	wire r;
	wire g;
	wire b;
	wire hs;
	wire vs;
	wire [1:0] buttons;
	wire [1:0] switches;
	wire ypbpr;
	wire scandoublerD;
	wire [31:0] status;
	wire [9:0] psg_out;
	wire [7:0] psg_a;
	wire [7:0] psg_b;
	wire [7:0] psg_c;
	wire [7:0] joystick_0;
	wire [7:0] joystick_1;
	wire tapebits;
	wire remote;
	reg reset;
	wire rom;
	wire old_rom;
	wire led_value;
	reg fdd_ready = 0;
	wire fdd_busy;
	reg fdd_layout = 0;
	reg fdd_reset = 0;
	wire disk_enable;
	reg old_disk_enable;
	assign disk_enable = status[6];
	assign rom = ~status[3];
	wire [1:0] stereo = status[9:8];
	assign LED = fdd_ready;
	always @(posedge clk_24) begin
		old_rom <= rom;
		old_disk_enable <= disk_enable;
		reset <= (((!pll_locked | status[0]) | buttons[0]) | (old_rom != rom)) | (old_disk_enable != disk_enable);
	end
	pll pll(
		.inclk0(CLOCK_27),
		.c0(clk_24),
		.c1(clk_72),
		.locked(pll_locked)
	);
	wire img_mounted;
	wire [31:0] img_size;
	wire sd_ack;
	wire sd_ack_conf;
	wire [8:0] sd_buff_addr;
	wire sd_conf;
	wire [7:0] sd_din;
	wire sd_din_strobe;
	wire [7:0] sd_dout;
	wire sd_dout_strobe;
	wire [31:0] sd_lba;
	wire sd_rd;
	wire sd_sdhc = 1'b1;
	wire sd_wr;
	user_io #(.STRLEN(228)) user_io(
		.clk_sys(clk_24),
		.clk_sd(clk_24),
		.conf_str(CONF_STR),
		.SPI_CLK(SPI_SCK),
		.SPI_SS_IO(CONF_DATA0),
		.SPI_MISO(SPI_DO),
		.SPI_MOSI(SPI_DI),
		.buttons(buttons),
		.switches(switches),
		.scandoubler_disable(scandoublerD),
		.ypbpr(ypbpr),
		.key_strobe(key_strobe),
		.key_pressed(key_pressed),
		.key_extended(key_extended),
		.key_code(key_code),
		.joystick_0(joystick_0),
		.joystick_1(joystick_1),
		.status(status),
		.sd_lba(sd_lba),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_ack(sd_ack),
		.sd_ack_conf(sd_ack_conf),
		.sd_conf(sd_conf),
		.sd_sdhc(sd_sdhc),
		.sd_dout(sd_dout),
		.sd_dout_strobe(sd_dout_strobe),
		.sd_din(sd_din),
		.sd_din_strobe(sd_din_strobe),
		.sd_buff_addr(sd_buff_addr),
		.img_mounted(img_mounted),
		.img_size(img_size)
	);
	mist_video #(.COLOR_DEPTH(1)) mist_video(
		.clk_sys(clk_24),
		.SPI_SCK(SPI_SCK),
		.SPI_SS3(SPI_SS3),
		.SPI_DI(SPI_DI),
		.R({r}),
		.G({g}),
		.B({b}),
		.HSync(hs),
		.VSync(vs),
		.VGA_R(VGA_R),
		.VGA_G(VGA_G),
		.VGA_B(VGA_B),
		.VGA_VS(VGA_VS),
		.VGA_HS(VGA_HS),
		.ce_divider(1'b0),
		.scandoubler_disable(scandoublerD),
		.scanlines((scandoublerD ? 2'b00 : status[5:4])),
		.ypbpr(ypbpr)
	);
	wire phi2;
	wire [15:0] ram_ad;
	wire ram_cs_oric;
	wire ram_cs = ram_cs_oric;
	wire [7:0] ram_d;
	wire ram_oe_oric;
	wire [7:0] ram_q;
	wire ram_we;
	oricatmos oricatmos(
		.clk_in(clk_24),
		.RESET(reset),
		.key_pressed(key_pressed),
		.key_code(key_code),
		.key_extended(key_extended),
		.key_strobe(key_strobe),
		.PSG_OUT(psg_out),
		.PSG_OUT_A(psg_a),
		.PSG_OUT_B(psg_b),
		.PSG_OUT_C(psg_c),
		.VIDEO_R(r),
		.VIDEO_G(g),
		.VIDEO_B(b),
		.VIDEO_HSYNC(hs),
		.VIDEO_VSYNC(vs),
		.K7_TAPEIN(TAPE_IN),
		.K7_TAPEOUT(UART_TX),
		.K7_REMOTE(remote),
		.ram_ad(ram_ad),
		.ram_d(ram_d),
		.ram_q((ram_cs ? ram_q : 8'd0)),
		.ram_cs(ram_cs_oric),
		.ram_oe(ram_oe_oric),
		.ram_we(ram_we),
		.joystick_0(joystick_0),
		.joystick_1(joystick_1),
		.fd_led(led_value),
		.fdd_ready(fdd_ready),
		.fdd_busy(fdd_busy),
		.fdd_reset(fdd_reset),
		.fdd_layout(fdd_layout),
		.phi2(phi2),
		.pll_locked(pll_locked),
		.disk_enable(disk_enable),
		.rom(rom),
		.img_mounted(img_mounted),
		.img_size(img_size),
		.img_wp(status[7]),
		.sd_lba(sd_lba),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_ack(sd_ack),
		.sd_buff_addr(sd_buff_addr),
		.sd_dout(sd_dout),
		.sd_din(sd_din),
		.sd_dout_strobe(sd_dout_strobe),
		.sd_din_strobe(sd_din_strobe)
	);
	reg port1_req;
	reg port2_req;
	wire ram_oe = ram_oe_oric;
	reg sdram_we;
	reg [15:0] sdram_ad;
	always @(posedge clk_72) begin : sv2v_autoblock_1
		reg ram_we_old;
		reg ram_oe_old;
		reg [15:0] ram_ad_old;
		ram_we_old <= ram_cs & ram_we;
		ram_oe_old <= ram_cs & ram_oe;
		ram_ad_old <= ram_ad;
		if ((((ram_cs & ram_oe) & ~ram_oe_old) || ((ram_cs & ram_we) & ~ram_we_old)) || ((ram_cs & ram_oe) & (ram_ad != ram_ad_old))) begin
			port1_req <= ~port1_req;
			sdram_ad <= ram_ad;
			sdram_we <= ram_we;
		end
	end
	assign SDRAM_CLK = clk_72;
	assign SDRAM_CKE = 1;
	sdram sdram(
		.*,
		.init_n(pll_locked),
		.clk(clk_72),
		.clkref(phi2),
		.port1_req(port1_req),
		.port1_ack(),
		.port1_a(ram_ad),
		.port1_ds((ram_we ? (sdram_ad[0] ? 2'b10 : 2'b01) : 2'b11)),
		.port1_we(sdram_we),
		.port1_d({ram_d, ram_d}),
		.port1_q(ram_q),
		.port2_req(port2_req),
		.port2_ack(),
		.port2_a(),
		.port2_ds(),
		.port2_we(),
		.port2_d(),
		.port2_q()
	);
	wire [15:0] psg_l;
	wire [15:0] psg_r;
	always @(psg_a or psg_b or psg_c or psg_out or stereo)
		case (stereo)
			2'b01: {psg_l, psg_r} <= {{{2'b00, psg_a} + {2'b00, psg_b}}, 6'b000000, {{2'b00, psg_c} + {2'b00, psg_b}}, 6'b000000};
			2'b10: {psg_l, psg_r} <= {{{2'b00, psg_a} + {2'b00, psg_c}}, 6'b000000, {{2'b00, psg_c} + {2'b00, psg_b}}, 6'b000000};
			default: {psg_l, psg_r} <= {psg_out, 6'b000000, psg_out, 6'b000000};
		endcase
	dac #(.c_bits(16)) audiodac_l(
		.clk_i(clk_24),
		.res_n_i(1),
		.dac_i(psg_l),
		.dac_o(AUDIO_L)
	);
	dac #(.c_bits(16)) audiodac_r(
		.clk_i(clk_24),
		.res_n_i(1),
		.dac_i(psg_r),
		.dac_o(AUDIO_R)
	);
	assign DAC_L = psg_l;
	assign DAC_R = psg_r;
	wire sd_buff_wr;
	wire [1:1] sv2v_tmp_A6993;
	assign sv2v_tmp_A6993 = status[1];
	always @(*) fdd_reset = sv2v_tmp_A6993;
	always @(posedge clk_24) begin : sv2v_autoblock_2
		reg old_mounted;
		old_mounted <= img_mounted;
		if (reset)
			fdd_ready <= 0;
		else if (~old_mounted & img_mounted)
			fdd_ready <= 1;
	end
endmodule
