`timescale 1ns/1ps

// ROM del ejemplo Dally-Harting compartido en clase.
// Adaptacion: indicar explicitamente las direcciones de carga.

module rom_reg (a, d);

    // Dimensiones y archivo de la ROM.
    parameter b = 32;
    parameter w = 4;
    parameter fileName = "dataFile";

    input  [w-1:0] a;
    output [b-1:0] d;

    // Memoria del ejemplo original.
    reg [b-1:0] rom [2**w-1:0];

    // Cargar la tabla desde la direccion cero.
    initial begin
        $readmemh(fileName, rom, 0, (2**w)-1);
    end

    // Consultar la palabra indicada por la direccion.
    assign d = rom[a];

endmodule