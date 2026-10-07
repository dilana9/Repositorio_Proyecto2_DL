`timescale 1ns/1ps

module tb_m3_explorador_teclado;

    // Reloj, reinicio y habilitacion de exploracion.
    logic reloj = 1'b0;
    logic reinicio = 1'b1;
    logic paso_teclado = 1'b0;
    logic [2:0] contador_pasos = 3'b000;

    // Teclado ideal y conexiones entre M2 y M3.
    logic [15:0] teclas_presionadas = 16'b0;
    logic [3:0] columnas_asincronas;
    logic [3:0] columnas_sincronizadas;
    logic [3:0] filas_activas;
    logic [15:0] mapa_teclas;
    logic lectura_valida;
    logic [15:0] mapa_anterior = 16'b0;

    // Sincronizacion de las columnas del modelo de teclado.
    m2_sincronizador sincronizador (
        .reloj_pi                 (reloj),
        .reinicio_pi              (reinicio),
        .columnas_asincronas_pi    (columnas_asincronas),
        .columnas_sincronizadas_po (columnas_sincronizadas)
    );

    // Explorador bajo prueba.
    m3_explorador_teclado dut (
        .reloj_pi                  (reloj),
        .reinicio_pi               (reinicio),
        .paso_teclado_pi           (paso_teclado),
        .columnas_sincronizadas_pi (columnas_sincronizadas),
        .filas_activas_po          (filas_activas),
        .mapa_teclas_po            (mapa_teclas),
        .lectura_valida_po         (lectura_valida)
    );

    // Periodo de 10 ns.
    always #5 reloj = ~reloj;

    // Preparar una habilitacion cada ocho ciclos.
    always @(negedge reloj) begin
        if (reinicio) begin
            contador_pasos = 3'b000;
            paso_teclado = 1'b0;
        end else begin
            paso_teclado = (contador_pasos == 3'd7);
            contador_pasos = contador_pasos + 1'b1;
        end
    end

    // Columnas activas en cero para este modelo de simulacion.
    // No representa efectos electricos de ghosting del teclado real.
    always_comb begin
        columnas_asincronas = 4'b1111;

        for (int fila = 0; fila < 4; fila++) begin
            if (filas_activas[fila])
                columnas_asincronas = columnas_asincronas
                                   & ~teclas_presionadas[fila * 4 +: 4];
        end
    end

    // Verificar seleccion exclusiva y estabilidad del mapa publicado.
    always @(posedge reloj) begin
        #1;

        if (reinicio) begin
            mapa_anterior = 16'b0;

            if (mapa_teclas !== 16'b0 || lectura_valida !== 1'b0)
                $fatal(1, "FALLO: reinicio de las salidas");
        end else begin
            case (filas_activas)
                4'b0001, 4'b0010, 4'b0100, 4'b1000: begin end
                default: $fatal(1, "FALLO: seleccion de filas");
            endcase

            if (!lectura_valida && mapa_teclas !== mapa_anterior)
                $fatal(1, "FALLO: cambio del mapa sin lectura valida");

            mapa_anterior = mapa_teclas;
        end
    end

    // Esperar una publicacion completa, con limite de ciclos.
    task automatic esperar_mapa;
        integer ciclos;
        begin
            ciclos = 0;

            do begin
                @(posedge reloj);
                #2;
                ciclos = ciclos + 1;

                if (ciclos > 100)
                    $fatal(1, "FALLO: no se publico un mapa completo");
            end while (lectura_valida !== 1'b1);
        end
    endtask

    // Cambiar teclas y esperar un barrido completo con entrada estable.
    task automatic probar_mapa(input logic [15:0] esperado);
        begin
            @(negedge reloj);
            #1;
            teclas_presionadas = esperado;

            // El primer mapa puede incluir filas leidas antes del cambio.
            esperar_mapa();
            esperar_mapa();

            if (mapa_teclas !== esperado)
                $fatal(1, "FALLO: esperado %h, obtenido %h",
                       esperado, mapa_teclas);
        end
    endtask

    // Secuencia principal de pruebas.
    initial begin
        $dumpfile("src/build/tb_m3_explorador_teclado.vcd");
        $dumpvars(0, tb_m3_explorador_teclado);

        repeat (2) @(negedge reloj);
        #1;
        reinicio = 1'b0;

        // Ninguna tecla presionada.
        probar_mapa(16'h0000);

        // Las 16 posiciones, una por una.
        for (int tecla = 0; tecla < 16; tecla++)
            probar_mapa(16'h0001 << tecla);

        // Varias posiciones: M3 no decide si son entradas validas.
        probar_mapa(16'h0003);
        probar_mapa(16'h8421);
        probar_mapa(16'hFFFF);

        // Liberacion de las teclas.
        probar_mapa(16'h0000);

        // Reinicio durante la exploracion con una tecla mantenida.
        @(negedge reloj);
        #1;
        teclas_presionadas = 16'h0020;

        repeat (5) @(negedge reloj);
        #1;
        reinicio = 1'b1;

        repeat (2) @(negedge reloj);
        #1;
        reinicio = 1'b0;

        probar_mapa(16'h0020);

        $display("PASS: 16 posiciones, ausencia de tecla, multiples posiciones, mapa estable y reinicio con M2.");
        $finish;
    end

    // Evitar que una simulacion con errores permanezca ejecutandose.
    initial begin
        #30000;
        $fatal(1, "FALLO: tiempo maximo de simulacion excedido");
    end

endmodule