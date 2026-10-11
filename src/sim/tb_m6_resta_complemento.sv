`timescale 1ns/1ps

module tb_m6_resta_complemento;

    // ============================================================
    // SEÑALES DE PRUEBA
    // ============================================================

    logic reloj = 1'b0;
    logic reinicio = 1'b1;
    logic borrar = 1'b0;
    logic calcular = 1'b0;

    logic [9:0] operando_a = 10'd0;
    logic [9:0] operando_b = 10'd0;

    logic signed [10:0] resultado;
    logic resultado_valido;

    integer pruebas = 0;

    // ============================================================
    // MÓDULO BAJO PRUEBA
    // ============================================================

    m6_resta_complemento dut (
        .reloj_pi            (reloj),
        .reinicio_pi         (reinicio),
        .borrar_pi           (borrar),
        .calcular_pi         (calcular),
        .operando_a_pi       (operando_a),
        .operando_b_pi       (operando_b),
        .resultado_po        (resultado),
        .resultado_valido_po (resultado_valido)
    );

    // Reloj acelerado para simulación: periodo de 10 ns.
    always #5 reloj = ~reloj;

    // ============================================================
    // VERIFICACIÓN DE UNA OPERACIÓN
    // ============================================================

    task automatic probar_operacion(
        input logic [9:0] a,
        input logic [9:0] b
    );

        integer esperado;
        logic signed [10:0] resultado_anterior;

        begin
            // La resta directa solo se usa como referencia de prueba.
            esperado = int'(a) - int'(b);

            @(negedge reloj);
            #1;

            resultado_anterior = resultado;
            operando_a = a;
            operando_b = b;
            calcular = 1'b1;

            // Primer flanco: captura, sin publicar todavía.
            @(posedge reloj);
            #1;

            if (resultado_valido !== 1'b0 ||
                resultado !== resultado_anterior)
                $fatal(
                    1,
                    "FALLO: resultado publicado antes de tiempo"
                );

            // Cambiar las entradas después de capturar.
            // El resultado debe depender de los valores guardados.
            @(negedge reloj);
            #1;

            calcular = 1'b0;
            operando_a = 10'd0;
            operando_b = 10'd999;

            // Segundo flanco: resultado disponible.
            @(posedge reloj);
            #1;

            if (resultado_valido !== 1'b1 ||
                $isunknown(resultado) ||
                $signed(resultado) != esperado)
                $fatal(
                    1,
                    "FALLO: A=%0d B=%0d esperado=%0d obtenido=%0d",
                    a, b, esperado, $signed(resultado)
                );

            // Tercer flanco: termina el pulso y conserva el resultado.
            @(posedge reloj);
            #1;

            if (resultado_valido !== 1'b0 ||
                $isunknown(resultado) ||
                $signed(resultado) != esperado)
                $fatal(
                    1,
                    "FALLO: duracion del pulso o conservacion del resultado"
                );

            pruebas = pruebas + 1;
        end

    endtask

    // ============================================================
    // CANCELACIÓN DE UNA OPERACIÓN PENDIENTE
    // ============================================================

    task automatic probar_cancelacion;

        begin
            @(negedge reloj);
            #1;

            operando_a = 10'd500;
            operando_b = 10'd123;
            calcular = 1'b1;

            @(posedge reloj);
            #1;

            // Borrar antes del flanco que publicaría el resultado.
            @(negedge reloj);
            #1;

            calcular = 1'b0;
            borrar = 1'b1;

            @(posedge reloj);
            #1;

            if (resultado !== 11'sd0 ||
                resultado_valido !== 1'b0)
                $fatal(
                    1,
                    "FALLO: borrado no cancelo la operacion"
                );

            @(negedge reloj);
            #1;

            borrar = 1'b0;

            repeat (2) begin
                @(posedge reloj);
                #1;

                if (resultado !== 11'sd0 ||
                    resultado_valido !== 1'b0)
                    $fatal(
                        1,
                        "FALLO: reaparecio la operacion cancelada"
                    );
            end
        end

    endtask

    // ============================================================
    // SECUENCIA PRINCIPAL DE PRUEBAS
    // ============================================================

    initial begin

        // Activar una traza breve agregando +ondas al comando vvp.
        if ($test$plusargs("ondas")) begin
            $dumpfile("src/build/tb_m6_resta_complemento.vcd");
            $dumpvars(0, tb_m6_resta_complemento);
        end

        // Comprobar el reinicio inicial.
        repeat (2) begin
            @(posedge reloj);
            #1;

            if (resultado !== 11'sd0 ||
                resultado_valido !== 1'b0)
                $fatal(1, "FALLO: reinicio inicial");
        end

        @(negedge reloj);
        #1;

        reinicio = 1'b0;

        // Casos normales, igualdad, cero y extremos.
        probar_operacion(10'd7,   10'd2);
        probar_operacion(10'd2,   10'd7);
        probar_operacion(10'd42,  10'd42);
        probar_operacion(10'd0,   10'd0);
        probar_operacion(10'd999, 10'd0);
        probar_operacion(10'd0,   10'd999);
        probar_operacion(10'd999, 10'd999);
        probar_operacion(10'd100, 10'd99);

        // Cancelación y nueva operación después del borrado.
        probar_cancelacion();
        probar_operacion(10'd12, 10'd34);

        // Reiniciar después de obtener un resultado negativo.
        @(negedge reloj);
        #1;

        reinicio = 1'b1;

        @(posedge reloj);
        #1;

        if (resultado !== 11'sd0 ||
            resultado_valido !== 1'b0)
            $fatal(1, "FALLO: reinicio posterior");

        @(negedge reloj);
        #1;

        reinicio = 1'b0;

        probar_operacion(10'd123, 10'd456);

        // Evitar una traza enorme durante la prueba exhaustiva.
        if ($test$plusargs("ondas"))
            $dumpoff;

        // Probar todos los pares entre 0 y 999.
        for (int a = 0; a <= 999; a++) begin
            for (int b = 0; b <= 999; b++) begin
                probar_operacion(a[9:0], b[9:0]);
            end
        end

        $display(
            "PASS: %0d operaciones, signo, limites, registros, latencia, pulso valido, borrado y reinicio.",
            pruebas
        );

        $finish;
    end

    // ============================================================
    // LÍMITE DE TIEMPO PARA DETECTAR UNA PRUEBA BLOQUEADA
    // ============================================================

    initial begin
        #40000000;
        $fatal(1, "FALLO: tiempo maximo de simulacion excedido");
    end

endmodule