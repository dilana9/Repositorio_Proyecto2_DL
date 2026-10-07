`timescale 1ns/1ps

module tb_m2_sincronizador;

    // Entradas, salida y referencia de la primera etapa.
    logic       reloj = 1'b0;
    logic       reinicio = 1'b1;
    logic [3:0] columnas_asincronas = 4'b0000;
    logic [3:0] columnas_sincronizadas;
    logic [3:0] primera_etapa_referencia = 4'b0000;

    // Instancia del modulo bajo prueba.
    m2_sincronizador dut (
        .reloj_pi                 (reloj),
        .reinicio_pi              (reinicio),
        .columnas_asincronas_pi    (columnas_asincronas),
        .columnas_sincronizadas_po (columnas_sincronizadas)
    );

    // Reloj de simulacion: periodo de 10 ns.
    always #5 reloj = ~reloj;

    // Cambia la entrada entre flancos y comprueba la salida registrada.
    task automatic probar_ciclo(input logic [3:0] nuevo_valor);
        logic [3:0] salida_anterior;
        begin
            @(negedge reloj);
            salida_anterior = columnas_sincronizadas;
            #1;
            columnas_asincronas = nuevo_valor;
            #1;

            if (columnas_sincronizadas !== salida_anterior)
                $fatal(1, "FALLO: la salida cambio entre flancos");

            @(posedge reloj);
            #1;
            if (columnas_sincronizadas !== primera_etapa_referencia)
                $fatal(1, "FALLO: esperado %b, obtenido %b",
                       primera_etapa_referencia, columnas_sincronizadas);

            primera_etapa_referencia = nuevo_valor;
        end
    endtask

    // Comprueba que el reinicio actua en el flanco ascendente.
    task automatic probar_reinicio;
        logic [3:0] salida_anterior;
        begin
            @(negedge reloj);
            salida_anterior = columnas_sincronizadas;
            #1;
            reinicio = 1'b1;
            #1;

            if (columnas_sincronizadas !== salida_anterior)
                $fatal(1, "FALLO: el reinicio no fue sincronico");

            @(posedge reloj);
            #1;
            if (columnas_sincronizadas !== 4'b0000)
                $fatal(1, "FALLO: salida incorrecta durante reinicio");

                        primera_etapa_referencia = 4'b0000;
            @(negedge reloj);

            // Preparar una entrada conocida antes de liberar el reinicio.
            columnas_asincronas = 4'b0000;
            reinicio = 1'b0;
        end
    endtask

    // Pruebas funcionales.
    initial begin
        $dumpfile("src/build/tb_m2_sincronizador.vcd");
        $dumpvars(0, tb_m2_sincronizador);

        // Reinicio inicial: tambien se comprueba que queda mantenido.
        repeat (2) begin
            @(posedge reloj);
            #1;
            if (columnas_sincronizadas !== 4'b0000)
                $fatal(1, "FALLO: reinicio inicial");
        end
        @(negedge reloj);
        reinicio = 1'b0;

        // Todas las combinaciones: primer flanco captura; segundo entrega.
        for (int i = 0; i < 16; i++) begin
            probar_ciclo(i[3:0]);
            probar_ciclo(i[3:0]);
        end

        // Cambios en ciclos consecutivos.
        probar_ciclo(4'b1010);
        probar_ciclo(4'b0101);
        probar_ciclo(4'b1111);
        probar_ciclo(4'b0000);
        probar_ciclo(4'b0000);

        // Reinicio con datos distintos de cero y recuperacion posterior.
        probar_ciclo(4'b1111);
        probar_ciclo(4'b1111);
        probar_reinicio();
        probar_ciclo(4'b0101);
        probar_ciclo(4'b0101);

        $display("PASS: 16 combinaciones, dos etapas, cambios entre flancos, cambios consecutivos y reinicio.");
        $finish;
    end

    // Limite de tiempo para detectar una simulacion que no termina.
    initial begin
        #2000;
        $fatal(1, "FALLO: tiempo maximo de simulacion excedido");
    end

endmodule