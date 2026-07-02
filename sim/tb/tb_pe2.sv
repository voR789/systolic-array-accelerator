module tb_pe2 #(
    ROW_NUM    = 2;
    COL_NUM    = 2;
    ACT_WIDTH  = 8;
    PSUM_WIDTH = 24;
) ();

    logic               i_clk        ;
    logic               i_rst_n      ;
    logic               ee           ;
    logic               i_load_weight;
    logic               i_clear_acc  ;

    logic signed [ROW_NUM-1:0][ ACT_WIDTH-1:0] i_act_array  ,
    logic signed [COL_NUM-1:0][PSUM_WIDTH-1:0] i_psum_array ,
    logic signed [ROW_NUM-1:0][ ACT_WIDTH-1:0] o_act_array  ,
    logic signed [COL_NUM-1:0][PSUM_WIDTH-1:0] o_psum_array 

    systolic_mesh_top dut#(
        .ROW_NUM(ROW_NUM),
        .COL_NUM(COL_NUM),
        .ACT_WIDTH(ACT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH)
    )(
        .i_clk        (i_clk        ),
        .i_rst_n      (i_rst_n      ),
        .i_ee         (ee           ),
        .i_load_weight(i_load_weight),
        .i_clear_acc  (i_clear_acc  ),
        .i_act_array(i_act_array),
        .i_psum_array(i_psum_array),
        .o_act_array(o_act_array),
        .o_psum_array(o_psum_array)
    );

    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;
    end

    bit check_data;

    initial begin
        // System reset + initialization
        i_rst_n = 1'b0;
        i_ee = 1'b1;
        i_load_weight = 1'b0;
        i_clear_acc = 1'b0;
        i_act_array = '0;
        i_psum_array = '0;
        check_data = 1'b0;

        repeat(2) @ (posedge i_clk);
         
        @(negedge i_clk);
        i_rst_n = 1'b1;
        
        $display("[%0t ns] System Reset Completed", $time);

        if(o_act_array !== '0 || o_psum_array !== '0) begin
            $display("[%0t] ns ERROR: DUT leaked data during reset phase!", $time);
            $finish;
        end
        // End system reset + intialization

        
    end
endmodule