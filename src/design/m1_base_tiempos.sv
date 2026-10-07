// Bases de tiempo mediante habilitaciones; no genera relojes internos.
`timescale 1ns/1ps
module m1_base_tiempos #(
    parameter integer CICLOS_TECLADO = 27000,
    parameter integer CICLOS_DISPLAY = 27000
)(
    input  logic reloj_pi,
    input  logic reinicio_pi,
    output logic paso_teclado_po,
    output logic paso_display_po
);
    // Anchos suficientes, incluso cuando el divisor es uno.
    localparam integer ANCHO_TECLADO =
        (CICLOS_TECLADO > 1) ? $clog2(CICLOS_TECLADO) : 1;
    localparam integer ANCHO_DISPLAY =
        (CICLOS_DISPLAY > 1) ? $clog2(CICLOS_DISPLAY) : 1;
    localparam logic [ANCHO_TECLADO-1:0] FIN_TECLADO = CICLOS_TECLADO - 1;
    localparam logic [ANCHO_DISPLAY-1:0] FIN_DISPLAY = CICLOS_DISPLAY - 1;

    logic [ANCHO_TECLADO-1:0] cuenta_teclado;
    logic [ANCHO_DISPLAY-1:0] cuenta_display;

    // Reinicio sincrónico activo en uno; salidas registradas.
    always_ff @(posedge reloj_pi) begin
        if (reinicio_pi) begin
            cuenta_teclado <= '0;
            cuenta_display <= '0;
            paso_teclado_po <= 1'b0;
            paso_display_po <= 1'b0;
        end else begin
            paso_teclado_po <= 1'b0;
            paso_display_po <= 1'b0;

            // Habilitación de exploración del teclado.
            if (cuenta_teclado == FIN_TECLADO) begin
                cuenta_teclado <= '0;
                paso_teclado_po <= 1'b1;
            end else begin
                cuenta_teclado <= cuenta_teclado + 1'b1;
            end

            // Habilitación del refresco de displays.
            if (cuenta_display == FIN_DISPLAY) begin
                cuenta_display <= '0;
                paso_display_po <= 1'b1;
            end else begin
                cuenta_display <= cuenta_display + 1'b1;
            end
        end
    end
endmodule
