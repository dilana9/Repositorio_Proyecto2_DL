`timescale 1ns/1ps

// Conversor ROM compartido en clase.
// Adaptacion: parametrizar la ruta del archivo de la tabla.

module bcd_converter #(
    parameter N = 4,
    parameter M = 8,
    parameter ARCHIVO_TABLA = "bcdtable.txt"
) (
    input  logic [N-1:0] input_bin,
    output logic [M-1:0] output_bcd
);

    // La tabla de verdad realiza la conversion.
    rom_reg #(
        .w(N),
        .b(M),
        .fileName(ARCHIVO_TABLA)
    ) ucode (
        .a(input_bin),
        .d(output_bcd)
    );

endmodule