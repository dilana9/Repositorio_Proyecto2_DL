`timescale 1ns/1ps

module m3_explorador_teclado #(
    parameter bit COLUMNAS_ACTIVAS_EN_CERO = 1'b1
) (
    input  logic        reloj_pi,
    input  logic        reinicio_pi,
    input  logic        paso_teclado_pi,
    input  logic [3:0]  columnas_sincronizadas_pi,
    output logic [3:0]  filas_activas_po,
    output logic [15:0] mapa_teclas_po,
    output logic        lectura_valida_po
);

    // Indice binario de fila y espera posterior a cada cambio de fila.
    logic [1:0] indice_fila;
    logic [1:0] espera_asentamiento;

    // Mapa en construccion y siguiente lectura parcial.
    logic [15:0] mapa_parcial;
    logic [15:0] mapa_actualizado;
    logic [3:0]  columnas_presionadas;

    // Mascara logica: un bit en uno selecciona una fila.
    // El TOP adaptara esta mascara a los niveles fisicos del montaje.
    assign filas_activas_po = 4'b0001 << indice_fila;

    // Normalizar las columnas: uno significa posicion presionada.
    assign columnas_presionadas = COLUMNAS_ACTIVAS_EN_CERO
                                ? ~columnas_sincronizadas_pi
                                :  columnas_sincronizadas_pi;

    // Insertar las cuatro columnas en el grupo de la fila actual.
    always_comb begin
        mapa_actualizado = mapa_parcial;
        mapa_actualizado[indice_fila * 4 +: 4] = columnas_presionadas;
    end

    // Recorrido secuencial de filas y publicacion del mapa completo.
    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi) begin
            indice_fila          <= 2'b00;
            espera_asentamiento  <= 2'd3;
            mapa_parcial         <= 16'b0;
            mapa_teclas_po       <= 16'b0;
            lectura_valida_po    <= 1'b0;
        end else begin
            lectura_valida_po <= 1'b0;

            if (espera_asentamiento != 2'd0) begin
                espera_asentamiento <= espera_asentamiento - 1'b1;
            end else if (paso_teclado_pi) begin
                mapa_parcial        <= mapa_actualizado;
                indice_fila         <= indice_fila + 1'b1;
                espera_asentamiento <= 2'd3;

                if (indice_fila == 2'd3) begin
                    mapa_teclas_po    <= mapa_actualizado;
                    lectura_valida_po <= 1'b1;
                end
            end
        end
    end

endmodule
