`timescale 1ns/1ps

module tb_m9_refresco_display;

    // Pausa reducida para probar rapidamente.
    localparam integer PAUSA = 2;

    logic reloj = 1'b0;
    logic reinicio = 1'b1;
    logic paso = 1'b0;

    logic [15:0] simbolos = 16'hFFFF;
    logic validos = 1'b0;

    logic [6:0] segmentos;
    logic [3:0] digitos;

    // ============================================================
    // MODULO BAJO PRUEBA
    // ============================================================

    m9_refresco_display #(
        .CICLOS_APAGADO(PAUSA)
    ) dut (
        .reloj_pi(reloj),
        .reinicio_pi(reinicio),
        .paso_display_pi(paso),
        .simbolos_pi(simbolos),
        .simbolos_validos_pi(validos),
        .segmentos_po(segmentos),
        .digitos_po(digitos)
    );

    always #5 reloj = ~reloj;

    // ============================================================
    // PATRONES DE REFERENCIA ACTIVOS EN UNO
    // ORDEN: a,b,c,d,e,f,g
    // ============================================================

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

    // ============================================================
    // VIGILAR QUE NO SE ACTIVEN DOS TRANSISTORES
    // ============================================================

    always @(negedge reloj) begin
        case (digitos)
            4'b0000,
            4'b0001,
            4'b0010,
            4'b0100,
            4'b1000: ;

            default:
                $fatal(
                    1,
                    "FALLO: seleccion multiple o desconocida"
                );
        endcase
    end

    // ============================================================
    // CARGAR CUATRO SIMBOLOS
    // ============================================================

    task automatic cargar(input logic [15:0] valor);

        begin
            @(negedge reloj);

            reinicio = 1'b0;
            simbolos = valor;
            validos = 1'b1;

            repeat (2) begin
                @(posedge reloj);
                #1;
            end
        end

    endtask

    // ============================================================
    // COMPROBAR UN TURNO DE DISPLAY
    // ============================================================

    task automatic turno(
        input integer indice,
        input logic [3:0] simbolo
    );

        logic [6:0] anteriores;

        begin
            @(negedge reloj);

            anteriores = segmentos;
            paso = 1'b1;

            @(posedge reloj);
            #1;

            // Primero debe apagarse el transistor anterior.
            if (digitos !== 4'b0000 ||
                segmentos !== anteriores)
                $fatal(
                    1,
                    "FALLO: no se apago antes de cambiar segmentos"
                );

            @(negedge reloj);
            paso = 1'b0;

            // Durante la pausa ningun transistor debe estar activo.
            for (int c = 1; c <= PAUSA; c++) begin
                @(posedge reloj);
                #1;

                if (digitos !== 4'b0000)
                    $fatal(1, "FALLO: pausa insuficiente");

                if (c < PAUSA && segmentos !== anteriores)
                    $fatal(
                        1,
                        "FALLO: segmentos cambiaron antes de la pausa"
                    );
            end

            if (segmentos !== patron(simbolo))
                $fatal(
                    1,
                    "FALLO: patron del simbolo %h",
                    simbolo
                );

            // Encender despues de estabilizar los segmentos.
            @(posedge reloj);
            #1;

            if (digitos !== (4'b0001 << indice) ||
                segmentos !== patron(simbolo))
                $fatal(
                    1,
                    "FALLO: indice o segmentos incorrectos"
                );

            // Sin habilitacion, las salidas deben mantenerse.
            repeat (3) begin
                @(posedge reloj);
                #1;

                if (digitos !== (4'b0001 << indice) ||
                    segmentos !== patron(simbolo))
                    $fatal(
                        1,
                        "FALLO: cambio sin habilitacion"
                    );
            end
        end

    endtask

    // ============================================================
    // COMPROBAR QUE LAS SALIDAS QUEDEN APAGADAS
    // ============================================================

    task automatic comprobar_apagado;

        begin
            repeat (3) begin
                @(posedge reloj);
                #1;
            end

            if (digitos !== 4'b0000 ||
                segmentos !== 7'b0000000)
                $fatal(1, "FALLO: salida no apagada");
        end

    endtask

    // ============================================================
    // SECUENCIA DE PRUEBAS
    // ============================================================

    initial begin
        $dumpfile("src/build/tb_m9_refresco_display.vcd");
        $dumpvars(0, tb_m9_refresco_display);

        comprobar_apagado();

        // Todos los codigos en las cuatro posiciones.
        for (int s = 0; s < 16; s++) begin
            cargar({4{s[3:0]}});

            for (int d = 0; d < 4; d++)
                turno(d, s[3:0]);
        end

        // Cambiar los simbolos a mitad del barrido.
        // Debe terminar F123 antes de comenzar E456.
        cargar(16'hF123);
        turno(0, 4'h3);

        cargar(16'hE456);
        turno(1, 4'h2);
        turno(2, 4'h1);
        turno(3, 4'hF);

        turno(0, 4'h6);
        turno(1, 4'h5);
        turno(2, 4'h4);
        turno(3, 4'hE);

        // Retirar validez durante un cambio pendiente.
        @(negedge reloj);
        paso = 1'b1;

        @(posedge reloj);
        #1;

        @(negedge reloj);
        paso = 1'b0;
        validos = 1'b0;

        comprobar_apagado();

        // Recuperar validez y comenzar por unidades.
        cargar(16'hF007);

        turno(0, 4'h7);
        turno(1, 4'h0);
        turno(2, 4'h0);
        turno(3, 4'hF);

        // Reinicio durante un cambio pendiente.
        @(negedge reloj);
        paso = 1'b1;

        @(posedge reloj);
        #1;

        @(negedge reloj);
        paso = 1'b0;
        reinicio = 1'b1;

        comprobar_apagado();

        // Comprobar recuperacion y numero negativo.
        cargar(16'hE042);

        turno(0, 4'h2);
        turno(1, 4'h4);
        turno(2, 4'h0);
        turno(3, 4'hE);

        $display(
            "PASS: 16 codigos, cuatro posiciones, polaridad, pausa, marco estable, invalidez y reinicio."
        );

        $finish;
    end

    // Limite para detectar una prueba bloqueada.
    initial begin
        #100000;
        $fatal(1, "FALLO: tiempo maximo excedido");
    end

endmodule