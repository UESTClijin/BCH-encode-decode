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
// File   : enc_dec_tb.v
// Create : 2020-12-18 01:09:06
// Revise : 2020-12-18 01:09:06
// Editor : sublime text3, tab size (4)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module enc_dec_tb;

`include "bch_params.vh"
`include "bch_defs.vh"
parameter T = 3;
parameter OPTION = "SERIAL";
parameter DATA_BITS = 128;//5;
parameter BITS = 8;//1;
parameter REG_RATIO = 1;
parameter SEED = 0;

localparam BCH_PARAMS = bch_params(DATA_BITS, T);

reg [31:0] seed = SEED;

initial begin
	$dumpfile("test.vcd");
	$dumpvars(0);
end

localparam TCQ = 1;

reg clk = 0;
reg reset = 0;
reg [DATA_BITS-1:0] din = 0;
reg [$clog2(T+2)-1:0] nerr = 0;
reg [`BCH_CODE_BITS(BCH_PARAMS)-1:0] error = 0;

function [DATA_BITS-1:0] randk;
	input [31:0] useless;
	integer i;
begin
	for (i = 0; i < (31 + DATA_BITS) / 32; i = i + 1)
		if (i * 32 > DATA_BITS) begin
			if (DATA_BITS % 32)
				/* Placate isim */
				randk[i*32+:(DATA_BITS%32) ? (DATA_BITS%32) : 1] = $random(seed);
		end else
			randk[i*32+:32] = $random(seed);
end
endfunction

function integer n_errors;
	input [31:0] useless;
	integer i;
begin
	n_errors = (32'h7fff_ffff & $random(seed)) % (T + 1);
end
endfunction

function [`BCH_CODE_BITS(BCH_PARAMS)-1:0] rande;
	input [31:0] nerr;
	integer i;
begin
	rande = 0;
	while (nerr) begin
		i = (32'h7fff_ffff & $random(seed)) % (`BCH_CODE_BITS(BCH_PARAMS));
		if (!((1 << i) & rande)) begin
			rande = rande | (1 << i);
			nerr = nerr - 1;
		end
	end
end
endfunction

reg  encode_en = 0;
wire ready;


always
	#5 clk = ~clk;

reg [31:0] s;

initial begin
	s = seed;
	#100;
	encode_en <= 1;
	din <= randk(0);
	#10
	encode_en <= 0;
	nerr <= n_errors(0);
	#1;
	error <= rande(nerr);
	$display("%b", din);
	#999
	encode_en <= 1;
	din <= randk(1);
	#10
	encode_en <= 0;
	nerr <= n_errors(1);
	#1;
	error <= rande(nerr);
end

initial begin
	$display("GF(2^%1d) (%1d, %1d/%1d, %1d) %s",
		`BCH_M(BCH_PARAMS), `BCH_N(BCH_PARAMS), `BCH_K(BCH_PARAMS),
		DATA_BITS, `BCH_T(BCH_PARAMS), OPTION);
	reset <= #1 1;
	@(posedge clk);
	@(posedge clk);
	reset <= #1 0;
end

wire enc_rdy;
wire dec_rdy;
wire encoded_valid;
wire decoded_valid;
wire [`BCH_CODE_BITS(BCH_PARAMS)-1:0] encoded_out ;
wire [`BCH_DATA_BITS(BCH_PARAMS)-1:0] decoded_out;


assign ready = enc_rdy & dec_rdy;
bch_encode_wrapper #(
		.P(BCH_PARAMS),
		.OPTION(OPTION),
		.BITS(BITS),
		.REG_RATIO(REG_RATIO)
	) inst_bch_encode_wrapper (
		.clk        (clk),
		.reset      (reset),
		.data_in    (din),
		.din_en     (encode_en),
		.data_out   (encoded_out),
		.dout_valid (encoded_valid),
		.ready      (enc_rdy)
	);


bch_decode_wrapper #(
		.P(BCH_PARAMS),
		.OPTION(OPTION),
		.BITS(BITS),
		.REG_RATIO(REG_RATIO)
	) inst_bch_decode_wrapper (
		.clk        (clk),
		.reset      (reset),
		.data_in    (encoded_out^error),
		.din_en     (encoded_valid),
		.data_out   (decoded_out),
		.dout_valid (decoded_valid),
		.ready      (dec_rdy)
	);


endmodule
