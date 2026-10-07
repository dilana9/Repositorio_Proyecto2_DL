# Arquitectura inicial
Teclado -> sincronización -> exploración -> antirrebote original y evento -> FSM y operandos -> resta registrada -> selección visible -> ROM BCD -> formato -> refresco.
Top únicamente conecta módulos. Control y ruta de datos diferenciados. No conectar habilitaciones a puertos de reloj.
## M1
Entradas reloj_pi y reinicio_pi, 1 bit cada una. Salidas paso_teclado_po y paso_display_po, 1 bit cada una. Reinicio sincrónico activo alto. Cada salida se actualiza después del flanco; los módulos consumidores la observan en el siguiente flanco.
Parámetros CICLOS_TECLADO y CICLOS_DISPLAY: enteros >=1. Contadores independientes. Divisor 1 produce habilitación continua después del reinicio.
## Reparto
Persona 1: temporización, sincronización, teclado, captura y top. Persona 2: resta, ROM BCD, formato, display y restricciones. Cada módulo incluye testbench y revisión cruzada.
