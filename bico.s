@@@@@@@@@@@@@@@@@@@@@@
@BiCo - Biblioteca de Controle           @
@@@@@@@@@@@@@@@@@@@@@@

 @Global symbols
    .global set_speed_motor
    .global set_speed_motors
    .global read_sonar
    .global read_sonars
    .global register_proximity_callback
    .global add_alarm   
    .global get_time
    .global set_time

    .text
    .align 4

@muda a velocidade de 1 motor
set_speed_motor:
    stmfd sp!, {r7, lr} 

    mov r7, #18     @coloca o valor da syscall em r7
    svc 0x0         @ Faz a chamada da syscall.

    ldmfd sp!, {r7, pc}
    
    
@muda a velocidade de dois motores
set_motors_speed:	
	stmfd sp!, 	{r7,lr}
	mov 	r7, 	#19
	svc 	0x0
	ldmfd sp!, 	{r7,pc}

@faz a leitura de um sonar
@p0 = sonar a ser lido
@retorno = valor da leitura
read_sonar:	
	stmfd sp!, {r7,lr}
	mov 	r7,  #16 
	svc 	0x0                         @faz a chamada da syscall
	ldmfd sp!, {r7,pc}
    

@le todos os sonres
@p0 = vetor onde salvar toda as distancias
 read_sonars:
	stmfd sp!, {r5,r6,r7,lr}
	mov   r5,  r0                    @coloca o endereco do vetor em r5
	mov   r6,  #0                   @i  = 0
	mov 	r7,  #16              @idenfitica a syscall de ler o sonar

ler_sonar: 							@ while i < 16
	cmp   r6,  #16                  
	beq   fim_da_leitura
	
    svc 	0x0                         @faz a leitura do sonar
	str   r0,  [r5]                    @coloca a leitura (salva em r0), no vetor
	add   r6,  r6, #1              @ i = i + 1
	add   r5,  r5, #4              @da um passo no vetor de int (4 bytes)

	b     ler_sonar                 @le os sensores restantes

    
fim_da_leitura:	
	ldmfd sp!, {r5,r6,r7,pc}
    

@registra uma callback nova
register_proximity_callback:
	stmfd sp!, {r7,lr}
	mov   r7,  #17          @identifica a syscall
	svc   0x0                   @chama a syscall
	ldmfd sp!, {r7,pc} 
    
@adiciona um alarme
add_alarm:
	stmfd sp!, {r7,lr}
	mov   r7,  #22          @idenfitica a syscall
	svc   0x0                   @faz a chamada da syscall
	ldmfd sp!, {r7,pc}


@recupera o tempo do sistema
@retorno: tempo atual do sistema
get_time: 
	stmfd sp!, {r7,lr}
	mov   r7,  #20
	svc   0
	ldmfd sp!, {r7,pc}
    
    
@altera o tempo do sistema
@p0 = tempo a ser colocado
set_time:
	stmfd sp!, {r7,lr}
	mov   r7,  #21
	svc   0
	ldmfd sp!, {r7,pc}
    