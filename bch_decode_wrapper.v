// This is a simple example.
// You can make a your own header file and set its path to settings.
// (Preferences > Package Settings > Verilog Gadget > Settings - User)
//
//		"header": "Packages/Verilog Gadget/template/verilog_header.v"
//
// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : 1453952597@qq.com
// File   : bch_decode_wrapper.v
// Create : 2020-12-17 21:36:49
// Revise : 2020-12-17 21:36:49
// Editor : sublime text3, tab size (4)
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

`include "bch_defs.vh"


module bch_decode_wrapper #(
	parameter [`BCH_PARAM_SZ-1:0] P = `BCH_SANE,
	parameter OPTION = "SERIAL",
	parameter BITS = 1,
	parameter REG_RATIO = 1
) (
	input clk,
	input reset,
	input [`BCH_CODE_BITS(P)-1:0] data_in,
	input din_en,
	output [`BCH_DATA_BITS(P)-1:0] data_out,
	output dout_valid,
	output ready
);

`include "bch.vh"

localparam TCQ = 1;//delay
localparam N = `BCH_N(P);//ç é•�?
localparam E = `BCH_ECC_BITS(P);
localparam M = `BCH_M(P);
localparam T = `BCH_T(P);//çº é”™ä½?
localparam K = `BCH_K(P);//ä¿¡æ¯ä½?
localparam B = `BCH_DATA_BITS(P);

function [BITS-1:0]reverse;
	input [BITS-1:0] in;
	integer i;
begin 	
	for (i = 0; i < N; i = i + 1)
		reverse[i] = in[BITS - i - 1];
end
endfunction


function integer bit_count;
	input [N-1:0] bits;
	integer count;
	integer i;
begin
	count = 0;
	for (i = 0; i < N; i = i + 1) begin
		count = count + bits[i];
	end
	bit_count = count;
end
endfunction


wire [`BCH_SYNDROMES_SZ(P)-1:0] syndromes;
wire [BITS-1:0] decoder_in;
wire syndrome_ready;
wire key_ready;
wire [`BCH_ERR_SZ(P)-1:0] err_count;
wire err_first;
wire err_last;
wire err_valid;
wire syn_done;
wire [BITS-1:0] err;


reg  [B-1:0] 		err_buf = 0;
reg  [`BCH_CODE_BITS(P)-1:0] 		din_buf;
reg  [`BCH_CODE_BITS(P)-1:0] 		decode_buf;

wire syndrome_start = din_en && syndrome_ready;
/* Keep adding data until the next stage is busy */
wire syndrome_ce = !syn_done || key_ready ;

always @(posedge clk) begin
	if (syndrome_start) beginbc
		decode_buf <= #TCQ data_in >> BITS;
		din_buf	   <= data_in;
	end else if (!syndrome_ready && syndrome_ce)
		decode_buf <= #TCQ decode_buf >> BITS;
end

/* Make it so we get the same syndromes, no matter what the word size */
assign decoder_in = reverse(syndrome_start ? data_in[BITS-1:0] : decode_buf[BITS-1:0]);

bch_syndrome #(P, BITS, REG_RATIO) u_bch_syndrome(
	.clk(clk),
	.start(syndrome_start),
	.ready(syndrome_ready),
	.ce(syndrome_ce),
	.data_in(decoder_in),
	.syndromes(syndromes),
	.done(syn_done)
);


if (T > 1 && (OPTION == "SERIAL" || OPTION == "PARALLEL" || OPTION == "NOINV")) begin : TMEC

	wire ch_start;
	wire [`BCH_SIGMA_SZ(P)-1:0] sigma;

	/* Solve key equation */
	if (OPTION == "SERIAL") begin : BMA_SERIAL
		bch_sigma_bma_serial #(P) u_bma (
			.clk(clk),
			.start(syn_done && key_ready),
			.ready(key_ready),
			.syndromes(syndromes),
			.sigma(sigma),
			.done(ch_start),
			.ack_done(1'b1),
			.err_count(err_count)
		);
	end else if (OPTION == "PARALLEL") begin : BMA_PARALLEL
		bch_sigma_bma_parallel #(P) u_bma (
			.clk(clk),
			.start(syn_done && key_ready),
			.ready(key_ready),
			.syndromes(syndromes),
			.sigma(sigma),
			.done(ch_start),
			.ack_done(1'b1),
			.err_count(err_count)
		);
	end else if (OPTION == "NOINV") begin : BMA_NOINV
		bch_sigma_bma_noinv #(P) u_bma (
			.clk(clk),
			.start(syn_done && key_ready),
			.ready(key_ready),
			.syndromes(syndromes),
			.sigma(sigma),
			.done(ch_start),
			.ack_done(1'b1),
			.err_count(err_count)
		);
	end

	wire [BITS-1:0] err1;
	wire err_first1;

	/* Locate errors */
	bch_error_tmec #(P, BITS, REG_RATIO) u_error_tmec(
		.clk(clk),
		.start(ch_start),
		.sigma(sigma),
		.first(err_first),
		.err(err)
	);

	bch_error_one #(P, BITS) u_error_one(
		.clk(clk),
		.start(ch_start),
		.sigma(sigma[0+:2*M]),//[起始地址+：数据位宽]
		.first(err_first1),
		.err(err1)
	);

end else begin : DEC
	assign key_ready = 1'b1;
	/* Locate errors */
	bch_error_dec #(P, BITS, REG_RATIO) u_error_dec(
		.clk(clk),
		.start(syn_done && key_ready),
		.syndromes(syndromes),
		.first(err_first),
		.err(err),
		.err_count(err_count)
	);
end

bch_chien_counter #(P, BITS) u_chien_counter(
	.clk(clk),
	.first(err_first),
	.last(err_last),
	.valid(err_valid)
);


reg err_done = 0;

always @(posedge clk) begin
	if (err_first)
		err_buf <= #TCQ reverse(err) << (`BCH_DATA_BITS(P) - BITS);
	else if (err_valid)
		err_buf <= #TCQ (reverse(err) << (`BCH_DATA_BITS(P) - BITS)) | (err_buf >> BITS);

	err_done <= #TCQ err_last;
end

assign data_out = err_buf ^ din_buf[`BCH_DATA_BITS(P)-1:0];

assign ready 	  = syndrome_ready;
assign dout_valid = err_done;

endmodule