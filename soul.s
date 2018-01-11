@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@subcamada SOUL                          @
@Autores: Focoder traficante de empada   @
@         Romulo Oliveira                @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

.set TIME_SZ 1000
.set MAX_ALARMS 8
.set MAX_CALLBACKS 8
.set DELAY_1 200000
.set DELAY_2 300000
.set FIM_VETOR_ALARMES, (VETOR_ALARMES + MAX_ALARMS*9)  @final do vetor de alarmes//se isso nao compilar, colocar no fim do código

.global read_sonar
.global register_proximity_callback
.global set_motor_speed
.global set_motors_speed
.global get_time
.global set_time
.global set_alarm

.org 0x0
.section .iv,"a"


_start:     

interrupt_vector:

    b RESET_HANDLER
        
.org 0x08

    b SUPERVISOR_HANDLER
    
.org 0x18

    b IRQ_HANDLER
    
.text
.align 4


    

RESET_HANDLER:
    @configura a tabela de interrupcoes
    @on coprocessor 15.
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0
    
    
    

CONFIGURA_ALARME:
    @reseta o numero de alarmes ativos
    ldr r0, #0 
    str r0, =N_ALARMES
    
    @indica no vetor que todos os alarmes estao desativados
    ldr r0, =VETOR_ALARMES
    mov r1, #0
    mov r2, #0

    desativa_alarme:
        strb r1, [r0]                @salva que o alarme esta desativado
        add r2, r2, #1               @incrementa contador
        cmp r2, #MAX_ALARMS          @configura todas as posicoes do vetor de alarmes
        beq alarmes_configurados     @para o loop se r2 = MAX_ALARMS
        add r0, r0, #9
        b desativa_alarme            @se nao terminou de configurar, da mais um passo
    alarmes_configurados:

SET_TZIC:

    @ Constantes para os enderecos do TZICo p
    .set TZIC_BASE,             0x0FFFC000
    .set TZIC_INTCTRL,          0x0
    .set TZIC_INTSEC1,          0x84 
    .set TZIC_ENSET1,           0x104
    .set TZIC_PRIOMASK,         0xC
    .set TZIC_PRIORITY9,        0x424

    @ Liga o controlador de interrupcoes
    @ R1 <= TZIC_BASE

    ldr r1, =TZIC_BASE

    @ Configura interrupcao 39 do GPT como nao segura
    mov r0, #(1 << 7)
    str r0, [r1, #TZIC_INTSEC1]

    @ Habilita interrupcao 39 (GPT)
    @ reg1 bit 7 (gpt)

    mov r0, #(1 << 7)
    str r0, [r1, #TZIC_ENSET1]

    @ Configure interrupt39 priority as 1
    @ reg9, byte 3

    ldr r0, [r1, #TZIC_PRIORITY9]
    bic r0, r0, #0xFF000000
    mov r2, #1
    orr r0, r0, r2, lsl #24
    str r0, [r1, #TZIC_PRIORITY9]

    @ Configure PRIOMASK as 0
    eor r0, r0, r0
    str r0, [r1, #TZIC_PRIOMASK]

    @ Habilita o controlador de interrupcoes
    mov r0, #1
    str r0, [r1, #TZIC_INTCTRL]

    @instrucao msr - habilita interrupcoes
    msr  CPSR_c, #0x13       @ SUPERVISOR mode, IRQ/FIQ enabled
    
    
SET_GPT:
    
    mov r0, #0x00000041    @valor para habilitar o gpt
    ldr r1, =0x53FA0000    
    str r0, [r1]           @escreve em GPT_CR

    mov r0, #0x00000000    @valor para habilitar o gpt
    ldr r1, =0x53FA0004    
    str r0, [r1]           @escreve em GPT_PR

    mov r0, #TIME_SZ       @valor para habilitar o gpt
    ldr r1, =0x53FA0010    
    str r0, [r1]           @escreve em GPT_OCR1

    mov r0, #0x00000001    @valor para habilitar o gpt
    ldr r1, =0x53FA000C    
    str r0, [r1]           @escreve em GPT_IR
    
    @ZERA O TEMPO DO SISTEMA
    ldr r2, =SYS_TIME
    mov r0,#0
    str r0,[r2]
    
SET_GPIO
    
    .set GPIO_BASE, 0x53F84000
    .set GPIO_DR,   0x0
    .set GPIO_GDIR, 0x4
    .set GPIO_PSR,  0x8
    
    mov r4, =GPIO_BASE
    mov r0, #0                @zera os dados
    str r0, [r4, #GPIO_DR]
    
    ldr r0, =0xFFFC003E       @configura pinos dos perifericos
    str r0, [r4, #GPIO_GDIR]
    
    
SET_PILHAS:    

    @inicializando pilhas para os 3 modos a serem usados
    ldr sp, =PILHA_SUPERVISOR        @inicializa pilha modo supervisor
    
    mrs r0, cpsr
    orr r0, r0, #0x0000001F          @muda para modo system (nao precisa de bitclear por ser 11111)
    msr cpsr_c, r0
    
    ldr sp, =PILHA_USUARIO           @inicializa pilha modo system, pilha do usuário
    
    mrs r0, cpsr
    bic r0, r0, #0x0000001F          @bit clear nos bits de modo
    orr r0, r0, #0x00000012          @muda para modo IRQ (interrupçoes de hardware)
    msr cpsr_c, r0
    
    ldr sp, =PILHA_INTERRUPCAO       @inicializa pilha modo IRQ
    
    msr  cpsr_c, #0x10               @entra em modo usuario
    
    @@FALAT TRANSFERIR EXECUÇÃO PARA APLICAÇÃO DE CONTROLE@@
    
@tratamento de interrupções por hardware
@a cada TIME_SZ o gpt gera uma interrupção
@incrementa o tempo e checa callbakcs e alarmes
IRQ_HANDLER:
   
    stmfd sp!,{r0-r10, lr}

    mov r0, #1
    ldr r2, =0x53FA0008
    str r0, [r2]            @reseta gpt_sr

    @incrementa o tempo do sistema
    ldr r3, =SYS_TIME       @coloca o endereco de SYS_TIME em r3
    ldr r1, [r3]            @coloca o valor de SYS_TIME em r1
    add r1, r1, #1          @incrementa 1
    str r1, [r3]            @armazena o numero de interrupcoes
    
    @checa se ja esta ocorrendo uma interrupção
    ldr r0, =CHECANDO_CALLBACK
    ldr r1, [r0]
    cpm r1, #1
    beq fim_irq
    
    ldr r0, =CHECANDO_ALARME
    ldr r1, [r0]
    cpm r1, #1
    beq fim_irq
    
    
    @checando se algum sensor entrou no limiar da calback
    
    ldr r4, =N_CALLBACKS
    ldr r4, [r4]                  @numero de callbacks ativas
    ldr r5, =VETOR_CALLBACKS      @começo do vetor de callbacks
    mul r6, r4, #7                @quantidade de memoria ocupada pelas callback ativas
    add r10, r5, r6               @ultima posição da ultima callback adicionada
    
    @indicando que esta checando as callbacks
    ldr r8, =CHECANDO_CALLBACK
    mov r9, #1        
    ldr r9, [r8]        
    
start_callback: 
    
    @começo do loop de chacagem de callbacks   
    @condição para o fim da checagem de callbacks
    cmp r5, r10                    
    beq fim_callback
    
    @checando se algum sensor passou do limiar de distancia
    ldrb r0, [r5]                 @identificador do sonar (1 byte)
    bl read_sonar                    
    ldrh r1, [r5, #1]             @limiar de distancia (2 bytes)
    cpm r1, r0
    bhi cont_callback             @caso onde limiar nao foi ultrapassado
    
    @caso onde é necessario chamar a funçao da callback
    
    ldr r2, [r5, #3]              @endereço da função a ser chamada (4 bytes)
    
    @muda para modo usuario antes de chamar a função
    
    mrs r0, cpsr
    bic r0, r0, #0x1F             @bitclear nos bits de modo
    orr r0, r0, #0x10     
    msr cpsr_c, r0                @entra em modo usuario
    
    blx r2                        @chama função 
    
    @muda para modo supervisor 
    mov r7, #23
    svc 0x0

retorno_callback:
    
    @coloca em modo interrução
    mrs r0, cpsr
    bic r0, r0, #0x1F             @bitclear nos bits de modo
    orr r0, r0, #0x12             @entra em modo de IRQ
    msr cpsr_c, r0
    
    
    
cont_callback: 

    add r5, r5, #7                @pula para proxima callback a ser checada
    b start_callback

fim_callback:
    
    mov r9, #0        
    ldr r9, [r8]                  @indicando que acabou a checagem das callbacks
    
    
    @começa a checar os alarmes
    
    ldr r4, =VETOR_ALARMES        @carrega começo
    ldr r5, =FIM_VETOR_ALARMES    @e fim do vetor de alarmes
    
    ldr r8, =CHECANDO_ALARME      @indicando que ja esta ocorrendo uma checagem de alarmes
    mov r9, #1        
    ldr r9, [r8]   

start_alarme: 
    @condição para o fim da checagem de alarmes
    
    cpm r4, r5
    beq fim_alarme 
    
    @confere se o alarme atual esta ativo
    ldrb r0, [r4]        
    cpm r0, #1
    bne cont_alarme
    
    @checa se o alarme deve tocar
    
    ldr r1, [r4, #5]        @pega tempo do alarme 
    bl get_time             @pega tempo atual do sistema
    cmp r1, r0
    bhi cont_alarme         @caso onde nao deve tocar
    
    @caso onde o alarme deve tocar
    
    mov r0, #0
    str r0, [r4]            @seta o alarme como inativo
    
    @entra em modo usuario para chamar a função 
    
    ldr r2, [r4, #1]        @pega endereço da função a ser chamada
    
    mrs r0, cpsr
    bic r0, r0, #0x1F       @bitclear nos bits de modo
    orr r0, r0, #0x10     
    msr cpsr_c, r0          @entra em modo usuario
    
    blx r2                  @chama a função
    
    @voltando para o modo supervisor
    mov r7, #23        
    svc 0x0

retorno_alarme:
   
    @volta para modo IRQ
    mrs r0, cpsr
    bic r0, r0, #0x1F       @bit clear nos bits de modo
    orr r0, r0, #0x12       @entra em modo IRQ
    msr cpsr_c, r0
     
    

@continua checagem de alarmes
cont_alarme: 

    add r4, r4, #9
    b start_alarme
    
fim_alarme:
    
    mov r9, #0              @indicando que acabou a checagem de alarmes       
    ldr r9, [r8] 
    
fim_irq:
   
    @retorna ao fluxo de execucao
    ldmfd sp!,{r0-r10, lr}
    sub lr, lr, #4
    movs pc, lr
    
@tratamento de interrupções de software
SUPERVISOR_HANDLER:
    
    @@@@@ TEM QUE PEGAR OS PARAMETROS DAS SYSCALL DA PILHA AQUI? @@@@           
    @@@@@ ANTES DE USAR O COMAND SVC 0 EMPILHA R2, R1 E R0 (stmfd sp!,{r0, r1, r2}) E AQUI DESEMPILHA?? @@@@
    stmfd sp!,{r4, r7, lr}
    @entra em modo system para desempilhar parametros da pilha do usuario
    mrs r4, cpsr
    bic r4, r4, #0x1F       @bit clear nos bits de modo
    orr r4, r4, #0x1F       @entra em modo system
    msr cpsr_c, r4
     
    
    ldmfd sp!,{r0, r1, r2}       @desempilhando parametros para a syscall
    
    @volta para modo supervisor
    mrs r4, cpsr
    bic r4, r4, #0x1F       @bit clear nos bits de modo
    orr r4, r4, #0x13       @entra em modo supervisor
    msr cpsr_c, r4
       
    @pula para a rotina correta de cada syscall
    
    cmp r7, #16
    bleq read_sonar
    
    cmp r7, #17
    bleq register_proximity_callback
    
    cmp r7, #18
    bleq set_motor_speed
    
    cmp r7, #19
    bleq set_motors_speed
    
    cmp r7, #20
    bleq get_time    
    
    cmp r7, #21
    bleq set_time
    
    cmp r7, #22
    bleq set_alarm
    
    cmp r7, #23
    bleq modo_supervisor
    
    ldmfd sp!,{r7-r10, lr}
    movs pc, lr
    
    
    
@le distancia de um soanr 
@parametro r0: identificador do sonar
@retorno r0: -1 identificador invalido;
@valor obtido se leitura funcionou     
read_sonar:

    stmfd sp!,{r4-r6,r8-r9, lr}
    
    @caso de identificador do sonar invalido 
    mov r4, #16
    cpm r0, r4
    
    movge r0, #-1
    ldmgefd sp!,{r4-r6,r8-r9, pc}
    
    
    ldr r4, =GPIO_BASE
    ldr r5, [r4, #GPIO_DR]
    ldr r6, =0x0000003C
    ldr r8, =0xFFFFFFFD        
    bic r5, r5, r6            @bitclear nos bits de sonar_mux[0-3] 
    r0, lsl #2                @arruma posição dos bits do identificador
    orr r5, r5, r0            @coloca os bits do identificador em sonar_mux[0-3] e mantem os outros
    and r5, r5, r8            @coloca 0 no trigger e mantem os outros
    str r5, [r4, #GPIO_DR]    
    
    ldr r9, =DELAY_1
    
@delay depois de colocar 0 no trigger   
DELAY1: 
    sub r9, r9, #1
    cmp r9, #0
    bne DELAY1
    
    
    ldr r5, [r4, #GPIO_DR]
    ldr r6, =0x00000002 
    orr r5, r5, r6            @coloca 1 no trigger e mantem os outros
    str r5, [r4, #GPIO_DR]
    
    ldr r9, =DELAY_1 
    
@delay depois de colocar 1 no trigger   
DELAY2: 
    sub r9, r9, #1
    cmp r9, #0
    bne DELAY2   
    
    @zera trigger novamente e mantem os outros
    ldr r5, [r4, #GPIO_DR]
    ldr r6, =0xFFFFFFFD 
    and r5, r5, r6          
    str r5, [r4, #GPIO_DR]

FLAG_TEST:
    
    ldr r5, [r4, #GPIO_DR]
    mov r6, #1
    and r5, r5, r6
    cmp r5, #1
    beq READ
    
    ldr r9, =DELAY_2
    
DELAY_FLAG:
    
    @delay para esperar flag ir para 1
    sub r9, r9, #1
    cmp r9, #0
    bne DELAY_FLAG
    beq FLAG_TEST
    
READ: 
    
    @le o valor nos bits SONAR_DATA[0-11]
    ldr r5, [r4, #GPIO_DR]
    ldr r6, =0x0003FFC0
    and r5, r5, r6
    r5, lsr #6            @coloca os bits na posição correta para se tornar o valor da distancia
    
    @coloca o valor lido em r0 e retorna da rotina
    mov r0, r5
    
    ldmfd sp!,{r4-r6,r8-r9, pc}   

@registra um novo CALLBACK
@p0: sonar
@p1: distancia
@p2: endereco da funcao a ser chamada
@retorna 0 se der certo, -1 se ja temos o max de callbacks
@e retorna -2 se receber um sonar invalido
register_proximity_callback:
    stmfd sp!,{r4,r5,r6,lr}

    @caso o indentificador do sonar seja invalido retorna -2
    cmp     r0, #16                @verifica se o sonar passado eh maior ou igual 16
    movge   r0, #-2                @se for, coloca -2 para indicar erro
    ldmgefd sp!,{r4,r5,r6,pc}      @retorna a funcao com erro, se for o caso

    @verifica se temos espaco para outro callback
    ldr r4, =MAX_CALLBACKS    @carrega o numero maximo de callbacks que podemos ter (constante)
    ldr r5, =N_CALLBACKS      @carrega quantos callbacks temos atualmente (variavel)
    ldr r6, [r5]              @numero de callbacks ativas
    cmp r6, r4
    moveq r0, #-1             @se estamos no limite, retornamos com erro
    ldmeqfd sp!,{r4,r5,r6,pc} @retorna com mensagem de erro -1
    
    @se esta tudo certo, vamos registrar a nova callback
    @primeiro vamos procurar a proxima posicao livre do vetor de callbacks
    @[1 byte/sonar - 2 bytes/distancia - 4 bytes/endereco_da_funcao_a_ser_chamada]
    
    ldr r4, =N_CALLBACKS     @coloca em r4 o numero de callbacks
    ldr r4, [r4]             @carrega o numero de callbacks ativa no momento
    mov r5, #7               @r5 <-  7
    mul r3, r4, r5           @faz (n_callbacks * 7) para chegamos na posicao de escrever a nova
    ldr r6, =VETOR_CALLBACKS @carrega o endereco do vetor de callbacks
    add r6, r6, r3           @vai para a posicao onde iremos adicionar o novo callback
    
    @incrementa o numero de callbacks ativos
    ldr r5, =N_CALLBACKS     @carrega o endereco da variavel contadora
    add r4, r4, #1           @incrementa o valor
    str r4, [r1]             @coloca o novo valor na variavel apropriada
    
    @agora que estamos na posicao correta   
    @vamos escrever a callback no vetor        
    strb r0, [r6, #0]   @coloca o numero do sonar no primeiro byte
    strh r1, [r6, #1]   @coloca nos proximos 2 bytes a distancia
    str r2, [r6, #3]    @coloca, depois de 3 bytes, 4 bytes com o endereco da funcao
    
    @como deu tudo certo, vamos retornar com 0 em r0
    mov r0, #0
    ldmfd sp!,{r4,r5,r6,pc}

@muda a velocidade de um dos motores
@parametros r0: identificador do motor
@r1: nova velocidade do motor 
@retornos r0: -1 identificador invalido;
@-2 velocidade invalida; 0 OK
set_motor_speed:

    stmfd sp!,{r4-r6, r8, lr}
    
    @checa se velocidade requerida é valida
    cmp r1, #63
    movhs r0, #-2                @caso invalida retorna -2 em r0
    ldmhsfd sp!,{r4-r6, r8, pc}
    
    @checa se identificador é valido
    cmp     r0, #2
    movhs   r0, #-1
    ldmhsfd sp!,{r4-r6, r8, pc}  @caso invalido retorna -1 em r0
    
    
    @muda velocidade do motor requerido
    ldr r4, =GPIO_BASE
    ldr r5, [r4, #GPIO_DR]    @carrega estado atual do data register
    
    cmp r0, #1                @determinando qual motor sera mudado
    beq motor1
    r0, lsl #19               @muda posição dos bits para o caso do motor0 
    orr r5, r5, #0x02000000   @coloca 1 no bit para motor0_write
    str r5, [r4, #GPIO_DR]    
    ldr r6, =0x01F80000
    bic r5, r5, r6            @bitclear nas posiçoes que irao receber os bits da velocidade
    orr r5, r5, r0            @coloca os bits da nova velocidade nas posições corretas
    b fim

motor1:
    
    r0, lsl #26
    orr r5, r5, #0x00040000   @colcoa 1 no bit para motor1_write
    str r5, [r4, #GPIO_DR]    
    ldr r6, =0xFC000000
    bic r5, r5, r6            @bitclear nas posiçoes que irao receber os bits da velocidade
    orr r5, r5, r0            @coloca os bits da nova velocidade nas posições corretas
    
fim:
    
    str r5, [r4, #GPIO_DR]  
    
    ldr r6, =0xFDFBFFFF     @0 nos bits de motor0_write e motor1_write
    and r5, r5, r6          @zera os bits de motor0_write e motor1_write e mantem os outros
    str r5, [r4, #GPIO_DR]
    
    @coloca 0 em r0 se tudo deu certo e retorna da rotina
    mov r0, #0
    
    ldmfd sp!,{r4-r6, pc}
     

@muda a velocidade dos dois motores
@parametros r0: velocidade motor 0 r1: velocidade motor 1
@retorno r0: -1 velocidade motor 0 invalida; -2 velocidade
@motor 1 invalida; 0 OK
set_motors_speed:

    stmfd sp!,{r4-r6, r8, lr}
    
    
    @checa se velocidades são validas
    cmp r0, #63
    movhs r0, #-2                @caso invalida retorna -2 em r0
    ldmhsfd sp!,{r4-r6, r8, pc}
    
    cmp r1, #63
    movhs r0, #-2                @caso invalida retorna -2 em r0
    ldmhsfd sp!,{r4-r6, r8, pc}
    
    ldr r4, =GPIO_BASE           @carrega endereço base do GPIO
    
    @prepara para a escrita 
    ldr r5, [r4, #GPIO_DR]       @carrega estado atual do data register
    orr r5, r5, #0x02040000      @coloca 1 nos bits de motor0_write e motor1_write
    str r5, [r4, #GPIO_DR]
    
    r0, lsl #19                  @coloca os bits das velocidades na posicao 
    r1, lsl #26                  @correta para armazenar em DR
    
    mov r6, #0
    orr r6, r6, r0         
    orr r6, r6, r1               @registrador com as duas velocidades nas respectivas posiçoes
    
    ldr r5, [r4, #GPIO_DR]  
    ldr r8, =0xFDF80000          @1 nos bits das velocidades(MotorX_speed[0-5])
    bic r5, r5, r8               @bitclear nas posições de DR que vao receber os bits da velocidade
    orr r5, r5, r6               @coloca os bits das novas velocidades em r5    
    str r5, [r4, #GPIO_DR]       @atualiza DR com as novas velocidades
    
    ldr r5, [r4, #GPIO_DR]
    ldr r6, =0xFDFBFFFF          @0 nos bits de motor0_write e motor1_write
    and r5, r5, r6               @zera os bits de motor0_write e motor1_write e mantem os outros
    str r5, [r4, #GPIO_DR]
    
    @se tudo deu certo coloca 0 em r0 e retorna da rotina
    mov r0, #0
    
    ldmfd sp!,{r4-r6, r8, pc}
    
@retorna tempo atual do sistema
@retorno: r0 = tempo do sistema
get_time:
    
    stmfd sp!,{r4,lr}  
    
    ldr r4, =SYS_TIME
    ldr r0, [r4]
    
    ldmfd sp!,{r4,pc}


@altera o tempo do sistema
@r0 = tempo a ser setado
set_time:
    stmfd sp!,{lr}     

    ldr r1, =SYS_TIME     @variavel do tempo do sistema
    stre r0, [r1]         @coloca o tempo desejado na variavel

    ldmfd sp!,{pc}

@registra um novo alarme
@r0 = funcao a ser chamada
@r1 = tempo do alarme
@retorno r0 = 0 - tudo ok, -1 vetor de alarmes cheio, -2 alarme do passado
set_alarm:
    stmfd sp!,{r6,r7,lr}     
    
    @verifica se nao esta tentando colocar um alarme no passado
    mov r6, r0                @salva o enderedo da funcao a ser chamada em r6
    mov r7, r1                @coloca o tempo do alarme em r7
    bl  get_time              @verifica qual o tempo atual
    cmp r7, r0                @se o alarme foi definido para o passado, retorna com -2
    movlo r0, #-2             @soh passa o -2 pra r0 se o alarme for do passado
    ldmlofd sp!,{r6,r7,pc}    @POP CONDICIONAL p/ menor
    
    @se o alarme nao eh pro passado, verifica se ha espaco pra outro alarme
    ldr r0, =MAX_ALARMS         @coloca em r0 o numero maximo de alarmes
    ldr r2, #=_ALARMES          @coloca em r2 o numero de alarmes
    ldr r1, [r2]                @carrega em r1 o numero de alarmes ativos
    cmp r1,r0                   @compara o numero de alarmes ativos com o maximo permitido
    moveq r0, #-1               @se atingimos o maximo, coloca -1 no retorno da funcao 
    ldmeqfd sp!,{r6,r7,pc}      @se atingimos o maximo, retorna a funcao
    
    @se podemos adicionar o alarme, faremos isso! :)
    @incrementa o contador de alarmes    
    ldr r2, =N_ALARMES    @aumenta em 1 na variavel de alarmes ativos
    ldr r1, [r2]          @carrega o valor atual
    add r1, r1, #1        @incrementa 1
    str r1, [r2]          @salva
    
    @@REALMENTE ADICIONAUM ALARME
    @@ONDE ESTA O VETOR DE ALARME?
    @@COMO QUE FAZ?
    @@ONDE COLOCA
    
    @colocao alarme de fato
    ldr r0, =VETOR_ALARMES
    
    @encontra a proxima posicao livre no vetor de alarmes
    procura:
        @FUNCIONAMENTO DO ALARME:
        @[ATIVO? 1BYTE] [ENDERECO DA FUNCAO PRA SE CHAMAR? 4 BYTES] [TEMPO QUE O ALARME DEVE DISPARAR? 4 BYTES] (total = 9)
    
    
        @ATUALIZACAO, A PRIMEIRA PARTE (1) INDICA SE O ALARME TA ATIVO
        ldrb r1, [r0]     @posicao que diz se ta ativo ou nao 
        cmp r1, #0        @verifica se encontramos uma posicao vazia
        beq fim_da_busca  @se ja encontramos uma posicao, paramos de procurar
        add r0, r0, #9    @vamos pra proxima posicao do vetor procurar 
        b procura
    fim_da_busca:
    
    @coloca o alarme na posicao encontrada
    mov r1, #1
    strb r1, [r0]       @salva que o alarme esta ativo 
    str r6,[r0, #1]    @salva a funcao a ser chamada no vetor
    str r7,[r0, #5]    @salva o tempo de disparar alarme
    
    @ate apaguei seu chilique pq nao temos tempo pra isso
    
    @colocamos 0 em r0 pra dizer que deu tudo certo
    mov r0, #0
    
    @retornamos da funcao
    ldmfd sp!,{r6,r7,pc}
    
modo_supervisor:

    
    @caso de estar voltando para supervisor na checagem de callbacks
    ldr r1, =CHECANDO_CALLBACK
    ldr r0, [r1]
    cpm r0, #1
    beq retorno_callback
    
    @caso de estar voltando para supervisor na checagem de alarmes
    ldr r1, =CHECANDO_ALARME
    ldr r0, [r1]
    cpm r0, #1
    beq retorno_alarme
    
    @retorno padrao
    movs pc, lr
    

.data
SYS_TIME: .word 0             @contador de tempo de sistema

N_ALARMES: .word 0            @contador do numero de alarmes

VETOR_ALARMES:   .skip MAX_ALARMS * 9 @aloca espaço para o numero maximo de alarmes  

N_CALLBACKS: .word 0          @contador do numero de callbacks

VETOR_CALLBACKS:    .skip MAX_CALLBACKS * 7
@[1 byte/sonar - 2 bytes/distancia - 4 bytes/endereco_da_funcao_a_ser_chamada]
@nao reservvvamos um bit para saber se esta ativo ou nao, pq uma vez ativvo
@fica ativo ate o final do programa
@assim como sabe qauqleur pessoa que leu com atencao o enunciado 

PILHA_SUPERVISOR: .skip 50    @aloca espaço para a pilha do modo supervisor

PILHA_USUARIO: .skip 50       @aloca espaço para a pilha do modo usuario

PILHA_INTERRUPCAO: .skip 50   @aloca espaço para a pilha durante interrupção

CHECANDO_ALARME: .word 0

CHECANDO_CALLBACK: .word 0

@os cara guarda as palavra né