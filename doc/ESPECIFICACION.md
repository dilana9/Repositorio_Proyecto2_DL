# Especificación inicial
## Obligatorio
Captura decimal por teclado; resta por suma en complemento a dos; cuatro displays incluyendo signo; FSM; sincronización y antirrebote provisto; conversor BCD y refresco basados en código del curso; único reloj interno de 27 MHz; interfaces registradas; verificación RTL y temporal. Experimentos externos obligatorios: contadores y cerrojos, no sustituibles con FPGA.
## Decisiones
FSM binaria: CAPTURA_A=00, CAPTURA_B=01, ESPERA_RESULTADO=10, RESULTADO=11.
## Propuestas pendientes
Operandos 0..999, aceptar uno a tres dígitos, A confirma primero, B calcula, C borra; resultado -999..999. Confirmar ambigüedad de al menos tres dígitos frente a tres dígitos y admisión del cero.
## Hardware pendiente
Orden de terminales y resistencias de teclado; modelo y polaridades de displays; pines CST; circuito de manejo de corriente.
