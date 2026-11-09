# Fase 1: o que o Runna faz (análise de referência)

Objetivo: entender **quais recursos** um app de treino de corrida maduro oferece e **como ele organiza o plano**, para decidir o que o CRUNNING deve ter. Nada do Runna entra no CRUNNING: nem código, nem imagens, nem textos, nem nomes de recursos ou de treinos, nem conteúdo de planos, marca ou cores. Este documento descreve recursos com palavras próprias; os nomes internos do app ficam só nos artefatos locais.

## Como foi feito (08/11/2026)

- **Artefato:** APK base do Runna 8.55.0 (`com.runbuddy.prod`, versão de código 2076), baixado pelo Caio do APK4Fun. Hash e assinatura declarada em [artefatos.md](artefatos.md). O APK veio sem os pedaços de bibliotecas nativas, então o app **não foi instalado nem executado**; a análise é toda estática.
- **REA 6.8.0** pela linha de comando (sem registrar nada na configuração do Claude): `inspect-apk-signature` (evidência `ev_776efdb1…`) e `inspect-android-package` com JADX headless 0.7.1 e JDK 21 (evidência `ev_aa9fb113…`, 29.153 classes, manifesto completo).
- **Pacote JavaScript:** o app é React Native com Expo; o código das telas está em bytecode Hermes v96 (27 MB, SHA-256 `c6baefae…0fddcb`). Li só a tabela de textos (174.770 entradas), descartando antes de gravar tudo o que parecia chave, token ou endereço de servidor (cerca de 10.900 entradas). O resto virou um índice de nomes internos agrupado por assunto, guardado só em `crunning-artifacts\analise-runna\`.
- **Limites respeitados:** nenhum endpoint consultado, nenhuma credencial extraída ou usada, nenhuma proteção contornada, nenhum login feito.
- **Conferência:** os recursos principais foram conferidos na central de ajuda pública do Runna e em reportagens (lista no fim).

## Como o Runna é por dentro

- **Plano gerado no servidor.** O app manda as respostas do questionário e recebe o plano pronto; há versões do "motor" de planos e migração entre elas. Todo ajuste (adaptação, mudança de dias, revisão de ritmos) passa por esse servidor.
- **Gravação no próprio celular.** Serviço em primeiro plano do tipo localização, localização em segundo plano, reconhecimento de atividade, voltas e parciais, aviso de GPS impreciso, modo esteira e sensor de frequência cardíaca por Bluetooth. Traz um banco com mapa de altura do geoide; pelo nome, serve para corrigir a altitude do GPS no Android (inferência; no iOS isso não é preciso, porque o `CLLocation` já entrega altitude sobre o nível do mar).
- **Integrações:** Health Connect (lê e grava distância, exercício, rota, FC, potência, calorias, passos), Apple Health e Apple Watch, Garmin, COROS, Amazfit, Polar, Strava, Spotify, sincronização com calendários externos e esteiras inteligentes por Bluetooth (padrão FTMS).
- **Muito SDK de terceiros:** cobrança e paywall (RevenueCat, Google Play, Amazon), marketing e push (Iterable), atribuição de anúncios (AppsFlyer, Facebook, APIs de anúncio do Google), suporte (Intercom), erros (Sentry), análise (Firebase). O CRUNNING não terá nenhum disso.

## Mapa de recursos

### Questionário e criação do plano
Tempo atual de prova ou capacidade estimada, volume semanal atual e longão atual, metas de volume e de longão, quantos dias por semana e quais, dia do longão, duração do plano ou data da prova, data de início, terreno, provas de teste (contrarrelógio) para calibrar, histórico de lesão e risco, idade e sexo, unidades, zonas de frequência cardíaca. Há tipos de plano por distância, para iniciantes, de volta após pausa, de recuperação pós-prova, de condicionamento geral e de força.

### Ajustes do plano
- **Preferências de treino:** dificuldade (intensidade e número de sessões de velocidade), volume e ritmo de evolução (gradual ou mais rápido).
- **O tamanho do plano é o principal ajuste de dificuldade:** plano mais longo, evolução semanal mais suave.
- **O longão tem limite de evolução próprio,** separado do volume semanal. Quem corre mais vezes por semana evolui mais devagar.
- **Uma corrida por dia;** força, mobilidade e pilates podem dividir o dia.
- **Calendário:** mover treinos, trocar o longão de dia, ver o plano em PDF, compartilhar o plano, plano em rascunho, conflito entre planos sobrepostos.

### Adaptação (o coração do produto)
- **Calor e umidade:** com base na previsão do tempo, propõe ritmos mais lentos para o mesmo estímulo, troca o longão de dia ou desaconselha correr ou competir. O usuário pode voltar aos ritmos originais.
- **Revisão de ritmos:** analisa os treinos feitos e **propõe** ritmos mais rápidos ou mais lentos; o usuário aceita ou recusa. Há histórico das revisões.
- **Volume:** avisa se a pessoa está acima ou abaixo do volume semanal planejado e oferece ajustar.
- **Períodos de menos treino:** férias ou pausa (datas, capacidade de treinar, nome) e redução por motivo (datas, intensidade, motivo, plano de volta). O plano se reorganiza e retoma depois.
- **Treino perdido:** um "check-in" pergunta o que houve e reorganiza.
- **Prova secundária dentro do plano:** com categorias de fadiga e ajuste de esforço; há casos em que o app diz que não dá para encaixar.
- **Recuperação pós-prova:** plano próprio de volta, considerando o esforço da prova e metas de volume.

### Treinos e execução
Treinos avulsos fora do plano (com dificuldade), testes de referência, força com equipamento e duração escolhidos e vídeo-guia, ioga e mobilidade. Na corrida: avisos de voz configuráveis (voz, volume, distância das parciais), contagem regressiva antes de começar, vibração configurável, modo esteira (inclusive controlando esteira por Bluetooth), envio do treino ao relógio.

### Depois da corrida
Resumo com análise, voltas, parciais e mapa; edição da atividade e atividade manual; feedback de esforço e de como foi o treino; notas privadas; contagem de quilometragem por tênis; cartões para compartilhar (com voltas, estatísticas ou contagem para a prova); marcos, conquistas, níveis e pontos.

### Acompanhamento
Gráfico de volume, histórico de ritmos, comentários de treinadores e textos de metodologia, "insights" gerados por IA, contagem regressiva da prova.

### Comunidade e assinatura
Espaços, posts, comentários, reações, enquetes, clubes, desafios, indicação de amigos, código de barras do parkrun, paywall, ofertas, testes grátis, ícones alternativos do app.

## O que levar para o CRUNNING

Tudo implementado do nosso jeito, com regras próprias e com a ciência conferida em `docs/CIENCIA.md` antes de virar código.

| Ideia | Fase | Como fica no CRUNNING |
|---|---|---|
| Entradas do plano: marca recente ou teste, volume e longão atuais, dias disponíveis, dia do longão, data da prova, início | 4 e 8 | Questionário curto no app; o motor é local e determinístico (sem servidor). |
| Tamanho do plano como ajuste de dificuldade, longão com limite de evolução próprio, evolução mais lenta para quem corre mais vezes | 4 | Regras do motor com testes de propriedade (o volume nunca sobe acima do limite, o longão também não). Limites a confirmar na literatura. |
| Teste de referência para calibrar ritmos | 4 e 5 | Treino de teste no construtor; o resultado atualiza as zonas. |
| Revisão de ritmos proposta e aceita pelo usuário | 8 | Depois de alguns treinos de qualidade, o app sugere ajuste; nada muda sem o seu OK. |
| Ajuste por calor e umidade | 8 | Previsão pelo WeatherKit (a confirmar se o Apple ID gratuito permite) ou digitada; fator de ajuste só com fonte confirmada. |
| Períodos de menos treino e volta gradual | 8 | "Pausa" com datas e motivo; o motor refaz as semanas seguintes com rampa de volta. |
| Treino perdido | 8 e 9 | Regras simples na 8; na 9 o coach de IA conversa sobre o que houve. |
| Prova secundária no plano e recuperação pós-prova | 8 | Mini-polimento e dias leves depois; recusa explicada quando não cabe. |
| Avisos de voz configuráveis, contagem regressiva, vibração | 5 | Voz em português, parciais a cada X, aviso de bloco, faixa de ritmo. |
| Modo esteira | 5 | Corrida sem GPS, distância digitada no fim (esteira por Bluetooth fica fora). |
| Feedback de esforço e notas | 3 e 8 | Já temos o esforço (1 a 10); notas e sensação entram como sinal para adaptar. |
| Quilometragem por tênis | 8 | Simples e útil para um corredor só. |
| Plano em PDF e sincronização com o calendário | 8 | `ShareLink` de PDF e EventKit. |
| Apple Health | 7 | Ler e gravar treinos e rotas (com a conta paga ou o plano B em GPX). |

## O que fica de fora

Comunidade, clubes, desafios, indicação, paywall e ofertas, pontos e níveis, ícones alternativos, códigos de parkrun, todos os SDKs de marketing, anúncio, análise e suporte, e plano gerado em servidor. O CRUNNING é de uma pessoa só e roda sem servidor.

## Fontes públicas consultadas

- [Central de ajuda do Runna: recursos e perguntas frequentes](https://support.runna.com/en/collections/3431949-app-features-subscriptions-faqs)
- [Central de ajuda do Runna: criação e gestão do plano](https://support.runna.com/en/collections/16743424-plan-creation-management)
- [Como o Runna monta o plano a partir da forma atual](https://support.runna.com/en/articles/15231838-how-does-runna-build-your-training-plan-around-your-current-fitness)
- [Como o Runna reduz risco de lesão e excesso de treino](https://support.runna.com/en/articles/15279082-how-does-runna-reduce-the-risk-of-injury-and-overtraining)
- [Como o Runna calcula a quilometragem](https://support.runna.com/en/articles/14666572-how-runna-calculates-your-mileage-and-how-to-adjust-it)
- [Como adicionar uma prova secundária](https://intercom.help/runna/en/articles/10856802-how-to-add-and-manage-your-b-race)
- [Wareable: ajuste de ritmo por calor e recuperação pós-prova](https://www.wareable.com/running/runna-adapt-for-heat-post-race-recovery-update)
- [9to5Mac: ritmos ajustados por calor e umidade (29/07/2026)](https://9to5mac.com/2026/07/29/runna-now-automatically-adapts-training-paces-based-on-heat-and-humidity/)
