module tb_pe1 ();
    // Goal, verify single PE unit before chaining
    logic               i_clk        ;
    logic               i_rst_n      ;
    logic               ee           ;
    logic               i_load_weight;
    logic               i_clear_acc  ;
    logic               o_load_weight;
    logic               o_clear_acc  ;
    logic signed [ 7:0] i_act        ;
    logic signed [23:0] i_psum       ;

    logic signed [ 7:0] o_act ;
    logic signed [23:0] o_psum;

    pe dut (
        .i_clk        (i_clk        ),
        .i_rst_n      (i_rst_n      ),
        .i_ee         (ee           ),
        .i_load_weight(i_load_weight),
        .i_clear_acc  (i_clear_acc  ),
        .o_load_weight(o_load_weight),
        .o_clear_acc  (o_clear_acc  ),
        .i_act        (i_act        ),
        .i_psum       (i_psum       ),
        .o_act        (o_act        ),
        .o_psum       (o_psum       )
    );

    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;
    end

    typedef struct {
        logic signed [ 7:0] expected_act ;
        logic signed [23:0] expected_psum;
        logic               clear_acc    ; // Flag that signals packet before it should have expected_psum = 0

        // NEW: Control flag pipelines
        logic expected_load_weight;
        logic expected_clear_acc  ;
    } res_packet;
    res_packet         sb_queue     [$];
    logic signed [7:0] loaded_weight   ;
    bit                check_data      ;

    // Drive synchronized input into PE task
    // Push activation, push staggered psum, and add expected outputs to scoreboard
    logic signed [23:0] psum_delay_queue[$];
    task automatic drive_staggered_input(logic signed[7:0] act, logic signed[23:0] psum, logic load, logic clear);
        // Acts as our top level, staggered logic
        logic signed[23:0] staggered_psum;
        psum_delay_queue.push_back(psum);
        if(psum_delay_queue.size() > 1) begin
            staggered_psum = psum_delay_queue.pop_front();
        end else begin
            staggered_psum = 24'sd0;
        end

        // Drive inputs
        i_act = act;
        i_psum = staggered_psum;
        i_load_weight = load;
        i_clear_acc = clear;

        // Send expected results to scoreboard (software side)
        if(!load) begin
            res_packet pkt;
            pkt.expected_act = act;
            pkt.expected_psum = (act * loaded_weight) + psum;
            pkt.clear_acc = clear;

            // NEW: Control flag pipeline
            pkt.expected_load_weight = load;
            pkt.expected_clear_acc = clear;

            // Push to scoreboard queue our "expected" outputs
            sb_queue.push_back(pkt);
        end else begin
            res_packet pkt;
            pkt.expected_act = act;
            pkt.expected_psum = psum;
            pkt.clear_acc = clear;

            // NEW: Control flag pipeline
            pkt.expected_load_weight = load;
            pkt.expected_clear_acc = clear;

            // Push to scoreboard queue our "expected" outputs
            sb_queue.push_back(pkt);
            loaded_weight = act;
        end

        // Consume 1 simulation cycle clock tick
        @(negedge i_clk);
    endtask

    initial begin
        // System reset + initialization
        i_rst_n = 1'b0;
        ee = 1'b1;
        i_load_weight = 1'b0;
        i_clear_acc = 1'b0;
        i_act = 8'sd0;
        i_psum = 24'sd0;
        check_data = 1'b0;

        repeat(2) @(posedge i_clk) // 0 should be propogated through the system by 2 cycles

            @(negedge i_clk);
        i_rst_n = 1'b1;
        $display("[%0t ns] System Reset Completed", $time);

        if(o_act !== 8'sd0 || o_psum !== 8'sd0) begin
            $display("[%0t] ns ERROR: DUT leaked data during reset phase!", $time);
            $finish;
        end

        // Active driving phase
        check_data = 1'b1;
        // =========================================================================
        // PHASE 1: Standard Pipelined Compute Stream (Already verified!)
        // =========================================================================
        $display("[%0t ns] TEST PHASE 1 STARTED: Streaming standard MAC...", $time);
        drive_staggered_input(-8'sd2, 24'sd0, 1'b1, 1'b1); // Load -2 as
        drive_staggered_input(8'sd12, 24'sd120, 1'b0, 1'b0);
        drive_staggered_input(8'sd2, 24'sd10, 1'b0, 1'b0);
        drive_staggered_input(8'sd7, 24'sd83, 1'b0, 1'b0);
        drive_staggered_input(8'sd43, 24'sd1246, 1'b0, 1'b1);
        drive_staggered_input(8'sd23, 24'sd1343, 1'b0, 1'b0);
        drive_staggered_input(8'sd67, 24'sd812, 1'b1, 1'b1);
        drive_staggered_input(8'sd127, 24'sd85, 1'b0, 1'b0);
        drive_staggered_input(8'sd7, 24'sd80, 1'b0, 1'b0);

        // =========================================================================
        // PHASE 2: STRESS TEST - Dynamic Weight Overwrite Hazard
        // =========================================================================
        $display("[%0t ns] TEST PHASE 2 STARTED: Intercepting stream with Weight Load...", $time);
        drive_staggered_input(.act(8'sd50), .psum(24'sd1000), .load(1'b1), .clear(1'b0)); // Mid-stream override
        drive_staggered_input(.act(8'sd10), .psum(24'sd500),  .load(1'b0), .clear(1'b0)); // Uses NEW weight

        // =========================================================================
        // PHASE 3: STRESS TEST - Symmetrical Cross-Over Collision
        // =========================================================================
        $display("[%0t ns] TEST PHASE 3 STARTED: Simultaneous Load and Clear...", $time);
        drive_staggered_input(.act(-8'sd5), .psum(24'sd250),  .load(1'b1), .clear(1'b1)); // Mode Collision
        drive_staggered_input(.act(8'sd12), .psum(24'sd10),   .load(1'b0), .clear(1'b0));
        $display("================================");
        $display("DUT sucessfully passed!");
        $finish;
    end

    // Scoreboard checker
    res_packet exp               ;
    bit        valid_check = 1'b0;

    always @(posedge i_clk) begin
        if(i_rst_n && check_data) begin
            if(sb_queue.size() >= 2) begin // Because pipeline has 2 cycle latency, we make sure the queue has 2 elements before we check
                res_packet temp = sb_queue.pop_front();
                if(sb_queue[0].clear_acc == 1'b1) begin
                    temp.expected_psum = 24'sd0;
                end

                exp         <= temp;
                valid_check <= 1'b1;
            end else begin
                valid_check <= 1'b0;
            end

            if(valid_check) begin
                if(o_act !== exp.expected_act) begin
                    $display("Time: %t", $time);
                    $display("Activation output does not match!");
                    $display("Expected activation: %d", exp.expected_act);
                    $display("Actual activation: %d", o_act);
                end
                if(o_psum !== exp.expected_psum) begin
                    $display("Time: %t", $time);
                    $display("Partial sum does not match!");
                    $display("Expected partial sum: %d", exp.expected_psum);
                    $display("Actual partial sum: %d", o_psum);
                end
                if(o_load_weight !== exp.expected_load_weight) begin
                    $display("Time: %t", $time);
                    $display("Output load weight does not match!");
                    $display("Expected load weight: %d", exp.expected_load_weight);
                    $display("Actual load weight: %d", o_load_weight);    
                end
                if(o_clear_acc !== exp.expected_clear_acc) begin
                    $display("Time: %t", $time);
                    $display("Output clear accumulator does not match!");
                    $display("Expected clear accumulator: %d", exp.expected_clear_acc);
                    $display("Actual clear accumulator: %d", o_clear_acc);
                end
            end
        end
    end
endmodule