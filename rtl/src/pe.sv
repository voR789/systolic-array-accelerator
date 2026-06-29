module pe(
    // Clock interface
    input logic i_clk,
    input logic i_rst_n,
    input logic i_ee, // Global enable

    input logic i_load_weight, // Load weight flag
    input logic i_clear_acc, // Clear accumulator flag
    input logic signed[7:0] i_act, // Activation input bus from western neighbor
    input logic signed[23:0] i_psum, // Partial sum input bus from northern neighbor

    output logic signed[7:0] o_act, // Registered activation output bus to eastern neighbor
    output logic signed[23:0] o_psum // Registered compute output bus to southern neighbor
)
    // Two outputs -> two pipelines
    // Output 1: Multiply Accumulate Sum propogated vertically, takes at least 2 cycles to run.
    // Output 2: Activation propogated horizontally, no math, but must be buffered by 1 cycle to match output 1.
    
    // Internal Weight Storage
    logic signed [ 7:0] weight_reg;
    
    always_ff @( posedge i_clk ) begin : weight_ff
        if(!i_rst_n) weight_reg <= '0;
        else if( i_load_weight ) weight_reg <= i_act; // Weight is loaded in through activation channel
    end

    // Activation pipeline buffer
    logic signed [ 7:0] act_reg;
    
    always_ff @( posedge i_clk ) begin : act_pipeline
        if(!i_rst_n) begin
            act_reg <= '0;
            o_act <= '0;
        end else begin
            // load weight en...
        end
    end

    // MAC Registers
    logic signed [15:0] prod_reg;

    always_ff @ (posedge i_clk) begin : mac_pipeline
        if(!i_rst_n) begin
            prod_reg <= '0;
            o_psum <= '0;
        end else begin
            // clear acc logic...
        end
    end

    endmodule