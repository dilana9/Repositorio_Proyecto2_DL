`timescale 1ns/1ps

module tb_sistema;

    // Senales externas del sistema.
    logic reloj = 1'b0;
    logic boton_reinicio_n = 1'b0;
    logic [3:0] columnas;
    wire [3:0] filas;
    logic [6:0] segmentos;
    logic [3:0] digitos;

    // Cada bit representa una tecla presionada.
    logic [15:0] teclas = 16'h0000;

    // Parametros reducidos para acelerar la simulacion.
    top #(
        .CICLOS_TECLADO(8),
        .CICLOS_DISPLAY(32),
        .BITS_FILTRO(7),
        .CICLOS_APAGADO(2)
    ) dut (
        .reloj_pi(reloj),
        .boton_reinicio_n_pi(boton_reinicio_n),
        .columnas_pi(columnas),
        .filas_po(filas),
        .segmentos_po(segmentos),
        .digitos_po(digitos)
    );

    // Reloj exclusivo de simulacion.
    always #5 reloj = ~reloj;

    // Modelo de contactos con pull-up en cada columna.
    // El caso de varias teclas utiliza dos de la misma fila.
    always_comb begin
        columnas = 4'b1111;

        for (int f = 0; f < 4; f++) begin
            for (int c = 0; c < 4; c++) begin
                if ((filas[f] === 1'b0) && teclas[4*f+c])
                    columnas[c] = 1'b0;
            end
        end
    end

    // Patrones esperados, activos en uno.
    // Orden de bits: a, b, c, d, e, f, g.
    function automatic logic [6:0] patron(
        input logic [3:0] simbolo
    );
        case (simbolo)
            0: patron = 7'b1111110;
            1: patron = 7'b0110000;
            2: patron = 7'b1101101;
            3: patron = 7'b1111001;
            4: patron = 7'b0110011;
            5: patron = 7'b1011011;
            6: patron = 7'b1011111;
            7: patron = 7'b1110000;
            8: patron = 7'b1111111;
            9: patron = 7'b1111011;
            4'hE: patron = 7'b0000001;
            default: patron = 7'b0000000;
        endcase
    endfunction

    // Esperar ciclos y permitir actualizar los registros.
    task automatic esperar(input integer ciclos);
        repeat (ciclos) begin
            @(posedge reloj);
            #1;
        end
    endtask

    // Presionar y liberar una tecla.
    task automatic pulsar(input integer posicion);
        @(negedge reloj);
        teclas = 16'h0001 << posicion;
        esperar(400);

        @(negedge reloj);
        teclas = 16'h0000;
        esperar(400);
    endtask

    // Comprobar los cuatro displays durante el barrido.
    task automatic comprobar_display(
        input logic [15:0] esperado
    );
        logic [3:0] vistos;
        logic [3:0] simbolo;

        begin
            esperar(320);
            vistos = 4'b0000;

            repeat (160) begin
                @(negedge reloj);

                case (digitos)
                    // Intervalo de apagado entre displays.
                    4'b0000: ;

                    // Solo puede estar activo un display.
                    4'b0001, 4'b0010,
                    4'b0100, 4'b1000: begin
                        for (int d = 0; d < 4; d++) begin
                            if (digitos[d]) begin
                                simbolo = esperado[4*d +: 4];

                                if (segmentos !== patron(simbolo))
                                    $fatal(
                                        1,
                                        "FALLO: display %0d esperado=%h segmentos=%b",
                                        d, simbolo, segmentos
                                    );

                                vistos[d] = 1'b1;
                            end
                        end
                    end

                    default:
                        $fatal(1, "FALLO: multiples displays activos");
                endcase
            end

            if (vistos !== 4'b1111)
                $fatal(1, "FALLO: barrido incompleto");

            $display(
                "OK: simbolos %h verificados en salidas fisicas",
                esperado
            );
        end
    endtask

    // Pruebas de funcionamiento completo.
    initial begin

        // Generar ondas solamente si se solicita +ondas.
        if ($test$plusargs("ondas")) begin
            $dumpfile("src/build/tb_sistema.vcd");
            $dumpvars(0, tb_sistema);
        end

        // Arranque y liberacion del reinicio.
        esperar(5);
        @(negedge reloj);
        boton_reinicio_n = 1'b1;
        esperar(400);
        comprobar_display(16'hF000);

        // A y B no deben confirmar una entrada vacia.
        pulsar(3);
        pulsar(7);

        if (dut.estado_operacion !== 2'b00)
            $fatal(1, "FALLO: entrada vacia confirmada");

        // 7 A 2 B = 5.
        pulsar(8);
        comprobar_display(16'hF007);
        pulsar(3);
        comprobar_display(16'hF000);
        pulsar(1);
        pulsar(7);
        comprobar_display(16'hF005);

        // C; 2 A 7 B = -5.
        pulsar(11);
        comprobar_display(16'hF000);
        pulsar(1);
        pulsar(3);
        pulsar(8);
        pulsar(7);
        comprobar_display(16'hE005);

        // C; 42 A 12 B = 30.
        pulsar(11);
        pulsar(4);
        pulsar(1);
        comprobar_display(16'hF042);
        pulsar(3);
        pulsar(0);
        pulsar(1);
        pulsar(7);
        comprobar_display(16'hF030);

        // C; 105 A 007 B = 98.
        pulsar(11);
        pulsar(0);
        pulsar(13);
        pulsar(5);
        comprobar_display(16'hF105);
        pulsar(3);
        pulsar(13);
        pulsar(13);
        pulsar(8);
        pulsar(7);
        comprobar_display(16'hF098);

        // Limite positivo: 999 - 0 = 999.
        pulsar(11);
        pulsar(10);
        pulsar(10);
        pulsar(10);
        pulsar(3);
        pulsar(13);
        pulsar(7);
        comprobar_display(16'hF999);

        // Limite negativo: 0 - 999 = -999.
        pulsar(11);
        pulsar(13);
        pulsar(3);
        pulsar(10);
        pulsar(10);
        pulsar(10);
        pulsar(7);
        comprobar_display(16'hE999);

        // Cuarto digito ignorado.
        pulsar(11);
        pulsar(0);
        pulsar(1);
        pulsar(2);
        pulsar(4);
        comprobar_display(16'hF123);

        // Segundo operando vacio: B debe ignorarse.
        pulsar(3);
        pulsar(7);

        if (dut.estado_operacion !== 2'b01)
            $fatal(1, "FALLO: segundo operando vacio confirmado");

        // Completar 123 - 123 = 0.
        pulsar(0);
        pulsar(1);
        pulsar(2);
        pulsar(7);
        comprobar_display(16'hF000);

        // Dos teclas simultaneas: no aceptar un digito.
        pulsar(11);
        @(negedge reloj);
        teclas = 16'h0003;
        esperar(400);

        @(negedge reloj);
        teclas = 16'h0000;
        esperar(400);
        comprobar_display(16'hF000);

        // Una tecla mantenida debe producir un solo evento.
        @(negedge reloj);
        teclas = 16'h0001;
        esperar(1200);

        @(negedge reloj);
        teclas = 16'h0000;
        esperar(400);
        comprobar_display(16'hF001);

        // Reinicio fisico activado entre flancos.
        @(negedge reloj);
        #2 boton_reinicio_n = 1'b0;
        esperar(5);

        if (digitos !== 4'b0000 || filas !== 4'bzzzz)
            $fatal(1, "FALLO: reinicio fisico");

        @(negedge reloj);
        #2 boton_reinicio_n = 1'b1;
        esperar(400);
        comprobar_display(16'hF000);

        $display(
            "PASS: teclado, captura, resta, BCD, signo, barrido, limites, entradas vacias, cuarto digito, multiples teclas y reinicio."
        );
        $finish;
    end

    // Detectar una simulacion que no termina.
    initial begin
        #2000000;
        $fatal(1, "FALLO: tiempo maximo excedido");
    end

endmodule