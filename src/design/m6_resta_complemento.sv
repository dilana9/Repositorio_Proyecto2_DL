`timescale 1ns/1ps

module m6_resta_complemento (
    input  logic               reloj_pi,
    input  logic               reinicio_pi,
    input  logic               borrar_pi,
    input  logic               calcular_pi,
    input  logic [9:0]         operando_a_pi,
    input  logic [9:0]         operando_b_pi,
    output logic signed [10:0] resultado_po,
    output logic               resultado_valido_po
);

    // ============================================================
    // REGISTROS DE ENTRADA Y CONTROL
    // ============================================================

    logic [9:0] operando_a_reg;
    logic [9:0] operando_b_reg;
    logic       pendiente;

    // ============================================================
    // SEÑALES DE LA RUTA COMBINACIONAL
    // ============================================================

    logic [10:0] a_extendido;
    logic [10:0] b_extendido;
    logic [10:0] complemento_b;
    logic [10:0] suma_complemento;

    // Agregar un cero conserva el valor positivo de cada operando.
    assign a_extendido = {1'b0, operando_a_reg};
    assign b_extendido = {1'b0, operando_b_reg};

    // Complemento a dos de B: invertir los bits y sumar uno.
    assign complemento_b = ~b_extendido + 11'd1;

    // A menos B se obtiene sumando A con el complemento de B.
    // La señal de once bits descarta el acarreo final.
    assign suma_complemento = a_extendido + complemento_b;

    // ============================================================
    // CAPTURA DE OPERANDOS Y REGISTRO DEL RESULTADO
    // ============================================================

    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi || borrar_pi) begin
            operando_a_reg     <= 10'd0;
            operando_b_reg     <= 10'd0;
            pendiente          <= 1'b0;
            resultado_po       <= 11'sd0;
            resultado_valido_po <= 1'b0;
        end else begin
            // El indicador de resultado dura un ciclo.
            resultado_valido_po <= 1'b0;

            if (pendiente) begin
                // Publicar el resultado de los operandos registrados.
                resultado_po       <= $signed(suma_complemento);
                resultado_valido_po <= 1'b1;
                pendiente          <= 1'b0;
            end else if (calcular_pi) begin
                // Capturar una nueva solicitud.
                operando_a_reg <= operando_a_pi;
                operando_b_reg <= operando_b_pi;
                pendiente      <= 1'b1;
            end
        end
    end

endmodule