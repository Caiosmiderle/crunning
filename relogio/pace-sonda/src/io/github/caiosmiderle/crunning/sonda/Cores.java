package io.github.caiosmiderle.crunning.sonda;

/** Cores opacas: adaptação de App/Design/Paleta.swift para a tela transflexiva. */
final class Cores {
    static final int PRETO = 0xFF000000;   // Fundo opaco da tela de corrida.
    static final int BRANCO = 0xFFFFFFFF;  // Números/legendas de Metrica, contraste máximo.
    static final int VERDE_LOGO = 0xFF8BE105; // Paleta.verdeLogo / dentroDaFaixa, sem alteração.
    static final int AMARELO = 0xFFFFCC00; // Paleta.foraLeve #FFC53D, mais saturada.
    static final int ALERTA = 0xFFFF3030;  // Paleta.foraForte #FF4D4F, mais saturada.
    static final int SEM_LEITURA = 0xFF707070; // .secondary: só o indicador sem leitura é apagado.

    // TipoTreino.hex, na mesma ordem frio → quente do iPhone; reservadas para os treinos.
    // A sonda é corrida livre: não atribui um tipo nem inventa uma faixa-alvo de ritmo.
    static final int CAMINHADA = 0xFF00CFFF;   // #B7C4D1: cinza azulado → ciano frio.
    static final int RECUPERACAO = 0xFF008FFF; // #8FA3B8: azul acinzentado → azul saturado.
    static final int FACIL = 0xFF0080FF;       // #4DA3FF: azul.
    static final int LONGAO = 0xFF7050FF;      // #7B7CFF: violeta.
    static final int RITMO_PROVA = 0xFF00D9B0; // #2EC4B6: turquesa.
    static final int LIMIAR = AMARELO;        // #FFC53D: amarelo.
    static final int INTERVALADO = 0xFFFF6600; // #FF7A3D: laranja.
    static final int REPETICOES = 0xFFFF0050;  // #FF3D6E: vermelho rosado.
    static final int PROVA = VERDE_LOGO;      // #8BE105: exceção de marca do próprio iPhone.

    private Cores() { }
}
