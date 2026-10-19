`timescale 1ns/1ps

module top #(
    parameter integer CICLOS_TECLADO = 27000,
    parameter integer CICLOS_DISPLAY = 27000,
    parameter integer BITS_FILTRO = 20,
    parameter integer CICLOS_APAGADO = 16
) (
    input  logic       reloj_pi,
    input  logic       boton_reinicio_n_pi,
    input  logic [3:0] columnas_pi,
    output wire  [3:0] filas_po,
    output logic [6:0] segmentos_po,
    output logic [3:0] digitos_po
);

    // Senales de reloj, reinicio y habilitaciones.
    logic reinicio;
    logic paso_teclado;
    logic paso_display;

    // Senales de exploracion del teclado.
    logic [3:0] columnas_sincronizadas;
    logic [3:0] filas_activas;
    logic [15:0] mapa_teclas;
    logic lectura_valida;

    // Senales del filtro de pulsaciones.
    logic [3:0] posicion_tecla;
    logic evento_tecla;
    logic filtro_listo;

    // Senales del controlador de captura.
    logic [9:0] operando_a;
    logic [9:0] operando_b;
    logic [9:0] captura;
    logic [1:0] cantidad_digitos;
    logic [1:0] estado_operacion;
    logic calcular;
    logic borrar;

    // Resultado con signo.
    logic signed [10:0] resultado;
    logic resultado_valido;

    // Senales de conversion y visualizacion.
    logic [9:0] numero_visible;
    logic [11:0] bcd;
    logic bcd_valido;
    logic [15:0] simbolos;
    logic simbolos_validos;

    // M10: boton activo en cero y liberacion sincronizada.
    m10_sincronizador_reinicio control_reinicio (
        .reloj_pi(reloj_pi),
        .reinicio_asincrono_pi(~boton_reinicio_n_pi),
        .reinicio_po(reinicio)
    );

    // M1: generar habilitaciones usando el unico reloj del sistema.
    m1_base_tiempos #(
        .CICLOS_TECLADO(CICLOS_TECLADO),
        .CICLOS_DISPLAY(CICLOS_DISPLAY)
    ) base_tiempos (
        .reloj_pi(reloj_pi),
        .reinicio_pi(reinicio),
        .paso_teclado_po(paso_teclado),
        .paso_display_po(paso_display)
    );

    // M2: sincronizar las columnas externas del teclado.
    m2_sincronizador sincronizador_columnas (
        .reloj_pi(reloj_pi),
        .reinicio_pi(reinicio),
        .columnas_asincronas_pi(columnas_pi),
        .columnas_sincronizadas_po(columnas_sincronizadas)
    );

    // M3: explorar las filas y obtener el mapa de teclas.
    m3_explorador_teclado #(
        .COLUMNAS_ACTIVAS_EN_CERO(1'b1)
    ) explorador (
        .reloj_pi(reloj_pi),
        .reinicio_pi(reinicio),
        .paso_teclado_pi(paso_teclado),
        .columnas_sincronizadas_pi(columnas_sincronizadas),
        .filas_activas_po(filas_activas),
        .mapa_teclas_po(mapa_teclas),
        .lectura_valida_po(lectura_valida)
    );

    // Adaptacion fisica del teclado:
    // fila seleccionada = 0; otras filas = alta impedancia.
    generate
        for (genvar fila = 0; fila < 4; fila++) begin : salidas_filas
            assign filas_po[fila] =
                (reinicio || !filas_activas[fila]) ? 1'bz : 1'b0;
        end
    endgenerate

    // M4: eliminar rebotes y generar un evento por pulsacion.
    m4_filtro_evento #(
        .BITS_FILTRO(BITS_FILTRO)
    ) filtro_evento (
        .reloj_pi(reloj_pi),
        .reinicio_pi(reinicio),
        .mapa_teclas_pi(mapa_teclas),
        .lectura_valida_pi(lectura_valida),
        .posicion_tecla_po(posicion_tecla),
        .evento_tecla_po(evento_tecla),
        .listo_po(filtro_listo)
    );

    // M5: capturar operandos y controlar los estados.
    m5_control_captura control_captura (
        .reloj_pi(reloj_pi),
        .reinicio_pi(reinicio),
        .posicion_tecla_pi(posicion_tecla),
        .evento_tecla_pi(evento_tecla),
        .resultado_valido_pi(resultado_valido),
        .operando_a_po(operando_a),
        .operando_b_po(operando_b),
        .captura_po(captura),
        .cantidad_digitos_po(cantidad_digitos),
        .estado_po(estado_operacion),
        .calcular_po(calcular),
        .borrar_po(borrar)
    );

    // M6: realizar la resta mediante complemento a dos.
    m6_resta_complemento resta (
        .reloj_pi(reloj_pi),
        .reinicio_pi(reinicio),
        .borrar_pi(borrar),
        .calcular_pi(calcular),
        .operando_a_pi(operando_a),
        .operando_b_pi(operando_b),
        .resultado_po(resultado),
        .resultado_valido_po(resultado_valido)
    );

    // M7: convertir a BCD el numero seleccionado por M8.
    m7_adaptador_bcd conversor_bcd (
        .reloj_pi(reloj_pi),
        .reinicio_pi(reinicio),
        .numero_binario_pi(numero_visible),
        .bcd_po(bcd),
        .bcd_valido_po(bcd_valido)
    );

    // M8: seleccionar numero y preparar signo y digitos.
    m8_formato_display formato_display (
        .reloj_pi(reloj_pi),
        .reinicio_pi(reinicio),
        .estado_pi(estado_operacion),
        .captura_pi(captura),
        .resultado_pi(resultado),
        .bcd_pi(bcd),
        .bcd_valido_pi(bcd_valido),
        .numero_binario_po(numero_visible),
        .simbolos_po(simbolos),
        .simbolos_validos_po(simbolos_validos)
    );

    // M9: generar segmentos y activar un display a la vez.
    m9_refresco_display #(
        .CICLOS_APAGADO(CICLOS_APAGADO)
    ) refresco_display (
        .reloj_pi(reloj_pi),
        .reinicio_pi(reinicio),
        .paso_display_pi(paso_display),
        .simbolos_pi(simbolos),
        .simbolos_validos_pi(simbolos_validos),
        .segmentos_po(segmentos_po),
        .digitos_po(digitos_po)
    );

endmodule