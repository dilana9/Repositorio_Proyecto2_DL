`timescale 1ns/1ps
module tb_m1_base_tiempos;
    logic reloj = 1'b0;
    logic reinicio = 1'b1;
    logic paso_teclado, paso_display;
    logic paso_uno_teclado, paso_uno_display;

    // Periodo aproximado de 27 MHz; precisión de 1 ps.
    always #18.5185 reloj = ~reloj;

    m1_base_tiempos #(.CICLOS_TECLADO(3), .CICLOS_DISPLAY(5)) dut (
        .reloj_pi(reloj), .reinicio_pi(reinicio),
        .paso_teclado_po(paso_teclado), .paso_display_po(paso_display)
    );
    // Caso límite: habilitación cada ciclo.
    m1_base_tiempos #(.CICLOS_TECLADO(1), .CICLOS_DISPLAY(1)) dut_uno (
        .reloj_pi(reloj), .reinicio_pi(reinicio),
        .paso_teclado_po(paso_uno_teclado),
        .paso_display_po(paso_uno_display)
    );

    task automatic verificar_reinicio;
        @(posedge reloj);
        #1;
        if ({paso_teclado, paso_display, paso_uno_teclado,
             paso_uno_display} !== 4'b0000)
            $fatal(1, "FALLO: salidas durante reinicio");
    endtask

    task automatic verificar_ciclos(input integer cantidad);
        for (integer ciclo = 1; ciclo <= cantidad; ciclo = ciclo + 1) begin
            @(posedge reloj);
            #1; // Espera las asignaciones no bloqueantes del diseño.
            if (paso_teclado !== ((ciclo % 3) == 0))
                $fatal(1, "FALLO teclado en ciclo %0d", ciclo);
            if (paso_display !== ((ciclo % 5) == 0))
                $fatal(1, "FALLO display en ciclo %0d", ciclo);
            if ({paso_uno_teclado, paso_uno_display} !== 2'b11)
                $fatal(1, "FALLO divisor uno en ciclo %0d", ciclo);
        end
    endtask

    initial begin
        $dumpfile("src/build/tb_m1_base_tiempos.vcd");
        $dumpvars(0, tb_m1_base_tiempos);
        verificar_reinicio();
        verificar_reinicio();
        @(negedge reloj);
        reinicio = 1'b0;
        verificar_ciclos(32);
        // Reinicio en mitad de una cuenta; verificar nuevo comienzo.
        @(negedge reloj);
        reinicio = 1'b1;
        verificar_reinicio();
        @(negedge reloj);
        reinicio = 1'b0;
        verificar_ciclos(20);
        $display("PASS: periodos 3 y 5, coincidencias, divisor 1 y reinicio.");
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FALLO: tiempo máximo de simulación");
    end
endmodule
