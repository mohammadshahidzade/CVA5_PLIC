
module wishbone_plic_top #(
    parameter TRIGER_MODE = 1, //0 for edge trigger, 1 for level trigger should be always 1 as the edge triger is not implimented
    parameter REGLENGHT = 32, //Register length
    parameter SOURCES = 32, //Number of interrupt sources
    parameter TARGETS = 2, //number of targets for example including the number of cores  * the number of modes(S mode and M mode) + external master interrupt sources such as DMA
    parameter PADDR_SIZE = 30, //Address bus size
    parameter PDATA_SIZE = 32  //Data bus size
)
(
  input                         clk,
  input                         reset,
  input wire wb_cyc,
  input wire wb_stb,
  input wire wb_we,
  input wire [PADDR_SIZE-1:0] wb_adr,
  input wire [PDATA_SIZE-1:0] wb_dat_i,
  output reg [PDATA_SIZE-1:0] wb_dat_o,
  output reg wb_ack,

  input      [SOURCES     -1:0] sources,       //Interrupt sources
  output     [TARGETS     -1:0] targets        //Interrupt targets
);

    reg [2:0] next_state,state;

    localparam IDLE = 3'b000, ACCESS = 3'b001, RESET = 3'b010, ACCESS_DELAY = 3'b011;
    localparam NUM_MODE = 3;
    localparam int IE_SOURCES = (TARGETS*32);//log(targets)+5
    wire [NUM_MODE-1:0] module_select;
    wire [19:0] output_address;

    AddressDecoder #(PADDR_SIZE, NUM_MODE) decoder_inst (
        .address(wb_adr),
        .module_select(module_select),
        .output_address(output_address)
    );

    always @(posedge clk) begin
        if (reset) begin
            state <= RESET;
        end else begin
            state <= next_state;
        end
    end

    always @* begin
    case (state)
        IDLE: begin
            if (wb_cyc && wb_stb) begin
                next_state = ACCESS;
            end else begin
                next_state = IDLE;
            end
        end
        ACCESS: begin
            next_state = ACCESS_DELAY;
            // if (~wb_cyc) begin
            //     next_state = IDLE;
            // end else if(wb_stb) begin
            //     next_state = ACCESS;
            // end
        end
        ACCESS_DELAY: begin
            next_state = IDLE;
        end
        RESET: begin
            next_state = IDLE;
        end
        default: begin
            next_state = IDLE;
        end
    endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            wb_ack <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    wb_ack <= 1'b0;
                end
                ACCESS_DELAY: begin
                    if (wb_stb & wb_cyc) begin
                        wb_ack <= 1'b1;
                    end else begin
                        wb_ack <= 1'b0;
                    end
                end
                default: begin
                    wb_ack <= 1'b0;
                end
            endcase
        end
    end




    reg [SOURCES-1:0] claim_request ;//Interrupt Claim Request
    reg [REGLENGHT-1:0] IP [31:0];//Interrupt Pending for each source
    reg [REGLENGHT-1:0] IPR [SOURCES-1:0];//Interrupt PRoirities for each source
    wire [REGLENGHT-1:0] IP_PR [SOURCES-1:0];//AND of IP and IPR for each source
    wire [REGLENGHT-1:0] IP_PR_IE [SOURCES-1:0] [TARGETS-1:0];//AND of IP and IPR and IE for each source
    wire [REGLENGHT-1:0] MUX_PR [SOURCES-1:0] [TARGETS-1:0];//AND of IP and IPR and IE for each source
    wire [REGLENGHT-1:0] MUX_ID [SOURCES-1:0] [TARGETS-1:0];//AND of IP and IPR and IE for each source
    wire [REGLENGHT-1:0] MUX_SEL [SOURCES-1:0] [TARGETS-1:0];//AND of IP and IPR and IE for each source
    reg  [REGLENGHT-1:0] IE [IE_SOURCES-1:0];//Interrupt Enable for each target
    wire [REGLENGHT-1:0] ID [TARGETS-1:0];//Interrupt ID for the maximum priority peding interrupt
    reg [REGLENGHT-1:0] CLAIM_COMPLETE [TARGETS-1:0];//Interrupt Claim
    reg [REGLENGHT-1:0] THRESHOLD [TARGETS-1:0];//Interrupt Complete
    wire [REGLENGHT-1:0] MAX_ID_TARGETS [TARGETS-1:0];//Maximum ID that is enabled
    wire [REGLENGHT-1:0] MAX_PR_TARGETS [TARGETS-1:0];//Maximum ID that is enabled
    wire [TARGETS-1:0] EIP ;//Maximum ID that is enabled
    wire [SOURCES-1:0] MAX_ID_DECODER [TARGETS-1:0];//Maximum ID that is enabled and complete

    wire  [REGLENGHT-1:0] wire_to_check_ie;
    assign wire_to_check_ie = IE[32];

    wire [REGLENGHT-1:0] diplay_IP_PR_IE [4-1:0];
    assign diplay_IP_PR_IE[0] = IP_PR_IE[0][1];
    assign diplay_IP_PR_IE[1] = IP_PR_IE[1][1];
    assign diplay_IP_PR_IE[2] = IP_PR_IE[2][1];
    assign diplay_IP_PR_IE[3] = IP_PR_IE[3][1];

    wire [REGLENGHT-1:0] diplay_MUX_SEL [4-1:0];
    assign diplay_MUX_SEL[0] = MUX_SEL[0][1];
    assign diplay_MUX_SEL[1] = MUX_SEL[1][1];
    assign diplay_MUX_SEL[2] = MUX_SEL[2][1];
    assign diplay_MUX_SEL[3] = MUX_SEL[3][1];


    always @(posedge clk) begin
        if (reset) begin
            wb_dat_o <= 0;
            
            // Initialize arrays to zero
            for (integer i = 0; i < 32; i = i + 1) begin
                IP[i] <= 0;
            end
            for (integer i = 0; i < SOURCES; i = i + 1) begin
                IPR[i] <= 0;
            end
            for (integer i = 0; i < IE_SOURCES; i = i + 1) begin
                IE[i] <= 0;
            end
            for (integer i = 0; i < TARGETS; i = i + 1) begin
                CLAIM_COMPLETE[i] <= 0;
                THRESHOLD[i] <= 0;
            end
        end else begin
            if(state == ACCESS | state == ACCESS_DELAY) begin
                    if (wb_stb & wb_cyc) begin
                        case (module_select)
                            3'b000: begin
                                if(wb_we)
                                    IPR[output_address] <= wb_dat_i;
                                else
                                    wb_dat_o <= IPR[output_address];
                            end
                            3'b001: begin
                                // if(wb_we)
                                //     IP[output_address] <= wb_dat_i;
                                // else
                                if(~wb_we)
                                    wb_dat_o <= IP[output_address];
                            end
                            3'b010: begin
                                if(wb_we)
                                    IE[output_address*32] <= wb_dat_i;
                                else
                                    wb_dat_o <= IE[output_address*32];
                            end
                            3'b011: begin
                                if(wb_we)
                                    THRESHOLD[output_address] <= wb_dat_i;
                                else
                                    wb_dat_o <= THRESHOLD[output_address];
                            end
                            3'b100: begin
//                                claim_request[output_address] <= 1'b1;
                                if(~wb_we) begin
                                    if(MAX_ID_TARGETS[output_address]>0)begin
                                        claim_request[MAX_ID_TARGETS[output_address]-1] <= 1'b1;
                                    end
                                    wb_dat_o <= CLAIM_COMPLETE[output_address];
                                end else begin
                                    claim_request[wb_dat_i-1] <= 1'b0;
                                end
                            end
                            default: begin
                                wb_dat_o <= 0;
                            end
                        endcase
                    end else begin
                            wb_dat_o <= 0;
                    end
            end
        end
end

    genvar i;
    genvar j;
    
    generate
        for (i = 1; i < SOURCES; i = i + 1) begin : SOURCES_GEN
            localparam int d = (i-1)/32;
            localparam int r = (i-1)%32;
            assign IP_PR[i]  = {32{IP[d][r]}} & IPR[i]; 
        end
    endgenerate



    generate
        for (j = 0; j < TARGETS; j = j + 1) begin : Initialize
            assign IP_PR_IE[0][j] =  0;
            assign MUX_PR[0][j] =  0;
            assign MUX_ID[0][j] =  0;
            assign MUX_SEL[0][j] =  0;
        end
        for (i = 1; i < SOURCES; i = i + 1) begin : CELL_GEN
            for (j = 0; j < TARGETS; j = j + 1) begin : AND_IP_PR_GEN
                localparam int d = (i-1)/32;
                localparam int r = (i-1)%32;
                assign IP_PR_IE[i][j]  = IP_PR[i] & {32{IE[j*32+d][r]}};
                assign MUX_SEL[i][j] = IP_PR_IE[i][j]>IP_PR_IE[i-1][j] ? 1'b1 : 1'b0;
                assign MUX_PR[i][j] = MUX_SEL[i][j] ? IP_PR[i] :  MUX_PR[i-1][j];
                assign MUX_ID[i][j] = MUX_SEL[i][j] ? i :  MUX_ID[i-1][j]; 
            end
        end
    endgenerate


    generate
        for (j = 0; j < TARGETS; j = j + 1) begin : TARGET_GEN
            assign MAX_ID_TARGETS[j] = MUX_ID[SOURCES-1][j];
            assign MAX_PR_TARGETS[j] = MUX_PR[SOURCES-1][j];
            assign EIP[j] = MAX_PR_TARGETS[j] > THRESHOLD[j];
            assign ID[j] = MAX_ID_TARGETS[j];
//            Decoder #(LOG_SOURCES,SOURCES) decoder_inst (
//                .in(MAX_ID_TARGETS[LOG_SOURCES-1:0]),
//                .out(MAX_ID_DECODER[j])
//            );
            always @(posedge clk) begin
                if (reset) begin
                    CLAIM_COMPLETE[j] <= 0;
                end else begin
                    CLAIM_COMPLETE[j] <= ID[j]>0 ? ID[j] : 0;
                end
            end
        end
    endgenerate
    
    assign targets = EIP;

    generate
        for (i = 0; i < SOURCES; i = i + 1) begin : INTERRUPT_PENDING_GEN
            localparam int d = i/32;
            localparam int r = i%32;
            always @(posedge clk) begin
                if (reset) begin
                    IP[d][r] <= 0;
                end else begin
                    if(TRIGER_MODE && sources[i] && claim_request[i]==0)begin
                        IP[d][r] <= 32'b1;
                    end else if(claim_request[i]==0) begin
                        IP[d][r] <= IP[d][r];
                    end else begin
                        IP[d][r] <= 32'b0;
                    end
                end
            end
        end
    endgenerate


endmodule


module AddressDecoder #(
    parameter PADDR_SIZE = 30, // Address bus size
    parameter NUM_MODE = 3 // Number of modules to decode
) (
    input wire [PADDR_SIZE-1:0] address,
    output wire [NUM_MODE-1:0] module_select,
    output wire [19:0] output_address
);
    wire [19:0] real_address;
    assign real_address = address[19:0];

    assign module_select = (real_address <= 20'h003FF && real_address >= 20'h00000) ? 3'b000 :
                           (real_address <= 20'h0041F && real_address >= 20'h00400) ? 3'b001 :
                           (real_address <= 20'h7C7FF && real_address >= 20'h00800) ? 3'b010 :
                           ((real_address-20'h80000)%(20'h00400))==20'h00000 ? 3'b011 :
                           ((real_address-20'h80000)%(20'h00400))==20'h00001 ? 3'b100 : 3'b101;
    
    
    
    
    assign output_address = (module_select == 3'b000) ? real_address-20'h00000 :
                            (module_select == 3'b001) ? real_address-20'h00400 :
                            (module_select == 3'b010) ? real_address-20'h00800 :
                            (module_select == 3'b011) ? ((real_address-20'h80000)/(20'h00400)) :
                            (module_select == 3'b100) ? ((real_address-20'h80000)/(20'h00400)) :
                            real_address;
endmodule




//module Decoder #(
//  parameter EncodeWidth = 4,
//  parameter DecodeWidth = 2 ** EncodeWidth
//) (
//  input  logic [EncodeWidth-1:0] in,
//  output logic [DecodeWidth-1:0] out
//);

//  always_comb begin
//    // Initialize all output bits to 0
//    out = '0;

//    // Set the corresponding decoded bit to 1
//    out[in] = 1'b1;
//  end

//endmodule
