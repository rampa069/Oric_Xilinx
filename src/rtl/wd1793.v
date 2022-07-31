
// ====================================================================
//
//  WD1793, WD1772, WD1773 replica (with write capability)
//
//  Copyright (C) 2007,2008 Viacheslav Slavinsky
//  Copyright (C) 2016 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================
module wd1793 
(
	input wire        clk_sys,     // sys clock
	input wire        ce,          // ce at CPU clock rate
	input wire        reset,	     // async reset
	input wire        io_en,
	input wire        rd,          // i/o read
	input wire        wr,          // i/o write
	input wire  [1:0] addr,        // i/o port addr
	input wire  [7:0] din,         // i/o data in
	output wire [7:0] dout,        // i/o data out
	output wire       drq,         // DMA request
	output wire       intrq,
	output wire       busy,

	input wire        wp,          // write protect

	input wire [2:0]  size_code,
	input wire        layout,      // 0 = Track-Side-Sector, 1 - Side-Track-Sector
	input wire        side,
	input wire        ready,

	input wire        img_mounted, // signaling that new image has been mounted
	input wire [19:0] img_size,    // size of image in bytes. 1MB MAX!
	output wire       prepare,
	output wire[31:0] sd_lba,
	output reg   sd_rd,
	output reg   sd_wr,
	input  wire       sd_ack,
	input  wire[8:0]  sd_buff_addr,
	input  wire[7:0]  sd_buff_dout,
	output wire[7:0]  sd_buff_din,
	input  wire       sd_buff_wr
);

// Possible track configs:
// 0: 26 x 128  = 3.3KB
// 1: 16 x 256  = 4.0KB
// 2:  9 x 512  = 4.5KB
// 3:  5 x 1024 = 5.0KB
// 4: 10 x 512  = 5.0KB

// Register addresses
localparam A_COMMAND         = 0;
localparam A_STATUS          = 0;
localparam A_TRACK           = 1;
localparam A_SECTOR          = 2;
localparam A_DATA            = 3;

assign dout      = q;
assign drq       = s_drq;
assign busy      = s_busy;
assign intrq     = s_intrq;
assign sd_lba    = scan_active ? scan_addr[19:9] : buff_a[19:9] + sd_block;
assign prepare   = scan_active;


wire        rde;
wire        wre;
reg         scan_active;
reg         buff_wr;

reg   [7:0] sectors_per_track, edsk_spt;
wire [10:0] sector_size = 11'd128 << wd_size_code;
reg  [10:0] byte_addr;
reg  [19:0] buff_a;
reg   [1:0] wd_size_code;

wire  [7:0] buff_dout;
reg   [1:0] sd_block = 0;
reg         format;

//reg buff_wr;
wd1793_dpram sbuf
	(
		.clock(clk_sys),
		.address_a({sd_block, sd_buff_addr}),
		.data_a(sd_buff_dout),
		.wren_a(sd_buff_wr & sd_ack),
		.q_a(sd_buff_din),

		.address_b(scan_active ? {2'b00, scan_addr[8:0]} : byte_addr),
		.data_b(format ? 8'd0 : din),
		.wren_b(wre & buff_wr & (addr == A_DATA) & ~scan_active),
		.q_b(buff_dout)
	);
		
reg         var_size  = 0;
reg  [19:0] disk_size;
reg         layout_r;
wire [19:0] hs  = (layout_r & side) ? disk_size >> 1 : 20'd0;
wire  [7:0] dts = {disk_track[6:0], side} >> layout_r;
always @(posedge clk_sys) begin
	case({var_size,size_code})
				0: buff_a <= hs + {{1'b0, dts, 4'b0000} + {dts, 3'b000} + {dts, 1'b0} + wdreg_sector - 1'd1,  7'd0};
				1: buff_a <= hs + {{dts, 4'b0000}                                     + wdreg_sector - 1'd1,  8'd0};
				2: buff_a <= hs + {{dts, 3'b000}  + dts                               + wdreg_sector - 1'd1,  9'd0};
				3: buff_a <= hs + {{dts, 2'b00}   + dts                               + wdreg_sector - 1'd1, 10'd0};
				4: buff_a <= hs + {{dts, 3'b000}  +{dts, 1'b0}                        + wdreg_sector - 1'd1,  9'd0};
		default: buff_a <= edsk_offset;
	endcase
	case({var_size,size_code})
				0: sectors_per_track <= 26;
				1: sectors_per_track <= 16;
				2: sectors_per_track <= 9;
				3: sectors_per_track <= 5;
				4: sectors_per_track <= 10;
		default: sectors_per_track <= edsk_spt;
	endcase
	case({var_size,size_code})
				0: wd_size_code <= 0;
				1: wd_size_code <= 1;
				2: wd_size_code <= 2;
				3: wd_size_code <= 3;
				4: wd_size_code <= 2;
		default: wd_size_code <= edsk_sizecode;
	endcase
end

reg   [1:0] blk_size;
always @* begin
	case(wd_size_code)
		0: blk_size = 0;
		1: blk_size = 0;
		2: blk_size = buff_a[8:0] ? 2'd1 : 2'd0;
		3: blk_size = buff_a[8:0] ? 2'd2 : 2'd1;
	endcase
end



// States
/*typedef enum 
{
	STATE_IDLE,

	STATE_SEARCH,
	STATE_SEARCH_1,

	STATE_WAIT_READ,
	STATE_WAIT_READ_1,
	STATE_WAIT_READ_2,

	STATE_READ,
	STATE_READ_1,
	STATE_READ_2,
	STATE_READ_3,

	STATE_WAIT_WRITE,
	STATE_WAIT_WRITE_1,
	STATE_WAIT_WRITE_2,

	STATE_WRITE,
	STATE_WRITE_1,
	STATE_WRITE_2,

	STATE_ABORT,
	STATE_WAIT,
	STATE_WAIT_2,
	STATE_ENDCOMMAND
} io_state_t;*/


// common status bits
wire        s_readonly = (wp);
reg			s_crcerr;
reg			s_headloaded, s_seekerr, s_index;  // mode 1
reg			s_lostdata, s_wrfault; 			     // mode 2,3

// Command mode 0/1 for status register
reg 			cmd_mode;

// allow write protect flag
reg 			s_wpe;

// DRQ/BUSY are always going together
reg	[1:0]	s_drq_busy;
wire			s_drq  = s_drq_busy[1];
wire			s_busy = s_drq_busy[0];
reg         s_intrq;

reg   [7:0] wdreg_track;
reg   [7:0] wdreg_sector;
reg   [7:0] wdreg_data;
wire  [7:0] wdreg_status = cmd_mode == 0 ?
	{~ready, s_readonly & s_wpe, s_headloaded, s_seekerr | ~ready, s_crcerr, !disk_track, s_index, s_busy}:
	{~ready, s_readonly & s_wpe, s_wrfault,    s_seekerr | ~ready, s_crcerr, s_lostdata,  s_drq,   s_busy};

reg   [7:0] read_addr[0:5];
reg   [7:0] q;
reg   [32:0] state = 32'd0;

always @* begin
	case (addr)
		A_STATUS: q = wdreg_status;
		A_TRACK:  q = wdreg_track;
		A_SECTOR: q = wdreg_sector;
		A_DATA:   q = (state == 32'd0) ? wdreg_data : buff_rd ? buff_dout  : read_addr[byte_addr[2:0]];
	endcase
end

reg         buff_rd;
reg         step_direction; // last step direction

reg   [7:0] disk_track;		 // "real" heads position
reg  [10:0]	data_length;	 // this many bytes to transfer during read/write ops

// Reusable expressions
wire  [7:0] next_track  = (din[6] ? din[5] : step_direction) ? disk_track - 1'd1 : disk_track + 1'd1;
wire [10:0]	next_length = data_length - 1'b1;

// Watchdog
reg         watchdog_set;
wire        watchdog_bark = (wd_timer == 0);
reg  [15:0] wd_timer;
always @(posedge clk_sys) begin
	if(ce) begin
		if(watchdog_set) wd_timer <= 4096;
			else if(wd_timer != 0) wd_timer <= wd_timer - 1'b1;
	end
end

always @(posedge clk_sys) begin : blk1
	integer cnt;
	if(ce) begin
		if(ready) begin
			if(cnt) cnt <= cnt - 1;
				else cnt <= 35000;
		end else cnt <= 0;
		s_index <= (cnt < 100);
	end
end


assign rde  = rd & io_en;
assign wre = wr & io_en;

always @(posedge clk_sys) begin : blk2
	reg old_wr, old_rd;

	reg [2:0] cur_addr;
	reg       read_data;
	reg       write_data;
	reg       rw_type;
	integer   wait_time;
	reg [3:0] read_timer;
	reg [9:0] seektimer;
	reg [7:0] ra_sector;
	reg       multisector;
	reg       write;
	reg [5:0] ack;
	reg       sd_busy;
	reg       old_mounted;
	reg [3:0] scan_state;
	reg [1:0] scan_cnt;
	reg [1:0] blk_max;

   begin
		old_mounted <= img_mounted;
		if(old_mounted && ~img_mounted) begin
			
				scan_active<= 1'b1;
				scan_addr  <= 0;
				scan_state <= 0;
				scan_wr    <= 0;
				sd_block   <= 0;
			   disk_size <= img_size[19:0];
			   layout_r  <= layout;
		end
	end 

	if(reset & ~scan_active) begin
		read_data <= 0;
		write_data <= 0;
		multisector <= 0;
		step_direction <= 0;
		disk_track <= 0;
		wdreg_track <= 0;
		wdreg_sector <= 0;
		wdreg_data <= 0;
		data_length <= 0;
		byte_addr <=0;
		buff_rd <= 0;
		buff_wr <= 0;
		state <= 32'd0;
		cmd_mode <= 0;
		s_wpe <= 1;
		{s_headloaded, s_seekerr, s_crcerr, s_intrq} <= 0;
		{s_wrfault, s_lostdata} <= 0;
		s_drq_busy <= 0;
		watchdog_set <= 0;
		seektimer <= 'h3FF;
		{ack, sd_wr, sd_rd, sd_busy} <= 0;
		ra_sector <= 1;
	end else if(ce) begin

		ack <= {ack[4:0], sd_ack};
		if(ack[5:4] == 'b01) {sd_rd,sd_wr} <= 2'b0;
		if(ack[5:4] == 'b10) sd_busy <= 0;

		if(scan_active) begin
			if(scan_addr >= img_size) scan_active <= 0;
			else begin
				case(scan_state)
					0:	begin
							sd_rd   <= 1;
							sd_busy <= 1;
							scan_wr <= 0;
							scan_state <= 1;
						end
					1: if(!sd_busy) begin
							scan_wr    <= 1;
							scan_cnt   <= 1;
							scan_state <= 2;
						end
					2: begin
							scan_cnt <= scan_cnt + 1'd1;
							if(!scan_cnt) begin
								scan_wr <= ~scan_wr;
								if(scan_wr) begin
									scan_addr <= scan_addr + 1'b1;
									if(&scan_addr[8:0]) begin
										scan_active <= var_size;
										scan_state  <= 0;
									end
								end
							end
						end
				endcase
			end
		end

		old_wr <=wre;
		old_rd <=rde;

		if((!old_rd && rde) || (!old_wr && wre)) cur_addr <= addr;

		//Register read operations
		if(old_rd && !rde && (cur_addr == A_STATUS)) s_intrq <= 0;

		//end of data reading
		if(old_rd && !rde && (cur_addr == A_DATA)) read_data <=1;

		//end of data writing
		if(old_wr && !wre && (cur_addr == A_DATA)) write_data <=1;

		case (state)
			/* Idle state or buffer to host transfer */
			32'd0:; // do nothing

			32'd1:
				begin
					if(!ready) begin
						s_seekerr <= 1;
						state <= 32'd19;
					end else begin
						seektimer <= seektimer - 1'b1;
						if(!seektimer) begin
							byte_addr <= 0;
							if(var_size) begin
								if(~format) edsk_addr <= edsk_start;
								spt_addr  <= (side ? spt_size>>1 : 8'd0) + disk_track;
								state     <= 32'd2;
							end else begin
								if(!wdreg_sector || (wdreg_sector > sectors_per_track)) begin
									if(~format) s_seekerr <= 1;
									state <= 32'd19;
								end else begin
									state <= rw_type ? 32'd3 : 32'd6;
								end
							end
						end
					end
				end
			32'd2:
				begin
					if(rw_type & (edsk_track == disk_track) &
									 (edsk_side == side) &
									 (format | (edsk_sector == wdreg_sector))) begin
						state <= 32'd3;
					end
					else
					if(~rw_type & (edsk_track == disk_track) &
									  (edsk_side == side)) begin
						read_addr[0] <= edsk_trackf;
						read_addr[1] <= edsk_sidef;
						read_addr[2] <= edsk_sector;
						read_addr[3] <= edsk_sizecode;
						state        <= 32'd6;
					end
					else
					if(edsk_next == edsk_start) begin
						if(~format) s_seekerr <= 1;
						state <= 32'd19;
					end
					else
					begin
						edsk_addr <= edsk_next;
					end
				end
			// read before write in case if sector not aligned or smaller than 512b
			32'd3:
				begin
					data_length <= sector_size;
					byte_addr   <= buff_a[8:0];
					blk_max     <= blk_size;
					sd_block    <= 0;
					state       <= 32'd4;
				end
			32'd4:
				begin
					sd_busy <= 1;
					sd_rd   <= 1;
					state   <= 32'd5;
				end
			32'd5:
				begin
					if(!sd_busy) begin
						sd_block <= sd_block + 1'd1;
						state <= write ? 32'd13 : 32'd6;
						if(sd_block < blk_max) state <= 32'd4;
					end
				end

			32'd6:
				begin
					watchdog_set <= 1;
					read_timer <= 15;
					state <= 32'd7;
				end
			32'd7:
				begin
					read_timer <= read_timer - 1'b1;
					if(!read_timer) begin
						read_data <= 0;
						watchdog_set <= 0;
						s_lostdata <= 0;
						s_drq_busy <= 2'b11;
						state <= 32'd8;
					end
				end
			32'd8:
				begin
					if(watchdog_bark | (read_data & s_drq)) begin
						// reset drq until next byte is read, nothing is lost
						s_drq_busy <= 2'b01;
						s_lostdata <= watchdog_bark;

						if(next_length == 0) begin
							// either read the next sector, or stop if this is track end
							if(multisector) begin
								wdreg_sector <= wdreg_sector + 1'b1;
								state <= 32'd1;
							end else begin
								state <= 32'd19;
							end
						end else begin
							byte_addr <= byte_addr + 1'd1;
							data_length <= next_length;
							state <= 32'd6;
						end
					end
				end

			32'd10:
				begin
					if(!ready) begin
						s_wrfault <= 1;
						state <= 32'd19;
					end else begin
						sd_block <= 0;
						state <= 32'd11;
					end
				end
			32'd11:
				begin
					sd_busy <= 1;
					sd_wr   <= 1;
					state   <= 32'd12;
				end
			32'd12:
				begin
					if(!sd_busy) begin
						sd_block <= sd_block + 1'd1;
						if(sd_block < blk_max) state <= 32'd11;
						else begin
							if(format && var_size && !edsk_next) begin
								state <= 32'd19;
							end else if(multisector) begin
								edsk_addr <= edsk_next;
								wdreg_sector <= wdreg_sector + 1'b1;
								state <= 32'd1;
							end else begin
								state <= 32'd19;
							end
						end
					end
				end
			32'd13:
				begin
					watchdog_set <= 1;
					read_timer <= 15;
					state <= 32'd14;
				end
			32'd14:
				begin
					read_timer <= read_timer - 1'b1;
					if(!read_timer) begin
						write_data <= 0;
						watchdog_set <= 0;
						s_lostdata <= 0;
						s_drq_busy <= 2'b11;
						state <= 32'd15;
					end
				end
			32'd15:
				begin
					if(watchdog_bark | (write_data & s_drq)) begin
						s_drq_busy <= 2'b01;
						s_lostdata <= watchdog_bark;

						if(!next_length) state <= 32'd10;
						else begin
							byte_addr <= byte_addr + 1'd1;
							data_length <= next_length;
							state <= 32'd13;
						end
					end
				end

			// Abort current operation ($D0)
			32'd16:
				begin
					data_length <= 0;
					{s_wrfault,s_seekerr,s_crcerr,s_lostdata} <= 0;
					state <= 32'd19;
				end

			32'd17:
				begin
					wait_time <= 4000;
					state <= 32'd18;
				end
			32'd18:
				begin
					if(wait_time) wait_time <= wait_time - 1;
						else state <= 32'd19;
				end

			// End any command.
			32'd19:
				begin
					format  <= 0;
					buff_rd <= 0;
					buff_wr <=0;
					state <= 32'd0;
					s_drq_busy <= 2'b00;
					seektimer <= 'h3FF;
					s_intrq <= 1;
				end
		endcase

		/* Register write operations */
		if (!old_wr & wre) begin
			case (addr)
				A_COMMAND:
					begin
						s_intrq <= 0;
						if((state == 32'd0) | (din[7:4] == 'hD)) begin
							cmd_mode <= din[7];
							s_wpe    <= ~din[7];
							case (din[7:4])
							'h0: 	// RESTORE
								begin
									// head load as specified, index, track0
									s_headloaded <= din[3];
									wdreg_track <= 0;
									disk_track <= 0;

									// some programs like it when FDC gets busy for a while
									s_drq_busy <= 2'b01;
									state <= 32'd17;
								end
							'h1:	// SEEK
								begin
									// set real track to datareg
									disk_track <= wdreg_data;
									s_headloaded <= din[3];
									wdreg_track <= wdreg_data;
									// get busy
									s_drq_busy <= 2'b01;
									state <= 32'd17;
								end
							'h2,	// STEP
							'h3,	// STEP & UPDATE
							'h4,	// STEP-IN
							'h5,	// STEP-IN & UPDATE
							'h6,	// STEP-OUT
							'h7:	// STEP-OUT & UPDATE
								begin
									// if direction is specified, store it for the next time
									if (din[6] == 1) step_direction <= din[5]; // 0: forward/in

									// perform step
									disk_track <= next_track;

									// update TRACK register too if asked to
									if (din[4]) wdreg_track <= next_track;

									s_headloaded <= din[3];

									// some programs like it when FDC gets busy for a while
									s_drq_busy <= 2'b01;
									state <= 32'd17;
								end
							'h8, 'h9, // READ SECTORS
							'hA, 'hB: // WRITE SECTORS
								begin
									// seek data
									// 5: 0: read, 1: write
									// 4: m: 0: one sector, 1: until the track ends
									// 3: S: SIDE
									// 2: E: some 15ms delay
									// 1: C: check side matching?
									// 0: 0

									s_drq_busy <= 2'b01;
									{s_wrfault,s_seekerr,s_crcerr,s_lostdata} <= 0;

									{write,buff_rd} <= din[5] ? 2'b10 : 2'b01;
									buff_wr <= din[5];

									if(din[6]) wdreg_sector <= 1;

									format      <= din[6];
									multisector <= din[4];
									rw_type     <= 1;
									write_data  <= 0;
									read_data   <= 0;
									edsk_start  <= 0;
									edsk_addr   <= 0;
									state       <= 32'd1;
									s_wpe       <= din[5];

									if(s_readonly & din[5]) begin
										s_wrfault <= 1;
										state <= 32'd17;
									end
								end
							'hC:	// READ ADDRESS
								begin
									// track, side, sector, sector size code, 2-byte checksum (crc?)
									s_drq_busy <= 2'b01;
									{s_wrfault,s_seekerr,s_crcerr,s_lostdata} <= 0;

									{write,buff_rd} <= 0;
									buff_wr <=0;

									format      <= 0;
									multisector <= 0;
									rw_type     <= 0;
									read_data   <= 0;
									edsk_start  <= edsk_next;
									data_length <= 6;

									read_addr[0] <= disk_track;
									read_addr[1] <= {7'b0, side};
									read_addr[2] <= ra_sector;
									read_addr[3] <= wd_size_code;
									read_addr[4] <= 0;
									read_addr[5] <= 0;

									if(ra_sector >= sectors_per_track) ra_sector <= 1;
										else ra_sector <= ra_sector + 1'd1;
									state <= 32'd1;
								end
							'hD:	// interrupt
								begin
									cmd_mode <= 0;
									if(state != 32'd0) state <= 32'd16;
										else {s_wrfault,s_seekerr,s_crcerr,s_lostdata, s_drq_busy} <= 0;
								end
							'hF:  // WRITE TRACK
								begin
									s_wpe <= din[5];
									{s_wrfault,s_seekerr,s_crcerr,s_lostdata} <= 0;
									s_drq_busy <= 2'b01;
									state <= 32'd17;
								end
							'hE:	// READ TRACK
								begin
									{s_wrfault,s_crcerr,s_lostdata} <= 0;
									s_seekerr  <= 1;
									s_drq_busy <= 2'b01;
									state <= 32'd17;
								end
							endcase
						end
					end

				A_TRACK:  if (!s_busy) wdreg_track <= din;
				A_SECTOR: if (!s_busy) {ra_sector, wdreg_sector} <= {din,din};
				A_DATA:   wdreg_data <= din;
			endcase
		end
	end
end

reg [19:0] scan_addr;
reg        scan_wr;

reg  [1:0] edsk_sizecode = 0;      // sector size: 0=128K, 1=256K, 2=512K, 3=1024K
reg        edsk_side = 0;          // Side number (0 or 1)
reg  [6:0] edsk_track = 0;         // Track number
reg  [7:0] edsk_sector = 0;        // Sector number 0..15
reg [19:0] edsk_offset = 0;
reg  [7:0] edsk_trackf = 0, edsk_sidef = 0;

reg [10:0] edsk_addr, edsk_start;

reg [10:0] edsk_size = 0;
wire[10:0] edsk_next = ((edsk_addr + 1'd1) >= edsk_size) ? 11'd0 : edsk_addr + 1'd1;

reg  [7:0] spt_size = 0;
reg  [7:0] spt_addr;


wire [7:0] scan_data =  buff_dout;
reg [53:0] edsk[0:1991];  //[53:0][0:1991]
reg  [7:0] spt[0:165]; // 7:0 [0:165]

//reg  [7:0] spt_addr;
always @(posedge clk_sys) begin
	{edsk_track,edsk_side,edsk_trackf,edsk_sidef,edsk_sector,edsk_sizecode,edsk_offset} <= edsk[edsk_addr];
	edsk_spt <= spt[spt_addr];
end

reg  [7:0] tpos;
reg  [7:0] tsize;
reg  [7:0] tsizes[0:165];
always @(posedge clk_sys) tsize <= tsizes[tpos];

wire[127:0] edsk_sig = "EXTENDED CPC DSK";
wire[127:0] sig_pos  = edsk_sig >> (8'd120-(scan_addr[7:0]<<3));

always @(posedge clk_sys) begin : blk3
	reg old_active, old_wr;
	reg [13:0] hdr_pos, bcnt;
	reg  [7:0] idStatus;
	reg  [6:0] track;
	reg        side;
	reg  [7:0] sector;
	reg  [1:0] sizecode;
	reg  [7:0] crc1;
	reg  [7:0] crc2;
	reg  [7:0] sectors;
	reg [15:0] track_size, track_pos;
	reg [19:0] offset, offset1;
	reg  [7:0] size_lo;
	reg [10:0] secpos;
	reg  [7:0] trackf, sidef;

	old_active <= scan_active;
	if(scan_active & ~old_active) begin
		edsk_size <=0;
		spt_size  <=0;
		track_pos <=0;
		var_size  <=1;
	end

	old_wr <= scan_wr;
	if(scan_wr & ~old_wr & scan_active) begin
		if((scan_addr[19:0] < 16) & (sig_pos[7:0] != scan_data)) var_size <= 0;
		if(var_size) begin
			if( scan_addr == 48) spt_size <= scan_data; else
			if((scan_addr == 49) & (scan_data == 2)) spt_size <= spt_size << 1; else
			if( scan_addr == 52) begin
				track_size <= {scan_data, 8'd0};
				track_pos  <= 0;
				tpos <= 1;
			end else
			if((scan_addr  > 52) & (scan_addr < 218)) begin
				tsizes[scan_addr - 52] <= scan_data;
				spt[scan_addr - 52] <= 0;
			end else
			if((scan_addr >= 256) && track_size) begin
				track_pos <= track_pos + 1'd1;
				case(track_pos)
					00: offset  <= scan_addr + 9'd256;
					16: track   <= scan_data[6:0];
					17: side    <= scan_data[0];
					21: sectors <= scan_data;
					22: spt[(side ? (spt_size >> 1) : 8'd0) + track] <= sectors;
					default:
						if((track_pos >= 24) && sectors) begin
							case(track_pos[2:0])
								0: begin
										trackf  <= scan_data;
										secpos  <= edsk_size;
										offset1 <= offset;
									end
								1: sidef   <= scan_data;
								2: sector  <= scan_data;
								3: sizecode<= scan_data[1:0];
								6: size_lo <= scan_data;
								7: begin
										if({scan_data, size_lo}) begin
											edsk[secpos] <= {track,side,trackf,sidef,sector,sizecode,offset1};
											edsk_size <= edsk_size + 1'd1;
											offset <= offset + {scan_data, size_lo};
										end
										sectors <= sectors - 1'd1;
									end
								default:;
							endcase
						end
				endcase
				if(track_pos >= (track_size - 1'd1)) begin
					track_size <= {tsize, 8'd0};
					track_pos  <= 0;
					tpos <= tpos + 1'd1;
				end
			end
		end
	end
end


endmodule

module wd1793_dpram #(parameter DATAWIDTH=8, ADDRWIDTH=11)
(
	input	wire                     clock,

	input	wire     [ADDRWIDTH-1:0] address_a,
	input	wire     [DATAWIDTH-1:0] data_a,
	input	wire                     wren_a,
	output reg     [DATAWIDTH-1:0] q_a,

	input	wire     [ADDRWIDTH-1:0] address_b,
	input	wire     [DATAWIDTH-1:0] data_b,
	input	wire                     wren_b,
	output reg     [DATAWIDTH-1:0] q_b
);

reg [DATAWIDTH-1:0] ram[0:(1<<ADDRWIDTH)-1];

always @(posedge clock) begin
	if(wren_a) begin
		ram[address_a] <= data_a;
		q_a <= data_a;
	end else begin
		q_a <= ram[address_a];
	end
end

always @(posedge clock) begin
	if(wren_b) begin
		ram[address_b] <= data_b;
		q_b <= data_b;
	end else begin
		q_b <= ram[address_b];
	end
end

endmodule
