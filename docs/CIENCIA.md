# Base científica do motor de treino

Cada regra do motor (`CrunningCore`) e de onde ela vem. Revisão de novembro de 2026.

**Níveis de evidência** usados aqui:
- **Forte:** meta-análise ou vários ensaios concordando.
- **Moderada:** um ensaio ou coorte grande, ou modelo empírico muito usado e conferido.
- **Prática de treinadores:** regra de livro ou de treinador, sem estudo que a teste diretamente. Quando o número exato só apareceu em fontes secundárias (resumos do livro, calculadoras), está dito.
- **Controversa:** estudos discordam.

Toda citação foi conferida na web antes de entrar aqui (links no fim). O que não foi encontrado virou "prática de treinadores" ou ficou de fora. Os números de cada regra ficam presos por testes em `CrunningCore/Tests`.

## Ritmos e previsão de prova

| Regra no motor | Fonte | Evidência | Código |
|---|---|---|---|
| **VDOT** a partir de uma prova recente: custo de oxigênio de uma velocidade (VO2 = −4,60 + 0,182258·v + 0,000104·v², v em m/min) dividido pela fração do VO2máx sustentável por aquele tempo (0,8 + 0,1894393·e^(−0,012778·t) + 0,2989558·e^(−0,1932605·t), t em min). | Daniels e Gilbert, *Oxygen Power* (1979, edição dos autores). O livro não está online; as equações aparecem iguais em várias reproduções. Conferidas contra as tabelas publicadas de Daniels: 5 km em 19:57 e maratona em 3:10:49 dão VDOT 50. | Moderada (modelo empírico muito usado; não é medida de laboratório) | `Treino/Zonas.swift` (`Daniels`) |
| **Previsão de tempo** em outra distância: o tempo cujo VDOT é igual ao da prova de referência (busca numérica). | Mesmas equações. Para VDOT 50 o motor dá 5 km em 19:56 e maratona em 3:10:40 (tabela: 19:57 e 3:10:49). | Moderada | `Daniels.tempoPrevisto` |
| **Riegel** (T2 = T1 × (D2/D1)^1,06) como comparação, nunca como alvo. | Riegel (1981, *American Scientist* 69:285). Em 2.303 corredores recreativos, Riegel acertou até a meia, mas foi otimista demais na maratona, com erro de 10 minutos ou mais para metade deles (Vickers e Vertosick, 2016, *BMC Sports Sci Med Rehabil* 8). | Moderada, com limite conhecido | `Riegel` |
| **Zonas de ritmo** como fração do VDOT: fácil 59% a 74%, limiar 83% a 88% (alvo 88%), intervalado 95% a 100% (alvo 97,5%); maratona = ritmo previsto da maratona. | Daniels, *Daniels' Running Formula* (Human Kinetics). Faixas de fácil, maratona (75% a 84%) e intervalado conferidas em resumos do livro; o limiar a 88% reproduz o ritmo da tabela publicada (VDOT 50: 4:15/km, ou 6:51/milha). | Prática de treinadores | `Zonas` |
| **Repetições** a 105% do VDOT (mais rápido que o intervalado, perto do ritmo de prova de 1.500 a 3.000 m). | Daniels descreve o ritmo R como acima do VO2máx; o número 105% é escolha do app e não foi conferido em tabela. | Prática de treinadores (número do app) | `Zonas` |
| **Sem tempo de referência**, a intensidade vai por esforço percebido (escala 0 a 10) e pelo teste da fala: fácil = conversa em frases inteiras. | Escala CR10 de Borg, usada no método de esforço da sessão (Foster e colegas, 2001, *J Strength Cond Res* 15:109). Teste da fala: quem fala confortavelmente costuma estar abaixo do limiar ventilatório (Foster e colegas, 2008, *J Cardiopulm Rehabil Prev*; achado repetido em estudos posteriores). A correspondência exata entre nota e zona é escolha do app. | Moderada (escala e teste da fala); prática (correspondência) | `Zonas.porEsforco` |
| **Frequência cardíaca** só opcional. Máxima estimada por 208 − 0,7 × idade, com aviso de erro de cerca de 10 bpm. | Tanaka, Monahan e Seals (2001, *J Am Coll Cardiol* 37:153). Erro padrão de cerca de 10 a 11 bpm em amostras independentes (estudo HERITAGE). | Moderada | `FrequenciaCardiaca` |

## Distribuição de intensidade

| Regra no motor | Fonte | Evidência | Código |
|---|---|---|---|
| Pelo menos 80% do volume semanal em ritmo fácil (inclui aquecimento, desaquecimento e longão). Iniciante na fase de base: só fácil, com acelerações curtas. | Corredores de elite treinam cerca de 80% leve (Seiler, 2010, *Int J Sports Physiol Perform* 5:276, descritivo). | Moderada | `GeradorPlano`, `ValidadorPlano` (fração de qualidade) |
| Forma piramidal (mais limiar que intervalado) em vez de polarizada. | O polarizado ganhou no VO2pico, mas não nas outras medidas de desempenho (Oliveira e colegas, 2024, *Sports Med* 54:2071). Em análise de dados individuais, recreativos responderam melhor ao piramidal e competitivos ao polarizado (Rosenblat e colegas, 2025, *Sports Med* 55:655, análise de subgrupo). | Controversa | `GeradorPlano` (escolha dos treinos de qualidade) |

## Progressão de carga e longão

| Regra no motor | Fonte | Evidência | Código |
|---|---|---|---|
| Volume semanal sobe no máximo 10% sobre a maior das 3 semanas anteriores (teto configurável de 5% a 20%) e nunca mais de 25% de uma semana para a seguinte. Voltar a um volume que a pessoa já fazia (depois de um alívio ou de uma pausa) pode subir até 25% por semana; acima dele, vale o teto. Abaixo de 10 km por semana (e de 3 km na maior corrida), a referência inicial conta como esses pisos. | A "regra dos 10%" é heurística: num ensaio com novatos, o programa gradual não reduziu lesões (Buist e colegas, 2008, *Am J Sports Med* 36:33). Novatos que subiram mais de 30% em 2 semanas tiveram mais lesões de distância, sem significância estatística (Nielsen e colegas, 2014, *JOSPT* 44:739). Subir de 20% a 60% teve mais lesões em 21 dias (Damsted e colegas, 2019, *JOSPT* 49:230). | Controversa (o teto é conservador, não comprovado) | `RegrasPlano.tetoProgressao`, `ValidadorPlano` |
| O teto de 10% é limite, não meta: o volume sobe em rampa, do que a pessoa corre hoje até o pico do objetivo, e chega ao pico perto de 3/4 das semanas antes do polimento. As últimas semanas antes do polimento ficam no pico. | Escolha do app. A subida gradual é prática de treinadores; a variação semanal de volume não mostrou relação com lesão na coorte de Schuster Brandt Frandsen e colegas (2025), então a rampa é prudência, não regra com evidência. | Prática de treinadores | `GeradorPlano.gerarSemanas` (`rampa`) |
| Nenhuma corrida passa 110% da maior corrida das 4 semanas anteriores (o longão sobe aos poucos). | Coorte de 5.205 corredores: corridas mais de 10% acima da maior dos 30 dias anteriores tiveram mais lesão por sobrecarga (razão de risco 1,64 a 2,28); a variação semanal não mostrou relação (Schuster Brandt Frandsen e colegas, 2025, *Br J Sports Med* 59:1203). Observacional. | Moderada | `GeradorPlano`, `ValidadorPlano` |
| Semana de alívio a cada 4 (a cada 3 para iniciante), com 20% menos volume; depois dela, volta ao nível de antes. Não há alívio na semana antes do polimento (o polimento já alivia). | Prática de treinadores (fala-se em 20% a 30%). Os 20% são escolha do app para a volta não passar de 25% de salto. | Prática de treinadores | `RegrasPlano.alivio`, `GeradorPlano` |
| Longão de no máximo 30% do volume semanal (25% acima de 64 km por semana) e 150 minutos nas provas de até 10 km e sem prova; com 4 corridas, até 35%; com 3, até 40%. Na meia, até 33%, 38% e 43%; na maratona, até 38%, 42% e 48%, e 180 minutos. Teto por objetivo: 12, 16, 20 e 32 km para 5, 10, 21 e 42 km (16 km sem prova). | Daniels: menor entre 25% do volume e 150 min (30% para quem corre menos de 64 km), visto só em fontes secundárias. Planos de maratona muito usados vão além: os de iniciante de Higdon chegam a 20 milhas (32 km) com o longão perto de 40% a 50% do volume semanal; nos de Pfitzinger, relatos dão 25% a 36% (fontes secundárias, [exemplo](https://runningwithrock.com/hal-higdon-marathon-training-plan/)). As frações da meia e da maratona e os 180 minutos são escolha do app entre esses extremos. | Controversa (prática de treinadores diverge) | `RegrasPlano.fracaoMaximaCorrida`, `ValidadorPlano` |
| O longão é a maior corrida da semana: as fáceis ficam em até 80% dele e os treinos de qualidade em até 85%. Nas provas de até 10 km e sem prova, o longão busca uma fração do volume (39%, 31%, 27% e 24% com 3, 4, 5 e 6 corridas); na meia e na maratona, cresce o que as travas deixam. As fáceis usam todos os dias livres que a pessoa deu (cada uma com pelo menos 20 minutos) e somam exatamente o volume que falta. Depois de um dia forte vem uma recuperação mais curta (80% das outras e no máximo 50 minutos), e a diferença vai para as outras. Se as fáceis baterem no teto e ainda faltar volume (poucos dias e dois treinos fortes), os treinos de qualidade ganham até 1,5 km de trote a mais no aquecimento e outro tanto no desaquecimento, sem mudar a parte forte. Se nem assim couber, a semana fica menor e o volume cresce junto com o longão. Com 3 corridas, 80% é o que deixa o longão dentro do teto de 40% sem a semana encolher. | Escolha do app, para o longão ser o treino-chave da semana (prática de treinadores). | Prática de treinadores | `GeradorPlano.montarSemana`, `ValidadorPlano` (nenhuma corrida acima de 90% do longão) |

## Treinos de qualidade

| Regra no motor | Fonte | Evidência | Código |
|---|---|---|---|
| No máximo 2 treinos de qualidade por semana (iniciante, 1), nunca em dias seguidos e nunca colados no longão. | Prática de treinadores (Daniels e outros). | Prática de treinadores | `GeradorPlano`, `ValidadorPlano` |
| Limite de trabalho por sessão: limiar até 10% do volume semanal; intervalado até o menor entre 8% e 10 km; repetições até o menor entre 5% e 8 km. Ritmo de maratona até o menor entre 20% e 16 km. | Regras de Daniels, conferidas em resumos do livro. O limite do ritmo de maratona é escolha do app. | Prática de treinadores | `RegrasPlano`, `ValidadorPlano` |
| Volume de pico por objetivo e nível (km por semana; iniciante, intermediário, avançado): 5 km 25/40/60, 10 km 30/50/70, meia 35/55/80, maratona 45/65/95, sem prova 25/40/60. Nunca abaixo do que a pessoa já corre. | Escolha do app, na faixa usada por planos de treinadores. | Prática de treinadores | `GeradorPlano.volumePico` |
| Dose mínima por sessão: 3 km de trabalho no limiar, 2 km no intervalado, 1,6 km em repetições e 5 km no ritmo de maratona. Quando o limite da sessão ou da semana não deixa chegar nisso, o treino principal vira fartlek (6 a 20 minutos no limiar, em trechos de 2 minutos) e o segundo vira corrida fácil. | Escolha do app: um treino forte de verdade vale mais que dois pequenos demais para estimular e que ainda cansam (prática de treinadores). | Prática de treinadores (números do app) | `GeradorPlano.doseMinima`, `montarSemana` |
| Tiros de intervalado de 2 a 5 minutos (800 a 1.200 m) perto da velocidade do VO2máx; os de 400 m entram como variação mais curta. | Tiros de 2 a 5 min a 90% a 100% da vVO2máx acumulam tempo perto do VO2máx, o estímulo que mais o eleva (Buchheit e Laursen, 2013, *Sports Med* 43:313). | Moderada | `Modelos` (intervalado) |

## Polimento e periodização

| Regra no motor | Fonte | Evidência | Código |
|---|---|---|---|
| Polimento de 1 semana (5 e 10 km), 2 (meia) ou 3 (maratona), nunca mais que um quarto do plano. O volume cai aos poucos até cerca de metade do pico (1 semana: 50%; 2: 70% e 50%; 3: 80%, 62% e 48%), com 1 treino de qualidade mais curto por semana e o mesmo número de corridas. | Definição e padrões de polimento (Mujika e Padilla, 2003, *Med Sci Sports Exerc* 35:1182). Meta-análise de 27 estudos: cortar 41% a 60% do volume em cerca de 2 semanas, sem mudar intensidade nem frequência (Bosquet e colegas, 2007, *Med Sci Sports Exerc* 39:1358). Meta-análise de 14 estudos em atletas de endurance: até 21 dias, com corte progressivo de 41% a 60% (Wang e colegas, 2023, *PLoS One*). | Forte | `GeradorPlano` (fase de polimento), `ValidadorPlano` |
| Fases: base, construção, específica e polimento, com a prova no fim. Sem prova, base e construção em ciclos com alívio. Proporção do app: 40%, 35% e 25% das semanas antes do polimento. | Modelo clássico de periodização. As proporções são escolha do app. | Prática de treinadores | `GeradorPlano` |

## Viabilidade do plano

| Regra no motor | Fonte | Evidência | Código |
|---|---|---|---|
| Antes de gerar um plano de prova, o app confere se há semanas suficientes: o longão precisa chegar ao pico recomendado (8, 12, 18 e 26 km para 5, 10, 21 e 42 km; 85% disso para iniciante; nunca acima do tempo máximo de corrida) subindo até 10% por semana, com alívio e polimento. Mínimo absoluto de 4, 6, 8 e 12 semanas (50% a mais para iniciante). Se faltar tempo, o app diz o mínimo e não gera; acima de 30 semanas, sugere uma prova menor. | A subida de 10% por corrida vem de Schuster Brandt Frandsen e colegas (2025). Os picos de longão ficam na ponta de baixo das faixas comuns em planos de treinadores (por exemplo, maratona com longões de 26 a 32 km), e os mínimos de semanas são escolha do app. | Prática de treinadores | `GeradorPlano.viabilidade`, `RegrasPlano` |
| Avisos do plano: semana inicial bem abaixo do volume atual (porque a maior corrida recente limita as corridas), e longão de pico abaixo do recomendado para a prova. | Escolha do app, para explicar em vez de esconder. | — | `GeradorPlano.alertas` |

## Aquecimento

| Regra no motor | Fonte | Evidência | Código |
|---|---|---|---|
| Antes de intervalado, repetições, subidas e prova: aquecimento completo (cerca de 20 min: trote leve, mobilidade dinâmica, educativos e 3 acelerações progressivas). Antes de limiar, ritmo de prova e fartlek: versão curta (cerca de 15 min). Nos treinos leves, o trote do começo basta. | Aquecer melhorou o desempenho em 79% das medidas de 32 estudos de boa qualidade (Fradkin, Zazryn e Smoliga, 2010, *J Strength Cond Res* 24:140). | Moderada | `Treino/Aquecimento.swift` (execução guiada na fase 5) |
| Só movimentos dinâmicos antes de correr; nada de alongamento estático longo. | Alongamento dinâmico logo antes da atividade melhorou o desempenho; o estático e o PNF deram pequenas perdas quando feitos logo antes (Behm e colegas, 2016, *Appl Physiol Nutr Metab* 41:1). | Moderada | `Aquecimento` |
| O app não promete que o aquecimento evita lesão. | Em 421 corredores recreativos, um programa de aquecimento, desaquecimento e alongamento não reduziu lesões em 16 semanas (van Mechelen e colegas, 1993, *Am J Sports Med* 21:711). | Moderada (um ensaio, qualidade limitada) | `Aquecimento.porque` |

## Iniciante

| Regra no motor | Fonte | Evidência | Código |
|---|---|---|---|
| "Começar a correr": caminhada e corrida alternadas por tempo, 3 sessões por semana com um dia livre entre elas, até 30 minutos de corrida contínua em 9 semanas. A progressão semana a semana é do app: a corrida de cada sessão sobe no máximo 25% de uma semana para a outra (8, 9, 10, 12, 15, 16, 20, 24 e 30 minutos). Aqui as travas são por tempo, não por quilômetro. | Programa Couch to 5K do serviço de saúde britânico (NHS): 9 semanas, 3 corridas por semana, alternando caminhada e corrida até 30 minutos. | Prática (programa de saúde pública) | `GeradorPlano` (objetivo `comecarACorrer`), `Modelos.caminhadaCorrida` |

## Monitoramento

| Regra no motor | Fonte | Evidência | Código |
|---|---|---|---|
| Esforço percebido de 0 a 10 depois de cada corrida é o dado principal. Carga da sessão = esforço × minutos. | Método de esforço da sessão (Foster e colegas, 2001, *J Strength Cond Res* 15:109), com a escala CR10 de Borg. | Forte | `CargaTreino` |
| **A razão carga aguda/crônica (ACWR) não é usada.** | Problemas estatísticos e falta de base causal (Impellizzeri e colegas, 2020, *Int J Sports Physiol Perform* 15:907). Na coorte de 5.205 corredores, a ACWR teve relação inversa com lesão (Schuster Brandt Frandsen e colegas, 2025). A regra de pico por corrida, acima, cobre o risco com evidência melhor. | Controversa | — (decisão de não usar) |

## Adaptação do plano

São regras explícitas que devolvem uma recomendação. O app pergunta antes de mudar o plano, e a IA (fase 9) nunca improvisa fora delas.

| Situação | Regra | Fonte | Evidência | Código |
|---|---|---|---|---|
| Perdeu 1 treino | Segue o plano; não acumula o treino perdido em outro dia. | Prática de treinadores. | Prática de treinadores | `Adaptacao` |
| Ficou parado | Até 5 dias: segue. Depois, a primeira semana volta com 75% (6 a 13 dias), 50% (14 a 27) ou 33% (28 ou mais) do volume de antes, e o volume sobe até 25% por semana até o que a pessoa já fazia. A maior corrida recomeça na mesma proporção. Com 28 dias ou mais, ritmos por esforço até um novo teste. | A perda de condicionamento cresce com o tempo parado (Mujika e Padilla, 2000, *Sports Med* 30:79 e 30:145). As porcentagens são prática de treinadores (tabelas atribuídas a Daniels e guias de retorno não foram conferidas no livro). | Prática de treinadores | `Adaptacao.retomada` |
| Doença | Febre ou sintomas abaixo do pescoço (peito, corpo, estômago): parar e, com febre, procurar um médico. Só acima do pescoço (nariz, garganta): corrida leve e curta é opcional. | "Regra do pescoço", prática clínica difundida, sem ensaio controlado. O consenso do COI sobre carga e risco de doença (Schwellnus e colegas, 2016, *Br J Sports Med* 50:1043) trata de gerir a carga, não dessa regra. | Prática de treinadores | `Adaptacao` |
| Prova mudou de data | Refaz as semanas restantes mantendo o polimento e todas as travas. | Prática de treinadores. | Prática de treinadores | `OperacoesPlano.reajustar` |
| Fora do ritmo | 3 treinos de qualidade seguidos fora da faixa (todos mais rápidos ou todos mais lentos): pergunta se quer ajustar os ritmos. | Prática de treinadores. | Prática de treinadores | `Adaptacao` |
| Esforço alto no fácil | 2 corridas fáceis seguidas com esforço 6 ou mais: propõe semana de alívio. | Uso do esforço percebido para monitorar carga (Foster e colegas, 2001); o gatilho é do app. | Prática de treinadores | `Adaptacao` |
| Dor | Dor que muda a passada ou que persiste: o app não prescreve treino por cima. Propõe parar, reduzir e procurar um profissional; depois, volta por caminhada e corrida. | Segurança; prática clínica. | Prática de treinadores | `Adaptacao` |

## Segurança

| Regra | Fonte | Evidência | Código |
|---|---|---|---|
| O app avisa que não é aconselhamento médico. | — | — | `AjustesView` (já existe) |
| Triagem no primeiro uso com perguntas próprias sobre sinais de alerta (coração, dor no peito, tontura, remédios para pressão, outras condições), com aviso para procurar um médico e link para o PAR-Q+ oficial. | PAR-Q+ (Warburton e colegas, 2011, *Health Fit J Can*; versão de 2023 é a vigente). O formulário oficial não permite alterações, por isso o app não o reproduz: só aponta para ele. | Prática clínica | Fase 8 |

## Calorias

| Regra | Fonte | Evidência | Código |
|---|---|---|---|
| Energia = MET × peso (kg) × horas, com o MET da corrida ou da caminhada pela velocidade média (interpolado entre as linhas da tabela). | *2024 Adult Compendium of Physical Activities* (Herrmann e colegas, 2024, *J Sport Health Sci* 13:6), tabelas oficiais de corrida (códigos 12xxx) e caminhada (17xxx) em pacompendium.com. Valores médios: o gasto real varia de pessoa para pessoa. | Moderada | `Treino/Calorias.swift` |

## Por que cada modelo de treino existe

O campo `porque` de cada modelo em `Treino/Modelos.swift` é escrito a partir destas fontes, nunca gerado na hora.

| Modelo | Propósito | Fonte |
|---|---|---|
| Fácil e recuperação | Volume aeróbico com pouco desgaste; é a maior parte da semana. | Seiler (2010) |
| Longão | Resistência para a distância da prova. | Prática de treinadores (especificidade) |
| Progressivo | Termina mais rápido, para treinar ritmo com as pernas já cansadas. | Prática de treinadores |
| Acelerações (strides) | 15 a 20 s rápidos e soltos, para técnica e velocidade sem cansar. | Prática de treinadores |
| Fartlek | Trechos mais fortes por tempo; introduz intensidade com menos desgaste. | Prática de treinadores |
| Limiar contínuo e cruise intervals | Tempo perto do limiar; as pausas curtas do cruise permitem mais volume no mesmo ritmo. | Daniels (prática de treinadores) |
| Intervalado de VO2máx (400, 800, 1.000, 1.200 m e escada) | Tempo perto do VO2máx. | Buchheit e Laursen (2013) |
| Repetições | Velocidade e economia, com recuperação completa. | Daniels (prática de treinadores) |
| Subidas | Força específica com menos impacto. | Prática de treinadores |
| Ritmo de prova (simulado) | Especificidade: correr no ritmo da prova. | Prática de treinadores |
| Caminhada e corrida | Entrada gradual para quem está começando. | NHS Couch to 5K |

## Como revisar

Toda regra nova do motor entra aqui com a fonte (ou "prática de treinadores") antes de virar código. Os testes de `ZonasTests`, `PlanoTests` e `PlanoPropriedadesTests` prendem os números e as travas.

## Referências conferidas

- Bosquet L e colegas (2007). Effects of tapering on performance: a meta-analysis. *Med Sci Sports Exerc* 39(8):1358–1365. [resumo](https://coachsci.sdsu.edu/csa/vol131/bosquet.htm)
- Buchheit M, Laursen PB (2013). High-intensity interval training, solutions to the programming puzzle. Part I. *Sports Med* 43(5):313–338. [PubMed](https://pubmed.ncbi.nlm.nih.gov/23539308/)
- Buist I e colegas (2008). No effect of a graded training program on the number of running-related injuries in novice runners. *Am J Sports Med* 36(1):33–39. [PEDro](https://search.pedro.org.au/search-results/record-detail/20220)
- Damsted C e colegas (2019). The association between changes in weekly running distance and running-related injury: preparing for a half marathon. *JOSPT* 49(4):230–238. [registro](https://researchportal.lih.lu/en/publications/the-association-between-changes-in-weekly-running-distance-and-ru/)
- Daniels J, Gilbert J (1979). *Oxygen Power: Performance Tables for Distance Runners*. Edição dos autores. Equações reproduzidas em várias calculadoras (por exemplo, [esta](https://calcpace-ccab5cc04603.herokuapp.com/guides/vo2max-estimate)).
- Daniels J. *Daniels' Running Formula*. Human Kinetics (3.ª ed. 2014; 4.ª ed. 2022). Faixas conferidas em resumos ([exemplo](https://www.coachray.nz/2023/05/03/jack-daniels-running-intensity/)).
- Behm DG, Blazevich AJ, Kay AD, McHugh M (2016). Acute effects of muscle stretching on physical performance, range of motion, and injury incidence in healthy active individuals: a systematic review. *Appl Physiol Nutr Metab* 41(1):1–11. [PubMed](https://pubmed.ncbi.nlm.nih.gov/26642915/)
- Foster C e colegas (2001). A new approach to monitoring exercise training. *J Strength Cond Res* 15(1):109–115. [revisão](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5673663/)
- Foster C e colegas (2008). The talk test as a marker of exercise training intensity. *J Cardiopulm Rehabil Prev* (conferido por citações em estudos posteriores, [exemplo](https://hrcak.srce.hr/en/248095); texto completo não lido).
- Fradkin AJ, Zazryn TR, Smoliga JM (2010). Effects of warming-up on physical performance: a systematic review with meta-analysis. *J Strength Cond Res* 24(1):140–148. [PubMed](https://pubmed.ncbi.nlm.nih.gov/19996770/)
- Schuster Brandt Frandsen J e colegas (2025). How much running is too much? Identifying high-risk running sessions in a 5200-person cohort study. *Br J Sports Med* 59(17):1203–1210. [registro](https://pure.au.dk/portal/en/publications/how-much-running-is-too-much-identifying-high-risk-running-sessio/)
- Herrmann SD e colegas (2024). 2024 Adult Compendium of Physical Activities. *J Sport Health Sci* 13(1):6–12. [PubMed](https://pubmed.ncbi.nlm.nih.gov/38242596/); tabelas em [pacompendium.com/running](https://pacompendium.com/running/) e [pacompendium.com/walking](https://pacompendium.com/walking/)
- Impellizzeri FM e colegas (2020). Acute:chronic workload ratio: conceptual issues and fundamental pitfalls. *Int J Sports Physiol Perform* 15(6):907–913. [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7534938/)
- Mujika I, Padilla S (2000). Detraining: loss of training-induced physiological and performance adaptations. Part I e Part II. *Sports Med* 30(2):79–87 e 30(3):145–154.
- Mujika I, Padilla S (2003). Scientific bases for precompetition tapering strategies. *Med Sci Sports Exerc* 35(7):1182–1187. [PubMed](https://pubmed.ncbi.nlm.nih.gov/12840640/)
- NHS. Couch to 5K running plan. [nhs.uk](https://www.nhs.uk/better-health/get-active/get-running-with-couch-to-5k/couch-to-5k-running-plan/)
- Nielsen RO e colegas (2014). Excessive progression in weekly running distance and risk of running-related injuries. *JOSPT* 44(10):739–747. [registro](https://vbn.aau.dk/da/publications/excessive-progression-in-weekly-running-distance-and-risk-of-runn)
- Oliveira e colegas (2024). Revisão sistemática e meta-análise de 17 estudos comparando o treino polarizado com outras distribuições de intensidade. *Sports Med* 54(8):2071–2095. [PDF](https://link.springer.com/content/pdf/10.1007/s40279-024-02034-z.pdf)
- Riegel PS (1981). Athletic records and human endurance. *American Scientist* 69(3):285–290. [cópia](https://nku.edu/~longa/classes/mat375/docs/CrossCountry/riegel.pdf)
- Rosenblat M e colegas (2025). Which training intensity distribution intervention will produce the greatest improvements in maximal oxygen uptake and time-trial performance in endurance athletes? *Sports Med* 55:655–673. [registro](https://www.stir.ac.uk/research/hub/publication/2095779)
- Schwellnus M e colegas (2016). How much is too much? (Part 2) IOC consensus statement on load in sport and risk of illness. *Br J Sports Med* 50(17):1043–1052. [registro](https://bjsm.bmj.com/content/50/17/1043.info)
- Seiler S (2010). What is best practice for training intensity and duration distribution in endurance athletes? *Int J Sports Physiol Perform* 5(3):276–291.
- Tanaka H, Monahan KD, Seals DR (2001). Age-predicted maximal heart rate revisited. *J Am Coll Cardiol* 37(1):153–156. [PubMed](https://pubmed.ncbi.nlm.nih.gov/11153730/)
- van Mechelen W e colegas (1993). Prevention of running injuries by warm-up, cool-down, and stretching exercises. *Am J Sports Med* 21(5):711–719. [PEDro](https://search.pedro.org.au/search-results/record-detail/11851)
- Vickers AJ, Vertosick EA (2016). An empirical study of race times in recreational endurance runners. *BMC Sports Sci Med Rehabil* 8. [PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5000509/)
- Wang e colegas (2023). Effects of tapering on performance in endurance athletes: a systematic review and meta-analysis. *PLoS One* 18(5):e0282838. [PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10171681/)
- Warburton DER e colegas (2011). The Physical Activity Readiness Questionnaire for Everyone (PAR-Q+) and electronic Physical Activity Readiness Medical Examination (ePARmed-X+). *Health Fit J Can* 4(2). [revista](https://hfjc.library.ubc.ca/index.php/HFJC/article/view/103)
