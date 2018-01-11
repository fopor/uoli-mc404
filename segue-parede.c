#include "api_robot2.h" /*API de controle do robo*/

#define DIST_PAREDE 4000
#define PAREDE_SAFE_DIST 4000    //distancia para seguir em frente
#define PAREDE_MIN_DIST 1400     //distancia minima pra se considerar ao lado
#define TURN_90_TIME 300             //tempo necessario para virar 90 graus
#define TURN_A_LITTLE 100             //tempo necessario para virar o robo apenas um pouco
#define TRUE 1

/*funcao que retorna o tempo atual do sistema*/
unsigned int tempo_atual();

void _star(void){
    /*variavel auxiliar para o tempo*/
    unsigned int temp_aux;

    /*variaveis para os motores*/
    motor_cfg_t motor0, motor1;

    /*define a ID dos motores*/
    motor0.id = 0;
    motor1.id = 1;

    /*da uma velocidade inicial para o robo buscar a parede*/
    motor0.speed = 1;
    motor1.speed = 1;

    /*atualiza a velocidade dos motores*/
    set_motors_speed(&motor0, &motor1);
    
    /*aguarda se aproximar de uma parede*/
    while(read_sonar(3) >= DIST_PAREDE && read_sonar(4) >= DIST_PAREDE ) { }
    
    /*apos encontrar uma parede, rotaciona o robo ate ficar de lado com ela*/
     motor0.speed = 0;                  //para um dos motores para que o robo gire
     set_motor_speed(&motor0);  //atualiza a velocidade do motor0

    /*aguarda a posicao correta*/
    while(read_sonar(0) >= PAREDE_MIN_DIST || read_sonar(3) <= PAREDE_SAFE_DIST){ }

    /*na posicao correta, anda pra frente*/
    motor0.speed = 1;
    set_motor_speed(&motor0);
    
     /*ajusta o robo para contornar a parede*/
    while(TRUE){
        /*enquanto estiver nas condicoes de emparalhamento com a parede, segue reto*/
        while(read_sonar(0) <= PAREDE_MIN_DIST && read_sonar(3) >= PAREDE_SAFE_DIST && read_sonar(0) >= PAREDE_SAFE_DIST)  {}
        
        /*verifica pra qual lado devemos virar o robo em caso de problema*/
        /*se ta mto perto da parede, tenta se afastar*/
        if(read_sonar(0) <= PAREDE_MIN_DIST){
            //TODO VIRA LEVEMENTE PRA DIREITA
            temp_aux = tempo_atual();
            
            /*coloca o robo pra rodar pra direita*/
            motor0.speed = 0;
            motor1.speed = 1;
            set_motors_speed(&motor0, &motor1);
            
            /*aguarda o tempo de virar*/
            while(tempo_atual() <= (tempo_aux + TURN_A_LITTLE)){}
        }
        
        /*se esta muito longe da parede, tenta busca-la*/
        else if(read_sonar(0) >= PAREDE_SAFE_DIST){
            //TODO VIRA LEVEMENTE PRA ESQUERDA
            temp_aux = tempo_atual();
            
            /*coloca o robo pra rodar pra direita*/
            motor0.speed = 1;
            motor1.speed = 0;
            set_motors_speed(&motor0, &motor1);
            
            /*aguarda o tempo de virar*/
            while(tempo_atual() <= (tempo_aux + TURN_A_LITTLE)){}
        }
        
        /*se a parte da frente esta muito proxima da parede, ajusta o curso*/
        else if(read_sonar(3) <= PAREDE_SAFE_DIST){
            //TODO vira 90 graus p/ direita
            temp_aux = tempo_atual();
            
            /*coloca o robo pra rodar pra direita*/
            motor0.speed = 0;
            motor1.speed = 1;
            set_motors_speed(&motor0, &motor1);
            
            /*aguarda o tempo de virar 90 graus*/
            while(tempo_atual() <= (tempo_aux + TURN_90_TIME)){}
        }
        
        /*com as condicoes resolvidas, volta a andar pra frente*/
        motor0.speed = 1;
        motor1.speed = 1;
        set_motors_speed(&motor0, &motor1);
    }
}

/*retorna o tempo atual do sistema*/
unsigned int tempo_atual(){
    unsigned int tempo_aux;
   
    /*coloca no endereco passado o tempo atual do sistema*/
    get_time(&tempo_aux);
    
    return tempo_aux;
}