# Proyecto corto 2: calculadora de resta
Tang Nano 9K, SystemVerilog y reloj único de 27 MHz.

## Estado
Arquitectura aceptada para iniciar módulos; FSM binaria. Rango 0..999 y teclas A/B/C aún son propuestas. Pines y displays pendientes de identificación. No hay top ni CST programable todavía.

## Primer módulo
`m1_base_tiempos`: habilitaciones registradas para exploración y refresco. Parámetros positivos; valores de hardware provisionales. Con 27000 ciclos a 27 MHz, cada salida se activa cada 1 ms. Si el controlador de display cambia una posición por pulso, cada display se refresca a 250 Hz.

Desde la raíz, en PowerShell con OSS CAD Suite disponible:
```powershell
iverilog -g2012 -Wall -s tb_m1_base_tiempos -o src/build/tb_m1_base_tiempos.vvp src/design/m1_base_tiempos.sv src/sim/tb_m1_base_tiempos.sv
vvp src/build/tb_m1_base_tiempos.vvp
```
El testbench debe terminar con PASS. No se ha ejecutado Icarus en el entorno de preparación porque no está instalado.

## Referencias obligatorias
Antirrebote Digi-Key DeBounce; BCD ROM: https://www.edaplayground.com/x/RGrE ; display multiplexado: https://www.edaplayground.com/x/W4Zr . Conservar créditos en las adaptaciones. Los originales aún no se incorporan a este paquete.
