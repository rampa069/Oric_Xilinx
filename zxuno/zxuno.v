//-------------------------------------------------------------------------------------------------
module zxd
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire        VGA_VS,
   output wire        VGA_HS,
	output wire[ 2:0]  VGA_R,
  	output wire[ 2:0]  VGA_G,
	output wire[ 2:0]  VGA_B,
	
	output wire       VGA_NTSC,
	output wire       VGA_PAL,

	inout  wire       ps2kCk,
	inout  wire       ps2kDQ,

	output wire       sdcCs,
	output wire       sdcCk,
	output wire       sdcMosi,
	input  wire       sdcMiso,
	
	output wire       sramWe,
	inout  wire[7:0]  sramDQ,
	output wire[18:0] sramA,
	
   output wire       AUDIO_L,
	output wire       AUDIO_R,
	input  wire       tape,   
	output wire       led
);

`default_nettype none

//-------------------------------------------------------------------------------------------------

wire clk_sys,pll_locked;

clock clock
( .CLK_IN1 (clock50),
  .RESET   (1'b0),
  .CLK_OUT1(clk_sys),
  .LOCKED  (pll_locked)
);


//------------------------------------------------------------------------------------------------

wire [7:0] joy_0, joy_1;
/*assign joyS=hs;

joystick Joystick
(
   .clock (clk_sys),
	.ce    (clk_sys),
	.joy1  (joy_0),
	.joy2  (joy_1),
	.joyS  (),
	.joyCk (joyCk),
	.joyLd (joyLd),
	.joyD  (joyD)
	
);
*/
//-------------------------------------------------------------------------------------------------

wire SPI_SCK = sdcCk;
wire SPI_SS2;
wire SPI_SS3;
wire SPI_SS4;
wire CONF_DATA_0;
wire SPI_DO;
wire SPI_DI;

wire kbiCk = ps2kCk;
wire kbiDQ = ps2kDQ;
wire kboCk; assign ps2kCk = kboCk ? 1'bZ : kboCk;
wire kboDQ; assign ps2kDQ = kboDQ ? 1'bZ : kboDQ;

substitute_mcu #(.sysclk_frequency(240)) controller
(
	.clk          (clk_sys),
	.reset_in     (1'b1   ),
	.reset_out    (       ),
	.spi_cs       (sdcCs  ),
	.spi_clk      (sdcCk  ),
	.spi_mosi     (sdcMosi),
	.spi_miso     (sdcMiso),
	.spi_req      (       ),
	.spi_ack      (1'b1   ),
	.spi_ss2      (SPI_SS2 ),
	.spi_ss3      (SPI_SS3 ),
	.spi_ss4      (SPI_SS4 ),
	.conf_data0   (CONF_DATA_0),
	.spi_toguest  (SPI_DI),
	.spi_fromguest(SPI_DO),
	.ps2k_clk_in  (kbiCk  ),
	.ps2k_dat_in  (kbiDQ  ),
	.ps2k_clk_out (kboCk  ),
	.ps2k_dat_out (kboDQ  ),
	.ps2m_clk_in  (1'b1   ),
	.ps2m_dat_in  (1'b1   ),
	.ps2m_clk_out (       ),
	.ps2m_dat_out (       ),
	.joy1         (8'hFF  ),
	.joy2         (8'hFF  ),
	.joy3         (8'hFF  ),
	.joy4         (8'hFF  ),
	.buttons      (8'hFF  ),
	.rxd          (1'b0   ),
	.txd          (       ),
	.intercept    (       ),
	.c64_keys     (64'hFFFFFFFF)
);


//-------------------------------------------------------------------------------------------------

localparam CONF_STR = {
        "ORIC;;",
        "S0,DSK,Mount Drive A:;",
        "O3,ROM,Oric Atmos,Oric 1;",
        "O6,FDD Controller,Off,On;",
        "O7,Drive Write,Allow,Prohibit;",
        "O45,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
        "O89,Stereo,Off,ABC (West Europe),ACB (East Europe);",
        "T0,Reset;",
        "V,v2.2-EDSK."
};

wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;
wire        r, g, b;
wire        hs, vs;

wire  [1:0] buttons, switches;
wire                    ypbpr;
wire        scandoublerD;
wire [63:0] status;

wire [9:0]  psg_out;
wire [7:0]  psg_a;
wire [7:0]  psg_b;
wire [7:0]  psg_c;

wire [7:0]  joystick_0;
wire [7:0]  joystick_1;

wire        tapebits;
wire        remote;
reg         reset;

wire        rom;
reg         old_rom;

wire        led_value;
reg         fdd_ready;
wire        fdd_busy;
reg         fdd_layout;
wire        fdd_reset ;

wire        disk_enable;
reg         old_disk_enable;

assign      disk_enable = status[6];
assign      rom = ~status[3] ;
wire [1:0]  stereo = status[9:8];


wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire        sd_ack;
wire        sd_ack_conf;
wire        sd_conf;
wire        sd_sdhc = 1'b1;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_dout;
wire  [7:0] sd_din;
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire [63:0] img_size;
wire        sd_dout_strobe;
wire        sd_din_strobe;

always @(posedge clk_sys) begin
        old_rom <= rom;
        old_disk_enable <= disk_enable;
        reset <= (!pll_locked | status[0] | buttons[0] | old_rom != rom |old_disk_enable != disk_enable);
end


user_io #(.STRLEN (1824>>3),.SD_IMAGES(1)) user_io
(
        .clk_sys                (clk_sys       ),
        .clk_sd                 (clk_sys       ),
        .conf_str               (CONF_STR      ),
        .SPI_CLK                (SPI_SCK       ),
        .SPI_SS_IO              (CONF_DATA_0   ),
        .SPI_MISO               (SPI_DO        ),
        .SPI_MOSI               (SPI_DI        ),
        .buttons                (buttons       ),
        .switches               (switches      ),
        .scandoubler_disable    (scandoublerD  ),
        .ypbpr                  (ypbpr         ),
        .key_strobe             (key_strobe    ),
        .key_pressed            (key_pressed   ),
        .key_extended           (key_extended  ),
        .key_code               (key_code      ),
        .joystick_0             ( joystick_0   ),
        .joystick_1             ( joystick_1   ),
        .status                 (status        ),
        // SD CARD
        .sd_lba                 (sd_lba        ),
        .sd_rd                  (sd_rd         ),
        .sd_wr                  (sd_wr         ),
        .sd_ack                 (sd_ack        ),
        .sd_ack_conf            (sd_ack_conf   ),
        .sd_conf                (sd_conf       ),
        .sd_sdhc                (sd_sdhc       ),
        .sd_dout                (sd_dout       ),
        .sd_dout_strobe         (sd_dout_strobe),
        .sd_din                 (sd_din        ),
        .sd_din_strobe          (sd_din_strobe ),
        .sd_buff_addr            (sd_buff_addr  ),
        .img_mounted            (img_mounted   ),
        .img_size               (img_size      )
);

/////////////////  RESET  /////////////////////////

wire keyb_reset;// = (ctrl&alt&del);


wire hard_reset; // = status[1] |(ctrl&alt&bs);

multiboot #(.ADDR(24'h058000)) Multiboot
(
	.clock(clk_sys),
	.boot(hard_reset)
);



reg [15:0] psg_l;
reg [15:0] psg_r;

always @ (psg_a,psg_b,psg_c,psg_out,stereo) begin
                case (stereo)
                        2'b01  : {psg_l,psg_r} <= {{{2'b0,psg_a} + {2'b0,psg_b}},6'b0,{{2'b0,psg_c} + {2'b0,psg_b}},6'b0};
                        2'b10  : {psg_l,psg_r} <= {{{2'b0,psg_a} + {2'b0,psg_c}},6'b0,{{2'b0,psg_c} + {2'b0,psg_b}},6'b0};
                        default: {psg_l,psg_r} <= {psg_out,6'b0,psg_out,6'b0};

                endcase
end

dac #(16) dac_l (
   .clk_i        (clk_sys),
   .res_n_i      (1'b1   ),
   .dac_i        (psg_l),
   .dac_o        (AUDIO_L)
);

dac #(16) dac_r (
   .clk_i        (clk_sys),
   .res_n_i      (1'b1   ),
   .dac_i        (psg_r  ),
   .dac_o        (AUDIO_R)
);

/////////////////  Memory  ////////////////////////


assign sramA = {3'b0,ram_ad};
assign sramWe = ~ram_we;
assign sramDQ = sramWe ? 8'bZ : ram_d;
assign ram_q = sramDQ;



//-------------------------------------------------------------------------------------------------
wire [5:0] TMP_R,TMP_G,TMP_B;

mist_video #(.COLOR_DEPTH(1)) mist_video(
        .clk_sys      (clk_sys     ),
        .SPI_SCK      (SPI_SCK    ),
        .SPI_SS3      (SPI_SS3    ),
        .SPI_DI       (SPI_DI     ),
        .R            ({r}    ),
        .G            ({g}    ),
        .B            ({b}    ),
        .HSync        (hs         ),
        .VSync        (vs         ),
        .VGA_R        (TMP_R      ),
        .VGA_G        (TMP_G      ),
        .VGA_B        (TMP_B      ),
        .VGA_VS       (VGA_VS     ),
        .VGA_HS       (VGA_HS     ),
        .ce_divider   (1'b0       ),
        .scandoubler_disable(scandoublerD       ),
        .scanlines    (scandoublerD ? 2'b00 : status[5:4]),
        .ypbpr        (ypbpr       )
        );

assign VGA_R=TMP_R[5:3];
assign VGA_G=TMP_G[5:3];
assign VGA_B=TMP_B[5:3];
//-------------------------------------------------------------------------------------------------
wire [15:0] ram_ad;
wire  [7:0] ram_d;
wire  [7:0] ram_q;
wire        ram_cs_oric, ram_oe_oric, ram_we;
wire        ram_oe = ram_oe_oric;
wire        ram_cs = ram_cs_oric ;
wire        phi2;

oricatmos oricatmos(
        .clk_in           (clk_sys       ),
        .RESET            (reset),
        .key_pressed      (key_pressed  ),
        .key_code         (key_code     ),
        .key_extended     (key_extended ),
        .key_strobe       (key_strobe   ),
        .PSG_OUT          (psg_out      ),
        .PSG_OUT_A        (psg_a        ),
        .PSG_OUT_B        (psg_b        ),
        .PSG_OUT_C        (psg_c        ),
        .VIDEO_R          (r            ),
        .VIDEO_G          (g            ),
        .VIDEO_B          (b            ),
        .VIDEO_HSYNC      (hs           ),
        .VIDEO_VSYNC      (vs           ),
        .K7_TAPEIN        (tape         ),
        .K7_TAPEOUT       (      ),
        .K7_REMOTE        (remote       ),
        .ram_ad           (ram_ad       ),
        .ram_d            (ram_d        ),
        .ram_q            (ram_cs ? ram_q : 8'd0 ),
        .ram_cs           (ram_cs_oric  ),
        .ram_oe           (ram_oe_oric  ),
        .ram_we           (ram_we       ),
        .joystick_0       (joystick_0   ),
        .joystick_1       (joystick_1   ),
        .fd_led           (led_value    ),
        .fdd_ready        (fdd_ready    ),
        .fdd_busy         (fdd_busy     ),
        .fdd_reset        (fdd_reset    ),
        .fdd_layout       (fdd_layout   ),
        .phi2             (phi2         ),
        .pll_locked       (pll_locked   ),
        .disk_enable      (disk_enable  ),
        .rom              (rom          ),
        .img_mounted      ( img_mounted[0]), // signaling that new image has been mounted
        .img_size         ( img_size[19:0]), // size of image in bytes
        .img_wp           ( status[7]     ), // write protect
        .sd_lba           ( sd_lba        ),
        .sd_rd            ( sd_rd[0]      ),
        .sd_wr            ( sd_wr[0]      ),
        .sd_ack           ( sd_ack        ),
        .sd_buff_addr      ( sd_buff_addr  ),
        .sd_dout          ( sd_dout       ),
        .sd_din           ( sd_din        ),
        .sd_dout_strobe   ( sd_dout_strobe),
        .sd_din_strobe    ( sd_din_strobe )

);
  ///////////////////   FDC   ///////////////////


always @(posedge clk_sys) begin : mounted_blk
        reg old_mounted;

        old_mounted <= img_mounted[0];
        if(reset) begin
                fdd_ready <= 1'b0;
        end

        else if(~old_mounted & img_mounted[0]) begin
                fdd_ready <= 1'b1;
        end
end

assign  led = fdd_busy;
assign VGA_NTSC=1'b0;
assign VGA_PAL=1'b1;
//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
