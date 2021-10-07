module cache_4w_8bitsAdrs_4wordsBlock_16bitsWord_pseudoLRU(
	input clk,
	input [31:0] i_address, 
	input [15:0] i_data,
	input w,
	output [15:0] o_data,
	output o_write_back,
	output [63:0] o_write_back_block	
);	
	reg  [351:0]cache[0:255];
	reg  [3:0]lru[0:255];//for writing's policy opmization, relies on a corollary of locality
	
	//decomposing Address from input
	wire [1:0] block_offset;
	assign block_offset = i_address[1:0];
	wire [7:0] index;
	assign index = i_address[9:2];
	wire [21:0] tag;
	assign tag = i_address[31:10];
	
	//decomposing Cache Line from Cache
	wire [351:0] cache_line;
	assign cache_line = cache[index];
	
	//asserting tags with the sets for tag validity, for readings
	wire assertT1;
	assign assertT1 = cache_line[349:328] == tag ? 1'b1:1'b0;//1st set tag
	wire assertT2;
	assign assertT2 = cache_line[261:240] == tag ? 1'b1:1'b0;//2nd set tag
	wire assertT3;
	assign assertT3 = cache_line[173:152] == tag ? 1'b1:1'b0;//3rd set tag
	wire assertT4;
	assign assertT4 = cache_line[85:64] == tag ? 1'b1:1'b0;//4th set tag
	wire [3:0] assertancesT;
	assign assertancesT = {assertT1,assertT2,assertT3,assertT4};
	
	//asserting validity bit with tag validity for hitting read validity
	wire assertV1;
	assign assertV1 = cache_line[351] & assertT1;//1st set hit case
	wire assertV2;
	assign assertV2 = cache_line[263] & assertT2;//2nd set hit case
	wire assertV3;
	assign assertV3 = cache_line[175] & assertT3;//3rd set hit case
	wire assertV4;
	assign assertV4 = cache_line[87] & assertT4;//4th set hit case
	wire [3:0] assertancesV;
	assign assertancesV = {assertV1,assertV2,assertV3,assertV4};
	
	//hitting or missing
	wire hit;
	assign hit = (assertV1 | assertV2 | assertV3 | assertV4) & ~w;
	
	//if it's not a hit we write the tag in data's field 
	//we'd need, actually, to fetch from memory instead(and write it back on cache)
	wire miss_write;
	assign miss_write = ~hit & ~w;
	
	/*//decoding the hit from cache line into the a block
	wire [63:0] block;
	assign block = assertV1 == 1 ? cache_line[327:264]:(
		assertV2 == 1 ? cache_line[239:176]:(
			assertV3 == 1 ? cache_line[151:88]:(
				assertV4 == 1 ? cache_line[63:0]:(
					64'b0
				)
			)
		)
	);*///	^^ o mesmo de vv
	//multiplexing the decoded hit from cache line into the a block
	wire [63:0] block;
	wire [1:0] decoded_hitSet;
	decoder4x2 DC4X2_1(
		.in(assertancesV),
		.out(decoded_hitSet)		
	);
	multiplexador4x64 MP4X64_1(
		.sel(decoded_hitSet),
		.in3(cache_line[327:264]),
		.in2(cache_line[239:176]),
		.in1(cache_line[151:88]),
		.in0(cache_line[63:0]),
		.out(block)
	);
	
	//multiplexing the output based on the block's offset
	wire [15:0] data;
	multiplexador4x16 MP4X16_1(
		.sel(block_offset),
		.in3(block[63:48]),
		.in2(block[47:32]),
		.in1(block[31:16]),
		.in0(block[15:0]),
		.out(data)
	);

	//declaring the writing policy accordingly to LRU thumb rule
	wire [1:0] lru_block_index;
	// the LRU table should be updated for hits, writes or miss read's write.
	wire lru_update_bool;
	assign lru_update_bool = hit|w|miss_write;//sempre atualizamos, basicamente
	
	//calculating the least recently used block's position in the LRU table line
	/*assign lru_block_index = lru[index][3] == 0 ? 2'b11:(
		lru[index][2] == 0 ? 2'b10:(
			lru[index][1] == 0 ? 2'b01:(
				lru[index][0] == 0 ? 2'b00:(
					2'b0//never used bc there will always be a 0  
				)
			)
		)
	);*/
	// ^^ is the same as vv
	wire [3:0] not_lru_truth;
	assign not_lru_truth = {~lru[index][3],~lru[index][2],~lru[index][1],~lru[index][0]};
	decoder4x2 DC4X2_2(
		.in(not_lru_truth),
		.out(lru_block_index)		
	); 
	wire [3:0] lru_block_truth;
	encoder2x4 ECX2X4_1(
		.in(lru_block_index),
		.out(lru_block_truth)
	);

	//declaring the write back condition output and data
	reg write_back;
	reg [63:0] write_back_block;

	integer i,cc;
	initial begin
		#0
		cc=0;//for clock cicles in console purposes
		for(i=0;i<256;i=i+1)begin
			cache[i]<=352'b0;
			lru[i]<=4'b0;
		end
		//PARTE 3 - cache inicialization
		cache[0][351:350]<=2'b10;//block validity and dirty 1
		cache[0][349:328]<=22'b001;//block tag 1
		cache[0][279:264]<=22'b001;//block data 1, in the first offset in my cache

		cache[1][351:350]<=2'b10;//block validity and dirty 1
		cache[1][263:262]<=2'b10;//block validity and dirty 2
		cache[1][175:174]<=2'b10;//block validity and dirty 3
		cache[1][261:240]<=22'b010;//block tag 2
		cache[1][173:152]<=22'b001;//block tag 3
		cache[1][ 85: 64]<=22'b011;//blcok tag 4
		cache[1][279:264]<=16'b010;//block data 1
		cache[1][191:176]<=16'b110;//block data 2
		cache[1][103: 88]<=16'b011;//block data 3
		cache[1][ 15:  0]<=16'b000;//block data 4

		cache[2][351:350]<=2'b10;//block validity and dirty 1
		cache[2][279:264]<=16'b101;//block data 1

		cache[3][349:328]<=16'b100;//block data 1

		//PARTE 3 - LRU inicialization
		lru[0][3]<=1'b1;
		
		lru[1][1]<=1'b1;
		lru[1][2]<=1'b1;
		lru[1][3]<=1'b1;

		lru[2][3]<=1'b1;
	end
	always@(posedge clk)begin//posedge synced write
		$display("%d w:%b hit:%b(o_data==block[offset:%b]:%b) adrs:%b i_data:%b
			tag:%b index:%b
			[%b %b %b,%b %b %b,%b %b %b,%b %b %b]
			assertancesT:%b assertancesV:%b
			miss_write:%b
			new assertancesV or lru_block_truth:%b == lru_block_index:%b -> lru[index]:%b
			lru_update_bool:%b(1)
			write_back?(%b)->block:%b",

			cc,w,hit,block_offset,o_data,i_address,i_data,tag,index,
			cache_line[351:350],cache_line[349:328],cache_line[327:264],
			cache_line[263:262],cache_line[261:240],cache_line[239:176],
			cache_line[175:174],cache_line[173:152],cache_line[151:88],
			cache_line[87:86],cache_line[85:64],cache_line[63:0],
			assertancesT,assertancesV,miss_write,lru_block_truth,lru_block_index,lru[index],lru_update_bool,write_back,o_write_back_block
		);
		cc=cc+1;
		if(w==1 || miss_write==1)begin//write in cache and update dirty bit
			//write in cache
			case(lru_block_index)
				2'b11:begin					
					cache[index][351] <= 1;//valid part
					cache[index][349:328] <= tag;//tag part
					case(block_offset)//data part
						2'b11:cache[index][327:312] <= miss_write == 0 ? i_data : tag[15:0];//"tag" gotta be the fecehd data instead
						2'b10:cache[index][311:296] <= miss_write == 0 ? i_data : tag[15:0];
						2'b01:cache[index][295:280] <= miss_write == 0 ? i_data : tag[15:0];
						2'b00:cache[index][279:264] <= miss_write == 0 ? i_data : tag[15:0];
					endcase						
					cache[index][350] <= miss_write == 0 ? 1'b1:1'b0;//dirty part
					if (cache[index][350] == 1)begin//write back block condition pre positive edge clk
						write_back<=1;
						write_back_block<=cache[index][327:264];
					end else begin
						write_back<=0;
					end
				end
				2'b10:begin
					cache[index][263] <= 1;//valid part
					cache[index][261:240] <= tag;//tag part
					case(block_offset)//data part
						2'b11:cache[index][239:224] <= miss_write == 0 ? i_data : tag[15:0];
						2'b10:cache[index][223:208] <= miss_write == 0 ? i_data : tag[15:0];
						2'b01:cache[index][207:192] <= miss_write == 0 ? i_data : tag[15:0];
						2'b00:cache[index][191:176] <= miss_write == 0 ? i_data : tag[15:0];
					endcase	
					cache[index][262] <= miss_write == 0 ? 1'b1:1'b0;//dirty part
					if (cache[index][262] == 1)begin
						write_back<=1;
						write_back_block<=cache[index][239:176];
					end else begin
						write_back<=0;
					end
				end
				2'b01:begin
					cache[index][175] <= 1;//valid part
					cache[index][173:152] <= tag;//tag part
					case(block_offset)//data part
						2'b11:cache[index][151:136] <= miss_write == 0 ? i_data : tag[15:0];
						2'b10:cache[index][135:120] <= miss_write == 0 ? i_data : tag[15:0];
						2'b01:cache[index][119:104] <= miss_write == 0 ? i_data : tag[15:0];
						2'b00:cache[index][103: 88] <= miss_write == 0 ? i_data : tag[15:0];
					endcase	
					cache[index][174] <= miss_write == 0 ? 1'b1:1'b0;//dirty part
					if (cache[index][174] == 1)begin
						write_back<=1;
						write_back_block<=cache[index][151:88];
					end else begin
						write_back<=0;
					end
				end
				2'b00:begin
					cache[index][87] <= 1;//valid part	
					cache[index][85:64] <= tag;//tag part
					case(block_offset)//data part
						2'b11:cache[index][63:48] <= miss_write == 0 ? i_data : tag[15:0];
						2'b10:cache[index][47:32] <= miss_write == 0 ? i_data : tag[15:0];
						2'b01:cache[index][31:16] <= miss_write == 0 ? i_data : tag[15:0];
						2'b00:cache[index][15: 0] <= miss_write == 0 ? i_data : tag[15:0];
					endcase	
					cache[index][86] <= miss_write == 0 ? 1'b1:1'b0;//dirty part
					if (cache[index][86] == 1)begin
						write_back<=1;
						write_back_block<=cache[index][63:0];
					end else begin
						write_back<=0;
					end
				end
			endcase			
		end
		if(lru_update_bool)begin//update LRU for reads and writes, sempre executa, irredundante, para melhor entendimento
			if(hit==1)begin
				if(lru[index] | assertancesV == 4'b1111)begin
					lru[index] <= assertancesV;
				end else begin
					lru[index] <= lru[index] | assertancesV;
				end
			end else if(w==1 || miss_write==1) begin
				if(lru[index] | lru_block_truth == 4'b1111)begin
					lru[index] <= lru_block_truth;
				end else begin
					lru[index] <= lru[index] | lru_block_truth;
				end
			end
		end
	end
	//OUTPUT ASSIGNMENTS
	//defining our offsetted block's data
	assign o_data = data;
	//defining our write back block output
	assign o_write_back = write_back;
	assign o_write_back_block = write_back_block;
endmodule