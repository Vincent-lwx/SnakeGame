module beep(
    input      sys_clk,
	input      sys_rst_n,
	
    // input      enb,                                 //嗡鸣器倒计时使能

    input      beep_en_eat,                           // 蛇吃到食物的触发信号

    output reg beep_en                                 //嗡鸣器使能
    );

// 定义一个32位的寄存器，用于实现1秒的计数器
reg [31:0] delay_cnt;

// 蛇吃到食物之后蜂鸣器叫 50ms
parameter BEEP_DURATION = 32'd16666666;

always @(posedge sys_clk or negedge sys_rst_n) begin 
    if (!sys_rst_n) begin 
        beep_en <= 1'b0;
        delay_cnt <= 32'd0;
    end
    else if (beep_en_eat) begin // 当蛇吃到食物时，触发蜂鸣器
        beep_en <= 1'b1;         // 立即使能嗡鸣器
        delay_cnt <= BEEP_DURATION; // 装载延时计数的初始值
    end
    else if (beep_en) begin // 如果嗡鸣器已经使能，并且enb信号为高
        if (delay_cnt > 32'd0) begin
            delay_cnt <= delay_cnt - 1'b1; // 开始倒计时
        end
        else begin
            beep_en <= 1'b0; // 倒计时结束，关闭嗡鸣器
        end
    end
    else begin
        beep_en <= beep_en; // 保持当前状态
    end
end




endmodule 
