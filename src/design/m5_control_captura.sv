`timescale 1ns/1ps

module m5_control_captura (
    input  logic       reloj_pi,
    input  logic       reinicio_pi,
    input  logic [3:0] posicion_tecla_pi,
    input  logic       evento_tecla_pi,
    input  logic       resultado_valido_pi,
    output logic [9:0] operando_a_po,
    output logic [9:0] operando_b_po,
    output logic [9:0] captura_po,
    output logic [1:0] cantidad_digitos_po,
    output logic [1:0] estado_po,
    output logic       calcular_po,
    output logic       borrar_po
);

    // Codificacion binaria de los cuatro estados.
    typedef enum logic [1:0] {
        CAPTURA_A        = 2'b00,
        CAPTURA_B        = 2'b01,
        ESPERA_RESULTADO = 2'b10,
        RESULTADO        = 2'b11
    } estado_t;

    estado_t estado_reg;

    // Posiciones logicas del teclado.
    localparam logic [3:0] POSICION_A = 4'd3;
    localparam logic [3:0] POSICION_B = 4'd7;
    localparam logic [3:0] POSICION_C = 4'd11;

    // Senales combinacionales para interpretar y acumular digitos.
    logic es_digito;
    logic [3:0] digito;
    logic [9:0] captura_ampliada;

    // Exponer el estado registrado.
    assign estado_po = estado_reg;

    // Traducir posiciones a digitos decimales.
    // Distribucion logica: 123A / 456B / 789C / *0#D.
    always_comb begin
        es_digito = 1'b1;
        digito = 4'd0;

        case (posicion_tecla_pi)
            4'd0:  digito = 4'd1;
            4'd1:  digito = 4'd2;
            4'd2:  digito = 4'd3;
            4'd4:  digito = 4'd4;
            4'd5:  digito = 4'd5;
            4'd6:  digito = 4'd6;
            4'd8:  digito = 4'd7;
            4'd9:  digito = 4'd8;
            4'd10: digito = 4'd9;
            4'd13: digito = 4'd0;
            default: es_digito = 1'b0;
        endcase
    end

    // Agregar un digito: nuevo valor = anterior * 10 + digito.
    // Multiplicar por 10 equivale a multiplicar por 8 y sumar por 2.
    // Solo se guarda si habia menos de tres digitos.
    assign captura_ampliada = (captura_po << 3)
                            + (captura_po << 1)
                            + {6'b000000, digito};

    // Registros de captura, operandos, estado y pulsos de control.
    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi) begin
            estado_reg          <= CAPTURA_A;
            operando_a_po       <= 10'd0;
            operando_b_po       <= 10'd0;
            captura_po          <= 10'd0;
            cantidad_digitos_po <= 2'd0;
            calcular_po         <= 1'b0;
            borrar_po           <= 1'b0;
        end else begin
            // Los pulsos duran un unico ciclo.
            calcular_po <= 1'b0;
            borrar_po   <= 1'b0;

            // C borra todo y tiene prioridad en cualquier estado.
            if (evento_tecla_pi &&
                posicion_tecla_pi == POSICION_C) begin

                estado_reg          <= CAPTURA_A;
                operando_a_po       <= 10'd0;
                operando_b_po       <= 10'd0;
                captura_po          <= 10'd0;
                cantidad_digitos_po <= 2'd0;
                borrar_po           <= 1'b1;

            end else begin
                case (estado_reg)

                    CAPTURA_A: begin
                        if (evento_tecla_pi) begin
                            if (es_digito &&
                                cantidad_digitos_po < 2'd3) begin

                                captura_po <= captura_ampliada;
                                cantidad_digitos_po
                                    <= cantidad_digitos_po + 1'b1;

                            end else if (
                                posicion_tecla_pi == POSICION_A &&
                                cantidad_digitos_po != 2'd0
                            ) begin

                                operando_a_po       <= captura_po;
                                captura_po          <= 10'd0;
                                cantidad_digitos_po <= 2'd0;
                                estado_reg          <= CAPTURA_B;
                            end
                        end
                    end

                    CAPTURA_B: begin
                        if (evento_tecla_pi) begin
                            if (es_digito &&
                                cantidad_digitos_po < 2'd3) begin

                                captura_po <= captura_ampliada;
                                cantidad_digitos_po
                                    <= cantidad_digitos_po + 1'b1;

                            end else if (
                                posicion_tecla_pi == POSICION_B &&
                                cantidad_digitos_po != 2'd0
                            ) begin

                                operando_b_po <= captura_po;
                                calcular_po   <= 1'b1;
                                estado_reg    <= ESPERA_RESULTADO;
                            end
                        end
                    end

                    ESPERA_RESULTADO: begin
                        if (resultado_valido_pi)
                            estado_reg <= RESULTADO;
                    end

                    RESULTADO: begin
                        // Mantener los datos hasta C o reinicio.
                    end

                    default: begin
                        estado_reg          <= CAPTURA_A;
                        operando_a_po       <= 10'd0;
                        operando_b_po       <= 10'd0;
                        captura_po          <= 10'd0;
                        cantidad_digitos_po <= 2'd0;
                        borrar_po           <= 1'b1;
                    end

                endcase
            end
        end
    end

endmodule