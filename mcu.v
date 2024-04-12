`define	CLK_30HZ_DIV4		24'd225000
`define	CLK_100HZ_DIV4		24'd67500
`define	CLK_3375KHZ_DIV4	24'd2

module mcu_connections (
	output	[15:0]	addr,
	output	[7:0]		data,

	output	rden,
	output	wren,
	
	output	ccpu,
	output	cram,

	inout		[7:0]		p0,
	//inout		[7:0]		p1,
	//inout		[7:0]		p2,
	//inout		[7:0]		p3,

	input		clk,
	
	input		rst
);

// CLOCK	
	reg	[23:0]	clk_counter = 24'd0;
	reg	clk_div = 1'b0;
	reg	clk_div_2 = 1'b0;

	reg	clk_cpu = 1'b0;
	reg	clk_ram = 1'b0;	
	assign ccpu = clk_cpu;
	assign cram = clk_ram;
	
// CONNECTIONS
	wire	[15:0]	addr_cpu;
	wire	[7:0]		data_cpu;

	wire	[7:0]		data_ram_out;
	wire	[7:0]		data_pio_out;

	assign data = data_cpu;
	assign addr = addr_cpu;

	assign data_cpu = rden ? 
							addr_cpu <= 16'h01FF ? data_ram_out :
							addr_cpu >= 16'h0200 & addr_cpu <= 16'h020F ? data_pio_out :
							8'bzzzzzzzz : 8'bzzzzzzzz;

// ENABLE_SIGNALS
	wire	ce_ram;
	wire	ce_pio;
	assign	ce_ram = addr_cpu <= 16'h01FF ? 1'b1 : 1'b0;
	assign	ce_pio = addr_cpu >= 16'h0200 & addr_cpu <= 16'h020F ? 1'b1 : 1'b0;

	wire rst_reverse;
	assign rst_reverse = ~rst;

// ALWAYS
	always @(posedge clk) begin
		clk_counter = clk_counter + 1'b1;

		if (clk_counter >= `CLK_3375KHZ_DIV4) begin
			clk_div = ~clk_div;
			clk_counter = 24'd0;
		end
	end

	always @(posedge clk_div)
		clk_div_2 = rst ? ~clk_div_2 : 1'b0;
	
	always @(posedge clk_div_2)
		clk_cpu = rst ? ~clk_cpu : 1'b0;
	
	always @(negedge clk_div_2)
		clk_ram = rst ? ~clk_ram : 1'b0;
	
// MODULES
	// CPU
	cpu cpu (
		.addr		(addr_cpu),
		.clk		(clk_cpu),
		.data		(data_cpu),
		.we		(wren),
		.re		(rden),
		.rst		(rst)
	);

	// RAM	($0000 - $01FF)
	ram ram (
		.dout		(data_ram_out), 	//output [7:0] dout
		.clk		(clk_ram), 			//input clk
		.oce		(ce_ram),		 	//input oce
		.ce		(ce_ram), 			//input ce
		.reset	(rst_reverse),		//input reset
		.wre		(wren), 				//input wre
		.ad		(addr_cpu[8:0]), 	//input [8:0] ad
		.din		(data_cpu) 			//input [7:0] din
   );

	// PIO	($0200 - $020F)
	pio pio (
		.p0			(p0),
		//.p1			(p1),
		//.p2			(p2),
		//.p3			(p3),
		.clk			(clk_ram),
		.wren			(wren),
		.rden			(rden),
		.addr			(addr_cpu[3:0]),
		.data_in		(data_cpu),
		.data_out	(data_pio_out),
		.ce			(ce_pio),
		.rst			(rst)
	);

endmodule