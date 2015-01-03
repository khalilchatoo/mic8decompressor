/*
Coperandyright by Henry Ko and Nicola Nicolici
Developeranded for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

`include "define_state.h"

// This is the toperand module
// It connects the SRAM and VGA together
// It will first write RGB data of an image with 8x8 rectangles of size 40x30 pixels into the SRAM
// The VGA will then read the SRAM and display the image
module M2 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock
		input logic resetn,	
		output logic [17:0] SRAM_address,
		output logic [15:0] SRAM_write_data,
		input logic [15:0] SRAM_read_data,
		output logic SRAM_we_n,
		input logic M2_enable,
		output logic M2_done
);

//dram0
logic [5:0] address_a_0;
logic [5:0] address_b_0;
logic signed [31:0] data_a_0;
logic signed [31:0] data_b_0;
logic wren_a_0;
logic wren_b_0;
logic signed [31:0] q_a_0;
logic signed [31:0] q_b_0;

//dram1
logic [5:0] address_a_1;
logic [5:0] address_b_1;
logic signed [31:0] data_a_1;
logic signed [31:0] data_b_1;
logic wren_a_1;
logic wren_b_1;
logic signed [31:0] q_a_1;
logic signed [31:0] q_b_1;

//dram2
logic [5:0] address_a_2;
logic [5:0] address_b_2;
logic signed [31:0] data_a_2;
logic signed [31:0] data_b_2;
logic wren_a_2;
logic wren_b_2;
logic signed [31:0] q_a_2;
logic signed [31:0] q_b_2;

// Instantiate RAM2
dual_port_RAM2 dual_port_RAM_inst2 (
	.address_a ( address_a_2 ),
	.address_b ( address_b_2 ),
	.clock ( CLOCK_50_I ),
	.data_a ( data_a_2 ),
	.data_b ( data_b_2 ),
	.wren_a ( wren_a_2 ),
	.wren_b ( wren_b_2 ),
	.q_a ( q_a_2 ),
	.q_b ( q_b_2 )
	);


// Instantiate RAM1
dual_port_RAM1 dual_port_RAM_inst1 (
	.address_a ( address_a_1 ),
	.address_b ( address_b_1 ),
	.clock ( CLOCK_50_I ),
	.data_a ( data_a_1 ),
	.data_b ( data_b_1 ),
	.wren_a ( wren_a_1 ),
	.wren_b ( wren_b_1 ),
	.q_a ( q_a_1 ),
	.q_b ( q_b_1 )
	);

// Instantiate RAM0
dual_port_RAM0 dual_port_RAM_inst0 (
	.address_a ( address_a_0 ),
	.address_b ( address_b_0 ),
	.clock ( CLOCK_50_I ),
	.data_a ( data_a_0 ),
	.data_b ( data_b_0 ),
	.wren_a ( wren_a_0 ),
	.wren_b ( wren_b_0 ),
	.q_a ( q_a_0 ),
	.q_b ( q_b_0 )
	);

M2_state_type state;

// Define the offset for Y,U,V, data in the SRAM 
parameter 	Y_OFFSET = 18'd0,
			Y_OFFSET_FETCH = 18'd76800,
			U_OFFSET = 18'd38400,
			U_OFFSET_FETCH = 18'd153600,
			V_OFFSET = 18'd57600,
			V_OFFSET_FETCH = 18'd192000;

//multiplication stuff
logic signed [31:0] reg_s_0;
logic signed [31:0] reg_s_1;
logic signed [31:0] operand0;
logic signed [31:0] operand1;
logic signed [31:0] operand2;
logic signed [31:0] operand3;
logic signed [31:0] temp0;
logic signed [31:0] temp1;
logic signed [31:0] temp2;
logic signed [31:0] temp3;
logic signed [31:0] result0;
logic signed [31:0] result1;
logic signed [31:0] result2;
logic signed [31:0] result3;
logic signed [31:0] C[7:0];
logic signed [31:0] Sprime[7:0];
logic signed [31:0] T_saved[7:0];
logic signed [31:0] T_final_even_32;
logic signed [31:0] T_final_odd_32;
logic signed [31:0] S_0_final;
logic signed [31:0] S_8_final; 

//two T matrix values to be written
logic signed [31:0] T_even_32;
logic signed [31:0] T_odd_32;

//two S matrix values to be written
logic signed [31:0] S_0;
logic signed [31:0] S_8;

//counters for fetching
logic [7:0] row_address;
logic [4:0] row_block;
logic [2:0] row_index;

logic [8:0] column_address;
logic [5:0] column_block;
logic [2:0] column_index;

logic [17:0] total_address_y;
logic [17:0] total_address_uv;
logic [5:0] counter_64;

//counters for writing
logic [7:0] row_address_w;
logic [4:0] row_block_w;
logic [2:0] row_index_w;

logic [8:0] column_address_w;
logic [4:0] column_block_w;
logic [1:0] column_index_w;

logic [17:0] total_address_y_w;
logic [17:0] total_address_uv_w;
logic [4:0] counter_64_w;
logic [4:0] write_counter_32;

logic [5:0] delay_counter_64;
logic [5:0] read_counter_64;
logic [5:0] write_T_counter_64;
logic [5:0] read_counter_64_T; //read counter for T values
logic [5:0] write_counter_64_S; //write counter for S values


//multiplication select_m2	
logic [4:0] select_m2;

logic lead_in;

//enable flag for fetching y s'
logic counter_y_enable;

//0 when you're computing T, 1 when you're computing S
logic compute_t_or_s;

//addresses for 8by8 S'
assign row_address = {row_block, row_index}; //equivalent to 8*row_block + row_index
assign column_address = {column_block, column_index}; //equivalent to 4*cb + ci
assign total_address_y = {2'd0, row_address, 8'd0} + {4'd0, row_address, 6'd0} + {9'd0, column_address}; //320*ra + ca (sram_address)
assign total_address_uv = {3'd0, row_address, 7'd0} + {5'd0, row_address, 5'd0} + {9'd0, column_address}; //160*ra + ca (sram_address)
assign row_index = counter_64[5:3];
assign column_index = counter_64[2:0];

//addresses for 8by8 writing S
assign row_address_w = {row_block_w, row_index_w}; //equivalent to 8*row_block + row_index
assign column_address_w = {column_block_w, column_index_w}; //equivalent to 8*cb + ci
assign total_address_y_w = {3'd0, row_address_w, 7'd0} + {5'd0, row_address_w, 5'd0} + {9'd0, column_address_w}; //160*ra + ca (sram_address)
assign total_address_uv_w = {6'd0, row_address_w, 4'd0} + {4'd0, row_address_w, 6'd0} + {9'd0, column_address_w}; //80*ra + ca (sram_address)
assign row_index_w = counter_64_w[4:2];
assign column_index_w = counter_64_w[1:0];

//coeff matrix constants
assign C[0] = 32'd1448;
assign C[1] = 32'd2008;
assign C[2] = 32'd1892;
assign C[3] = 32'd1702;
assign C[4] = 32'd1448;
assign C[5] = 32'd1137;
assign C[6] = 32'd783;
assign C[7] = 32'd399;

assign T_final_even_32 = result0 + result2 + T_even_32;
assign T_final_odd_32 = result0 + result2 + T_odd_32;
assign S_0_final = result0 + result2 + S_0;
assign S_8_final = result1 + result3 + S_8;

//multiplier for S'C and CtT -- combinational logic
always_comb begin
	operand0 = 32'd0;
	operand1 = 32'd0;
	operand2 = 32'd0;
	operand3 = 32'd0;
	
	if (select_m2 == 4'd0) begin
		operand0 = C[0];
		operand1 = C[0];
		operand2 = C[1];
		operand3 = C[3];
	end else if (select_m2 == 4'd1) begin
		operand0 = C[2];
		operand1 = C[6];
		operand2 = C[3];
		operand3 = -C[7];
	end else if (select_m2 == 4'd2) begin
		operand0 = C[4];
		operand1 = -C[4];
		operand2 = C[5];
		operand3 = -C[1];
	end else if (select_m2 == 4'd3) begin
		operand0 = C[6];
		operand1 = -C[2];
		operand2 = C[7];
		operand3 = -C[5];
	end else if (select_m2 == 4'd4) begin
		operand0 = C[0];
		operand1 = C[0];
		operand2 = C[5];
		operand3 = C[7];
	end	else if (select_m2 == 4'd5) begin
		operand0 = -C[6];
		operand1 = -C[2];
		operand2 = -C[1];
		operand3 = -C[5];
	end	else if (select_m2 == 4'd6) begin
		operand0 = -C[0];
		operand1 = C[0];
		operand2 = C[7];
		operand3 = C[3];
	end	else if (select_m2 == 4'd7) begin
		operand0 = C[2];
		operand1 = -C[6];
		operand2 = C[3];
		operand3 = -C[1];
	end	else if (select_m2 == 4'd8) begin
		operand0 = C[0];
		operand1 = C[0];
		operand2 = -C[7];
		operand3 = -C[5];
	end	else if (select_m2 == 4'd9) begin
		operand0 = -C[2];
		operand1 = -C[6];
		operand2 = C[5];
		operand3 = C[1];
	end	else if (select_m2 == 4'd10) begin
		operand0 = C[0];
		operand1 = -C[0];
		operand2 = -C[3];
		operand3 = -C[7];
	end	else if (select_m2 == 4'd11) begin
		operand0 = -C[6];
		operand1 = C[2];
		operand2 = C[1];
		operand3 = -C[3];
	end	else if (select_m2 == 4'd12) begin
		operand0 = C[0];
		operand1 = C[0];
		operand2 = -C[3];
		operand3 = -C[1];
	end	else if (select_m2 == 4'd13) begin
		operand0 = C[6];
		operand1 = C[2];
		operand2 = C[7];
		operand3 = -C[3];
	end	else if (select_m2 == 4'd14) begin
		operand0 = -C[0];
		operand1 = C[0];
		operand2 = C[1];
		operand3 = -C[5];
	end else if (select_m2 == 4'd15) begin
		operand0 = -C[2];
		operand1 = C[6];
		operand2 = C[5];
		operand3 = -C[7];
	end
end

assign result0 = operand0*temp0;
assign result1 = operand1*temp1;
assign result2 = operand2*temp2;
assign result3 = operand3*temp3;

assign temp0 = reg_s_0;
assign temp1 = reg_s_0;
assign temp2 = reg_s_1;
assign temp3 = reg_s_1;


logic [5:0] t0_2;
logic [5:0] t1_2;
logic [5:0] s0_2;
logic [5:0] s1_2;

assign t0_2 = {read_counter_64_T[4:0], 1'd0}; //2k
assign t1_2 = {read_counter_64_T[4:0], 1'd1}; //2k+1

assign s0_2 = {write_counter_64_S[4:0], 1'd0}; //2k
assign s1_2 = {write_counter_64_S[4:0], 1'd1}; //2k+1

//writing final S values
logic [7:0] s_8_0;
logic [7:0] s_8_1;

logic [2:0] y_or_uv_flag;
logic increment_complete;

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		state <= S_M2_IDLE;
		//initially start at rb,cb 0,0 and ri,ci 0,0
		row_block <= 5'd0;
		column_block <= 6'd0;
		counter_64 <= 6'd0;
		row_block_w <= 5'd0;
		column_block_w <= 6'd0;
		counter_64_w <= 5'd0;
		wren_a_0 <= 1'b0;
		wren_b_0 <= 1'b0;
		wren_a_1 <= 1'b0;
		wren_b_1 <= 1'b0;
		wren_a_2 <= 1'b0;
		wren_b_2 <= 1'b0;
		data_a_0 <= 32'b0;
		data_b_0 <= 32'b0;
		data_a_1 <= 32'b0;
		data_b_1 <= 32'b0;
		data_a_2 <= 32'b0;
		data_b_2 <= 32'b0;
		address_a_0 <= 7'd0;
		address_b_0 <= 7'd0;
		address_a_1 <= 7'd0;
		address_b_1 <= 7'd0;
		address_a_2 <= 7'd0;
		address_b_2 <= 7'd0;
		y_or_uv_flag <= 1'b0;
		SRAM_we_n <= 1'b1;
		delay_counter_64 <= 6'd0;
		read_counter_64 <= 6'd0;
		select_m2 <= 4'd0;
		write_T_counter_64 <= 6'd0;
		compute_t_or_s <= 1'b0;
		T_even_32 <= 32'd0;
		T_odd_32 <= 32'd0;
		read_counter_64_T <= 6'd0;
		S_0 <= 32'd0;
		S_8 <= 32'd0;
		write_counter_64_S <= 6'd0;
		write_counter_32 <= 5'd0;
		SRAM_address <= 18'd0;
		counter_y_enable <= 1'b1;
		SRAM_write_data <= 16'd0;
		lead_in <= 1'b0;
	end else begin
		case (state)
		S_M2_IDLE: begin
			if (M2_enable == 1'b1) begin
				counter_y_enable <= 1'b1;
				state <= S_SETUP_FETCH_Y;
			end
		end
		
		S_SETUP_FETCH_Y: begin
			SRAM_address <= Y_OFFSET_FETCH + total_address_y;
				
			counter_64 <= counter_64 + 6'd1;
			state <= S_DELAY_M2_0;
				
		end
	
		
		S_DELAY_M2_0: begin

			SRAM_address <= Y_OFFSET_FETCH + total_address_y;

			counter_64 <= counter_64 + 6'd1;
			state <= S_DELAY_M2_1;
		end
		
		S_DELAY_M2_1: begin

			SRAM_address <= Y_OFFSET_FETCH + total_address_y;

			counter_64 <= counter_64 + 6'd1;
			state <= S_FETCH_S_Y0;
			wren_a_0 <= 1'b1;
		end
		
		S_FETCH_S_Y0: begin
			counter_64 <= counter_64 + 6'd1;
			SRAM_address <= Y_OFFSET_FETCH + total_address_y;

			
			if (delay_counter_64 < 6'd63) begin
				address_a_0 <= delay_counter_64;
				delay_counter_64 <= delay_counter_64 + 6'd1;
				data_a_0 <= {{16{SRAM_read_data[15]}}, SRAM_read_data[15:0]};
				state <= S_FETCH_S_Y0;
			end else begin
				//end of fetching 8 by 8
				wren_a_0 <= 1'b0;
				counter_64 <= 6'd0;
					if (column_block < 6'd39) begin
						address_a_0 <= delay_counter_64;
						column_block <= column_block + 6'd1;
					end
					
					if (column_block == 6'd40) begin
						column_block <= 6'd0;
						row_block <= row_block + 5'd1;
					end
					
					if (column_block < 6'd19) begin
						address_a_0 <= delay_counter_64;
						column_block <= column_block + 6'd1;
					end
					
					if (column_block == 6'd20) begin
						column_block <= 6'd0;
						row_block <= row_block + 5'd1;
					end
								
				delay_counter_64 <= 6'd0;
				state <= S_DELAY_SETUP_CALC_T_0;
			end
		end
		
		S_DELAY_SETUP_CALC_T_0: begin
			address_a_0 <= {read_counter_64[4:0], 1'd0}; //equivalent to 2n READING S0 
			address_b_0 <= {read_counter_64[4:0], 1'd1}; //equivalent to 2n + 1 READING S1
			read_counter_64 <= read_counter_64 + 6'd1;
				
			state <= S_DELAY_SETUP_CALC_T;
		end
		S_DELAY_SETUP_CALC_T: begin
			address_a_0 <= {read_counter_64[4:0], 1'd0}; //equivalent to 2n READING S2
			address_b_0 <= {read_counter_64[4:0], 1'd1}; //equivalent to 2n + 1 READING S3
			read_counter_64 <= read_counter_64 + 6'd1;

			state <= S_C_TIMES_S_0;
		end
		
		S_C_TIMES_S_0: begin
			counter_64 <=6'd0;
			wren_a_1 <= 1'b0;
			wren_b_1 <= 1'b0;
			select_m2 <= 4'd0;
		
			address_a_0 <= {read_counter_64[4:0], 1'd0}; //equivalent to 2n READING S4
			address_b_0 <= {read_counter_64[4:0], 1'd1}; //equivalent to 2n + 1 READING S5
			read_counter_64 <= read_counter_64 + 6'd1;
			reg_s_0 <= q_a_0; //READING 0
			reg_s_1 <= q_b_0; //READING 1
			Sprime[0] <= q_a_0; //saving 0
			Sprime[1] <= q_b_0; //saving 1
			
			state <= S_C_TIMES_S_1;
		end
		
		S_C_TIMES_S_1: begin
			wren_a_1 <= 1'b0;
			wren_b_1 <= 1'b0;
			select_m2 <= 4'd1;
			
			address_a_0 <= {read_counter_64[4:0], 1'd0}; //equivalent to 2n READING S6 (2nd last element)
			address_b_0 <= {read_counter_64[4:0], 1'd1}; //equivalent to 2n + 1 READING S7 (last element)
			read_counter_64 <= read_counter_64 + 6'd1;
			reg_s_0 <= q_a_0; //READING 2
			reg_s_1 <= q_b_0; //READING 3
			Sprime[2] <= q_a_0; //saving 2
			Sprime[3] <= q_b_0; //saving 3
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			state <= S_C_TIMES_S_2;
		end
		
		S_C_TIMES_S_2: begin
			select_m2 <= 4'd2;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			reg_s_0 <= q_a_0; //READING 4
			reg_s_1 <= q_b_0; //READING 5
			Sprime[4] <= q_a_0; //saving 4
			Sprime[5] <= q_b_0; //saving 5
			
			state <= S_C_TIMES_S_3;
			
		end
		
		S_C_TIMES_S_3: begin
			select_m2 <= 4'd3;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			reg_s_0 <= q_a_0; //READING 6
			reg_s_1 <= q_b_0; //READING 7
			Sprime[6] <= q_a_0; //saving 6
			Sprime[7] <= q_b_0; //saving 7			
			
			state <= S_C_TIMES_S_4;
		end
		
		S_C_TIMES_S_4: begin
			/* Writing Teven and Todd to Dram1 */
			wren_a_1 <= 1'b1;
			wren_b_1 <= 1'b1;
			
			address_a_1 <= {write_T_counter_64[4:0], 1'd0}; //equivalent to 2n
			address_b_1 <= {write_T_counter_64[4:0], 1'd1}; //equivalent to 2n + 1
			
			data_a_1 <= {{8{T_even_32[31]}}, T_final_even_32[31:8]}; //WRITING 0
			data_b_1 <= {{8{T_odd_32[31]}}, T_final_odd_32[31:8]}; //WRITING 1
			write_T_counter_64 <= write_T_counter_64 + 6'd1;
						
			//Reset both T odd and T even values for next accumulation
			T_odd_32 <= 32'd0;
			T_even_32 <= 32'd0; 
			
			select_m2 <= 4'd4;

			reg_s_0 <= Sprime[0]; //READING saved 0
			reg_s_1 <= Sprime[1]; //READING saved 1
			state <= S_C_TIMES_S_5;
		end
		
		S_C_TIMES_S_5: begin
			select_m2 <= 4'd5;
			
			reg_s_0 <= Sprime[2]; //READING saved 2
			reg_s_1 <= Sprime[3]; //READING saved 3

			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			state <= S_C_TIMES_S_6;
		end
		
		S_C_TIMES_S_6: begin
			wren_a_1 <= 1'b0;
			wren_b_1 <= 1'b0;
			select_m2 <= 4'd6;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			reg_s_0 <= Sprime[4]; //READING saved 4
			reg_s_1 <= Sprime[5]; //READING saved 5
			
			state <= S_C_TIMES_S_7;
		end
			
		S_C_TIMES_S_7: begin
			select_m2 <= 4'd7;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			reg_s_0 <= Sprime[6]; //READING saved 6
			reg_s_1 <= Sprime[7]; //READING saved 7
			
			state <= S_C_TIMES_S_8;
		end
		
		S_C_TIMES_S_8: begin
			wren_a_1 <= 1'b1;
			wren_b_1 <= 1'b1;
			
			address_a_1 <= {write_T_counter_64[4:0], 1'd0}; //equivalent to 2n
			address_b_1 <= {write_T_counter_64[4:0], 1'd1}; //equivalent to 2n + 1
			
			data_a_1 <= {{8{T_even_32[31]}}, T_final_even_32[31:8]}; //WRITING 2
			data_b_1 <= {{8{T_odd_32[31]}}, T_final_odd_32[31:8]}; //WRITING 3
			
			write_T_counter_64 <= write_T_counter_64 + 6'd1;
		
			//Reset both T odd and T even values for next accumulation
			T_odd_32 <= 32'd0;
			T_even_32 <= 32'd0; 
			
			select_m2 <= 4'd8;

			reg_s_0 <= Sprime[0]; //READING 0
			reg_s_1 <= Sprime[1]; //READING 1
			
			state <= S_C_TIMES_S_9;
		end
		
		S_C_TIMES_S_9: begin
			select_m2 <= 4'd9;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			reg_s_0 <= Sprime[2]; //READING 2
			reg_s_1 <= Sprime[3]; //READING 3
			
			state <= S_C_TIMES_S_10;
		end
		
		S_C_TIMES_S_10: begin
			wren_a_1 <= 1'b0;
			wren_b_1 <= 1'b0;
			
			select_m2 <= 4'd10;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			reg_s_0 <= Sprime[4]; //READING 4
			reg_s_1 <= Sprime[5]; //READING 5

			state <= S_C_TIMES_S_11;
		end
			
		S_C_TIMES_S_11: begin
			select_m2 <= 4'd11;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			reg_s_0 <= Sprime[6]; //READING 6
			reg_s_1 <= Sprime[7]; //READING 7
			
			state <= S_C_TIMES_S_12;
		end
		
		S_C_TIMES_S_12: begin
			/* Writing Teven and Todd to Dram1 */
			wren_a_1 <= 1'b1;
			wren_b_1 <= 1'b1;
			address_a_1 <= {write_T_counter_64[4:0], 1'd0}; //equivalent to 2n
			address_b_1 <= {write_T_counter_64[4:0], 1'd1}; //equivalent to 2n + 1
			write_T_counter_64 <= write_T_counter_64 + 6'd1;			
			data_a_1 <= {{8{T_even_32[31]}}, T_final_even_32[31:8]}; //WRITING 4
			data_b_1 <= {{8{T_odd_32[31]}}, T_final_odd_32[31:8]}; //WRITING 5
							
			//Reset both T odd and T even values for next accumulation
			T_odd_32 <= 32'd0;
			T_even_32 <= 32'd0; 
			
			select_m2 <= 4'd12;

			reg_s_0 <= Sprime[0]; //READING S0
			reg_s_1 <= Sprime[1]; //READING S1
			
			state <= S_C_TIMES_S_13;
		end
		
		S_C_TIMES_S_13: begin		
			select_m2 <= 4'd13;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
	
			reg_s_0 <= Sprime[2]; //READING S2
			reg_s_1 <= Sprime[3]; //READING S3
			
			state <= S_C_TIMES_S_14;
		end
		
		S_C_TIMES_S_14: begin
			wren_a_1 <= 1'b0;
			wren_b_1 <= 1'b0;
			select_m2 <= 4'd14;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			reg_s_0 <= Sprime[4]; //READING S4
			reg_s_1 <= Sprime[5]; //READING S5
			
			address_a_0 <= {read_counter_64[4:0], 1'd0}; //equivalent to 2n SETTING UP ADDRESS FOR S8
			address_b_0 <= {read_counter_64[4:0], 1'd1}; //equivalent to 2n + 1 SETTING UP ADDRESS FOR S9
			read_counter_64 <= read_counter_64 + 6'd1;
			
			state <= S_C_TIMES_S_15;
		end
			
		S_C_TIMES_S_15: begin
			select_m2 <= 4'd15;
			
			T_even_32 <= T_even_32 + result0 + result2;
			T_odd_32 <= T_odd_32 + result1 + result3;
			
			reg_s_0 <= Sprime[6]; //READING S6
			reg_s_1 <= Sprime[7]; //READING S7
			address_a_0 <= {read_counter_64[4:0], 1'd0}; //equivalent to 2n SETUP FOR S10
			address_b_0 <= {read_counter_64[4:0], 1'd1}; //equivalent to 2n + 1 SETUP FOR S11
			read_counter_64 <= read_counter_64 + 6'd1;
			
			state <= S_C_TIMES_S_16;
		end
		
		S_C_TIMES_S_16: begin
			/* Writing Teven and Todd to Dram1 */
			wren_a_1 <= 1'b1;
			wren_b_1 <= 1'b1;
			address_a_1 <= {write_T_counter_64[4:0], 1'd0}; //equivalent to 2n SETUP FOR S12
			address_b_1 <= {write_T_counter_64[4:0], 1'd1}; //equivalent to 2n + 1 SETUP FOR S13
			data_a_1 <= {{8{T_even_32[31]}}, T_final_even_32[31:8]}; //WRITING 6
			data_b_1 <= {{8{T_odd_32[31]}}, T_final_odd_32[31:8]}; //WRITING 7
			
			write_T_counter_64 <= write_T_counter_64 + 6'd1;
			
			address_a_0 <= {read_counter_64[4:0], 1'd0}; //equivalent to 2n SETUP FOR S12
			address_b_0 <= {read_counter_64[4:0], 1'd1}; //equivalent to 2n + 1 SETUP FOR S13
			read_counter_64 <= read_counter_64 + 6'd1;

			//Reset both T odd and T even values for next accumulation
			T_odd_32 <= 32'd0;
			T_even_32 <= 32'd0; 
			
			select_m2 <= 4'd0;

			reg_s_0 <= q_a_0; //READING S8
			reg_s_1 <= q_b_0; //READING S9
			Sprime[0] <= q_a_0; //saving s8
			Sprime[1] <= q_b_0; //saving s9
			
			//loop back to the beginning to write the second line
			if (write_T_counter_64 < 6'd31) begin
				state <= S_C_TIMES_S_1;
			end else begin
				state <= S_SETUP_COMPUTE_S;
			end
			
		end

		S_SETUP_COMPUTE_S: begin
			wren_a_1 <= 1'b0;
			wren_b_1 <= 1'b0;

			address_a_1 <= {t0_2[2:0], t0_2[5:3]}; //equivalent to 2n SETTING ADDRESS TO T0
			address_b_1 <= {t1_2[2:0], t1_2[5:3]}; //equivalent to 2n + 1 SETTING ADDRESS TO T8
			read_counter_64_T <= read_counter_64_T + 6'd1;
			
			state <= S_DELAY_COMPUTE_S;
		end
		
		S_DELAY_COMPUTE_S: begin
			address_a_1 <= {t0_2[2:0], t0_2[5:3]}; //equivalent to 2n SETTING ADDRESS TO T16
			address_b_1 <= {t1_2[2:0], t1_2[5:3]}; //equivalent to 2n + 1 SETTING ADDRESS TO T24
			read_counter_64_T <= read_counter_64_T + 6'd1;
			
			state <= S_S_TIMES_T_S0;
		end
		
		S_S_TIMES_T_S0: begin
					select_m2 <= 4'd0;
					
					wren_a_2 <= 1'b0;
					wren_b_2 <= 1'b0;
					
					reg_s_0 <= q_a_1; //reading in T0
					reg_s_1 <= q_b_1; //reading in T8
					T_saved[0] <= q_a_1;
					T_saved[1] <= q_b_1;
					
					address_a_1 <= {t0_2[2:0], t0_2[5:3]}; //equivalent to 2n SETTING ADDRESS TO T32
					address_b_1 <= {t1_2[2:0], t1_2[5:3]}; //equivalent to 2n + 1 SETTING ADDRESS TO T40
					read_counter_64_T <= read_counter_64_T + 6'd1;
					
					state <= S_S_TIMES_T_S1;
		end
		
		S_S_TIMES_T_S1: begin
			wren_a_2 <= 1'b0;
			wren_b_2 <= 1'b0;
			
			select_m2 <= 4'd1;
			
			reg_s_0 <= q_a_1; //reading in T16
			reg_s_1 <= q_b_1; //reading in T24
			T_saved[2] <= q_a_1;
			T_saved[3] <= q_b_1;
			
			address_a_1 <= {t0_2[2:0], t0_2[5:3]}; //equivalent to 2n SETTING ADDRESS TO T48
			address_b_1 <= {t1_2[2:0], t1_2[5:3]}; //equivalent to 2n + 1 SETTING ADDRESS TO T56
			read_counter_64_T <= read_counter_64_T + 6'd1;
			
			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		
			state <= S_S_TIMES_T_S2;
		end
		
		S_S_TIMES_T_S2: begin
			select_m2 <= 4'd2;
			
			reg_s_0 <= q_a_1; //reading in T32
			reg_s_1 <= q_b_1; //reading in T40
			T_saved[4] <= q_a_1;
			T_saved[5] <= q_b_1;
			
			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation
			state <= S_S_TIMES_T_S3;
			
		end
		
		S_S_TIMES_T_S3: begin
			select_m2 <= 4'd3;
			
			reg_s_0 <= q_a_1; //reading in T48
			reg_s_1 <= q_b_1; //reading in T56
			T_saved[6] <= q_a_1;
			T_saved[7] <= q_b_1;

			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		

			state <= S_S_TIMES_T_S4;	
		
		end
		
		S_S_TIMES_T_S4: begin
			wren_a_2 <= 1'b1;
			wren_b_2 <= 1'b1;
			address_a_2 <= {s0_2[2:0], s0_2[5:3]}; //equivalent to 2n
			address_b_2 <= {s1_2[2:0], s1_2[5:3]}; //equivalent to 2n + 1
			data_a_2 <= S_0_final; //WRITING 0
			data_b_2 <= S_8_final; //WRITING 8
			write_counter_64_S <= write_counter_64_S + 6'd1;
			
			select_m2 <= 4'd4;
			
			reg_s_0 <= T_saved[0]; //reading in T0 again
			reg_s_1 <= T_saved[1]; //reading in T8 again
			
			//Reset both S0 and S8 for the next accumulation
			S_0 <= 32'd0;
			S_8 <= 32'd0;
				
			state <= S_S_TIMES_T_S5;
			
		end			
		
		S_S_TIMES_T_S5: begin
			wren_a_2 <= 1'b0;
			wren_b_2 <= 1'b0;
			
			select_m2 <= 4'd5;
			
			reg_s_0 <= T_saved[2]; //reading in saved t16
			reg_s_1 <= T_saved[3]; //reading in saved t24

			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		

			state <= S_S_TIMES_T_S6;
		end
		
		S_S_TIMES_T_S6: begin
			select_m2 <= 4'd6;
			
			reg_s_0 <= T_saved[4]; //reading in saved t16
			reg_s_1 <= T_saved[5]; //reading in saved t24


			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		

			state <= S_S_TIMES_T_S7;	
		end
			
		S_S_TIMES_T_S7: begin
			select_m2 <= 4'd7;
			
			reg_s_0 <= T_saved[6]; //reading in saved t16
			reg_s_1 <= T_saved[7]; //reading in saved t24

			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		

			state <= S_S_TIMES_T_S8;
		end		
				
		S_S_TIMES_T_S8: begin
			wren_a_2 <= 1'b1;
			wren_b_2 <= 1'b1;
			address_a_2 <= {s0_2[2:0], s0_2[5:3]}; //equivalent to 2n
			address_b_2 <= {s1_2[2:0], s1_2[5:3]}; //equivalent to 2n + 1
			data_a_2 <= S_0_final; //WRITING 16
			data_b_2 <= S_8_final; //WRITING 24
			
			write_counter_64_S <= write_counter_64_S + 6'd1;
			
			select_m2 <= 4'd8;
					
			reg_s_0 <= T_saved[0]; //reading in T0 again
			reg_s_1 <= T_saved[1]; //reading in T8 again
			
			//Reset both S0 and S8 for the next accumulation
			S_0 <= 32'd0;
			S_8 <= 32'd0;

			state <= S_S_TIMES_T_S9;	
			
		end	
		
		S_S_TIMES_T_S9: begin
			wren_a_2 <= 1'b0;
			wren_b_2 <= 1'b0;
			
			select_m2 <= 4'd9;
			
			reg_s_0 <= T_saved[2]; //reading in saved t16
			reg_s_1 <= T_saved[3]; //reading in saved t24

			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		

			state <= S_S_TIMES_T_S10;	
		end

		S_S_TIMES_T_S10: begin
			select_m2 <= 4'd10;
			
			reg_s_0 <= T_saved[4]; //reading in saved t32
			reg_s_1 <= T_saved[5]; //reading in saved t40

			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		

			state <= S_S_TIMES_T_S11;
		end
							
		S_S_TIMES_T_S11: begin
			select_m2 <= 4'd11;
			
			reg_s_0 <= T_saved[6]; //reading in saved t16
			reg_s_1 <= T_saved[7]; //reading in saved t24

			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		

			state <= S_S_TIMES_T_S12;

		end
					
		S_S_TIMES_T_S12: begin
			wren_a_2 <= 1'b1;
			wren_b_2 <= 1'b1;
			address_a_2 <= {s0_2[2:0], s0_2[5:3]}; //equivalent to 2n
			address_b_2 <= {s1_2[2:0], s1_2[5:3]}; //equivalent to 2n + 1
			data_a_2 <= S_0_final; //WRITING 32
			data_b_2 <= S_8_final; //WRITING 40
			
			select_m2 <= 4'd12;
									
			reg_s_0 <= T_saved[0]; //reading in T0 again
			reg_s_1 <= T_saved[1]; //reading in T8 again
			
			//Reset both S0 and S8 for the next accumulation
			S_0 <= 32'd0;
			S_8 <= 32'd0;

			state <= S_S_TIMES_T_S13;
		end
		
		S_S_TIMES_T_S13: begin
			wren_a_2 <= 1'b0;
			wren_b_2 <= 1'b0;
			
			write_counter_64_S <= write_counter_64_S + 6'd1;
			select_m2 <= 4'd13;
			
			reg_s_0 <= T_saved[2]; //reading in saved t16
			reg_s_1 <= T_saved[3]; //reading in saved t24


			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		

			state <= S_S_TIMES_T_S14;
		end
		
		S_S_TIMES_T_S14: begin
			select_m2 <= 4'd14;
			
			reg_s_0 <= T_saved[4]; //reading in saved t32
			reg_s_1 <= T_saved[5]; //reading in saved t40

			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		

			address_a_1 <= {t0_2[2:0], t0_2[5:3]}; //equivalent to 2n SETTING ADDRESS TO T01
			address_b_1 <= {t1_2[2:0], t1_2[5:3]}; //equivalent to 2n + 1 SETTING ADDRESS TO T09
			read_counter_64_T <= read_counter_64_T + 6'd1;

			state <= S_S_TIMES_T_S15;
		end
						
		S_S_TIMES_T_S15: begin
			select_m2 <= 4'd15;
			
			reg_s_0 <= T_saved[6]; //reading in saved t16
			reg_s_1 <= T_saved[7]; //reading in saved t24

			S_0 <= S_0 + result0 + result2; //Calculating S0 accumulation
			S_8 <= S_8 + result1 + result3; //Calculation S8 accumulation		
			
			address_a_1 <= {t0_2[2:0], t0_2[5:3]}; //equivalent to 2n SETTING ADDRESS TO T17
			address_b_1 <= {t1_2[2:0], t1_2[5:3]}; //equivalent to 2n + 1 SETTING ADDRESS TO T25
			read_counter_64_T <= read_counter_64_T + 6'd1;
			state <= S_S_TIMES_T_S16;	
		end			
		
		S_S_TIMES_T_S16: begin
			wren_a_2 <= 1'b1;
			wren_b_2 <= 1'b1;
			address_a_2 <= {s0_2[2:0], s0_2[5:3]}; //equivalent to 2n
			address_b_2 <= {s1_2[2:0], s1_2[5:3]}; //equivalent to 2n + 1
			data_a_2 <= S_0_final; //WRITING 48
			data_b_2 <= S_8_final; //WRITING 56
			
			write_counter_64_S <= write_counter_64_S + 6'd1;
			
			address_a_1 <= {t0_2[2:0], t0_2[5:3]}; //equivalent to 2n SETTING ADDRESS TO T17
			address_b_1 <= {t1_2[2:0], t1_2[5:3]}; //equivalent to 2n + 1 SETTING ADDRESS TO T25
			read_counter_64_T <= read_counter_64_T + 6'd1;
			
			//Reset both S0 and S8 for the next accumulation
			S_0 <= 32'd0;
			S_8 <= 32'd0;
			
			select_m2 <= 4'd0;			
			
			reg_s_0 <= q_a_1; //reading in T1 
			reg_s_1 <= q_b_1; //reading in T9 
			T_saved[0] <= q_a_1;
			T_saved[1] <= q_b_1;		
						
			if (write_counter_64_S < 6'd31) begin
				state <= S_S_TIMES_T_S1;
			end else begin 
			
				state <= S_SETUP_WRITE_S;
				compute_t_or_s <= 1'b0; //stopped computing S..
				write_counter_64_S <= 6'd0;
				delay_counter_64 <= 6'd0; //clearing the counter used to Fetch S'
				
			end	
		end
		
		
		S_SETUP_WRITE_S: begin
			counter_64_w <= 5'd0;
			wren_a_2 <= 1'b0;
			wren_b_2 <= 1'b0;
			address_a_2 <= {s0_2}; //equivalent to 2n
			address_b_2 <= {s1_2}; //equivalent to 2n + 1
			write_counter_64_S <= write_counter_64_S + 6'd1;
			
			state <= S_DELAY_WRITE_S;
		end
		
		S_DELAY_WRITE_S: begin
			address_a_2 <= {s0_2}; //equivalent to 2n
			address_b_2 <= {s1_2}; //equivalent to 2n + 1
			write_counter_64_S <= write_counter_64_S + 6'd1;
			
			state <= S_WRITE_S;
		end
		
		S_WRITE_S: begin
			address_a_2 <= {s0_2}; //equivalent to 2n
			address_b_2 <= {s1_2}; //equivalent to 2n + 1
			write_counter_64_S <= write_counter_64_S + 6'd1;
			SRAM_we_n <= 1'b0;
			SRAM_address <= Y_OFFSET + total_address_y_w;
			SRAM_write_data <= {s_8_0, s_8_1};
			counter_64_w <= counter_64_w + 5'd1;
			write_counter_32 <= write_counter_32 + 5'd1;
			
			if (counter_64_w < 5'd31) begin
				state <= S_WRITE_S;
			end else begin
				M2_done <= 1'b1;
			end
		end	
		
		default: state <= S_M2_IDLE;
		endcase
	end

end


assign s_8_0 = q_a_2[31] ? 8'd0 : 
			|q_a_2[30:24] ? 8'hFF : 
			q_a_2[23:16];
			
assign s_8_1 = q_b_2[31] ? 8'd0 : 
			|q_b_2[30:24] ? 8'hFF : 
			q_b_2[23:16];


endmodule