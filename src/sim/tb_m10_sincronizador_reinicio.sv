`timescale 1ns/1ps

module tb_m10_sincronizador_reinicio;

    // Senales de prueba.
    logic reloj = 1'b0;
    logic reinicio_asincrono = 1'b1;
    logic reinicio;

    // Modulo bajo prueba.
    m10_sincronizador_reinicio dut (
        .reloj_pi(reloj),
        .reinicio_asincrono_pi(reinicio_asincrono),
        .reinicio_po(reinicio)
    );

    // Reloj de simulacion: periodo de 10 ns.
    always #5 reloj = ~reloj;

    // Liberar entre flancos y comprobar las dos etapas.
    task automatic liberar;
        begin
            @(negedge reloj);
            #2 reinicio_asincrono = 1'b0;
            #1;

            if (reinicio !== 1'b1)
                $fatal(1, "FALLO: liberacion asincrona");

            @(posedge reloj);
            #1;

            if (reinicio !== 1'b1)
                $fatal(1, "FALLO: liberacion antes del segundo flanco");

            @(posedge reloj);
            #1;

            if (reinicio !== 1'b0)
                $fatal(1, "FALLO: liberacion no sincronizada");
        end
    endtask

    // Secuencia principal de pruebas.
    initial begin
        $dumpfile("src/build/tb_m10_sincronizador_reinicio.vcd");
        $dumpvars(0, tb_m10_sincronizador_reinicio);

        // Caso 1: mantener activo el reinicio.
        repeat (2) begin
            @(posedge reloj);
            #1;

            if (reinicio !== 1'b1)
                $fatal(1, "FALLO: reinicio mantenido");
        end

        // Caso 2: comprobar la liberacion sincronizada.
        liberar();

        // Caso 3: activar entre flancos.
        @(negedge reloj);
        #2 reinicio_asincrono = 1'b1;
        #1;

        if (reinicio !== 1'b1)
            $fatal(1, "FALLO: afirmacion asincrona");

        liberar();

        // Caso 4: pulso corto sin un flanco ascendente en su interior.
        @(negedge reloj);
        #1 reinicio_asincrono = 1'b1;
        #1;

        if (reinicio !== 1'b1)
            $fatal(1, "FALLO: pulso corto no detectado");

        #1 reinicio_asincrono = 1'b0;

        @(posedge reloj);
        #1;

        if (reinicio !== 1'b1)
            $fatal(1, "FALLO: pulso corto no extendido");

        @(posedge reloj);
        #1;

        if (reinicio !== 1'b0)
            $fatal(1, "FALLO: liberacion despues del pulso corto");

        $display("PASS: afirmacion asincrona, dos etapas de liberacion, reinicio mantenido y pulso corto.");
        $finish;
    end

    // Limite de tiempo para detectar una simulacion bloqueada.
    initial begin
        #1000;
        $fatal(1, "FALLO: tiempo maximo excedido");
    end

endmodule