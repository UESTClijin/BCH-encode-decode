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
// File   : bch_encode_wrapper.v
// Create : 2020-12-17 21:36:49
// Revise : 2020-12-17 21:36:49
// Editor : sublime text3, tab size (4)
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

`include "bch_defs.vh"


module bch_encode_wrapper #(
	parameter [`BCH_PARAM_SZ-1:0] P = `BCH_SANE,
	parameter OPTION = "SERIAL",
	parameter BITS = 1,
	parameter REG_RATIO = 1
) (
	input clk,
	input reset,
	input [`BCH_DATA_BITS(P)-1:0] data_in,
	input din_en,
	output [`BCH_CODE_BITS(P)-1:0] data_out,
	output reg dout_valid,
	output ready
);

`include "bch.vh"

localparam TCQ = 1;//delay
localparam N = `BCH_N(P);//码长
localparam E = `BCH_ECC_BITS(P);
localparam M = `BCH_M(P);
localparam T = `BCH_T(P);//纠错�?
localparam K = `BCH_K(P);//信息�?
localparam B = `BCH_DATA_BITS(P);

function [BITS-1:0]reverse;
	input [BITS-1:0] in;
	integer i;
begin 	
	for (i = 0; i < N; i = i + 1)
		reverse[i] = in[BITS - i - 1];
end
endfunction

wire [BITS-1:0] 	encoder_in ; 
wire 				encoded_first;//encoded_last raise up one clock after encoded_last raise up,fall down after first encoded_data outputed
wire 				encode_ready;
wire 				data_bits;
wire 				ecc_bits;
wire 				encoded_last;
wire [BITS-1:0] 	encoded_data;


reg 				encode_ce;
reg 				start_in;
reg [B-1:0] 		din_buf;
reg [B-1:0] 		encode_buf;

reg [`BCH_CODE_BITS(P)-1:0] encoded_buf;

always @(posedge clk) begin
	if (reset) begin
		encode_ce <= 0;// reset	
		start_in  <= 0;
	end
	else if (din_en) begin
		encode_ce <= 1;
		start_in  <= 1;
		din_buf	  <= data_in;
	end
	else if (encoded_last) begin
		encode_ce <= 0;
		start_in  <= 0;
	end
	else begin
		start_in  <= 0;
	end
end

always @(posedge clk) begin
	if (start_in) begin
		encode_buf <= #TCQ din_buf >> BITS;
	end else if (!encode_ready && encode_ce)
		encode_buf <= #TCQ encode_buf >> BITS;
end

assign encoder_in = reverse(start_in ? din_buf[BITS-1:0] : encode_buf[BITS-1:0]);

bch_encode #(P, BITS) u_bch_encode(
	.clk(clk),
	.start(start_in),
	.ready(encode_ready),
	.ce(encode_ce),
	.data_in(encoder_in),
	.data_out(encoded_data),
	.data_bits(data_bits),
	.ecc_bits(ecc_bits),
	.first(encoded_first),
	.last(encoded_last)
);

always @(posedge clk) begin
	if (encoded_first) begin
		encoded_buf <= #TCQ reverse(encoded_data) << `BCH_CODE_BITS(P)-BITS;
	end else if (ecc_bits || data_bits)
		encoded_buf <= #TCQ (encoded_buf >> BITS) | (reverse(encoded_data)<< `BCH_CODE_BITS(P)-BITS);
end

always @(posedge clk) begin
	if (reset) begin
		dout_valid <= 0;	
	end
	else
		dout_valid <= encoded_last;
end

assign data_out = encoded_buf;
assign ready = encode_ready;
endmodule 