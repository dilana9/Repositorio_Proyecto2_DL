`timescale 1ns/1ps

module tb_m8_formato_display;

    // ============================================================
    // SENALES DE PRUEBA
    // ============================================================

    logic reloj = 1'b0;
    logic reinicio = 1'b1;

    logic [1:0] estado = 2'b00;
    logic [9:0] captura = 10'd0;
    logic signed [10:0] resultado = 11'sd0;

    logic [9:0] numero;
    logic [11:0] bcd;
    logic bcd_valido;

    logic [15:0] simbolos;
    logic simbolos_validos;

    // Referencias de las dos muestras anteriores.
    logic [15:0] esperado_1 = 16'hFFFF;
    logic [15:0] esperado_2 = 16'hFFFF;

    logic valido_1 = 1'b0;
    logic valido_2 = 1'b0;

    integer pruebas = 0;

    // ============================================================
    // M7 REAL
    // ============================================================

    m7_adaptador_bcd conversor (
        .reloj_pi(reloj),
        .reinicio_pi(reinicio),
        .numero_binario_pi(numero),
        .bcd_po(bcd),
        .bcd_valido_po(bcd_valido)
    );

    // ============================================================
    // M8 BAJO PRUEBA
    // ============================================================

    m8_formato_display dut (
        .reloj_pi(reloj),
        .reinicio_pi(reinicio),
        .estado_pi(estado),
        .captura_pi(captura),
        .resultado_pi(resultado),
        .bcd_pi(bcd),
        .bcd_valido_pi(bcd_valido),
        .numero_binario_po(numero),
        .simbolos_po(simbolos),
        .simbolos_validos_po(simbolos_validos)
    );

    // Reloj acelerado para simulacion.
    always #5 reloj = ~reloj;

    // ============================================================
    // APLICAR DATOS Y COMPARAR CON UNA REFERENCIA INDEPENDIENTE
    // ============================================================

    task automatic aplicar(
        input logic [1:0] nuevo_estado,
        input integer nueva_captura,
        input integer nuevo_resultado
    );

        integer magnitud;
        integer centenas;
        integer decenas;
        integer unidades;

        logic [3:0] signo;
        logic [15:0] esperado_actual;
        logic valido_actual;

        begin
            // Calcular el valor visible mediante aritmetica de referencia.
            if (nuevo_estado == 2'b11) begin
                magnitud = (nuevo_resultado < 0)
                    ? -nuevo_resultado
                    : nuevo_resultado;

                signo = (nuevo_resultado < 0)
                    ? 4'hE
                    : 4'hF;
            end else begin
                magnitud = nueva_captura;
                signo = 4'hF;
            end

            valido_actual = (magnitud <= 999);

            centenas = magnitud / 100;
            decenas = (magnitud / 10) % 10;
            unidades = magnitud % 10;

            esperado_actual = valido_actual
                ? {
                    signo,
                    centenas[3:0],
                    decenas[3:0],
                    unidades[3:0]
                }
                : 16'hFFFF;

            // Cambiar entradas lejos del flanco de captura.
            @(negedge reloj);

            reinicio = 1'b0;
            estado = nuevo_estado;
            captura = nueva_captura[9:0];
            resultado = nuevo_resultado[10:0];

            #1;

            // Comprobar la magnitud combinacional enviada a M7.
            if (numero !== magnitud[9:0])
                $fatal(1, "FALLO: seleccion de magnitud");

            @(posedge reloj);
            #1;

            // La salida corresponde a dos muestras anteriores.
            if (simbolos !== esperado_2 ||
                simbolos_validos !== valido_2)
                $fatal(
                    1,
                    "FALLO: esperado=%h obtenido=%h valido esperado=%b obtenido=%b",
                    esperado_2,
                    simbolos,
                    valido_2,
                    simbolos_validos
                );

            // Avanzar el modelo de referencia.
            esperado_2 = esperado_1;
            valido_2 = valido_1;

            esperado_1 = esperado_actual;
            valido_1 = valido_actual;

            pruebas = pruebas + 1;
        end

    endtask

    // ============================================================
    // REINICIO DE AMBOS MODULOS
    // ============================================================

    task automatic probar_reinicio;

        begin
            @(negedge reloj);
            reinicio = 1'b1;

            repeat (2) begin
                @(posedge reloj);
                #1;

                if (simbolos !== 16'hFFFF ||
                    simbolos_validos !== 1'b0)
                    $fatal(1, "FALLO: reinicio de simbolos");
            end

            esperado_1 = 16'hFFFF;
            esperado_2 = 16'hFFFF;

            valido_1 = 1'b0;
            valido_2 = 1'b0;
        end

    endtask

    // ============================================================
    // SECUENCIA DE PRUEBAS
    // ============================================================

    initial begin
        $dumpfile("src/build/tb_m8_formato_display.vcd");
        $dumpvars(0, tb_m8_formato_display);

        probar_reinicio();

        // Captura A: ignorar un resultado negativo anterior.
        aplicar(2'b00, 0, -999);
        aplicar(2'b00, 7, -999);
        aplicar(2'b00, 42, -999);
        aplicar(2'b00, 105, -999);

        // Captura B.
        aplicar(2'b01, 0, -999);
        aplicar(2'b01, 9, -999);
        aplicar(2'b01, 99, -999);
        aplicar(2'b01, 999, -999);

        // Espera: conservar el numero capturado.
        aplicar(2'b10, 123, -999);

        // Todos los resultados posibles de la calculadora.
        for (int r = -999; r <= 999; r++)
            aplicar(2'b11, 555, r);

        // Alternar signos y valores en ciclos consecutivos.
        aplicar(2'b11, 0, -7);
        aplicar(2'b11, 0, 42);
        aplicar(2'b11, 0, -105);
        aplicar(2'b11, 0, 999);
        aplicar(2'b11, 0, 0);

        // Volver a captura: retirar el signo anterior.
        aplicar(2'b00, 0, -999);

        // Valores fuera del rango de tres digitos.
        aplicar(2'b11, 0, -1024);
        aplicar(2'b11, 0, -1000);
        aplicar(2'b11, 0, 1000);
        aplicar(2'b11, 0, 1023);
        aplicar(2'b00, 1000, 0);
        aplicar(2'b01, 1023, 0);

        // Comprobar las ultimas muestras pendientes.
        aplicar(2'b00, 0, 0);
        aplicar(2'b00, 0, 0);

        // Reiniciar con un resultado negativo pendiente.
        aplicar(2'b11, 0, -999);
        probar_reinicio();

        // Recuperacion despues del reinicio.
        aplicar(2'b00, 7, -999);
        aplicar(2'b00, 42, -999);
        aplicar(2'b00, 105, -999);
        aplicar(2'b00, 0, 0);
        aplicar(2'b00, 0, 0);

        $display(
            "PASS: captura A/B, espera, 1999 resultados, ceros iniciales, signo alineado, fuera de rango y reinicio con M7."
        );

        $finish;
    end

    // ============================================================
    // LIMITE DE TIEMPO DE SIMULACION
    // ============================================================

    initial begin
        #100000;
        $fatal(1, "FALLO: tiempo maximo excedido");
    end

endmodule