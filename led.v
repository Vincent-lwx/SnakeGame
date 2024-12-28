module led(
    input wire sys_clk,          // 时钟信号
    input wire sys_rst_n,        // 复位信号
    input wire trigger,       // 触发信号，高电平有效
    output reg  [3:0] led            // LED状态，1表示亮，0表示灭
);

// 定义一个计时器来控制LED的亮起时间
reg [21:0] led_timer; 





// LED模块的行为描述
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        led <= 4'b0000;            // 初始状态LED熄灭
    end else begin
        if (trigger) begin    // 如果接收到触发信号
            led <= 4'b1111;        // LED点亮
        end 
        else if(!trigger)begin
            led <= 4'b0000;
        end
        else begin
            led<=led;
        end
    end
end


endmodule
