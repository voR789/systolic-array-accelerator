module pe(
    // Clock interface
    input logic i_clk,
    input logic i_rst_n,
    input logic i_ee, // Global enable

    // Control Flags
    // Must assert i_clear_acc if i_load_weight is high
    input logic i_load_weight, // Load weight input from western neighbor
    input logic i_clear_acc, // Clear accumulator input from northern neighbor
    output logic o_load_weight, // Load weight output to eastern neighbor
    output logic o_clear_acc,  // Load weight output to eastern neighbor

    input logic signed[7:0] i_act, // Activation input bus from western neighbor
    input logic signed[23:0] i_psum, // Partial sum input bus from northern neighbor

    output logic signed[7:0] o_act, // Registered activation output bus to eastern neighbor
    output logic signed[23:0] o_psum // Registered compute output bus to southern neighbor
);

    // Two outputs -> two pipelines
    // Output 1: Multiply Accumulate Sum propogated vertically, takes at least 2 cycles to run.
    // Output 2: Activation propogated horizontally, no math, but must be buffered by 1 cycle to match output 1.
    
    // Internal Weight Storage
    logic signed [ 7:0] weight_reg;
    
    always_ff @( posedge i_clk ) begin : weight_ff
        if(!i_rst_n) weight_reg <= '0;
        else if( i_ee ) begin
            if( i_load_weight )
                weight_reg <= i_act; // Weight is loaded in through activation channel        
        end 
    end

    // Local signal pipeline buffer (activation, load_weight, clear_acc)
    logic signed [7:0] act_reg;
    logic load_reg;
    logic clear_reg;
    
    // Pipeline signals to match 2 cycle latency of DSP MAC
    always_ff @( posedge i_clk ) begin : act_pipeline
        if(!i_rst_n) begin
            // Activation pipeline
            act_reg <= '0;
            o_act <= '0;

            // Load_weight flag pipeline
            load_reg <= '0;
            o_load_weight <= '0;

            // Clear_acc flag pipeline
            clear_reg <= '0;
            o_clear_acc <= '0;
        end else if( i_ee )begin
            // Activation pipeline
            act_reg <= i_act;
            o_act <= act_reg;

            // Load_weight flag pipeline
            load_reg <= i_load_weight;
            o_load_weight <= load_reg;

            // Clear_acc flag pipeline
            clear_reg <= i_clear_acc;
            o_clear_acc <= clear_reg;
        end
    end

    // MAC Registers/Nets
    logic signed [15:0] prod_reg;
    logic signed [15:0] next_prod;
    logic signed [7:0] gated_act;

    logic signed [23:0] next_o_psum;

    always_ff @ (posedge i_clk) begin : mac_pipeline
        if(!i_rst_n) begin
            prod_reg <= '0;
            o_psum <= '0;
        end else if( i_ee ) begin
            prod_reg <= next_prod;
            o_psum <= next_o_psum; 
        end
    end

    // Mux activation with zero during loading phase in order to save power.
    assign gated_act = i_load_weight ? 8'sd0 : i_act; 
    assign next_prod = weight_reg * gated_act;
    assign next_o_psum = i_clear_acc ? 24'sd0 : (i_psum + 24'(prod_reg));
endmodule