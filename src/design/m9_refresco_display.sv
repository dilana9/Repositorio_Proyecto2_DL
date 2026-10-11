`timescale 1ns/1ps
`include "seven_seg_defs.sv"

// Adaptacion de disp_hex_mux compartido en clase:
// contador binario, mux 4 a 1 y decodificador de segmentos.
//
// Cambios:
// - Habilitacion desde M1.
// - Polaridad del montaje.
// - Copia registrada de los cuatro simbolos.
// - Codigos de signo y espacio.
// - Pausa entre displays.

module m9_refresco_display #(
    parameter integer CICLOS_APAGADO = 16
) (
    input  logic        reloj_pi,
    input  logic        reinicio_pi,
    input  logic        paso_display_pi,
    input  logic [15:0] simbolos_pi,
    input  logic        simbolos_validos_pi,

    output logic [6:0]  segmentos_po,
    output logic [3:0]  digitos_po
);

    // ============================================================
    // TAMANO DEL CONTADOR DE APAGADO
    // CICLOS_APAGADO DEBE SER MAYOR O IGUAL QUE UNO
    // ============================================================

    localparam integer ANCHO_CONTADOR =
        (CICLOS_APAGADO < 2)
            ? 1
            : $clog2(CICLOS_APAGADO + 1);

    // ============================================================
    // REGISTROS DE ENTRADA Y COPIA DE UN BARRIDO
    // ============================================================

    logic [15:0] simbolos_reg;
    logic validos_reg;

    logic [15:0] marco_reg;

    // ============================================================
    // INDICE BINARIO Y MULTIPLEXOR DE SIMBOLOS
    // ============================================================

    logic [1:0] indice_reg;
    logic [15:0] simbolos_elegidos;
    logic [3:0] simbolo_actual;

    logic [6:0] segmentos_actuales;

    // ============================================================
    // CONTROL DEL CAMBIO ENTRE DISPLAYS
    // ============================================================

    logic pendiente_reg;
    logic [ANCHO_CONTADOR-1:0] contador_reg;

    logic [6:0] segmentos_pendientes_reg;
    logic [3:0] digito_pendiente_reg;

    // Al comenzar por unidades, utilizar la muestra mas reciente.
    // Las otras posiciones usan la copia del mismo barrido.
    assign simbolos_elegidos = (indice_reg == 2'd0)
        ? simbolos_reg
        : marco_reg;

    // Seleccionar cuatro bits segun el indice.
    assign simbolo_actual =
        simbolos_elegidos[4*indice_reg +: 4];

    // ============================================================
    // DECODIFICADOR DE SIETE SEGMENTOS
    // ============================================================

    always_comb begin
        case (simbolo_actual)
            4'h0: segmentos_actuales = ~`SS_0;
            4'h1: segmentos_actuales = ~`SS_1;
            4'h2: segmentos_actuales = ~`SS_2;
            4'h3: segmentos_actuales = ~`SS_3;
            4'h4: segmentos_actuales = ~`SS_4;
            4'h5: segmentos_actuales = ~`SS_5;
            4'h6: segmentos_actuales = ~`SS_6;
            4'h7: segmentos_actuales = ~`SS_7;
            4'h8: segmentos_actuales = ~`SS_8;
            4'h9: segmentos_actuales = ~`SS_9;

            // Codigo E de M8: encender solamente el segmento g.
            4'hE: segmentos_actuales = 7'b0000001;

            // F es espacio. A, B, C y D tampoco se muestran.
            default: segmentos_actuales = 7'b0000000;
        endcase
    end

    // ============================================================
    // REGISTROS Y SECUENCIA DE REFRESCO
    // ============================================================

    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi) begin
            simbolos_reg             <= 16'hFFFF;
            validos_reg              <= 1'b0;
            marco_reg                <= 16'hFFFF;

            indice_reg               <= 2'd0;
            pendiente_reg            <= 1'b0;
            contador_reg             <= '0;

            segmentos_pendientes_reg <= 7'b0000000;
            digito_pendiente_reg     <= 4'b0000;

            segmentos_po             <= 7'b0000000;
            digitos_po               <= 4'b0000;
        end else begin
            // Registrar las entradas de M8.
            simbolos_reg <= simbolos_pi;
            validos_reg  <= simbolos_validos_pi;

            if (!validos_reg) begin
                // Sin datos validos, apagar y volver a unidades.
                segmentos_po  <= 7'b0000000;
                digitos_po    <= 4'b0000;

                indice_reg    <= 2'd0;
                pendiente_reg <= 1'b0;
                contador_reg  <= '0;
                marco_reg     <= 16'hFFFF;

            end else if (pendiente_reg) begin
                // Completar el cambio solicitado anteriormente.
                if (contador_reg != 0) begin
                    contador_reg <= contador_reg - 1'b1;

                    // Cambiar segmentos cuando termina la pausa.
                    if (contador_reg == 1)
                        segmentos_po <= segmentos_pendientes_reg;

                end else begin
                    // Los segmentos ya llevan un ciclo estables.
                    digitos_po    <= digito_pendiente_reg;
                    pendiente_reg <= 1'b0;
                end

            end else if (paso_display_pi) begin
                // Apagar el display anterior.
                digitos_po <= 4'b0000;

                // Preparar los datos del siguiente display.
                contador_reg             <= CICLOS_APAGADO;
                segmentos_pendientes_reg <= segmentos_actuales;
                digito_pendiente_reg     <=
                    (4'b0001 << indice_reg);

                pendiente_reg <= 1'b1;

                // Contador binario: 0, 1, 2, 3, 0...
                indice_reg <= indice_reg + 2'd1;

                // Guardar los cuatro simbolos al comenzar un barrido.
                if (indice_reg == 2'd0)
                    marco_reg <= simbolos_reg;
            end
        end
    end

endmodule