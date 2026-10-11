`timescale 1ns/1ps

module tb_m7_adaptador_bcd;

    // ============================================================
    // SENALES Y MODELO DE REFERENCIA
    // ============================================================

    logic reloj = 1'b0;
    logic reinicio = 1'b1;

    logic [9:0] numero = 10'd0;
    logic [11:0] bcd;
    logic valido;

    logic [11:0] esperado = 12'h000;
    logic valido_esperado = 1'b0;

    integer pruebas = 0;

    // ============================================================
    // MODULO BAJO PRUEBA
    // ============================================================

    m7_adaptador_bcd dut (
        .reloj_pi(reloj),
        .reinicio_pi(reinicio),
        .numero_binario_pi(numero),
        .bcd_po(bcd),
        .bcd_valido_po(valido)
    );

    // Reloj acelerado para simulacion.
    always #5 reloj = ~reloj;

    // ============================================================
    // REFERENCIA INDEPENDIENTE DE LA ROM
    // ============================================================

    function automatic logic [11:0] referencia(
        input logic [9:0] valor
    );

        integer centenas;
        integer decenas;
        integer unidades;

        begin
            centenas = int'(valor) / 100;
            decenas  = (int'(valor) / 10) % 10;
            unidades = int'(valor) % 10;

            referencia = {
                centenas[3:0],
                decenas[3:0],
                unidades[3:0]
            };
        end

    endfunction

    // ============================================================
    // APLICAR UNA MUESTRA Y COMPROBAR LA ANTERIOR
    // ============================================================

    task automatic aplicar(input logic [9:0] valor);

        begin
            @(negedge reloj);

            reinicio = 1'b0;
            numero = valor;

            @(posedge reloj);
            #1;

            // La salida pertenece a la muestra del ciclo anterior.
            if (bcd !== esperado ||
                valido !== valido_esperado)
                $fatal(
                    1,
                    "FALLO: BCD esperado=%h obtenido=%h valido esperado=%b obtenido=%b",
                    esperado, bcd, valido_esperado, valido
                );

            // Preparar la referencia del proximo ciclo.
            valido_esperado = (valor <= 10'd999);

            esperado = valido_esperado
                ? referencia(valor)
                : 12'h000;

            pruebas = pruebas + 1;
        end

    endtask

    // ============================================================
    // REINICIO Y DESCARTE DE UNA MUESTRA PENDIENTE
    // ============================================================

    task automatic probar_reinicio;

        begin
            @(negedge reloj);
            reinicio = 1'b1;

            repeat (2) begin
                @(posedge reloj);
                #1;

                if (bcd !== 12'h000 ||
                    valido !== 1'b0)
                    $fatal(1, "FALLO: reinicio");
            end

            esperado = 12'h000;
            valido_esperado = 1'b0;

            // La siguiente llamada a aplicar libera el reinicio.
        end

    endtask

    // ============================================================
    // SECUENCIA DE PRUEBAS
    // ============================================================

    initial begin
        $dumpfile("src/build/tb_m7_adaptador_bcd.vcd");
        $dumpvars(0, tb_m7_adaptador_bcd);

        probar_reinicio();

        // Ejemplos y cambios en ciclos consecutivos.
        aplicar(10'd7);
        aplicar(10'd42);
        aplicar(10'd105);
        aplicar(10'd999);
        aplicar(10'd0);
        aplicar(10'd1000);
        aplicar(10'd1023);

        // Todas las direcciones posibles de diez bits.
        for (int n = 0; n < 1024; n++)
            aplicar(n[9:0]);

        // Comprobar la ultima muestra de la prueba exhaustiva.
        aplicar(10'd999);

        // Reiniciar con una muestra pendiente.
        probar_reinicio();

        // Comprobar recuperacion y las entradas 30 y 31.
        aplicar(10'd30);
        aplicar(10'd31);
        aplicar(10'd0);

        $display(
            "PASS: 1024 direcciones, ceros iniciales, limites, latencia, cambios consecutivos y reinicio."
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