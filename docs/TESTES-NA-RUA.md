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
5. **Corrigir depois da análise (0.5.0):** nos pontos com "Ver correção", toque e confira o antes e o depois semana a semana. "Aplicar" muda o plano; "Voltar ao anterior" desfaz. Teste também à mão: dentro de uma semana, "Aliviar semana" e "Reduzir 10%"; toque e segure um dia para "Trocar por equivalente" ou "Mover para". Uma correção que quebraria as travas aparece recusada, com o motivo.

O que me contar: algum plano que pareça sem sentido para você como corredor (volume, longão, ordem dos treinos), mesmo com as travas conferidas.

## Fase 5: treino por blocos, voz e aquecimento guiado (0.5.0)

### Em casa (10 minutos, com a simulação)

1. **Construtor:** aba Treinos > Novo treino. No texto rápido, escreva `10min fácil + 6x(400m forte / 90s trote) + 10min fácil`: a linha do tempo aparece na hora, com "×6" em cima da repetição e os totais estimados. Teste variações (`10' leve`, `6 x 400 m tiro / 1:30 trote`, `1,5km limiar`) e um erro de propósito (`400 forte`): a mensagem diz o que corrigir. Toque num trecho da linha do tempo para editar; segure e arraste um bloco (ou use "Editar") para mudar a ordem; use os atalhos de "Adicionar". Salve.
2. **Biblioteca:** o treino aparece em "Meus treinos". No menu "…" do treino: Duplicar, Salvar como modelo, Editar, Apagar. Em "Prontos", abra "6 × 400 m": os alvos aparecem nos seus ritmos (ou por esforço, sem prova em Meus ritmos).
3. **Execução simulada:** ligue Ajustes > Modo de desenvolvimento > Simular GPS a **10x**. Abra "6 × 400 m" > Começar. Confira: barra segmentada no topo, a etapa atual com o restante em número grande, "Repetição 2 de 6", o medidor de ritmo com a faixa verde, a lista "A seguir" e as feitas com ✓. Nos últimos 3 segundos de cada etapa: número grande na tela, bipe e voz "3, 2, 1".
4. **Aquecimento:** desde a 0.10.0 os exercícios não entram mais no treino; aparecem como sugestão antes de começar (veja a fase 10).
5. **Controles:** "Volta" fala o tempo da volta; "Pular" pede confirmação (nos exercícios, não); pausar e retomar; deslize para finalizar. No resumo: "Por bloco: planejado x feito" com o ritmo de cada tiro e o ✓ quando ficou na faixa.
6. **Voz com música:** toque uma música no iPhone e use Ajustes > Testar a voz: a música abaixa enquanto a voz fala e volta depois. Desligue a simulação antes de sair.

### Na rua (um treino com tiros, 30 a 45 minutos)

1. Escolha "6 × 400 m" ou "5 × 1.000 m" e toque em Começar. Com música, se quiser.
2. **Bloqueie a tela** logo no começo e faça o treino com o celular no bolso: as trocas de etapa têm que vir pela voz e pela vibração, a contagem 3, 2, 1 também.
3. Num tiro, corra devagar de propósito por meio minuto: deve vir "Acelere um pouco" (depois de uns 15 s fora da faixa). No trote fácil, correr devagar não gera aviso.
4. Na recuperação, fique parado uns segundos: o relógio da recuperação continua correndo mesmo com a pausa automática.
5. No fim, confira o planejado x feito por bloco e salve. Abra no Histórico: a tabela por bloco tem que estar lá.

### Esteira e teste de ritmo

- **Esteira:** Hoje > "Na esteira" (ou um treino com "Na esteira" ligado). Sem GPS, os trechos por distância viram tempo. No fim, digite a distância do painel da esteira.
- **Teste de referência:** Treinos > Prontos > "Teste de 3 km" (ou 5 km), num percurso plano e descansado. No resumo, "Usar como prova de referência" atualiza Meus ritmos.

### O que me contar

- Se a voz falou com a tela bloqueada e se a música voltou ao volume depois.
- **Se a vibração veio com a tela bloqueada** (o iOS pode não vibrar com o app em segundo plano; se não vibrar, eu troco por outro aviso).
- Se o aviso de ritmo veio no momento certo ou incomodou (dá para desligar em Ajustes > Avisos durante a corrida).
- Se algum trecho do texto rápido que você tentou não foi entendido.

## Fase 6: Live Activity e Dynamic Island (0.6.0)

1. Confira em Ajustes do iPhone > CRUNNING que "Atividades ao Vivo" está ligado.
2. Comece um treino (pode ser com a simulação a 10x em casa) e **bloqueie a tela**: o cartão do CRUNNING aparece com o bloco atual na cor dele, o cronômetro do bloco correndo sozinho (ou os metros que faltam), distância, ritmo e a barra do treino.
3. Desbloqueie e vá para outro app: na **Dynamic Island** aparece o ícone e o que falta; toque e segure para ver a versão expandida.
4. Pause: o cartão mostra "Pausado" com o tempo parado. Retome e veja voltar a correr.
5. Finalize ou descarte: o cartão some.
6. Corrida livre: o cartão mostra o tempo em movimento, a distância e o ritmo.

O que me contar: se o cartão aparece com o app instalado pelo Sideloadly, se atualiza na troca de bloco com a tela bloqueada e se algum texto fica cortado na Dynamic Island.

## Fase 7: Apple Saúde pelo plano B (0.7.0)

1. Ajustes > Apple Saúde: o modo aparece como "Histórico local + TCX/GPX". Informe o peso (opcional; serve só para a energia).
2. Histórico > abra uma corrida > menu … > "Exportar TCX (para o Saúde)". Salve em Arquivos ou abra direto num app que importa TCX. Uma corrida na esteira também exporta (sem rota, com distância e tempo).
3. No detalhe da corrida aparece "Energia (estimada)" quando há peso.
4. No fim do Histórico, "Preparar exportação de todas (TCX)" e depois "Exportar N arquivos TCX".
5. Se você usar um app que importa TCX e grava no Saúde (o HealthFit, por exemplo, que é pago), importe um arquivo e confira no app Saúde: treino de corrida com distância, duração e rota.

O que me contar: se algum app recusou o arquivo (e qual), e se a energia ficou parecida com a que você costuma ver.

## Fase 8: plano no calendário (0.8.0)

1. Plano > Prévia: gere um plano e toque em "Usar este plano". Na primeira vez aparecem as perguntas de segurança (e o link do PAR-Q+). Escolha a data de início.
2. Aba Plano: a semana com os dias e as datas, setas para outras semanas. Toque e segure um dia: correr, marcar feito ou perdido, trocar por equivalente, mover. "Opções do plano": PDF, nova data da prova, montar outro, encerrar.
3. Aba Hoje: o treino do dia com "Começar treino". Faça o treino (pode ser simulado): no fim, escolha o tênis e o esforço e salve; o dia aparece com ✓ no Plano e "Feito" no Hoje.
4. Deixe passar um dia de treino sem fazer: o Hoje mostra "Ficou para trás". Teste "Fiquei parado" com 10 dias: aparece a proposta de volta aos poucos com antes e depois.
5. Ajustes > Tênis: cadastre um par. Histórico: "Recordes pessoais" no topo.

O que me contar: se o treino do dia bate com o calendário, se o check-in faz sentido, e se o PDF abre bem.

## Fase 9: Coach de IA completo e Calendário (0.9.0)

Para testar sem gastar: Ajustes > Modo de desenvolvimento > "Simular o coach". Depois desligue para usar o de verdade (com a sua chave).

1. **Plano com o coach:** aba Plano (sem plano em uso) > "Montar o plano com o coach". Responda com os cartões numerados e toque em "Montar com o coach". Aparecem a explicação e as semanas; "Usar este plano" põe no calendário.
2. **Chat:** aba Plano > "Conversar com o coach". Escreva "viajo semana que vem" ou "estou com a canela dolorida". Vem a resposta e uma proposta com o antes e o depois: Salvar, Ajustar (escreva mais) ou Recusar. Depois de salvar, "Voltar ao anterior" desfaz.
3. **Revisão:** "Revisar a semana" (e o cartão no Hoje no domingo à noite e na segunda). As correções vêm com "Ver correção".
4. **Calendário:** Plano > Opções do plano > "Sincronizar com o Calendário". Na primeira vez o iPhone pede o acesso: escolha **acesso total** (o app só mexe no calendário "CRUNNING"). Abra o app Calendário: os treinos aparecem como eventos de dia inteiro. Mude o plano (mova um treino) e confira que o calendário acompanhou. Encerrar o plano ou parar de sincronizar apaga os eventos.

O que me contar: se as respostas do coach fizeram sentido, quanto custou na sua conta (painel da Anthropic) e se o calendário ficou certo.

## Pendências fechadas (0.9.5)

1. **Calor:** abra um treino em Treinos, ligue "Ajustar ritmos pelo calor" e informe temperatura e umidade. Confira o WBGT e o texto; no treino, as faixas de ritmo ficam um pouco mais lentas.
2. **Prova secundária:** Plano > Opções do plano > "Adicionar prova secundária". Escolha semana, dia e distância: vem a proposta com antes e depois (ou a recusa explicada, por exemplo no polimento).
3. **Avaliar o coach:** Ajustes > Modo de desenvolvimento > "Avaliar o coach (4 casos)". Com a chave, custa centavos; com "Simular o coach", roda de graça.


## Avisos na corrida e corrida minimizada (0.9.6)

1. **Bipe:** Ajustes > Avisos durante a corrida > desligue "Bipe na troca de etapa". Num treino com blocos (pode ser na simulação), a troca de etapa só fala e vibra; a contagem 3, 2, 1 continua na tela e na voz.
2. **Engrenagem na corrida:** com o treino rodando, toque na engrenagem no canto de cima. Desligue a voz ou o bipe e feche: vale na hora, sem pausar, e fica salvo para as próximas corridas.
3. **Minimizar:** toque na seta para baixo no canto de cima. A corrida vira uma barra acima das abas, com a etapa, o que falta e o botão de pausa. Navegue pelo app (Plano, Histórico, Ajustes) e veja se a voz e a Live Activity seguem normais. Toque na barra para voltar.
4. **Começar outro treino com um minimizado:** a tela da corrida que já está aberta volta; nada novo começa.

## Frequência cardíaca da Mi Band e Strava (0.9.7)

### Mi Band 6 (em casa, 5 minutos)

1. No app oficial da pulseira, ligue a opção de transmitir a frequência cardíaca para outros aparelhos.
2. Ajustes > Conexões > Frequência cardíaca. Aceite o Bluetooth, espere a pulseira aparecer em "Por perto" e toque nela.
3. Se aparecer "sem batimento", comece um treino na própria pulseira e veja se o número aparece. Com o Modo de desenvolvimento ligado, a lista mostra os bytes do anúncio: me mande uma captura se o batimento não bater com o da pulseira.
4. Na corrida (pode ser simulada), com a tela acesa, o batimento e a FC média aparecem nas métricas; no fim, o resumo mostra média e máxima. Bloqueie a tela por um minuto: o batimento para e volta quando você abre o app (limite do iOS).

### Strava

1. No computador, abra strava.com/settings/api e crie um app: nome CRUNNING, site qualquer endereço, Authorization Callback Domain `localhost`.
2. No iPhone: Ajustes > Conexões > Strava. Cole o Client ID e o Client Secret, salve e toque em Conectar. Autorize com a sua conta (deixe marcada a permissão de enviar atividades).
3. Salve uma corrida de verdade (curta serve): ela vai sozinha para o Strava. No detalhe da corrida, o cartão "Strava" mostra "Ver no Strava" ou o erro com "Tentar de novo".
4. Corridas antigas: abra no Histórico e toque em "Enviar ao Strava". Se ela já estiver lá (enviada antes pelo arquivo), o app liga à atividade existente.
5. Confira no Strava: distância, tempo, rota e batimentos (se a pulseira estava ligada). Esteira chega como treino indoor.

## Fase 10: ajustes do uso (0.10.0)

1. **Calendário:** em Plano > Opções do plano, deixe a sincronização ligada e abra o app Calendário. Cada treino aparece só no dia dele (antes aparecia também no dia seguinte). Os eventos antigos são refeitos sozinhos na primeira abertura.
2. **Dias do plano pelo coach:** monte um plano com o coach marcando, por exemplo, quarta, sexta e domingo. O plano só usa esses dias (pode usar menos, nunca outros). Se o seu plano atual tem treino em dias que você não marcou, monte de novo ou peça no chat do coach.
3. **Aba Plano com plano ativo:** embaixo do plano continuam "Montar o plano com o coach", "Prévia do motor" e as cores dos treinos.
4. **Strava sozinho:** com a conexão feita, salve uma corrida sem internet (modo avião). O detalhe dela mostra "Na fila". Tire o modo avião com o app aberto, ou feche e abra o app: ela vai sozinha.
5. **Tênis principal:** Ajustes > Tênis > ligue "Tênis principal" num deles. As corridas novas já vêm com ele; no resumo dá para trocar só naquela corrida, e depois no detalhe (menu … > Tênis desta corrida).
6. **Aquecimento como sugestão:** abra um treino forte (6 × 400 m). Antes de começar aparece "Antes de começar" com os exercícios e o como fazer; o tempo do treino só conta depois de deslizar.
7. **Revisão semanal:** no domingo à noite ou na segunda, com a semana cumprida, o Hoje mostra só "Semana dentro do plano". Com treino perdido, corrida fora do plano, esforço alto nas fáceis ou ritmo fora da faixa, aparece "Vale revisar a semana" com os motivos.
8. **Lista de treinos:** cartões mais baixos, barras em cápsulas com legenda de tempo por tipo, tempos sem segundos ("≈ 7,1 km · 49 min") e o título "Prontos" não passa mais por cima do relógio.

## Detalhe dos treinos e zonas de batimento (0.10.1)

1. **Zonas:** Ajustes > Meus ritmos > Frequência cardíaca. Informe a idade (e a FC máxima, se souber). Aparecem as zonas Z1 a Z5 em bpm.
2. **Detalhe no plano:** na aba Plano, toque num dia com treino. Abre o detalhe com cada trecho: a medida (tempo ou distância), "pace entre X e Y" e, embaixo, a outra medida estimada e, nos trechos contínuos de 3 min ou mais, a zona ("≈ 1,6 km · tente ficar na Z2"). Tiros curtos e recuperação vão só pelo pace. O botão Começar conta para aquela sessão do plano. O toque longo continua abrindo o menu do dia.
3. **Hoje:** no cartão do treino de hoje, "Ver os trechos" abre o mesmo detalhe.
4. **Na corrida:** aparece "Pace entre X e Y" e, nos trechos longos, "Tente ficar na Z2 (123–151 bpm)"; com a Mi Band transmitindo, mostra o batimento de agora e o coração fica verde dentro da zona e vermelho acima.
5. **Calendário:** as notas de cada evento listam os trechos com tempo, distância, ritmo e zona (os eventos são refeitos sozinhos na abertura).

