`timescale 1ns/1ps

module tb_m4_filtro_evento;

    // Entradas y salidas.
    logic reloj = 1'b0;
    logic reinicio = 1'b1;
    logic [15:0] mapa = 16'b0;
    logic lectura_valida = 1'b0;
    logic [3:0] posicion;
    logic evento;
    logic listo;

    // Variables de comprobacion.
    integer eventos = 0;
    logic evento_anterior = 1'b0;
    logic [3:0] ultima_posicion = 4'b0;

    // Filtro reducido exclusivamente para acelerar la simulacion.
    m4_filtro_evento #(.BITS_FILTRO(4)) dut (
        .reloj_pi          (reloj),
        .reinicio_pi       (reinicio),
        .mapa_teclas_pi    (mapa),
        .lectura_valida_pi (lectura_valida),
        .posicion_tecla_po (posicion),
        .evento_tecla_po   (evento),
        .listo_po          (listo)
    );

    // Reloj de simulacion: periodo de 10 ns.
    always #5 reloj = ~reloj;

    // Contar eventos y comprobar su duracion y validez.
    always @(posedge reloj) begin
        #1;

        if (reinicio) begin
            eventos = 0;
            evento_anterior = 1'b0;
            ultima_posicion = 4'b0;

            if (evento !== 1'b0 || listo !== 1'b0)
                $fatal(1, "FALLO: salidas durante reinicio");
        end else begin
            if (evento !== 1'b0 && evento !== 1'b1)
                $fatal(1, "FALLO: evento indefinido");

            if (evento) begin
                if (!listo || evento_anterior)
                    $fatal(1,
                           "FALLO: evento prematuro o mayor que un ciclo");

                eventos = eventos + 1;
                ultima_posicion = posicion;
            end

            evento_anterior = evento;
        end
    end

    // Esperar sin cambiar las entradas.
    task automatic esperar_ciclos(input integer cantidad);
        repeat (cantidad) @(negedge reloj);
        #2;
    endtask

    // Una publicacion completa, como la entregada por M3.
    task automatic publicar(input logic [15:0] nuevo_mapa);
        @(negedge reloj);
        #2;
        mapa = nuevo_mapa;
        lectura_valida = 1'b1;

        @(negedge reloj);
        #2;
        lectura_valida = 1'b0;
    endtask

    // Comprobar cantidad de eventos y ultima posicion aceptada.
    task automatic comprobar(
        input integer esperados,
        input logic [3:0] posicion_esperada
    );
        if (eventos != esperados ||
            ultima_posicion !== posicion_esperada)
            $fatal(1,
                   "FALLO: eventos=%0d posicion=%0d; esperados=%0d posicion=%0d",
                   eventos, ultima_posicion,
                   esperados, posicion_esperada);
    endtask

    // Secuencia principal.
    initial begin
        $dumpfile("src/build/tb_m4_filtro_evento.vcd");
        $dumpvars(0, tb_m4_filtro_evento);

        esperar_ciclos(2);
        reinicio = 1'b0;
        esperar_ciclos(40);

        if (listo !== 1'b1)
            $fatal(1, "FALLO: inicializacion incompleta");

        comprobar(0, 4'd0);

        // Rebotes breves: no producir eventos.
        publicar(16'h0001);
        esperar_ciclos(2);
        publicar(16'h0000);
        esperar_ciclos(2);
        publicar(16'h0001);
        esperar_ciclos(2);
        publicar(16'h0000);
        esperar_ciclos(30);
        comprobar(0, 4'd0);

        // Pulsacion estable y mantenida: solamente un evento.
        publicar(16'h0001);
        esperar_ciclos(30);
        comprobar(1, 4'd0);

        esperar_ciclos(30);
        comprobar(1, 4'd0);

        // Cambiar a otra tecla sin liberar: no generar otro evento.
        publicar(16'h8000);
        esperar_ciclos(30);
        comprobar(1, 4'd0);

        // Liberar y volver a presionar: aceptar la posicion 15.
        publicar(16'h0000);
        esperar_ciclos(30);

        publicar(16'h8000);
        esperar_ciclos(30);
        comprobar(2, 4'd15);

        // Varias posiciones estables: no entregar un codigo ambiguo.
        publicar(16'h0000);
        esperar_ciclos(30);

        publicar(16'h0003);
        esperar_ciclos(30);
        comprobar(2, 4'd15);

        // Otra pulsacion normal tras liberar.
        publicar(16'h0000);
        esperar_ciclos(30);

        publicar(16'h0020);
        esperar_ciclos(30);
        comprobar(3, 4'd5);

        // Reiniciar e ignorar las salidas antiguas del filtro original.
        esperar_ciclos(1);
        reinicio = 1'b1;

        esperar_ciclos(2);
        reinicio = 1'b0;

        esperar_ciclos(40);
        comprobar(0, 4'd0);

        publicar(16'h0020);
        esperar_ciclos(30);
        comprobar(1, 4'd5);

        $display("PASS: inicializacion, rebotes, pulsacion mantenida, liberacion, posiciones 0/15/5, multiples teclas y reinicio.");
        $finish;
    end

    // Limite de tiempo de simulacion.
    initial begin
        #20000;
        $fatal(1, "FALLO: tiempo maximo de simulacion excedido");
    end

endmodule