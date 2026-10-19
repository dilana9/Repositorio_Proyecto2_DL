`timescale 1ns/1ps

// Activa el reinicio de forma asincrona.
// Libera el reinicio despues de dos flancos ascendentes del reloj.
module m10_sincronizador_reinicio (
    input  logic reloj_pi,
    input  logic reinicio_asincrono_pi,
    output logic reinicio_po
);

    // Primera etapa del sincronizador.
    logic primera_etapa;

    // Dos registros con activacion asincrona del reinicio.
    always_ff @(posedge reloj_pi or posedge reinicio_asincrono_pi) begin
        if (reinicio_asincrono_pi) begin
            primera_etapa <= 1'b1;
            reinicio_po   <= 1'b1;
        end else begin
            primera_etapa <= 1'b0;
            reinicio_po   <= primera_etapa;
        end
    end

endmodule