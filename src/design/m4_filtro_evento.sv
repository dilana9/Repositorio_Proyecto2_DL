`timescale 1ns/1ps

module m4_filtro_evento #(
    parameter integer BITS_FILTRO = 20
) (
    input  logic        reloj_pi,
    input  logic        reinicio_pi,
    input  logic [15:0] mapa_teclas_pi,
    input  logic        lectura_valida_pi,
    output logic [3:0]  posicion_tecla_po,
    output logic        evento_tecla_po,
    output logic        listo_po
);

    // BITS_FILTRO debe ser mayor o igual que 2.
    // Esperar que las salidas del antirrebote original lleguen a cero.
    localparam logic [BITS_FILTRO:0] FIN_INICIO =
        (2 ** (BITS_FILTRO - 1)) + 5;

    // Registros de inicializacion y del mapa recibido.
    logic [BITS_FILTRO:0] contador_inicio;
    logic [15:0] mapa_mantenido;
    wire  [15:0] mapa_filtrado;
    logic armado;

    // Senales de deteccion paralela.
    logic [3:0] grupos_ocupados;
    logic [3:0] grupos_multiples;
    logic varios_grupos;
    logic tecla_unica;
    logic [3:0] posicion_detectada;

    // Mantener el mapa entre publicaciones completas de M3.
    // Durante la inicializacion, los filtros reciben cero.
    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi) begin
            contador_inicio <= '0;
            listo_po        <= 1'b0;
            mapa_mantenido  <= 16'b0;
        end else if (!listo_po) begin
            mapa_mantenido <= 16'b0;

            if (contador_inicio == FIN_INICIO - 1'b1)
                listo_po <= 1'b1;
            else
                contador_inicio <= contador_inicio + 1'b1;

        end else if (lectura_valida_pi) begin
            mapa_mantenido <= mapa_teclas_pi;
        end
    end

    // Antirrebote original: una instancia por posicion.
    generate
        for (genvar posicion = 0; posicion < 16; posicion++) begin : filtros
            DeBounce #(
                .N(BITS_FILTRO)
            ) filtro_original (
                .clk       (reloj_pi),
                .n_reset   (~reinicio_pi),
                .button_in (mapa_mantenido[posicion]),
                .DB_out    (mapa_filtrado[posicion])
            );
        end
    endgenerate

    // Dividir las 16 posiciones en cuatro grupos de cuatro.
    // Detectar ocupacion y varias teclas dentro de cada grupo.
    generate
        for (genvar grupo = 0; grupo < 4; grupo++) begin : deteccion_grupos

            wire [3:0] teclas_grupo;

            assign teclas_grupo = mapa_filtrado[4*grupo +: 4];

            assign grupos_ocupados[grupo] = |teclas_grupo;

            assign grupos_multiples[grupo] =
                (teclas_grupo[0] & teclas_grupo[1]) |
                (teclas_grupo[0] & teclas_grupo[2]) |
                (teclas_grupo[0] & teclas_grupo[3]) |
                (teclas_grupo[1] & teclas_grupo[2]) |
                (teclas_grupo[1] & teclas_grupo[3]) |
                (teclas_grupo[2] & teclas_grupo[3]);

        end
    endgenerate

    // Detectar ocupacion de dos o mas grupos diferentes.
    assign varios_grupos =
        (grupos_ocupados[0] & grupos_ocupados[1]) |
        (grupos_ocupados[0] & grupos_ocupados[2]) |
        (grupos_ocupados[0] & grupos_ocupados[3]) |
        (grupos_ocupados[1] & grupos_ocupados[2]) |
        (grupos_ocupados[1] & grupos_ocupados[3]) |
        (grupos_ocupados[2] & grupos_ocupados[3]);

    // Hay exactamente una tecla si:
    // existe un grupo ocupado,
    // ningun grupo contiene varias teclas,
    // y no hay varios grupos ocupados.
    assign tecla_unica =
        (|grupos_ocupados) &&
        !(|grupos_multiples) &&
        !varios_grupos;

    // Codificador binario paralelo.
    // Su resultado se acepta solamente cuando tecla_unica vale uno.
    assign posicion_detectada[0] =
        |(mapa_filtrado & 16'hAAAA);

    assign posicion_detectada[1] =
        |(mapa_filtrado & 16'hCCCC);

    assign posicion_detectada[2] =
        |(mapa_filtrado & 16'hF0F0);

    assign posicion_detectada[3] =
        |(mapa_filtrado & 16'hFF00);

    // Generar un evento por pulsacion.
    // Rearmar despues de una liberacion filtrada.
    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi) begin
            posicion_tecla_po <= 4'd0;
            evento_tecla_po   <= 1'b0;
            armado            <= 1'b1;
        end else begin
            evento_tecla_po <= 1'b0;

            if (listo_po) begin
                if ((mapa_mantenido == 16'b0) &&
                    (mapa_filtrado == 16'b0)) begin

                    armado <= 1'b1;

                end else if (
                    armado &&
                    tecla_unica &&
                    (mapa_filtrado == mapa_mantenido)
                ) begin

                    posicion_tecla_po <= posicion_detectada;
                    evento_tecla_po   <= 1'b1;
                    armado            <= 1'b0;

                end
            end
        end
    end

endmodule