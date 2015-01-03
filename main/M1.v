/*
Copyright by Henry Ko and Nicola Nicolici
Developed for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

`include "define_state.h"

// This is the top module
// It connects the SRAM and VGA together
// It will first write RGB data of an image with 8x8 rectangles of size 40x30 pixels into the SRAM
// The VGA will then read the SRAM and display the image
module M1 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock
		input logic resetn,
		output logic [17:0] SRAM_address,
		output logic [15:0] SRAM_write_data,
		input logic [15:0] SRAM_read_data,
		output logic SRAM_we_n,
		input logic M1_enable,
		output logic [31:0] temp_0,
		output logic [31:0] temp_1,
		output logic M1_done,
		output logic [7:0] reg_v_0, //j-5
		output logic [7:0] reg_v_1, //j-3
		output logic [7:0] reg_v_2, //j-1
		output logic [7:0] reg_v_3, //j+1
		output logic [7:0] reg_v_4, //j+3
		output logic [7:0] reg_v_5, //j+5
		output logic [7:0] reg_v_6, //j+7
		output logic [7:0] reg_0, //j-5
		output logic [7:0] reg_1, //j-3
		output logic [7:0] reg_2, //j-1
		output logic [7:0] reg_3, //j+1
		output logic [7:0] reg_4, //j+3
		output logic [7:0] reg_5, //j+5
		output logic [7:0] reg_6 //j+7
);


// Define the offset for Green and Blue data in the memory		
parameter U_OFFSET = 18'd76800,
    V_OFFSET = 18'd19200,
	U_FINAL_OFFSET = 18'd38400,
	V_FINAL_OFFSET = 18'd57600,
	RGB_FINAL_OFFSET = 18'd146944,
	BLUE_EVEN_BASE_ADDRESS = 18'd76800,
	BLUE_ODD_BASE_ADDRESS = 18'd96000;

// Data counter for getting RGB data of a pixel
logic [17:0] data_counter;

M1_state_type state;

//for push button
logic [3:0] PB_pushed;

// For VGA
logic [9:0] VGA_red, VGA_green, VGA_blue;
logic [9:0] pixel_X_pos;
logic [9:0] pixel_Y_pos;

//reg 6 buffer
logic [15:0] reg_6_buffer; //j+7 buffer

logic [31:0] temp_u_even;
logic [31:0] temp_u_odd;
logic [31:0] temp_v_even;
logic [31:0] temp_v_odd;
logic [31:0] temp_y_even;
logic [31:0] temp_y_odd;

logic [7:0] temp_2;

//multiplication registers
logic [31:0] total;
logic [31:0] first_value;
logic [31:0] second_value;
logic [31:0] op1;
logic [31:0] op2;
logic [31:0] utemp_0;
logic [31:0] utemp_1;
logic [31:0] temp_0_swap;
logic [31:0] temp_1_swap;
logic [31:0] total_u_1;
logic [31:0] total_u_2;
logic [31:0] total_u_3;
logic [31:0] total_v_1;
logic [31:0] total_v_2;
logic [31:0] total_v_3;

// For SRAM
logic [17:0] u_counter;
logic [17:0] v_counter;
logic [17:0] y_counter;
logic v_loaded;
logic SRAM_ready;
logic [3:0] select;
logic [15:0] VGA_sram_data [5:0];
logic swap_j_7;
logic first_common_cycle;
logic [17:0] u_counter_2;
logic [17:0] v_counter_2;
logic [31:0] temp_y0_constant;
logic [31:0] temp_y1_constant;
logic [17:0] rgb_counter;


//UV odd upsampled values
logic [31:0] u1;
logic [31:0] v1;

//RGB even and RGB odd on 32 bits
logic [31:0] red_32;
logic [31:0] green_32;
logic [31:0] blue_32;
logic [31:0] red_32_1;
logic [31:0] green_32_1;
logic [31:0] blue_32_1;

//RGB even and RGB odd on 8 bits
logic [4:0] LEADOUT_count;
logic [7:0] red_8;
logic [7:0] green_8;
logic [7:0] blue_8;
logic [7:0] red_8_1;
logic [7:0] green_8_1;
logic [7:0] blue_8_1;
logic [31:0] ytemp;

logic [7:0] blue_8_write;
logic [7:0] red_8_write;
logic [7:0] green_8_write;

logic [7:0] green_8_1_write;
logic [7:0] red_8_1_write;
logic [7:0] blue_8_1_write;

logic [31:0] delay_u_odd;
logic [31:0] delay_v_odd;
logic [31:0] temp_u_odd_total;
logic [31:0] temp_v_odd_total;
//0 if in U common case, 1 if in V common case
logic u_or_v_flag;

//assign resetn = ~SWITCH_I[17] && SRAM_ready;

always_comb begin
	op1 = 32'd0;
	op2 = 32'd0;
	temp_0 = 32'd0;
	temp_1 = 32'd0;
	blue_32 = 32'd0;
	red_32 = 32'd0;
	green_32 = 32'd0;
	red_32_1 = 32'd0;
	blue_32_1 = 32'd0;
	green_32_1 = 32'd0;
		if (select == 4'd0) begin
			op1 = 32'd21;
			op2 = 32'd52;
			if (u_or_v_flag == 1'b1)begin
				if (first_common_cycle == 1'b0) begin
					temp_0 = {24'd0, reg_v_1}; //buffer j-3
					temp_1 = {24'd0, reg_v_0}; 
				end
				else begin
					temp_0 = {24'd0, reg_v_4}; //buffer j-1
					temp_1 = {24'd0, reg_v_3}; //buffer j-1
				end
			end else begin
				if (first_common_cycle == 1'b0) begin
					temp_0 = {24'd0, reg_1}; //buffer j-3
					temp_1 = {24'd0, reg_0}; 
				end
				else begin
					temp_0 = {24'd0, reg_4}; //buffer j-1
					temp_1 = {24'd0, reg_3}; //buffer j-1
				end
			end
		end
		
		if (select == 4'd1) begin
			op1 = 32'd159;
			op2 = 32'd159;
			if (u_or_v_flag == 1'b1) begin
				temp_1 = {24'd0, reg_v_2}; //buffer j-1
				temp_0 = {24'd0, reg_v_3}; //buffer j+1
			end else begin
				temp_1 = {24'd0, reg_2}; //buffer j-1
				temp_0 = {24'd0, reg_3}; //buffer j+1
			end
		end
		
		if (select == 4'd2) begin
			op1 = 32'd52;
			op2 = 32'd21;
	
			if (u_or_v_flag == 1'd1) begin
				temp_1 = {24'd0, reg_v_2}; //buffer j+3
				temp_0 = {24'd0, reg_v_3}; //buffer j+5
			end
			 else begin
				temp_1 = {24'd0, reg_2}; //buffer j+3
				temp_0 = {24'd0, reg_3}; //buffer j+5
			 end
		end
		
		if (select == 4'd3) begin //colour conv for Y
			op1 = 32'd76284;
			op2 = 32'd76284;
			temp_0 = {24'd0,(temp_y_odd - 32'd16)}; //read y1
		    temp_1 = {24'd0, (temp_y_even - 32'd16)}; //read y0
		end
		
		if (select == 4'd4) begin //colour conv for U
			op1 = 32'd25624;
			op2 = 32'd132251;
			temp_1 = (temp_u_even - 32'd128); //u0 times 25624
			temp_0 = (temp_u_even - 32'd128); //u0 times 132251
			blue_32 = temp_y0_constant + second_value;
		end
		
		if (select == 4'd5) begin //colour conv for V
			op1 = 32'd104595;
			op2 = 32'd53281;
			temp_1 = (temp_v_even - 32'd128); //v0 times 104595 (first_value)
			temp_0 = (temp_v_even - 32'd128); //v0 times 53281 (second_value)
			
			red_32 = temp_y0_constant + first_value;
			green_32 = temp_y0_constant - utemp_0 - second_value;
		end
		
		if (select == 4'd6) begin 
			op1 = 32'd104595;
			op2 = 32'd53281;
			temp_1 = (delay_v_odd- 32'd128); // 104595*v1
			temp_0 = (delay_v_odd - 32'd128); // 53281*v1  
			red_32_1 = temp_y1_constant + first_value;
		end
		
		if (select == 4'd7) begin
			op1 = 32'd25624;
			op2 = 32'd132251;
			temp_1 = (delay_u_odd - 32'd128); // 25624*u1   first_value
			temp_0 = (delay_u_odd - 32'd128); // 132251*u1   seocnd_value
			green_32_1 = temp_y1_constant - first_value - utemp_1;
			blue_32_1 = temp_y1_constant + second_value;
		end
end

assign first_value = op1*temp_1;
assign second_value = op2 * temp_0;
assign temp_u_odd = temp_u_odd_total[31:8];
assign temp_v_odd = temp_v_odd_total[31:8];
assign temp_u_odd_total = (total_u_1 + total_u_2 + total_u_3);
assign temp_v_odd_total = (total_v_1 + total_v_2 + total_v_3);

assign red_8 = red_32[31] ? 8'd0 :
  (|red_32[30:24]) ? 8'hFF:
  red_32[23:16];

assign green_8 = green_32[31] ? 8'd0 :
  (|green_32[30:24]) ? 8'hFF:
  green_32[23:16];
  
assign blue_8 = blue_32[31] ? 8'd0 :
  (|blue_32[30:24]) ? 8'hFF:
  blue_32[23:16];
  
assign red_8_1 = red_32_1[31] ? 8'd0 :
  (|red_32_1[30:24]) ? 8'hFF:
  red_32_1[23:16];
  
assign blue_8_1 = blue_32_1[31] ? 8'd0 :
  (|blue_32_1[30:24]) ? 8'hFF:
  blue_32_1[23:16];
  
assign green_8_1 = green_32_1[31] ? 8'd0 :
  (|green_32_1[30:24]) ? 8'hFF:
  green_32_1[23:16];

	
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		state <= S_M1_IDLE;
		reg_0 <= 8'd0;
		reg_1 <= 8'd0;
		reg_2 <= 8'd0;
		reg_3 <= 8'd0;
		reg_4 <= 8'd0;
		reg_5 <= 8'd0;
		reg_6 <= 8'd0;
		reg_6_buffer <= 16'd0;
		reg_v_0 <= 8'd0;
		reg_v_1 <= 8'd0;
		reg_v_2 <= 8'd0;
		reg_v_3 <= 8'd0;
		reg_v_4 <= 8'd0;
		reg_v_5 <= 8'd0;
		reg_v_6 <= 8'd0;
		temp_u_even <= 32'd0;
		LEADOUT_count <= 4'd0;
		temp_v_even <= 32'd0;
		temp_y_even <= 32'd0;
		temp_y_odd <= 32'd0;
		delay_u_odd <= 32'd0;
		delay_v_odd <= 32'd0;
		temp_0_swap <= 32'd0;
		temp_1_swap <= 32'd0;
		u_counter <= 18'd0;
		y_counter <= 18'd0;
		v_counter <= 18'd0;
		v_loaded <= 1'b0;
		select <= 4'b0;
		swap_j_7 <= 1'b0;
		first_common_cycle <= 1'b0;
		u_counter_2 <= 18'd0;
		v_counter_2 <= 18'd0;
		temp_y0_constant <= 32'd0;
		temp_y1_constant <= 32'd0;
		rgb_counter <= 18'd0;
		u1 <= 32'd0;
		v1 <= 32'd0;
		SRAM_we_n <= 1'b1;
		SRAM_write_data <= 16'd0;
		SRAM_address <= 18'd0;
		M1_done <= 1'b0;
		data_counter <= 18'd0;
		
	end else begin
		case (state)
		S_M1_IDLE: begin
			if (M1_enable == 1'b1) begin
				// Start filling the SRAM
				state <= S_U_ADDRESS_UPDATE;
				SRAM_address <= 18'd38400; //when U starts
				u_counter <= 18'd0;
				v_counter <= 18'd0;
				
				u_counter_2 <= 18'd0;
				v_counter_2 <= 18'd0;
				// Data counter for getting RGB data of a pixel
				data_counter <= 18'd0;
			end
		end
		S_U_ADDRESS_UPDATE: begin
			SRAM_we_n <= 1'b1;
			SRAM_address <= 18'd38400 + u_counter; //reading U values
			state <= S_DELAY_0;
		end
		S_DELAY_0: begin
			state <= S_DELAY_1;
		end
		S_DELAY_1: begin
			state <= S_FILL_0;
			SRAM_we_n <= 1'b1;
		end
		S_FILL_0: begin
			reg_0 <= SRAM_read_data[15:8];
			state <= S_FILL_1;
		end
		S_FILL_1: begin
			reg_1 <= SRAM_read_data[15:8];
			SRAM_address<=SRAM_address + 18'd1; //update for u2u3
			u_counter <= u_counter + 18'd1;
			state <= S_FILL_2;
		end
		S_FILL_2: begin
			reg_2 <= SRAM_read_data[15:8];
			state <= S_FILL_3;
		end
		S_FILL_3: begin
			reg_3 <= SRAM_read_data[7:0];
			SRAM_address<=SRAM_address + 18'd1; //update for u4u5
			
			u_counter <= u_counter + 18'd1;
			
			state <= S_FILL_4;
		end
		S_FILL_4: begin
			reg_4 <= SRAM_read_data[15:8];
			state <= S_FILL_5;
		end
		S_FILL_5: begin
			reg_5 <= SRAM_read_data[7:0];
			
			SRAM_we_n <= 1'b1;
			state <= S_COMMON_U_0;
			select <= 4'd0;
			 u_or_v_flag <= 1'd0; //set to U
		end
		
		//-------------------------------------------------------------------------------------
		//-------------------------------------U COMMON CASE-----------------------------------
		//-------------------------------------------------------------------------------------
		
		S_COMMON_U_0: begin
			if (first_common_cycle == 1'b0) begin
				temp_u_even <= {24'd0, reg_2} ; //save j-1 (covers even case, where even is 8 MSB)
				temp_0_swap <= {24'd0, reg_1}; //buffer j-3
				temp_1_swap <= {24'd0, reg_0}; 
				total_u_1 <= 32'd128 + first_value - second_value;
				select <= 4'd1;
				
				state <= S_COMMON_U_1;
				SRAM_we_n <= 1'b1;
				
				reg_6_buffer <= SRAM_read_data;
			end else begin
				SRAM_write_data <= {green_8_1_write, blue_8_1_write};
				rgb_counter <= rgb_counter + 1;
				SRAM_address <= RGB_FINAL_OFFSET + rgb_counter;
				reg_5 <= reg_2; //j+7
				reg_4 <= reg_1; //j+5
				reg_3 <= reg_0; //j+3
				reg_2 <= reg_5; //j+1
				reg_1 <= reg_4; //j-1
				reg_0 <= reg_3; //j-3
				total_u_1 <= 32'd128 + first_value - second_value;
				temp_u_even <= {24'd0, reg_5} ; //save j+1 (covers even case, where even is 8 MSB)
				
				temp_0_swap <= {24'd0, reg_4}; //buffer j-1
				temp_1_swap <= {24'd0, reg_3}; //buffer j-3 
				select <= 2'd1;

				state <= S_COMMON_U_1;
			end
		end
				
		S_COMMON_U_1: begin
			SRAM_we_n <= 1'b1;
			if (swap_j_7 == 1'b0) begin
				reg_4 <= reg_6_buffer[15:8];
				SRAM_address <= V_FINAL_OFFSET + v_counter;
			end else begin
				reg_4 <= reg_6_buffer[7:0];
				SRAM_address <= V_FINAL_OFFSET + v_counter;
				u_counter <= u_counter + 1;
			end
			total_u_2 = (first_value + second_value);
			reg_6 <= reg_6_buffer[7:0];
			reg_0 <= reg_2; //j-5 to j-1
			reg_1 <= reg_3; //j-3 to j+1
			reg_2 <= reg_4; //j-1 to j+3
			reg_3 <= reg_5; //j+1 to j+5
			reg_5 <= reg_1;
			
			select <= 4'd2;
			
			state <= S_COMMON_U_2;
		end
		S_COMMON_U_2: begin
 			reg_0 <= reg_2; //j-1 to j+3
			reg_1 <= reg_3; //j+1 to j+5
			reg_2 <= reg_4; //j+3 to j+7
			reg_3 <= reg_5; //j+5 to j-3
			reg_4 <= reg_0;//temp_1_swap[7:0]; //j+7 to j-1
			reg_5 <= reg_1;//temp_0_swap[7:0];//j-3 to j+1
			
			temp_1_swap <= {24'd0, reg_2}; //buffer j+3
			temp_0_swap <= {24'd0, reg_3}; //buffer j+5			
			select <= 4'd0; 
			total_u_3 = (-first_value + second_value);
			
			u_or_v_flag <= 1'd1; //set to V
			
			if (first_common_cycle == 1'b0) begin
				state <= S_V_ADDRESS_UPDATE;
			end
			
			else begin
				state <= S_COMMON_V_0;
				SRAM_address <= 18'b0 + y_counter;
			end
		end	
		
		//-------------------------------------------------------------------------------------
		//-------------------------------------V COMMON CASE-----------------------------------
		//-------------------------------------------------------------------------------------
		
		S_V_ADDRESS_UPDATE: begin
			delay_u_odd <= temp_u_odd;
			SRAM_address <= 18'd57600 + v_counter; //reading V value
			state <= S_DELAY_0_V;
		end
		S_DELAY_0_V: begin
			state <= S_DELAY_1_V;
		end
		S_DELAY_1_V: begin
			state <= S_FILL_0_V;
			SRAM_we_n <= 1'b1;
		end
		S_FILL_0_V: begin
			reg_v_0 <= SRAM_read_data[15:8];
			v_counter <= v_counter + 18'd1;
			state <= S_FILL_1_V;
		end
		S_FILL_1_V: begin
			reg_v_1 <= SRAM_read_data[15:8];
			SRAM_address<= V_FINAL_OFFSET + v_counter; //update for v2v3
			
			
			state <= S_FILL_2_V;
		end
		S_FILL_2_V: begin
			reg_v_2 <= SRAM_read_data[15:8];
			
			state <= S_FILL_3_V;
		end
		S_FILL_3_V: begin
			SRAM_address <= 18'b0 + y_counter;
			v_counter <= v_counter + 18'd1;
			reg_v_3 <= SRAM_read_data[7:0];
			state <= S_FILL_4_V;
		end
		S_FILL_4_V: begin
			SRAM_address<= V_FINAL_OFFSET + v_counter; //update for v4v5
			reg_v_4 <= SRAM_read_data[15:8];
			state <= S_FILL_5_V;
		end
		S_FILL_5_V: begin
			reg_v_5 <= SRAM_read_data[7:0];
			SRAM_we_n <= 1'b1;
			state <= S_COMMON_V_0;
		end
		S_COMMON_V_0: begin
			if (first_common_cycle == 1'b0) begin
				temp_v_even <= {24'd0, reg_v_2} ; //save j-1 (covers even case, where even is 8 MSB)
				temp_0_swap <= {24'd0, reg_v_1}; //buffer j-3
				temp_1_swap <= {24'd0, reg_v_0}; 
				temp_y_even <= {24'd0,SRAM_read_data[15:8]};
				temp_y_odd <= {24'd0,SRAM_read_data[7:0]};
				select <= 4'd1;
				total_v_1 <= 32'd128 + first_value - second_value;		
				
				state <= S_COMMON_V_1;
			end else begin
				delay_u_odd <= temp_u_odd;
				total_v_1 <= (32'd128 + first_value - second_value);
				reg_v_5 <= reg_v_2; //j+7
				reg_v_4 <= reg_v_1; //j+5
				reg_v_3 <= reg_v_0; //j+3
				reg_v_2 <= reg_v_5; //j+1
				reg_v_1 <= reg_v_4; //j-1
				reg_v_0 <= reg_v_3; //j-3
				
				temp_v_even <= {24'd0,reg_v_5} ; //save j+1 (covers even case, where even is 8 MSB)
				
				temp_0_swap <= {24'd0, reg_v_4}; //buffer j-1
				temp_1_swap <= {24'd0, reg_v_3}; 
				select <= 4'd1;

				SRAM_we_n <= 1'b1;	
				state <= S_COMMON_V_1;
			end
		end
				
		S_COMMON_V_1: begin
			if (swap_j_7 == 1'b0) begin
				reg_v_4 <= SRAM_read_data[15:8];
				swap_j_7 <= 1'b1;
			end else begin
				reg_v_4 <= SRAM_read_data[7:0];
				SRAM_address <= SRAM_address + 18'd1;
				swap_j_7 <= 1'b0;
				v_counter <= v_counter + 1'd1;
			end
			total_v_2 = (first_value + second_value);
			
			reg_v_0 <= reg_v_2; //j-5 to j-1
			reg_v_1 <= reg_v_3; //j-3 to j+1
			reg_v_2 <= reg_v_4; //j-1 to j+3
			reg_v_3 <= reg_v_5; //j+1 to j+5
			reg_v_5 <= reg_v_1;//j+5 to j-3

			temp_1_swap <= {24'd0, reg_v_2}; //buffer j-1
			temp_0_swap <= {24'd0, reg_v_3}; //buffer j+1
			
			select <= 4'd2;
			
			state <= S_COMMON_V_2;
		end
		
		S_COMMON_V_2: begin		
			reg_v_0 <= reg_v_2; //j-1 to j+3
			reg_v_1 <= reg_v_3; //j+1 to j+5
			reg_v_2 <= reg_v_4; //j+3 to j+7
			reg_v_3 <= reg_v_5; //j+5 to j-3
			reg_v_4 <= reg_v_0; //j+7 to j-1
			reg_v_5 <= reg_v_1;//j-3 to j+1
			
			temp_1_swap <= {24'd0, reg_v_2}; //buffer j+3
			temp_0_swap <= {24'd0, reg_v_3}; //buffer j+5
			
			select <= 4'd3; 
			total_v_3 = (-first_value + second_value);
			
			if (first_common_cycle == 1'b1) begin
				temp_y_even <= {24'd0,SRAM_read_data[15:8]};
				temp_y_odd <= {24'd0,SRAM_read_data[7:0]};
			end
			state <= S_CONVERSION_Y;			
		end	
		
		
		//-------------------------------------------------------------------------------------
		//-------------------------------------CLR SPACE CONV----------------------------------
		//-------------------------------------------------------------------------------------

		S_CONVERSION_Y: begin
		delay_v_odd <= temp_v_odd;
			select <= 4'd4; //choose U
			temp_y0_constant <= first_value; //save s*y0
			temp_y1_constant <= second_value; //save s*y1
			state <= S_CONVERSION_U;
			
			y_counter <= y_counter + 18'd1;

			SRAM_address <= U_FINAL_OFFSET + u_counter; //set up for next u address
		end
		
		S_CONVERSION_U: begin
			utemp_0 = first_value;
			select <= 4'd5; //choose V
			blue_8_write <= blue_8;
			
			state <= S_CONVERSION_V;
		end
		
		S_CONVERSION_V: begin
			select <= 4'd6;
			red_8_write <= red_8;
			green_8_write <= green_8;
			SRAM_address <= RGB_FINAL_OFFSET + rgb_counter; //set value to first rgb value
			state <= S_FILL_CONV_0;			
		end
		
		S_FILL_CONV_0: begin
			select <= 4'd7; 
			red_8_1_write <= red_8_1;
			utemp_1 = second_value;
			reg_6_buffer <= SRAM_read_data;
			
			SRAM_we_n <= 1'b0;			
			SRAM_write_data <= {red_8_write, green_8_write};			
			rgb_counter <= rgb_counter + 1;
			SRAM_address <= RGB_FINAL_OFFSET + rgb_counter; //set value to first rgb value
			
			state <= S_FILL_CONV_1;
		end
		
		S_FILL_CONV_1: begin
			green_8_1_write <= green_8_1;
			blue_8_1_write<= blue_8_1;
			select <= 4'd0;
			SRAM_we_n <= 1'b0;
			SRAM_address <= RGB_FINAL_OFFSET + rgb_counter; //set value to first rgb value
			rgb_counter <= rgb_counter + 1;
			SRAM_write_data <= {blue_8_write, red_8_1_write};
			
			
			//loop back to delay 1, 
			//ensure all counters are incremented so it works properly
			first_common_cycle <= 1'b1;
			u_or_v_flag <= 1'd0; //set to U
			if ((u_counter%80) == 1'd0) begin
				state <= S_LEADOUT_1;
				LEADOUT_count <= 4'd0;
			end
			else begin
				state <= S_COMMON_U_0;
			end			
		end
		
		S_LEADOUT_1: begin
			LEADOUT_count <= LEADOUT_count + 4'd1;

			SRAM_write_data <= {green_8_1_write, blue_8_1_write};
			rgb_counter <= rgb_counter + 1;
			SRAM_address <= RGB_FINAL_OFFSET + rgb_counter;
			reg_5 <= reg_2; //j+7
			reg_4 <= reg_1; //j+5
			reg_3 <= reg_0; //j+3
			reg_2 <= reg_5; //j+1
			reg_1 <= reg_4; //j-1
			reg_0 <= reg_3; //j-3
			total_u_1 <= 32'd128 + first_value - second_value;
			temp_u_even <= {24'd0, reg_5} ; //save j+1 (covers even case, where even is 8 MSB)

			select <= 2'd1;
			state <= S_LEADOUT_2;
		end
		S_LEADOUT_2: begin
			reg_0 <= reg_2; //j-5 to j-1
			reg_1 <= reg_3; //j-3 to j+1
			reg_2 <= reg_4; //j-1 to j+3
			reg_3 <= reg_5; //j+1 to j+5
			reg_4 <= reg_5; //j+3 to j+7
			reg_5 <= reg_1;//temp_0_swap[7:0];//j+5 to j-3
			total_u_2 = (first_value + second_value);
			select <= 4'd2;
			SRAM_we_n <= 1'b1;	
			
			state <= S_LEADOUT_3;
		end
		
		S_LEADOUT_3: begin
			reg_0 <= reg_2; //j-1 to j+3
			reg_1 <= reg_3; //j+1 to j+5
			reg_2 <= reg_4; //j+3 to j+7
			reg_3 <= reg_5; //j+5 to j-3
			reg_4 <= reg_0;//temp_1_swap[7:0]; //j+7 to j-1
			reg_5 <= reg_1;//temp_0_swap[7:0];//j-3 to j+1
			select <= 4'd0; 
			total_u_3 = (-first_value + second_value);
			SRAM_address <= 18'b0 + y_counter;
			u_or_v_flag <= 1'd1; //set to V
			state <= S_LEADOUT_4;
		end
		
		S_LEADOUT_4: begin
				delay_u_odd <= temp_u_odd;
				total_v_1 <= (32'd128 + first_value - second_value);
				reg_v_5 <= reg_v_2; //j+7
				reg_v_4 <= reg_v_1; //j+5
				reg_v_3 <= reg_v_0; //j+3
				reg_v_2 <= reg_v_5; //j+1
				reg_v_1 <= reg_v_4; //j-1
				reg_v_0 <= reg_v_3; //j-3
				
				temp_v_even <= {24'd0,reg_v_5}  ; //save j+1 (covers even case, where even is 8 MSB)
				temp_0_swap <= {24'd0, reg_v_4}; //buffer j-1
				temp_1_swap <= {24'd0, reg_v_3}; 
				
				select <= 4'd1;
				SRAM_we_n <= 1'b1;	
				state <= S_LEADOUT_5;
		end
		
		S_LEADOUT_5: begin
			reg_v_0 <= reg_v_2; //j-5 to j-1
			reg_v_1 <= reg_v_3; //j-3 to j+1
			reg_v_2 <= reg_v_4; //j-1 to j+3
			reg_v_3 <= reg_v_5; //j+1 to j+5
			reg_v_4 <= reg_v_5; //j+3 to j+7
			reg_v_5 <= reg_v_1;//j+5 to j-3

			temp_1_swap <= {24'd0, reg_v_2}; //buffer j-1
			temp_0_swap <= {24'd0, reg_v_3}; //buffer j+1
			total_v_2 = (first_value + second_value);
			select <= 4'd2;
			
			state <= S_LEADOUT_6;
		end
		
		S_LEADOUT_6: begin
			reg_v_0 <= reg_v_2; //j-1 to j+3
			reg_v_1 <= reg_v_3; //j+1 to j+5
			reg_v_2 <= reg_v_4; //j+3 to j+7
			reg_v_3 <= reg_v_5; //j+5 to j-3
			reg_v_4 <= reg_v_0; //j+7 to j-1
			reg_v_5 <= reg_v_1;//j-3 to j+1
			
			total_v_3 = (-first_value + second_value);
			select <= 4'd3; 
			
			temp_y_even <= {24'd0,SRAM_read_data[15:8]};
			temp_y_odd <= {24'd0,SRAM_read_data[7:0]};

			state <= S_LEADOUT_7;			
		end
		
		S_LEADOUT_7: begin
			delay_v_odd <= temp_v_odd;
			select <= 4'd4; //choose U
			temp_y0_constant <= first_value; //save s*y0
			temp_y1_constant <= second_value; //save s*y1
			state <= S_LEADOUT_8;
			y_counter <= y_counter + 18'd1;
		end
		
		S_LEADOUT_8: begin
			utemp_0 = first_value;
			select <= 4'd5; //choose V
			blue_8_write <= blue_8;
			state <= S_LEADOUT_9;	
		end
		
		S_LEADOUT_9: begin
			select <= 4'd6;
			red_8_write <= red_8;
			green_8_write <= green_8;
			SRAM_address <= RGB_FINAL_OFFSET + rgb_counter; //set value to first rgb value
			state <= S_LEADOUT_10;	
		end
		
		S_LEADOUT_10: begin
			select <= 4'd7; 
			red_8_1_write <= red_8_1;
			utemp_1 = second_value;
			reg_6_buffer <= SRAM_read_data;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {red_8_write, green_8_write};
			rgb_counter <= rgb_counter + 1;
			SRAM_address <= RGB_FINAL_OFFSET + rgb_counter; //set value to first rgb value
			state <= S_LEADOUT_11;
		end
		
		S_LEADOUT_11: begin
			green_8_1_write <= green_8_1;
			blue_8_1_write<= blue_8_1;
			select <= 4'd0;
			SRAM_we_n <= 1'b0;
			SRAM_address <= RGB_FINAL_OFFSET + rgb_counter; //set value to first rgb value
			rgb_counter <= rgb_counter + 1;
			SRAM_write_data <= {blue_8_write, red_8_1_write};
			u_or_v_flag <= 1'd0; //set to U
			
			if (LEADOUT_count == 3'd4) begin
				state <= S_LEADOUT_12;
				first_common_cycle <= 1'b0;
			end else begin
				state <= S_LEADOUT_1;
			end
		end
		
		S_LEADOUT_12: begin
			if ((u_counter == 18'd19200) && (LEADOUT_count == 3'd4)) begin
				SRAM_we_n <= 1'b1;
				M1_done <= 1'b1;
			end
			
			SRAM_write_data <= {green_8_1_write, blue_8_1_write};
			rgb_counter <= rgb_counter + 1;
			SRAM_address <= RGB_FINAL_OFFSET + rgb_counter;
			
			state <= S_U_ADDRESS_UPDATE;
		end

		default: state <= S_M1_IDLE;
		endcase
	end
end

endmodule


