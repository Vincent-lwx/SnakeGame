module hdmi_snake_top(
	 input           sys_clk			, //系统时钟
	 input           sys_rst_n			,//系统复位信号
	 //按键输入
	 input           key_up				,
	 input           key_down			,
	 input           key_left			,
	 input           key_right			,

	 //红外输入
	 input           remote_in			,
	 
	 //vga接口
	 output          vga_hs				,//行同步信号
	 output          vga_vs				,//场同步信号
	 output  [15:0]  vga_rgb			,//红绿蓝三原色输入

     //hdmi接口
     output wire ddc_scl ,
     output wire ddc_sda ,
     output wire tmds_clk_p ,
     output wire tmds_clk_n , //HDMI时钟差分信号
     output wire [2:0] tmds_data_p ,
     output wire [2:0] tmds_data_n, //HDMI图像差分信号

	 //数码管接口
	 output  [ 5:0]  seg_sel			, // 数码管位选，最左侧数码管为最高位
     output  [ 7:0]  seg_led			, // 数码管段选 

    //蜂鸣器
     output          beep_en			,

	 
	// 在vga_snake_top模块的端口列表中添加LED输出端口
	output 	 [3:0] 		led // 假设有4个LED

	);

	wire        		 vga_clk_w		;     //PLL分频得到25Mhz时钟
    wire     		     hdmi_clk_5x_w	;     //PLL分频得到125Mhz时钟
	wire        		 locked_w		;      //PLL输出稳定信号
	wire        		 rst_n_w		;       //内部复位信号
	wire [15:0] 		 pixel_data_w	;  //像素点数据
	wire [ 9:0] 		 pixel_xpos_w	;  //像素点横坐标
	wire [ 9:0] 		 pixel_ypos_w	;  //像素点纵坐标    

    wire hsync_in;        //Internal 输出行同步信号
    wire vsync_in;        //Internal 输出场同步信号
    wire [15:0] rgb_in ;   //Internal 输出像素信息
    wire rgb_valid; //vga valid signal

	wire        		repeat_en		;   //重复码有效信号
	wire        		data_en			;    //数据有效信号
	wire [7:0]  		data			;       //红外控制码 
	
	wire [19:0] 		score			;
	wire        		en				;
	wire        		sign			;
	wire [5:0]  		point			;
	
	wire        		key_l			;
	wire        		key_r			;
	wire        		key_u			;
	wire        		key_d			;

	wire        		ky_right		;
	wire        		ky_left			;
	wire        		ky_up			;
	wire        		ky_down			;

	wire        		beep_clk		;
	wire                beep_en_eat     ;





//待PLL输出稳定之后，停止复位
assign rst_n_w = sys_rst_n && locked_w;

assign vga_rgb = rgb_in;
   
vga_pll	u_vga_pll(                      //时钟分频模块
	//in
	.inclk0         (sys_clk),    
	.areset         (~sys_rst_n),
    
	//out
	.c0             (vga_clk_w),          //VGA时钟 25M
	.locked         (locked_w),
    .c1             (hdmi_clk_5x_w)          //HDMI时钟 25M
	); 

vga_driver u_vga_driver(
	//in
    .vga_clk        (vga_clk_w),    
    .sys_rst_n      (rst_n_w),  
	.pixel_data     (pixel_data_w),  

	//out
    .vga_hs         (hsync_in),       
    .vga_vs         (vsync_in),       
    .vga_rgb        (rgb_in),  
    .vga_en         (rgb_valid),
    
    .pixel_xpos     (pixel_xpos_w), 
    .pixel_ypos     (pixel_ypos_w)
    ); 
    
vga_display u_vga_display(
	//in
    .vga_clk        (vga_clk_w),
    .sys_rst_n      (rst_n_w),
	 
    .key_down       (key_d),
	.kf_down        (kf_down),

	.key_up         (key_u),
	.kf_up          (kf_up),

	.key_left       (key_l),
	.kf_left        (kf_left),

	.key_right      (key_r),
	.kf_right       (kf_right),

	.con_flag       (data),
	
	//out
	.score          (score),
	.point          (point),
	.en             (en),
	.sign           (sign),
	
	.beep_clk       (beep_clk),
	.beep_en_eat    (beep_en_eat),//蛇吃到食物使能beep_en_eat为1
	
    .pixel_xpos     (pixel_xpos_w),
    .pixel_ypos     (pixel_ypos_w),
    .pixel_data     (pixel_data_w)

    );



/*
//蜂鸣器触发
beep u_beep(
	//in
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	.beep_en_eat     (beep_en_eat),

	//OUT
	// .enb             (beep_clk),
	.beep_en         (beep_en)
	);
*/


//led闪烁
led u_led(
    // .sys_clk(sys_clk),  
	.sys_clk(vga_clk_w),     
    .sys_rst_n(sys_rst_n),    

    .trigger(beep_en_eat),    // 连接触发LED闪烁的信号

    .led(led)              // 连接到LED的第一个输出
);



remote_rcv u_remote_rcv(
    .sys_clk         (sys_clk),
	.sys_rst_n       (sys_rst_n),
	 
	.remote_in       (remote_in),
	.repeat_en       (repeat_en),
	.data_en         (data_en),
	.data            (data)
    );	 

seg_led u_seg_led(
    .clk         (sys_clk),
	.rst_n       (sys_rst_n),
	
	.data            (score),
	.en              (en),
	.point           (point),
	.sign            (sign),
	
	.seg_led         (seg_led),
	.seg_sel         (seg_sel)
    );

// 
//  word U8(.rom_addr(rom_addr),    //保存“请选择难度”模块
        //  .M1(M1));












	



//以下是按键触发代码
key_debounce u_left(
	//in
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	
	.key             (key_left),

	//out
	.key_value       (key_l),//向左
	.key_flag        (kf_left)
);

key_debounce u_right(
	//in
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	
	.key             (key_right),
	
	//out
	.key_value       (key_r),//向右
	.key_flag        (kf_right)
);	

key_debounce u_up(
	//in
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	
	.key             (key_up),
	
	//out
	.key_value       (key_u),//向上
	.key_flag        (kf_up)
);

key_debounce u_down(
	//in
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	
	.key             (key_down),
	
	//out
	.key_value       (key_d),//向下
	.key_flag        (kf_down)
);

//------------- hdmi_ctrl_inst -------------
hdmi_ctrl hdmi_ctrl_inst
(
.clk_1x (vga_clk_w ), //输入系统时钟
.clk_5x (hdmi_clk_5x_w), //输入5倍系统时钟
.sys_rst_n (rst_n_w ), //复位信号,低有效
.rgb_blue ({rgb_in[4:0],3'b0} ), //蓝色分量
.rgb_green ({rgb_in[10:5],2'b0} ), //绿色分量
.rgb_red ({rgb_in[15:11],3'b0} ), //红色分量
.hsync (hsync_in ), //行同步信号
.vsync (vsync_in ), //场同步信号
.de (rgb_valid ), //使能信号
.hdmi_clk_p (tmds_clk_p ),
.hdmi_clk_n (tmds_clk_n ), //时钟差分信号
.hdmi_r_p (tmds_data_p[2] ),
.hdmi_r_n (tmds_data_n[2] ), //红色分量差分信号
.hdmi_g_p (tmds_data_p[1] ),
.hdmi_g_n (tmds_data_n[1] ), //绿色分量差分信号
.hdmi_b_p (tmds_data_p[0] ),
.hdmi_b_n (tmds_data_n[0] ) //蓝色分量差分信号
);
endmodule 