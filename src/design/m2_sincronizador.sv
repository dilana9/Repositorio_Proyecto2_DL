`timescale 1ns/1ps

// Sincronizacion independiente de las cuatro columnas del teclado.
module m2_sincronizador (
    input  logic       reloj_pi,
    input  logic       reinicio_pi,
    input  logic [3:0] columnas_asincronas_pi,
    output logic [3:0] columnas_sincronizadas_po
);

    // Primera etapa: recibe las entradas externas.
    logic [3:0] primera_etapa;

    // Dos etapas, actualizadas con el reloj principal.
    // Reinicio sincronico, activo en alto.
    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi) begin
            primera_etapa            <= 4'b0000;
            columnas_sincronizadas_po <= 4'b0000;
        end else begin
            primera_etapa            <= columnas_asincronas_pi;
            columnas_sincronizadas_po <= primera_etapa;
        end
    end

endmodule