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
    // Esperar a que las salidas originales, sin reset, lleguen a cero.
    localparam logic [BITS_FILTRO:0] FIN_INICIO =
        (2 ** (BITS_FILTRO - 1)) + 5;

    logic [BITS_FILTRO:0] contador_inicio;
    logic [15:0] mapa_mantenido;
    wire  [15:0] mapa_filtrado;
    logic armado;
    logic [4:0] cantidad_teclas;
    logic [3:0] posicion_detectada;

    // Mantener cada mapa entre publicaciones completas de M3.
    // Durante la inicializacion, todos los filtros reciben cero.
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

    // Instanciar el antirrebote original sin modificar su codigo.
    generate
        for (genvar posicion = 0; posicion < 16; posicion++) begin : filtros
            DeBounce #(.N(BITS_FILTRO)) filtro_original (
                .clk       (reloj_pi),
                .n_reset   (~reinicio_pi),
                .button_in (mapa_mantenido[posicion]),
                .DB_out    (mapa_filtrado[posicion])
            );
        end
    endgenerate

    // Contar posiciones filtradas y obtener su indice binario.
    always_comb begin
        cantidad_teclas    = 5'd0;
        posicion_detectada = 4'd0;

        for (int posicion = 0; posicion < 16; posicion++) begin
            if (mapa_filtrado[posicion]) begin
                cantidad_teclas = cantidad_teclas + 1'b1;
                posicion_detectada = posicion[3:0];
            end
        end
    end

    // Un evento por pulsacion; rearmar tras una liberacion filtrada.
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
                end else if (armado &&
                             (cantidad_teclas == 5'd1) &&
                             (mapa_filtrado == mapa_mantenido)) begin
                    posicion_tecla_po <= posicion_detectada;
                    evento_tecla_po   <= 1'b1;
                    armado            <= 1'b0;
                end
            end
        end
    end

endmodule
