/*camada LoCo
 *  rotina que faz Uóli
 *  seguir o contorno
 *  de uma parede   */
 
 #include "api_robot2.h" /*API de controle do robo*/
 
#define TEMPO_VIRAR_90_GRAUS 300
#define DIST_PAREDE 2000 /*distancia a se manter da parede*/

char flag;

/*variaveis para os motores*/
motor_cfg_t motor0, motor1;

/*retorna o tempo atual do sistema*/
unsigned int tempo_atual(){
    unsigned int tempo_aux; 

    get_time(&tempo_aux);

    return tempo_aux;    
}

/*coloca 1 na flag do tipo char recebida*/
void muda_flag(){
    (flag) = 1;
}

/*gira o robo 90 graus*/
void girar_robo(){
    /*VERIFICAR SE NO CASO DO ALARME DE DISTANCIA 
    TEM QUE SETAR O ALARME DE NOVO DEPOIS QUE
    ELE FOI ATIVADO*/   
    flag = 0;

    motor0.speed = 0;
    motor1.speed = 1;    

    /*atualiza a velocidade dos motores*/
    set_speed_motors(&motor0, &motor1);

    /*dispara um alarme quando termina de girar*/
    add_alarm(muda_flag, (TEMPO_VIRAR_90_GRAUS + tempo_atual()));

    /*aguarda terminar de girar*/
    while(flag == 0){ }

    /*para de girar o robo*/
    motor0.speed = 0;
    motor1.speed = 0;    

    /*atualiza a velocidade dos motores*/
    set_speed_motors(&motor0, &motor1);
}

void _start(void){
    unsigned int tempo;



    /*define a ID dos motores*/
    motor0.id = 0;
    motor1.id = 1;

    /*define a velocidade inicial dos motores*/
    motor0.speed = 0;
    motor1.speed = 0;

    /*atualiza a velocidade dos motores*/
    set_speed_motors(&motor0, &motor1);

    /*adicionar alarme de proximidade*/
    register_proximity_callback(3, DIST_PAREDE, girar_robo);    

    /*faz espirais indefinidamente*/    
    while(1){
        tempo = 0;

        /*faz uma espiral*/
        while(tempo <= 50){
            tempo++;
        
            /*reseta a flag*/
            (flag) = 0;

            /*adiciona um alarme pra saber quando virar*/
            add_alarm(muda_flag, (tempo + tempo_atual()));

            /*anda pra frente ate disparar o alarme*/
            motor0.speed = 1;
            motor1.speed = 1;

            set_speed_motors(&motor0, &motor1);

            while(!flag) { }

            /*vira 90 graus*/
            girar_robo();
        }
    }
}