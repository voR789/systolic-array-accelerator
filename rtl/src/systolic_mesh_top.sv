module systolic_mesh_top #(
    ROW_NUM    = 2,
    COL_NUM    = 2,
    ACT_WIDTH  = 8,
    PSUM_WIDTH = 24
) (
    // Global Control Signals
    input  logic                                      i_clk        ,
    input  logic                                      i_rst_n      ,
    input  logic                                      i_ee         ,
    // Global control flags
    // Must propogate each signal by row because of how data moves through systolic array in a skew
    input  logic                                      i_load_weight_array[ACT_WIDTH-1:0],
    input  logic                                      i_clear_acc_array[PSUM_WIDTH-1:0]  ,
    // Data I/O Buses
    // Choose packed array in order to have physical proximity on FPGA, as well as ARM AXI integration
    input  logic signed [ROW_NUM-1:0][ ACT_WIDTH-1:0] i_act_array  ,
    input  logic signed [COL_NUM-1:0][PSUM_WIDTH-1:0] i_psum_array ,
    output logic signed [ROW_NUM-1:0][ ACT_WIDTH-1:0] o_act_array  ,
    output logic signed [COL_NUM-1:0][PSUM_WIDTH-1:0] o_psum_array 
);
    // Intermediate routing meshes - pass data from one PE to another
    // Make 1 larger in order to hold output boundaries
    // Use unpacked arrays when we represent seperate physical boundaries (spatial representation), as well as make it easier for generate indexing
    logic signed [ ACT_WIDTH-1:0] act_mesh[ROW_NUM-1:0][  COL_NUM:0];
    logic signed [PSUM_WIDTH-1:0] psum_mesh[  ROW_NUM:0][COL_NUM-1:0];

    // Use loop unrolling in order to create configuration for mesh boudaries
    always_comb begin : mesh_boundary_comb
        for(int r = 0; r < ROW_NUM; r++) begin
            act_mesh[r][0] = i_act_array[r]; // Connect input to beginning horizontal side of mesh
            o_act_array[r] = act_mesh[r][COL_NUM]; // Connect output to ending horizontal side of mesh of mesh
        end

        for(int c = 0; c < COL_NUM; c++) begin
            psum_mesh[0][c] = i_psum_array[c];
            o_psum_array[c] = psum_mesh[ROW_NUM][c];
        end
    end

    // Use generate for creating copies of PE submodules
    genvar r;
    genvar c;
    generate
        for(r = 0; r < ROW_NUM; ++r) begin : gen_row
            for(c = 0; c < COL_NUM; ++c) begin : gen_col
                pe(
                    .i_clk(i_clk),
                    .i_rst_n(i_rst_n),
                    .i_ee(i_ee),
                    .i_load_weight(i_load_weight),
                    .i_clear_acc(i_clear_acc),
                    .i_act(act_mesh[r][c]),
                    .i_psum(psum_mesh[r][c]),
                    .o_act(act_mesh[r][c+1]),
                    .o_psum(psum_mesh[r+1][c]),
                );
            end
        end
    endgenerate

endmodule