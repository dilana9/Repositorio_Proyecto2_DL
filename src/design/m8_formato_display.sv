`timescale 1ns/1ps

module m8_formato_display (
    input  logic               reloj_pi,
    input  logic               reinicio_pi,
    input  logic [1:0]         estado_pi,
    input  logic [9:0]         captura_pi,
    input  logic signed [10:0] resultado_pi,
    input  logic [11:0]        bcd_pi,
    input  logic               bcd_valido_pi,

    output logic [9:0]         numero_binario_po,
    output logic [15:0]        simbolos_po,
    output logic               simbolos_validos_po
);

    // ============================================================
    // ESTADO DE M5 Y CODIGOS DE SIMBOLOS PARA M9
    // ============================================================

    localparam logic [1:0] ESTADO_RESULTADO = 2'b11;
    localparam logic [3:0] SIMBOLO_MENOS = 4'hE;
    localparam logic [3:0] SIMBOLO_BLANCO = 4'hF;

    // ============================================================
    // SELECCION DEL NUMERO Y CALCULO DE SU MAGNITUD
    // ============================================================

    logic mostrar_resultado;
    logic negativo_actual;

    logic [10:0] magnitud_resultado;
    logic [10:0] magnitud_actual;

    logic rango_valido_actual;

    // ============================================================
    // REGISTROS PARA ALINEAR SIGNO Y VALIDEZ CON M7
    // ============================================================

    logic [1:0] negativo_reg;
    logic [1:0] rango_valido_reg;

    // Mostrar el resultado solamente en el estado 11.
    assign mostrar_resultado =
        (estado_pi == ESTADO_RESULTADO);

    // Durante la captura nunca se muestra signo negativo.
    assign negativo_actual =
        mostrar_resultado && resultado_pi[10];

    // Obtener la magnitud del resultado.
    // Para negativos, invertir los bits y sumar uno.
    assign magnitud_resultado = resultado_pi[10]
        ? (~resultado_pi + 11'd1)
        : resultado_pi;

    // Elegir entre el resultado y la captura actual de M5.
    assign magnitud_actual = mostrar_resultado
        ? magnitud_resultado
        : {1'b0, captura_pi};

    // Comprobar el rango antes de reducir a diez bits.
    assign rango_valido_actual =
        (magnitud_actual <= 11'd999);

    // Entrada binaria para el conversor M7.
    assign numero_binario_po = magnitud_actual[9:0];

    // ============================================================
    // ALINEACION TEMPORAL Y REGISTRO DE LOS CUATRO SIMBOLOS
    // ============================================================

    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi) begin
            negativo_reg       <= 2'b00;
            rango_valido_reg   <= 2'b00;
            simbolos_po        <= 16'hFFFF;
            simbolos_validos_po <= 1'b0;
        end else begin
            // Desplazar el signo y la validez por dos etapas.
            negativo_reg <= {
                negativo_reg[0],
                negativo_actual
            };

            rango_valido_reg <= {
                rango_valido_reg[0],
                rango_valido_actual
            };

            // Combinar el signo alineado y los tres digitos BCD.
            if (bcd_valido_pi && rango_valido_reg[1]) begin
                simbolos_po <= {
                    negativo_reg[1]
                        ? SIMBOLO_MENOS
                        : SIMBOLO_BLANCO,
                    bcd_pi
                };

                simbolos_validos_po <= 1'b1;
            end else begin
                // Apagar los simbolos mientras no haya datos validos.
                simbolos_po        <= 16'hFFFF;
                simbolos_validos_po <= 1'b0;
            end
        end
    end

endmodule