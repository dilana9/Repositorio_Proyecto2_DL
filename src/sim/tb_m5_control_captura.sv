`timescale 1ns/1ps

module tb_m5_control_captura;

    // Entradas.
    logic reloj = 1'b0;
    logic reinicio = 1'b1;
    logic [3:0] posicion = 4'd0;
    logic evento = 1'b0;
    logic resultado_valido = 1'b0;

    // Salidas.
    logic [9:0] operando_a, operando_b, captura;
    logic [1:0] cantidad_digitos, estado;
    logic calcular, borrar;

    // Instancia bajo prueba.
    m5_control_captura dut (
        .reloj_pi            (reloj),
        .reinicio_pi         (reinicio),
        .posicion_tecla_pi   (posicion),
        .evento_tecla_pi     (evento),
        .resultado_valido_pi (resultado_valido),
        .operando_a_po       (operando_a),
        .operando_b_po       (operando_b),
        .captura_po          (captura),
        .cantidad_digitos_po (cantidad_digitos),
        .estado_po           (estado),
        .calcular_po         (calcular),
        .borrar_po           (borrar)
    );

    // Reloj de periodo 10 ns.
    always #5 reloj = ~reloj;

    // Evento de un ciclo, como el entregado por M4.
    task automatic pulsar(input logic [3:0] nueva_posicion);
        @(negedge reloj);
        #1;
        posicion = nueva_posicion;
        evento = 1'b1;

        @(negedge reloj);
        #1;
        evento = 1'b0;
    endtask

    // Revisar todos los registros visibles.
    task automatic comprobar(
        input logic [1:0] estado_esperado,
        input logic [9:0] a_esperado,
        input logic [9:0] b_esperado,
        input logic [9:0] captura_esperada,
        input logic [1:0] digitos_esperados
    );
        if (estado !== estado_esperado ||
            operando_a !== a_esperado ||
            operando_b !== b_esperado ||
            captura !== captura_esperada ||
            cantidad_digitos !== digitos_esperados)

            $fatal(1,
                   "FALLO: estado=%0d A=%0d B=%0d captura=%0d digitos=%0d",
                   estado, operando_a, operando_b,
                   captura, cantidad_digitos);
    endtask

    task automatic esperar_ciclo;
        @(posedge reloj);
        #1;
    endtask

    // Simular la respuesta de M6, sin calcular aqui la resta.
    task automatic responder_resultado;
        @(negedge reloj);
        #1;
        resultado_valido = 1'b1;

        @(posedge reloj);
        #1;
        if (estado !== 2'b11)
            $fatal(1, "FALLO: no se paso a RESULTADO");

        @(negedge reloj);
        #1;
        resultado_valido = 1'b0;
    endtask

    // C debe limpiar los datos y producir un pulso de borrado.
    task automatic borrar_todo;
        pulsar(4'd11);
        comprobar(2'b00, 10'd0, 10'd0, 10'd0, 2'd0);

        if (borrar !== 1'b1 || calcular !== 1'b0)
            $fatal(1, "FALLO: pulso de borrado");

        esperar_ciclo();
        if (borrar !== 1'b0)
            $fatal(1, "FALLO: borrado mayor que un ciclo");
    endtask

    // Secuencia principal.
    initial begin
        $dumpfile("src/build/tb_m5_control_captura.vcd");
        $dumpvars(0, tb_m5_control_captura);

        esperar_ciclo();
        comprobar(2'b00, 10'd0, 10'd0, 10'd0, 2'd0);

        @(negedge reloj);
        #1;
        reinicio = 1'b0;

        // Entrada vacia: A y B no deben iniciar una operacion.
        pulsar(4'd3);
        pulsar(4'd7);
        comprobar(2'b00, 10'd0, 10'd0, 10'd0, 2'd0);

        if (calcular !== 1'b0)
            $fatal(1, "FALLO: calculo con entrada vacia");

        // Cambiar posicion sin evento no debe ingresar un digito.
        posicion = 4'd10;
        esperar_ciclo();
        comprobar(2'b00, 10'd0, 10'd0, 10'd0, 2'd0);

        // Teclas sin funcion: *, # y D.
        pulsar(4'd12);
        pulsar(4'd14);
        pulsar(4'd15);
        comprobar(2'b00, 10'd0, 10'd0, 10'd0, 2'd0);

        // Un digito: A=7, B=0.
        pulsar(4'd8);
        comprobar(2'b00, 10'd0, 10'd0, 10'd7, 2'd1);

        pulsar(4'd3);
        comprobar(2'b01, 10'd7, 10'd0, 10'd0, 2'd0);

        // B vacio no se confirma.
        pulsar(4'd7);
        comprobar(2'b01, 10'd7, 10'd0, 10'd0, 2'd0);

        if (calcular !== 1'b0)
            $fatal(1, "FALLO: B vacio aceptado");

        // A no tiene funcion durante la captura de B.
        pulsar(4'd3);
        comprobar(2'b01, 10'd7, 10'd0, 10'd0, 2'd0);

        // Ingresar cero: cuenta como un digito.
        pulsar(4'd13);
        pulsar(4'd7);
        comprobar(2'b10, 10'd7, 10'd0, 10'd0, 2'd1);

        if (calcular !== 1'b1)
            $fatal(1, "FALLO: falta solicitud de calculo");

        esperar_ciclo();
        if (calcular !== 1'b0)
            $fatal(1, "FALLO: calculo mayor que un ciclo");

        // Los digitos no modifican operandos mientras se espera.
        pulsar(4'd10);
        comprobar(2'b10, 10'd7, 10'd0, 10'd0, 2'd1);

        responder_resultado();

        // Los digitos tampoco modifican el estado RESULTADO.
        pulsar(4'd0);
        comprobar(2'b11, 10'd7, 10'd0, 10'd0, 2'd1);
        borrar_todo();

        // Dos digitos: A=12 y B=34.
        pulsar(4'd0);
        pulsar(4'd1);
        comprobar(2'b00, 10'd0, 10'd0, 10'd12, 2'd2);

        pulsar(4'd3);
        pulsar(4'd2);
        pulsar(4'd4);
        comprobar(2'b01, 10'd12, 10'd0, 10'd34, 2'd2);

        pulsar(4'd7);
        comprobar(2'b10, 10'd12, 10'd34, 10'd34, 2'd2);

        if (calcular !== 1'b1)
            $fatal(1, "FALLO: solicitud de calculo de dos digitos");

        responder_resultado();
        borrar_todo();

        // Tres ceros cuentan como tres digitos.
        repeat (3) pulsar(4'd13);
        comprobar(2'b00, 10'd0, 10'd0, 10'd0, 2'd3);

        // Ignorar un cuarto digito en A.
        pulsar(4'd10);
        comprobar(2'b00, 10'd0, 10'd0, 10'd0, 2'd3);

        pulsar(4'd3);
        comprobar(2'b01, 10'd0, 10'd0, 10'd0, 2'd0);

        // Limite superior: B=999.
        repeat (3) pulsar(4'd10);
        comprobar(2'b01, 10'd0, 10'd0, 10'd999, 2'd3);

        // Ignorar tambien un cuarto digito en B.
        pulsar(4'd0);
        comprobar(2'b01, 10'd0, 10'd0, 10'd999, 2'd3);

        pulsar(4'd7);
        comprobar(2'b10, 10'd0, 10'd999, 10'd999, 2'd3);

        if (calcular !== 1'b1)
            $fatal(1, "FALLO: solicitud de calculo de tres digitos");

        // C durante la espera.
        borrar_todo();

        // Una respuesta posterior no cambia CAPTURA_A.
        resultado_valido = 1'b1;
        esperar_ciclo();
        comprobar(2'b00, 10'd0, 10'd0, 10'd0, 2'd0);

        @(negedge reloj);
        #1;
        resultado_valido = 1'b0;

        // C durante la captura del primer operando.
        pulsar(4'd5);
        borrar_todo();

        // C durante la captura del segundo operando.
        pulsar(4'd0);
        pulsar(4'd3);
        pulsar(4'd1);
        borrar_todo();

        // Reinicio mientras se captura un numero.
        pulsar(4'd6);

        @(negedge reloj);
        #1;
        reinicio = 1'b1;

        esperar_ciclo();
        comprobar(2'b00, 10'd0, 10'd0, 10'd0, 2'd0);

        if (calcular !== 1'b0 || borrar !== 1'b0)
            $fatal(1, "FALLO: pulsos durante reinicio");

        $display("PASS: captura de 1/2/3 digitos, cero, entrada vacia, cuarto digito, teclas ignoradas, FSM, calculo, borrado y reinicio.");
        $finish;
    end

    // Limite de tiempo de simulacion.
    initial begin
        #10000;
        $fatal(1, "FALLO: tiempo maximo de simulacion excedido");
    end

endmodule