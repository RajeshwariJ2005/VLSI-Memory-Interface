`timescale 1ns/1ps
module tb_memory_interface;
    reg clk, rst, we, re;
    reg [3:0] addr;
    reg [7:0] wdata;
    wire [7:0] rdata;
    wire single_error, double_error;
    integer bit_no;

    memory_interface dut (
        .clk(clk), .rst(rst), .we(we), .re(re), .addr(addr), .wdata(wdata),
        .rdata(rdata), .single_error(single_error), .double_error(double_error)
    );

    always #5 clk = ~clk;

    task write_word;
        input [3:0] a;
        input [7:0] d;
        begin
            @(negedge clk); addr = a; wdata = d; we = 1'b1; re = 1'b0;
            @(negedge clk); we = 1'b0;
        end
    endtask

    task read_word;
        input [3:0] a;
        begin
            @(negedge clk); addr = a; re = 1'b1; we = 1'b0;
            @(posedge clk); #1;
            re = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("memory_interface.vcd");
        $dumpvars(0, tb_memory_interface);
        clk = 0; rst = 1; we = 0; re = 0; addr = 0; wdata = 0;
        repeat (2) @(negedge clk);
        rst = 0;

        // Test 1: normal write and read.
        write_word(4'd0, 8'hA5);
        read_word(4'd0);
        if (rdata !== 8'hA5 || single_error !== 1'b0 || double_error !== 1'b0)
            $fatal(1, "FAIL: normal read/write");
        $display("PASS: normal memory write/read");

        // Test 2: inject each of the 13 possible single-bit faults.
        for (bit_no = 0; bit_no < 13; bit_no = bit_no + 1) begin
            write_word(4'd1, 8'h3C);
            @(negedge clk); dut.mem[1][bit_no] = ~dut.mem[1][bit_no];
            read_word(4'd1);
            if (rdata !== 8'h3C || single_error !== 1'b1 || double_error !== 1'b0)
                $fatal(1, "FAIL: single-bit correction at codeword bit %0d", bit_no);
        end
        $display("PASS: all 13 single-bit error positions corrected");

        // Test 3: inject two different bit faults; decoder must flag the error.
        write_word(4'd2, 8'h96);
        @(negedge clk);
        dut.mem[2][2] = ~dut.mem[2][2];
        dut.mem[2][8] = ~dut.mem[2][8];
        read_word(4'd2);
        if (double_error !== 1'b1 || single_error !== 1'b0)
            $fatal(1, "FAIL: double-bit error was not detected");
        $display("PASS: double-bit error detected");

        $display("ALL TESTS PASSED");
        #10 $finish;
    end
endmodule
