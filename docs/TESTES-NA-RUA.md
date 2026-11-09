# Testes que só um iPhone de verdade comprova

O CI compila o app e roda os testes do motor, mas não sai para correr. Tudo aqui está **não verificado** até você fazer o roteiro e me contar o resultado (um print ajuda muito).

## Fase 3: corrida livre com GPS

### Antes de sair (em casa, 10 minutos)

1. Instale o build novo por cima (passo 5 do INSTALAR.md). As corridas que você já tem continuam lá.
2. **Histórico:** ligue Ajustes > Modo de desenvolvimento e toque em "Gerar corrida de exemplo". Abra a corrida: deve ter mapa colorido pelo ritmo, parciais por km, gráfico de ritmo e de altitude. No menu "…", "Exportar GPX" abre o compartilhamento (salve em Arquivos para conferir).
3. **Tela bloqueada (simulação):** em Ajustes, ligue "Simular GPS" e escolha **5x**. Na aba Hoje, "Correr agora". Na primeira vez o iPhone pede a localização: escolha **Permitir Durante o Uso** (na simulação o GPS de verdade liga só para o app continuar com a tela bloqueada). Deslize para iniciar, espere uns 20 s e **bloqueie a tela por 1 minuto**. Ao desbloquear, a distância tem que ter andado nesse minuto (a 5x, uns 800 m). No canto da tela aparece o indicador de localização.
4. **App fechado no meio:** com a simulação ainda correndo, abra o seletor de apps (deslize de baixo para cima e segure) e **feche o CRUNNING**. Abra de novo: a tela de corrida volta sozinha com "Corrida recuperada", do ponto em que parou, e segue andando. Pause, deslize para finalizar, dê uma nota de esforço e salve.
5. No Histórico, abra essa corrida e toque em **Sinal do GPS**: deve mostrar pontos "com a tela bloqueada ou o app em segundo plano" e "Vezes que o iOS fechou o app: 1".
6. **Desligue a simulação** antes de sair (Ajustes > Simular GPS).

### Na rua (uma corrida de 20 a 40 minutos)

1. Na aba Hoje, "Correr agora". Se o iPhone pedir a localização, escolha **Permitir Durante o Uso**. É o suficiente: com a corrida rodando, o app continua gravando com a tela bloqueada (aparece o indicador de localização no canto).
2. Espere o selo do GPS ficar verde ("GPS ótimo" ou "GPS bom") e deslize para iniciar.
3. Corra os primeiros minutos olhando a tela: distância subindo, ritmo atual mudando, tempo correndo.
4. **Bloqueie a tela** e corra pelo menos 10 minutos assim, com o celular no bolso. Pode ouvir música.
5. **Pare num semáforo** (ou de propósito) por uns 20 s: o tempo em movimento deve parar ("Pausa automática") e voltar quando você anda.
6. Use o **pause manual** uma vez, ande um pouco, retome.
7. No fim: pause > deslize para finalizar > esforço > salvar.

### O que me contar

- A distância bateu com o que você esperava (ou com outro app/relógio, se tiver)? Diferença de até 2% a 3% é normal de GPS.
- Com a tela bloqueada a gravação **continuou**? (O mapa da corrida tem que ser contínuo, sem "linha reta" cortando caminho.)
- A pausa automática disparou no semáforo? Disparou sem você parar?
- O cartão **Sinal do GPS** da corrida (no Histórico): quantos pontos com a tela bloqueada, maior intervalo sem ponto e se o iOS fechou o app. Um print dele resolve quase tudo.
- O ritmo atual fazia sentido ou pulava muito?
- O mapa, as parciais e os gráficos no Histórico ficaram certos?
- Algum travamento, tela branca ou corrida perdida.

### Se o iOS fechar o app no meio

O app salva a corrida em disco a cada 10 segundos. Se o iOS fechar o app durante a corrida (pouca memória, por exemplo), ele mesmo reabre o app em segundo plano quando chega localização nova, e a gravação continua sem você fazer nada. Se não reabrir, a corrida volta quando você abrir o app: a tela de corrida aparece sozinha, do jeito que estava (correndo ou pausada), e o trecho em que o app ficou fechado vira uma linha reta no mapa. Se ficou fechado por mais de 30 minutos, a corrida volta pausada no último ponto salvo: aí você retoma ou finaliza.

Fechar o app de propósito pelo seletor de apps também cai nesse caso: o iOS não reabre sozinho (você mandou fechar), mas a corrida volta quando você abrir o app.

## Fase 4: motor de treino (em casa, 5 minutos)

1. **Meus ritmos:** Ajustes > Meus ritmos. Escolha a distância e o tempo de uma prova ou teste recente. Aparecem o VDOT, as faixas de ritmo (fácil, maratona, limiar, intervalado, repetições) e os tempos previstos com a comparação de Riegel. Sem prova, a tela mostra as intensidades pelo esforço e pelo teste da fala.
2. **Prévia do motor:** aba Plano > Prévia do motor de treino. Escolha objetivo, semanas, nível, dias, dia do longão, volume atual e maior corrida recente, e toque em Gerar prévia. Confira:
   - "Por que este plano?" explica as fases e as travas;
   - "Travas" mostra "Todas as travas conferidas";
   - em cada semana, nenhum treino de qualidade em dias seguidos ou colado no longão, e a prova no dia do longão da última semana.
3. Teste combinações estranhas (2 dias por semana, volume 0, maratona em 4 semanas, começar a correr). Se faltar tempo para a prova, a prévia diz o mínimo de semanas e oferece "Usar N semanas"; nos outros casos o plano sai, com as travas conferidas e os avisos em "Atenção".
4. **Coach de IA (0.4.1):** em Ajustes > Coach de IA, cole a sua chave da Anthropic e salve (fica só no Keychain). Na prévia, toque em "Analisar com o coach de IA". Cada análise custa poucos centavos de dólar na sua conta.

O que me contar: algum plano que pareça sem sentido para você como corredor (volume, longão, ordem dos treinos), mesmo com as travas conferidas.
