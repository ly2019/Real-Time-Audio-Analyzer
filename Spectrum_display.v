//All the modules are pasted below:
//Use VGAplayground to simulate. https://vga-playground.com/
//put display as the top module in the tab "project.v"
//also use VGAplayground's built-in hvsync_generator
//put each module into seperate tab



//top module
module display (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,      // 25 MHz pixel clock
    input  wire       rst_n
);
    localparam width  = 640;
    localparam height = 480;
    localparam axis_y = 420;
    localparam axis_x = 20;

    // ---- timing (provided by the playground) ----
    wire       hsync, vsync, active;
    wire [9:0] x0, y0;
    wire [9:0] x, y;
    hvsync_generator hvsync_gen (
        .clk(clk), .reset(~rst_n),
        .hsync(hsync), .vsync(vsync),
        .display_on(active), .hpos(x0), .vpos(y0)
    );

    assign  x = x0 - axis_x;
    assign  y = y0;


    // ---- border and center line ----
    wire border = (x0 < 5) || (x0 >= width - 5) || (y0 < 5) || (y0 >= height - 5);
    wire x_axis = (y == axis_y);
    
    //set the number of bins and binwidth
    localparam binnumber=30, binwidth=600/binnumber;

    // ---- 10 bin edges and the horizontal line ----
    wire [binnumber-1:0] binedge;
    reg  [binnumber-1:0] bin_h;
    reg   [binnumber-1:0] bin;


    reg [179:0] heights_data = 180'd0;
    reg [179:0] heights = 180'd0;
    wire         new_data;
    fake_data u_fake(.clk(clk), .tick(tick), .heights(heights_data), .new_data(new_data));
    
    always @(posedge clk)
        if (x == 10'd0 && y == height)       // frame just finished
            heights <= heights_data;           // take the newest data


    reg [59:0] heights_1 = {6'd10, 6'd10, 6'd10,6'd10,6'd30, 6'd50, 6'd60, 6'd20,6'd10,6'd60};
    reg [59:0]  heights_2 = {6'd10, 6'd10, 6'd10,6'd10,6'd30, 6'd63, 6'd60, 6'd20,6'd10,6'd60};
    reg [59:0]  heights_3 = {6'd63, 6'd10, 6'd10,6'd10,6'd30, 6'd50, 6'd60, 6'd20,6'd10,6'd63};
    //wire [179:0] heights= {heights_1, heights_2, heights_3};


    //draw bars
    genvar i;
    generate
        for (i = 0; i < binnumber; i = i + 1) begin : bar
        if (i ==0)
          assign binedge[i] = ((x >= (i) * binwidth+15) && (x <= (i + 1) * binwidth));   // assign each bin's edges
        else begin
            assign binedge[i] = ((x >= (i) * binwidth+5) && (x <= (i + 1) * binwidth));   // assign each bin's edges
            assign bin_h[i] = ((y >= axis_y - heights[i*6+: 6]*5) && (y <= axis_y)); //read heights data for 6 bits then jump to the next 6 bit
            assign   bin[i] = binedge[i] & bin_h[i];
        end
        end
    endgenerate

    //draw barheight
    
    reg [24:0] clk_cnt = 25'd0;
    wire tick = (clk_cnt == 25'd2_999_999);
    always @(posedge clk)
        clk_cnt <= tick ? 25'd0 : clk_cnt + 1'b1;

   
    reg [5:0] k = 6'd0;
    reg [1:0] R, G, B;
    always @(posedge clk) begin
      if (tick)
        if (k<binnumber)
          k <= k + 1;
        else k <=0;
        R <= (active && (x_axis || (|bin)) && (!border) || (x==40+k && y==40)) ? 2'b10 : 2'b00;
        B <= (active && border || on_label)           ? 2'b10 : 2'b00;
        G <= (active && (border || on_label))            ? 2'b01 : 2'b00;
    end
    
    axis_labels  #(.LAB_DX(3*binwidth), .AXIS_Y(axis_y), .AXIS_X(axis_x),.LAB_Y(axis_y+10)) u_labels ( .x(x), .y(y), .on_label(on_label));

    // ---- output in the playground's order ----
    assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;
    wire _unused = &{ena, ui_in, uio_in};
endmodule

//fake data input
module fake_data (
    input  wire         clk,
    input  wire         tick,          // one pulse per update period
    output reg  [179:0] heights,       // 30 values x 6 bits
    output reg          new_data       // 1-tick pulse when heights change
);
    reg [15:0] lfsr = 16'hACE1;
    always @(posedge clk)
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

    reg [2:0]   sub  = 3'd0;
    reg [179:0] pool = 180'd0;
    always @(posedge clk) begin
        sub <= sub + 1'b1;
        if (sub == 3'd0)
            pool <= {pool[173:0], lfsr[5:0]};
    end

    always @(posedge clk) begin
        new_data <= tick;
        if (tick) heights <= pool;
    end
endmodule


//font module
module font_rom (
    input  wire [3:0] code,     // 0-9 = digits, 10 = 'k'
    input  wire [2:0] row,      // 0..6, top to bottom
    output reg  [4:0] bits      // the 5 dots of that row
);
    reg [34:0] g;
    always @(*) begin
        case (code)
            4'd0:  g = 35'b01110_10001_10011_10101_11001_10001_01110;
            4'd1:  g = 35'b00100_01100_00100_00100_00100_00100_01110;
            4'd2:  g = 35'b01110_10001_00001_00010_00100_01000_11111;
            4'd3:  g = 35'b11110_00001_00001_01110_00001_00001_11110;
            4'd4:  g = 35'b00010_00110_01010_10010_11111_00010_00010;
            4'd5:  g = 35'b11111_10000_11110_00001_00001_10001_01110;
            4'd6:  g = 35'b00110_01000_10000_11110_10001_10001_01110;
            4'd7:  g = 35'b11111_00001_00010_00100_01000_01000_01000;
            4'd8:  g = 35'b01110_10001_10001_01110_10001_10001_01110;
            4'd9:  g = 35'b01110_10001_10001_01111_00001_00010_01100;
            4'd10: g = 35'b10000_10000_10010_10100_11000_10100_10010;   // 'k'
            4'd11: g = 35'd0; 
            default: g = 35'd0;
        endcase
        bits = g[34 - row*5 -: 5];
    end
endmodule

//labeling axis module
module axis_labels #(
    parameter NLAB   = 12,       // labels 0, 1k, ... 7k
    parameter LAB_DX = 80,      // pixels between labels
    parameter AXIS_Y = 420,     // row of the x-axis
    parameter LAB_Y  = 428,      // top row of the text
    parameter AXIS_X = 10,       //begining of the 
    parameter CHAR_N = 3,      //how many characters we need digit + k
    parameter SCALE =2
) (
    input  wire [9:0] x, y,
    output wire       on_label
);
    wire [NLAB-1:0] lab, tickm;
    wire       in_row = (y >= LAB_Y) && (y < LAB_Y + 7*SCALE);  //mark the vertical space needed for the labels
    wire [2:0] lrow   = (y - LAB_Y) / SCALE;               // double-height font row

    localparam W = (SCALE*5+1); // the width of a character
    genvar n;
    generate
      
        for (n = 0; n < NLAB; n = n + 1) begin : l
            localparam X0 = n * LAB_DX + AXIS_X;  //how many pixels away label n is from the first label (0)/ the starting x for this label
            wire [9:0] dx   = x - X0;    //the position of the pixel to the right of the begining position of this label
            wire       in_n = (x >= X0 ) && (x < X0 + ((n == 0) ? W : W*CHAR_N)); //mark the horizontal space for label n
            wire [9:0] cpos = dx % W;   //which character is it? 
            wire [2:0] col  = cpos / SCALE;                 // double-width font column
            reg [3:0] code = 4'd0;
            always @(*) 
              if (n <10) code = (dx >= W*(CHAR_N-1)) ? 4'd11 : (dx >= W*(CHAR_N-2) && dx<W*(CHAR_N-1)) ? (4'd10) : n ;
              else code = (dx >= W*(CHAR_N-1)) ? 4'd10 : ( dx >= W*(CHAR_N-2) && dx<W*(CHAR_N-1)) ? (n%10) : n/10;    // digit, then 'k'
            wire [4:0] rbits;

            font_rom f (.code(code), .row(lrow), .bits(rbits));

            assign lab[n]   = in_row && in_n && (col < 5) && rbits[4 - col];
            assign tickm[n] = (x == X0 ) && (y > AXIS_Y ) && (y <= AXIS_Y + 4);
        end
    endgenerate

    assign on_label = (|lab) || (|tickm);
endmodule
