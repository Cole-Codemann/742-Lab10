module radio_core (
    input  logic        clk,
    input  logic        resetn,
    input  logic        dds_reset,
    input  logic [31:0] fake_adc_pinc,
    input  logic [31:0] tuner_pinc,
    output logic [31:0] timer,
    output logic [31:0] m_axis_tdata,
    output logic        m_axis_tvalid
);

    always_ff @(posedge clk) begin
        if (!resetn) timer <= '0;
        else         timer <= timer + 1'b1;
    end

    logic [31:0] signal_source_padded;
    logic [15:0] signal_source;
    logic signal_source_valid;
    assign signal_source_padded = {16'd0, signal_source};
    dds_compiler_0 signal_source_gen (
        .aclk(clk),                                // input wire aclk
        .aresetn(~dds_reset),                          // input wire aresetn
        .s_axis_phase_tvalid(1'b1),  // input wire s_axis_phase_tvalid
        .s_axis_phase_tdata(fake_adc_pinc),    // input wire [31 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid(signal_source_valid),    // output wire m_axis_data_tvalid
        .m_axis_data_tdata(signal_source)      // output wire [15 : 0] m_axis_data_tdata
    );
    
    logic [31:0] DDS_output;
    logic DDS_valid;
    dds_compiler_1 DDS (
        .aclk(clk),                                // input wire aclk
        .aresetn(~dds_reset),                          // input wire aresetn
        .s_axis_phase_tvalid(1'b1),  // input wire s_axis_phase_tvalid
        .s_axis_phase_tdata(tuner_pinc),    // input wire [31 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid(DDS_valid),    // output wire m_axis_data_tvalid
        .m_axis_data_tdata(DDS_output)      // output wire [31 : 0] m_axis_data_tdata
    );
    
    logic mult_valid;
    logic [79:0] mult_data;
    logic [15:0] mult_out_real, mult_out_imag;
    logic [31:0] mult_out_spliced;
    assign mult_out_real = mult_data[29:14];
    assign mult_out_imag = mult_data[69:54];
    assign mult_out_spliced = {mult_out_imag, mult_out_real};
    cmpy_0 complex_mult (
        .aclk(clk),                              // input wire aclk
        .s_axis_a_tvalid(signal_source_valid),        // input wire s_axis_a_tvalid
        .s_axis_a_tdata(signal_source_padded),          // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(DDS_valid),        // input wire s_axis_b_tvalid
        .s_axis_b_tdata(DDS_output),          // input wire [31 : 0] s_axis_b_tdata
        .m_axis_dout_tvalid(mult_valid),  // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(mult_data)    // output wire [79 : 0] m_axis_dout_tdata
    );
    
    logic [47:0] fir_0_output;
    logic fir_0_valid;
    fir_compiler_0 fir_0 (
        .aclk(clk),                              // input wire aclk
        .s_axis_data_tvalid(mult_valid),  // input wire s_axis_data_tvalid
        .s_axis_data_tready(),  // output wire s_axis_data_tready
        .s_axis_data_tdata(mult_out_spliced),    // input wire [31 : 0] s_axis_data_tdata
        .m_axis_data_tvalid(fir_0_valid),  // output wire m_axis_data_tvalid
        .m_axis_data_tdata(fir_0_output)    // output wire [47 : 0] m_axis_data_tdata
    );
    
    logic [47:0] fir_1_output;
    logic fir_1_valid;
    logic [15:0] fir_1_real, fir_1_imag;
    logic [31:0] fir_1_spliced;
    assign fir_1_real = fir_1_output[15:0];
    assign fir_1_imag = fir_1_output[39:24];
    assign fir_1_spliced = {fir_1_real, fir_1_imag};
    fir_compiler_1 fir_1 (
        .aclk(clk),                              // input wire aclk
        .s_axis_data_tvalid(fir_0_valid),  // input wire s_axis_data_tvalid
        .s_axis_data_tready(),  // output wire s_axis_data_tready
        .s_axis_data_tdata(fir_0_output),    // input wire [47 : 0] s_axis_data_tdata
        .m_axis_data_tvalid(fir_1_valid),  // output wire m_axis_data_tvalid
        .m_axis_data_tdata(fir_1_output)    // output wire [47 : 0] m_axis_data_tdata
    );
              
    assign m_axis_tdata = fir_1_spliced;
    assign m_axis_tvalid = fir_1_valid;

endmodule