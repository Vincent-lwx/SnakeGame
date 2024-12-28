module vga_display(

    input                vga_clk,               //VGA驱动时钟
    input                sys_rst_n,             //复位信号

	 //按键输入
	input                 key_up,
	input                 kf_up,
	input                 key_down,
	input                 kf_down,
	input                 key_left,
	input                 kf_left,
	input                 key_right,
	input                 kf_right,

	//红外输入
	input      [ 7:0]     con_flag,             //红外控制信号

    //坐标输入
    input      [ 9:0]     pixel_xpos,           //像素点横坐标
    input      [ 9:0]     pixel_ypos,           //像素点纵坐标

    //数码信号输入
	output     reg        en,                   //数码管使能
	output     reg [ 5:0] point,                //小数点
	output     reg        sign,                 //数值正负
    output     reg [19:0] score,                //得分	

	//嗡鸣器输出
	output     reg        beep_clk,             // 嗡鸣器开始倒计时  
	output     reg        beep_en_eat ,  //蛇吃到食物的时候响一下 

    //像素点输出	 
    output     reg [15:0] pixel_data            //像素点数据	

    );


// 640480@60Hz 
//640 10个位宽 480 9个位宽
parameter  H_DISP      = 10'd640;                //分辨率——行
parameter  V_DISP      = 10'd480;                //分辨率——列

//snake_state
parameter  INIT_MAP  =   3'b111;                 //蛇头向左运动的状态
parameter  STATE_LEFT  = 3'b000;                 //蛇头向左运动的状态
parameter  STATE_RIGHT = 3'b001;                 //向右
parameter  STATE_DOWN  = 3'b010;                 //下
parameter  STATE_UP    = 3'b011;                 //上
parameter  STATE_DIE   = 3'b100;                 //g了
parameter  STATE_START = 3'b101;			     //开始游戏


//con_flag code 
parameter  TURN_LEFT   = 8'h44;
parameter  TURN_RIGHT  = 8'h43;
parameter  TURN_UP     = 8'h46;
parameter  TURN_DOWN   = 8'h15;

 
// parameter  MAX_LEN     = 10;                       //蛇的最大长度
// reg [ 12:0] block_x[MAX_LEN-1:0];                   //蛇所有节点的x坐标，block_x[0]为蛇头x坐标
// reg [ 12:0] block_y[MAX_LEN-1:0];                   //蛇所有节点的y坐标，block_y[0]为蛇头y坐标
 


parameter MAX_LEN = 14;          // 蛇的最大长度
reg [14:0] block_x[40:0]; // 蛇所有节点的x坐标，block_x[0]为蛇头x坐标
reg [14:0] block_y[40:0]; // 蛇所有节点的y坐标，block_y[0]为蛇头y坐标

// reg [ 9:0] cur_len;                       //蛇的当前长度
reg [40:0] cur_len;                       //蛇的当前长度




// localparam SIDE_W      = 10'd20;                  //边框宽度
localparam SIDE_W      = 10'd10;                  //边框宽 10个像素
localparam BLOCK_W     = 10'd20;                  //方块宽度

//颜色定义
// localparam BLUE        = 16'b00000_000000_11111;  //边框颜色 蓝色
localparam BLUE        	= 16'h7FFA;  //边框颜色 蓝色
localparam WHITE       	= 16'hFFFF;  //背景颜色 白色
localparam ORANGE       = 16'hFD20;  //背景颜色 橙色
localparam BLACK       	= 16'h0000;  //方块颜色 黑色
localparam RED       	= 16'hF800;  //蛇头颜色 红色
localparam BROWN       	= 16'h8A22;  //蛇头颜色 红色


//reg define
reg [ 2:0] cur_state;//当前状态 现态
reg [ 2:0] next_state;//此态



reg [ 9:0] food_x;                         //食物的x坐标
reg [ 9:0] food_y;                         //食物的y坐标
reg [ 9:0] temp_food_x;                    //临时食物x坐标
reg [ 9:0] temp_food_y;                    //临时食物y坐标


reg [32:0] div_cnt;                       //时钟分频计数器




reg        hit_w;                    //撞墙信号
reg        hit_self;                 //撞自己信号
reg        eated;                    //吃到食物信号
reg        eated_f;
reg        eated_s;
reg        die;                      //死亡信号


integer i;                           //循环计数值

 
wire move_en;                       //蛇移动使能信号，频率为100hz
wire pos_eated;


//控制蛇运动的速度

//25Mhz 40ns
//40ns*800000000 = 40*0.8 = 3.2s  22'd800000000 
//0.5s 0.5s/40ns = 125000000个时钟周期  27'd125000000

// /*
//10ms产生一个脉冲信号,确定蛇的移动速度
assign move_en = (div_cnt == 22'd800000000   - 1'b1) ? 1'b1 : 1'b0;
//通过对vga驱动时钟计数，实现时钟分频
always @(posedge vga_clk or negedge sys_rst_n) begin         
    if (!sys_rst_n)
        div_cnt <= 22'd0 ;
    else begin
		 // 如果计数器未达到10ms的计数，则继续递增
        if(div_cnt < 22'd800000000   - 1'b1) 
            div_cnt <= div_cnt + 1'b1;
        else// 计数器达到10ms的计数后，在下一个时钟周期重置计数器，产生move_en脉冲
            div_cnt <= 22'd0;                     //计数达ms后清零
    end
end
// */


//根据按键输入，改变移动方向
//状态机
always @ (posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
        cur_state <= STATE_START;
		// cur_state <= INIT_MAP;
    else
        cur_state <= next_state ;
end


//这段代码是一个状态机，用于根据当前状态和输入信号来决定蛇的下一个状态。状态机包括开始、左、右、上、下和死亡等状态
//根据玩家的输入和当前的游戏状态来决定蛇的下一个动作
always @(*) begin
    case(cur_state)

	      //next_state = STATE_RIGHT;
		    STATE_START : begin //开始状态
			    if( (key_right == 1'b0 ) || con_flag == TURN_RIGHT )  //按下右键或者当前状态是向右
                    next_state = STATE_RIGHT ; //赋予 向右状态              
                else if((key_left == 1'b0 ) || con_flag == TURN_LEFT) //按下左键或者当前状态是向左                                               
                    next_state = STATE_LEFT; //赋予向左状态
			    else if((key_up == 1'b0 ) || con_flag == TURN_UP) //按下上键或者当前状态是向上     
                    next_state = STATE_UP ; //赋予向上状态            
                else if((key_down == 1'b0 ) || con_flag == TURN_DOWN) //按下  向下键 或者当前状态是向下                                           
                    next_state = STATE_DOWN;//赋予向下状态  
			    else 
		            next_state = STATE_START;//保持原状态
			end
			STATE_LEFT : begin//向左状态
			    if(hit_w || hit_self)
				     next_state = STATE_DIE;
				else if(key_up == 1'b0 || con_flag == TURN_UP)         //按下up键，进入向上的状态，水平向上
                     next_state = STATE_UP ;               
                else if(key_down == 1'b0 || con_flag == TURN_DOWN)       //按下down键，进入向下的状态，水平向下                                               
                     next_state = STATE_DOWN;               
                else 
				     next_state = STATE_LEFT;
			end
		    STATE_RIGHT : begin
			    if(hit_w || hit_self)
				    next_state = STATE_DIE;
			    else if(key_up == 1'b0 || con_flag == TURN_UP)         //按下up键，水平向右
                    next_state = STATE_UP ;               
                else if(key_down == 1'b0 || con_flag == TURN_DOWN)       //按下down键，水平向左                                               
                    next_state = STATE_DOWN;               
                else 
				    next_state = STATE_RIGHT;
			end
		    STATE_DOWN : begin
			    if(hit_w || hit_self)
				    next_state = STATE_DIE;
				else if(key_right == 1'b0 || con_flag == TURN_RIGHT)      //按下右键，水平向右
                    next_state = STATE_RIGHT ;               
                else if(key_left == 1'b0 || con_flag == TURN_LEFT)       //按下左键，水平向左                                               
                    next_state = STATE_LEFT;               
                else 
				    next_state = STATE_DOWN;
				
		    end
	        STATE_UP : begin
			    if(hit_w || hit_self)
				    next_state = STATE_DIE;
				else if(key_right == 1'b0 || con_flag == TURN_RIGHT)      //按下右键，水平向右
                    next_state = STATE_RIGHT ;               
                else if(key_left == 1'b0 || con_flag == TURN_LEFT)       //按下左键，水平向左                                               
                    next_state = STATE_LEFT;               
                else 
				    next_state = STATE_UP;
	        end
			STATE_DIE : begin
			if(key_right == 1'b0 || con_flag == TURN_RIGHT)                        //按下右键，水平向右
                 next_state = STATE_START;            
            else if(key_left == 1'b0 || con_flag == TURN_LEFT)                    //按下左键，水平向左                                               
                 next_state = STATE_START;
			else if(key_up == 1'b0 || con_flag == TURN_UP)                      //按下右键，水平向右
                 next_state = STATE_START;              
            else if(key_down == 1'b0)                    //按下左键，水平向左                                               
                 next_state = STATE_START;
			else
	             next_state = STATE_DIE;		
			end
			
            default : begin
		        next_state = STATE_START;
            end		  
	 endcase 		
end 

//根据蛇头状态，改变其纵横坐标
//描述了蛇在游戏中的移动逻辑，包括蛇头的移动和蛇身体的跟随效果，以及在蛇死亡时重置蛇的位置
always @(posedge vga_clk or negedge sys_rst_n) begin // 这是一个时钟敏感的always块，会在vga_clk的上升沿或sys_rst_n的下降沿触发
    if(!sys_rst_n) begin // 当复位信号sys_rst_n为低时，执行以下代码
        block_x[0] <= 22'd100; // 将蛇头的x坐标设置为100（以像素为单位）
        block_y[0] <= 22'd100; // 将蛇头的y坐标设置为100
        die        <= 0;       // 将死亡信号设置为0，表示蛇初始状态是活着的
    end
    else begin
        if(move_en) // 如果蛇的移动使能信号move_en为高，则根据当前状态更新蛇头坐标
		begin 
            case(cur_state) // 使用case语句根据当前状态cur_state来更新坐标
                STATE_RIGHT: begin // 如果当前状态是向右移动
                    die        <=  1'b0; // 重置死亡信号，因为蛇正在移动
                    block_x[0] <= block_x[0] + 9'd20; // 将蛇头的x坐标增加20，实现向右移动
                end
                STATE_LEFT: begin // 如果当前状态是向左移动
                    die        <=  1'b0; // 同上
                    block_x[0] <= block_x[0] - 9'd20; // 将蛇头的x坐标减少20，实现向左移动
                end
                STATE_UP: begin  // 如果当前状态是向上移动
                    die        <=  1'b0; // 同上
                    block_y[0] <= block_y[0] - 9'd20; // 将蛇头的y坐标减少20，实现向上移动
                end
                STATE_DOWN: begin // 如果当前状态是向下移动
                    die        <=  1'b0; // 同上
                    block_y[0] <= block_y[0] + 9'd20; // 将蛇头的y坐标增加20，实现向下移动
                end
                STATE_DIE: begin // 如果当前状态是死亡
                    block_x[0] <= 22'd100; // 重置蛇头的x坐标到初始位置
                    block_y[0] <= 22'd100; // 重置蛇头的y坐标到初始位置
                    die        <=  1'b1;  // 设置死亡信号为1，表示蛇已死亡
                end
                default: begin
                    block_x[0] <= block_x[0]; // 如果不是以上任何状态，保持坐标不变
                    block_y[0] <= block_y[0];
                end
            endcase

            // 当运动信号使能时，更新蛇的身体节点坐标，以实现蛇的移动效果
            // 蛇的身体节点坐标是复制蛇头前一时刻的坐标
            for(i = 0; i < MAX_LEN - 1; i = i + 1) begin 
                block_x[i+1] <= block_x[i]; // 蛇的身体节点x坐标复制前一个节点的x坐标
                block_y[i+1] <= block_y[i]; // 蛇的身体节点y坐标复制前一个节点的y坐标
            end

        end
        else begin // 如果蛇的移动使能信号move_en为低，则保持当前坐标不变
            block_x[0] <= block_x[0];
            block_y[0] <= block_y[0];
        end
    end
end


//打印蛇，给不同的区域绘制不同的颜色
// 负责根据当前的像素坐标pixel_xpos和pixel_ypos，在VGA显示器上绘制蛇和食物。
// 代码使用了状态机来确定在屏幕的哪个部分绘制什么颜色
always @(posedge vga_clk or negedge sys_rst_n) begin         
    if (!sys_rst_n) 
        pixel_data <= BLACK;//如果复位信号sys_rst_n为低，则将像素数据设置为黑色，通常用于清屏
    else begin

		// 检查像素坐标是否在屏幕边框内，如果是，则绘棕色边框
        if((pixel_xpos < SIDE_W) || (pixel_xpos >= H_DISP - SIDE_W)
          || (pixel_ypos < SIDE_W) || (pixel_ypos >= V_DISP - SIDE_W))
            pixel_data <= BROWN;  //绘制边框为棕色
			
		// 检查像素坐标是否在食物方块内，如果是，则绘制白色食物方块
		else if((pixel_xpos >= food_x) && (pixel_xpos < food_x + BLOCK_W)
			     && (pixel_ypos >= food_y) && (pixel_ypos < food_y + BLOCK_W))
		         pixel_data <= WHITE;   //绘制食物方块为白色

		// 根据蛇的长度cur_len，绘制相应长度的蛇 
        else if(cur_len == 1)//绘制一节的蛇
		begin          
			// 如果是一节蛇，检查当前像素是否在蛇头的方块内，如果是，则绘制红色色蛇头			
		     if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			     && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			     pixel_data <= RED;//绘制方块为红色
		     else // 如果不在蛇头内，则绘制黑色背景
                 pixel_data <= BLACK;                //绘制背景为黑色
        end
		else if(cur_len == 2)//绘制两节的蛇
		begin                   
			//如果是两节蛇，检查当前像素是否在蛇头或蛇身的方块内 
		      if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			       && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
					begin
						pixel_data <= RED;//蛇头为红色
					end    
		      else if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			       && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
				   begin
						pixel_data <= ORANGE;//绘制方块为橙色色
				   end  
		      else
			  		begin
						pixel_data <= BLACK;//绘制背景为黑色 
			  		end
				    
		end
		else if(cur_len == 3) //绘制三节蛇
		begin                    
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			    && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
				begin
					pixel_data <= RED; //蛇头为红色
				end
			    
		    else if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			    && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
				begin
					pixel_data <= ORANGE;//绘制方块为橙色
				end
			    
		    else if((pixel_xpos >= block_x[2]) && (pixel_xpos < block_x[2] + BLOCK_W)
			    && (pixel_ypos >= block_y[2]) && (pixel_ypos < block_y[2] + BLOCK_W))
				begin
					pixel_data <= BLUE;//绘制方块为黑色 
				end
			    
			else
				begin
					pixel_data <= BLACK; //绘制背景为黑色 
				end
		        
	    end
        else if(cur_len == 4)//绘制最上的4节蛇
		begin
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			    && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			    pixel_data <= RED; //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			    && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
			    pixel_data <= ORANGE;  //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[2]) && (pixel_xpos < block_x[2] + BLOCK_W)
			    && (pixel_ypos >= block_y[2]) && (pixel_ypos < block_y[2] + BLOCK_W))
			    pixel_data <= BLUE; //绘制方块为黑色
		    else 
		    if((pixel_xpos >= block_x[3]) && (pixel_xpos < block_x[3] + BLOCK_W)
			    && (pixel_ypos >= block_y[3]) && (pixel_ypos < block_y[3] + BLOCK_W))
			    pixel_data <= ORANGE; //绘制方块为黑色
		    else
		        pixel_data <= BLACK;//绘制背景为白色 
	    end

	    else if(cur_len == 5) 
		begin
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			    && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			    pixel_data <= RED;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			    && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
			    pixel_data <= ORANGE;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[2]) && (pixel_xpos < block_x[2] + BLOCK_W)
			    && (pixel_ypos >= block_y[2]) && (pixel_ypos < block_y[2] + BLOCK_W))
			    pixel_data <= BLUE;                //绘制方块为黑色
		    else 
		    if((pixel_xpos >= block_x[3]) && (pixel_xpos < block_x[3] + BLOCK_W)
			    && (pixel_ypos >= block_y[3]) && (pixel_ypos < block_y[3] + BLOCK_W))
			    pixel_data <= ORANGE;                //绘制方块为黑色
			else
			if((pixel_xpos >= block_x[4]) && (pixel_xpos < block_x[4] + BLOCK_W)
			    && (pixel_ypos >= block_y[4]) && (pixel_ypos < block_y[4] + BLOCK_W))
				pixel_data <= BLUE;                //绘制方块为黑色
		    else
		        pixel_data <= BLACK;                //绘制背景为白色 
	    end

		// 继续绘制更长的蛇身体
		else if(cur_len == 6) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 6; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BLUE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 7) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 7; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BLUE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 8) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 8; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BLUE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		
		else if(cur_len == 9) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 9; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BLUE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		
		else if(cur_len == 10) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 10; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BLUE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 11) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 11; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? BLUE : ORANGE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 12) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 12; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? BLUE : ORANGE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		else if(cur_len == 13) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 13; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? BLUE : ORANGE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 14) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 14; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? BLUE : ORANGE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 15) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 15; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? BLUE : ORANGE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 16) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 16; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? BLUE : ORANGE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		else if(cur_len == 17) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 17; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? BLUE : ORANGE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 18) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 18; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? BLUE : ORANGE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 19) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 19; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? BLUE : ORANGE;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 20) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 20; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 21) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 21; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		else if(cur_len == 22) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 22; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 23) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 23; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 24) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 24; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 25) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 25; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 26) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 26; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 27) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 27; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 28) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 28; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 29) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 29; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? ORANGE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 30) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 30; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 31) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 31; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 32) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 32; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 33) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 33; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 34) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 34; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 35) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 35; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 36) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 36; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 37) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 37; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 38) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 38; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 39) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 39; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
		else if(cur_len == 40) begin
		    // 默认设置像素数据为背景色
		    pixel_data <= BLACK;

		    // 绘制蛇头（红色）
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W) &&
		       (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W)) begin
		        pixel_data <= RED;
		    end

		    // 绘制蛇身，颜色交替为白色和蓝色
		    for(i = 1; i < 40; i = i + 1) begin
		        if((pixel_xpos >= block_x[i]) && (pixel_xpos < block_x[i] + BLOCK_W) &&
		           (pixel_ypos >= block_y[i]) && (pixel_ypos < block_y[i] + BLOCK_W)) begin
		            // 交替颜色，蛇头不交替
		            pixel_data <= (i % 2 == 0) ? WHITE : BROWN;
		            // 找到匹配的蛇身部分后，不需要继续检查
		        end
		    end
		end
		
 
		
		else begin
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			    && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			    && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[2]) && (pixel_xpos < block_x[2] + BLOCK_W)
			    && (pixel_ypos >= block_y[2]) && (pixel_ypos < block_y[2] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else 
		    if((pixel_xpos >= block_x[3]) && (pixel_xpos < block_x[3] + BLOCK_W)
			    && (pixel_ypos >= block_y[3]) && (pixel_ypos < block_y[3] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
			else
			if((pixel_xpos >= block_x[4]) && (pixel_xpos < block_x[4] + BLOCK_W)
			    && (pixel_ypos >= block_y[4]) && (pixel_ypos < block_y[4] + BLOCK_W))
				pixel_data <= BLACK;                //绘制方块为黑色
			else
			if((pixel_xpos >= block_x[5]) && (pixel_xpos < block_x[5] + BLOCK_W)
			    && (pixel_ypos >= block_y[5]) && (pixel_ypos < block_y[5] + BLOCK_W))
				pixel_data <= BLACK;                //绘制方块为黑色
		    else
		        pixel_data <= WHITE;                //绘制背景为白色 
		end
    end
end




//判断蛇是否撞墙
/*
通过比较蛇头的坐标block_x[0]和block_y[0]与屏幕的边界
及边框宽度来确定蛇是否撞墙。如果蛇头的坐标超出了屏幕的
边界（减去或加上边框宽度和蛇身宽度BLOCK_W），则hit_w
会被设置为1，表示发生了撞墙事件。如果没有超出，则hit_w
保持为0，表示蛇没有撞墙
*/
always @(posedge vga_clk or negedge sys_rst_n) begin         
    if (!sys_rst_n) begin
        hit_w <= 0; // 将撞墙信号hit_w初始化为0，表示蛇没有撞墙
    end
    else begin

		// 如果蛇头的x坐标小于屏幕左边界加上边框宽度
        if(block_x[0] < SIDE_W - 1'b1)
            hit_w <= 1'b1; // 表示蛇撞到了左边界    

		// 如果蛇头的x坐标大于屏幕右边界减去边框宽度和蛇身宽度
        else if(block_x[0] > H_DISP - SIDE_W - BLOCK_W)
            hit_w <= 1'b1; // 表示蛇撞到了右边界

		// 如果蛇头的y坐标小于屏幕上边界加上边框宽度
        else if(block_y[0] < SIDE_W - 1'b1)
            hit_w <= 1'b1;// 表示蛇撞到了上边界   

		// 如果蛇头的y坐标大于屏幕下边界减去边框宽度和蛇身宽度            
        else if(block_y[0] > V_DISP - SIDE_W - BLOCK_W)
            hit_w <= 1'b1; // 表示蛇撞到了下边界 

        else
            hit_w <= 1'b0;// 如果以上条件都不满足，表示蛇没有撞墙
    end
end



/*
通过比较蛇头的坐标block_x[0]和block_y[0]与蛇身体的坐标
block_x[1]、block_x[2]、block_x[3]等以及相应的block_y坐标
来确定蛇是否撞到了它自己。如果蛇头的坐标与蛇身体的任何一部分
坐标相同，则hit_self会被设置为1，表示发生了撞到自己的事件。
如果蛇头的坐标与所有身体部分的坐标都不相等，则hit_self保持为0，表示蛇没有撞到自己。
*/
always @(posedge vga_clk or negedge sys_rst_n) begin 
    if (!sys_rst_n) begin 
        hit_self <= 0; // 将撞自己信号`hit_self`初始化为0，表示蛇没有撞到自己
    end
    else begin // 以下是检查蛇是否撞到自己的逻辑
       
        // 首先检查蛇头是否与第一个身体部分坐标相同
        if (block_x[0] == block_x[1] && block_y[0] == block_y[1])
            hit_self <= 1'b1; // 如果相同，表示蛇头撞到了蛇身的第一个
			
        // 然后检查蛇头是否与第二个身体部分坐标相同
        else if (block_x[0] == block_x[2] && block_y[0] == block_y[2])
            hit_self <= 1'b1; // 如果相同，表示蛇头撞到了蛇身的第二个部分

        // 再次检查蛇头是否与第三个身体部分坐标相同
        else if (block_x[0] == block_x[3] && block_y[0] == block_y[3])
            hit_self <= 1'b1; // 如果相同，表示蛇头撞到了蛇身的第三个部分
			
        // 这里只列出了前三个身体部分的检查，实际游戏中可能需要检查更多的身体部分
        // 如果蛇头的坐标与任何身体部分的坐标都不相等，则没有撞到自己
		  else if (block_x[0] == block_x[4] && block_y[0] == block_y[4])
            hit_self <= 1'b1;
			else if (block_x[0] == block_x[5] && block_y[0] == block_y[5])
            hit_self <= 1'b1;
				
				
				
				else if (block_x[0] == block_x[6] && block_y[0] == block_y[6])
            hit_self <= 1'b1;
				else if (block_x[0] == block_x[7] && block_y[0] == block_y[7])
            hit_self <= 1'b1;
				else if (block_x[0] == block_x[8] && block_y[0] == block_y[8])
            hit_self <= 1'b1;
				else if (block_x[0] == block_x[9] && block_y[0] == block_y[9])
            hit_self <= 1'b1;
				else if (block_x[0] == block_x[10] && block_y[0] == block_y[10])
            hit_self <= 1'b1;
				else if (block_x[0] == block_x[11] && block_y[0] == block_y[11])
            hit_self <= 1'b1;
				else if (block_x[0] == block_x[12] && block_y[0] == block_y[12])
            hit_self <= 1'b1;
				else if (block_x[0] == block_x[13] && block_y[0] == block_y[13])
            hit_self <= 1'b1;
				else if (block_x[0] == block_x[14] && block_y[0] == block_y[14])
            hit_self <= 1'b1;
				
				   
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
		else 
            hit_self <= 0;
    end
end

//随机生成食物坐标
//生成食物x坐标
always @(posedge vga_clk or negedge sys_rst_n) begin 
    if(!sys_rst_n) begin
        food_x <= 200; // 如果系统复位，将食物的x坐标设置为200
    end
    else begin
        if(eated) begin
            food_x <= temp_food_x; // 如果蛇吃掉了食物（eated为真），更新食物的x坐标为临时食物的x坐标
        end
        else if(temp_food_x > 560) begin
            temp_food_x <= 200; // 如果临时食物的x坐标大于560，重置为200
        end
        else if(temp_food_x < 200) begin
            temp_food_x <= 580; // 如果临时食物的x坐标小于200，重置为580
        end
        else begin
            temp_food_x <= temp_food_x + 9'd20; // 否则，每次时钟上升沿，临时食物的x坐标增加20
        end 
    end 
end

//生成了食物y坐标
always @(posedge vga_clk or negedge sys_rst_n) begin 
    if(!sys_rst_n) begin
        food_y <= 200; // 如果系统复位，将食物的y坐标设置为200
    end
    else begin
        if(eated) begin
            food_y <= temp_food_y; // 如果蛇吃掉了食物，更新食物的y坐标为临时食物的y坐标
        end
        else if(temp_food_y > 400) begin
            temp_food_y <= 160; // 如果临时食物的y坐标大于400，重置为160
        end
        else if(temp_food_y < 160) begin
            temp_food_y <= 400; // 如果临时食物的y坐标小于160，重置为400
        end
        else begin
            temp_food_y <= temp_food_y + 9'd20; // 否则，每次时钟上升沿，临时食物的y坐标增加20
        end 
    end 
end


//对输入的eated信号延时打拍
always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        eated_f <= 1'b0; // 如果系统复位信号sys_rst_n为低，则将一级触发器eated_f清零
        eated_s <= 1'b0; // 同时将二级触发器eated_s清零
    end
    else begin
        eated_f <= eated; // 在系统没有复位的情况下，将输入信号eated赋值给一级触发器eated_f
        eated_s <= eated_f; // 然后将一级触发器的值赋给二级触发器eated_s，实现信号的延时
    end
end

//判断是否吃到食物
always @(posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
	    eated <= 0;
	end
    else 
    if(block_x[0]==food_x && block_y[0]==food_y) begin
		eated <= 1'b1;
	end 
	else
		eated <= 1'b0;		
end
// 使用assign语句生成食物位置更新信号pos_eated，当蛇吃到食物时产生一个脉冲
assign pos_eated = (~eated_s) & eated_f;


/*
//吃到食物就得分
always @(posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) 
	begin
	    score <= 0;
		en    <= 0;
		point <= 6'b000000;
		sign  <= 0;		
		beep_en_eat <= 0;  // 初始化蜂鸣器使能信号
	end
    else 
	begin
		en    <= 1;
		point <= 6'b000000;
		sign  <= 0;	
		
		if(pos_eated)
		begin
			score <= score + 9'd20; // 增加得分
			beep_en_eat <= 1'b1;       // 当蛇吃到食物时，触发蜂鸣器
		end
		
		else if(die) 
		begin
			score <= 1'b0;
			beep_en_eat <= 0;          // 重置蜂鸣器使能
		end
		
		else begin
			score <= score;
			beep_en_eat <= 1'b0;
		end
		    
	end
end
// */


// /*
// 定义一个计时器，用于控制蜂鸣器的持续时间
reg [21:0] beep_timer; // 22位计数器，足以覆盖32MHz时钟下的0.5秒

always @(posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        score <= 0;
        en <= 0;
        point <= 6'b000000;
        sign <= 0;
        beep_en_eat <= 0;
        beep_timer <= 0; // 初始化计时器
    end 
	else begin
        en <= 1;
        point <= 6'b000000;
        sign <= 0;

        if(pos_eated) //吃到了果果
		begin
            score <= score + 9'd20; // 增加得分
            beep_en_eat <= 1'b1; // 触发蜂鸣器
            beep_timer <= 22'd32000000 / 2; // 设置计时器为0.5秒的计数（32MHz时钟下）
        end 
		else if(beep_en_eat && beep_timer != 0) 
		begin
    		beep_timer <= beep_timer - 1; // 如果蜂鸣器已经触发，开始倒计时
			beep_en_eat <= 1'b1; 
		end
		else if (beep_timer == 0)
		begin
			beep_en_eat <= 0; // 当计时器到0时，关闭蜂鸣器
		end
		else if(die) 
		begin
            score <= 0;
            beep_en_eat <= 0;
            beep_timer <= 0; // 如果蛇死亡，重置计时器
        end  
		// else if(beep_en_eat && beep_timer == 0) begin
        //     beep_en_eat <= 0; // 如果蜂鸣器已经在0.5秒前触发，关闭蜂鸣器
        // end
    end
end
// */

//蛇的长度
always @(posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
	    cur_len  <= 3'b101;
		// beep_clk <= 1'b0;
	end
	else begin
		if(pos_eated) begin
			cur_len  <= cur_len + 1'b1;
		    // beep_clk <= 1'b1;
		end
		else
		if(die) begin
			cur_len  <= 3'b101;
			// beep_clk <= 1'b1;
		end
		else
		    cur_len  <= cur_len;
			// beep_clk <= 1'b0;
	end
end

endmodule 