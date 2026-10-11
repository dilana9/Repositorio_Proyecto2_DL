`timescale 1ns/1ps

module m7_adaptador_bcd #(
    parameter ARCHIVO_TABLA = "src/design/bcdtable.txt"
) (
    input  logic        reloj_pi,
    input  logic        reinicio_pi,
    input  logic [9:0]  numero_binario_pi,
    output logic [11:0] bcd_po,
    output logic        bcd_valido_po
);

    // ============================================================
    // REGISTRO DE ENTRADA Y SENAL DE VALIDEZ
    // ============================================================

    logic [9:0] numero_reg;
    logic       entrada_valida_reg;
    logic [11:0] bcd_rom;

    // ============================================================
    // CONVERSOR DEL CURSO BASADO EN ROM
    // ============================================================

    bcd_converter #(
        .N(10),
        .M(12),
        .ARCHIVO_TABLA(ARCHIVO_TABLA)
    ) conversor (
        .input_bin(numero_reg),
        .output_bcd(bcd_rom)
    );

    // ============================================================
    // CAPTURA CONTINUA Y REGISTRO DE SALIDA
    // ============================================================

    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi) begin
            numero_reg         <= 10'd0;
            entrada_valida_reg <= 1'b0;
            bcd_po             <= 12'h000;
            bcd_valido_po      <= 1'b0;
        end else begin
            // Capturar la nueva muestra.
            numero_reg <= numero_binario_pi;

            // Comprobar el rango admitido por tres digitos decimales.
            entrada_valida_reg <=
                (numero_binario_pi <= 10'd999);

            // Publicar la conversion de la muestra anterior.
            bcd_po <= entrada_valida_reg
                ? bcd_rom
                : 12'h000;

            bcd_valido_po <= entrada_valida_reg;
        end
    end

endmodule
