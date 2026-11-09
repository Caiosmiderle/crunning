# CRUNNING

App nativo de iPhone para planejar e executar treinos de corrida. Uso pessoal, um único usuário, dados no aparelho, sem servidor.

## Situação

Fase 3 (corrida livre com GPS): gravação com a tela bloqueada (`CLLocationUpdate` + sessões de segundo plano, com o app reaberto pelo iOS se ele o fechar no meio), pausa manual e automática, tempo em movimento, ritmo atual, parciais, corrida retomada sozinha depois de o app fechar, diagnóstico do sinal do GPS por corrida, histórico com mapa colorido pelo ritmo, gráficos de ritmo e altitude, esforço percebido e exportação em GPX. Simulação de GPS para testar em casa. Instalar: [docs/INSTALAR.md](docs/INSTALAR.md). Testar na rua: [docs/TESTES-NA-RUA.md](docs/TESTES-NA-RUA.md).

Fase 4 (motor de treino): zonas de ritmo pelo VDOT, previsão de prova, biblioteca de modelos de treino, gerador de plano com fases, alívio e polimento, operações de mudança e regras de adaptação, tudo com fonte em [docs/CIENCIA.md](docs/CIENCIA.md) e testes por propriedade. No app: Ajustes > Meus ritmos, Plano > Prévia do motor (com viabilidade, alertas e análise opcional pelo Coach de IA, com a sua chave da Anthropic no Keychain).

Fase 5 (criar e executar treino): construtor com texto rápido ("10min fácil + 6x(400m forte / 90s trote)"), linha do tempo e editor de blocos, biblioteca com treinos prontos nos seus ritmos, execução por blocos com barra segmentada, medidor de ritmo, contagem regressiva, voz em português (abaixa a música) e vibração, aquecimento guiado antes dos treinos fortes, volta manual, pular etapa, modo esteira, teste de referência que atualiza os ritmos e resumo planejado x feito por bloco. Na prévia do plano, as sugestões do Coach de IA viram correções com antes e depois, aplicadas pelo motor e com desfazer.

Fase 6 (Live Activity): na tela de bloqueio e na Dynamic Island, o bloco atual com a cor dele, o que falta (cronômetro que roda sozinho ou distância), distância, ritmo e o progresso do treino; na corrida livre, o tempo em movimento. Atualiza na troca de bloco, na pausa e no máximo a cada 10 s, e some ao finalizar ou descartar.

Fase 7 (Apple Saúde, plano B sem conta paga): com Apple ID gratuito a Apple não libera o HealthKit, então cada corrida sai em TCX (distância, tempo em movimento, energia estimada pelo peso informado e rota; também na esteira) ou GPX, uma por vez ou todas de uma vez, para importar num app que grava no Saúde. Ajustes mostra o modo ativo.

Fase 8 (plano no dia a dia): "Usar este plano" na prévia (com triagem de segurança na primeira vez e link para o PAR-Q+ oficial) põe o plano no calendário. A aba Plano mostra semana a semana o que foi feito, com mover e trocar treino, marcar feito ou perdido, nova data de prova e PDF. O Hoje mostra o treino do dia com o botão de começar, pergunta o que houve com os treinos que ficaram para trás e propõe alívio ou um teste novo quando os dados pedem, sempre com antes e depois. Recordes pessoais no Histórico e quilometragem por tênis.

Fase 9 (Coach de IA completo): plano montado com o coach a partir de um questionário com cartões numerados (o Sonnet escolhe os parâmetros e o motor monta), chat de ajustes ("viajo semana que vem", "canela dolorida") com proposta, antes e depois, Salvar, Ajustar, Recusar e Voltar ao anterior (Haiku), revisão semanal do planejado x feito (sugerida no domingo à noite), modo simulado para testar sem gastar a API e sincronização do plano com um calendário "CRUNNING" no app Calendário.

Também: ajuste dos ritmos pelo calor (WBGT simplificado e Ely e colegas, 2007), prova secundária dentro do plano e avaliação do coach com 4 casos fixos (Ajustes > Desenvolvimento). Na corrida, a engrenagem muda os avisos (voz, bipe, contagem, ritmo, vibração) sem parar o treino, e a seta para baixo minimiza a corrida numa barra acima das abas para usar o resto do app. Frequência cardíaca da Mi Band (anúncio Bluetooth, com o app na tela) na corrida, no resumo e no TCX, e envio das corridas ao Strava pela API oficial com o app criado na sua conta (só envio; nada do Strava vai para o Coach de IA).

Fase 10 (ajustes do uso): calendário com o treino num dia só e nos dias escolhidos, opções de plano sempre à vista, fila de envio ao Strava com reenvio automático, tênis principal fixo, aquecimento como sugestão antes de começar (fora do relógio), revisão semanal só quando a semana sai do plano e lista de treinos com barras em cápsulas.

Idioma: o app segue o idioma do iPhone, português ou inglês. Os textos fixos das telas ficam em `App/Recursos/Localizable.xcstrings` (extraídos pelo Xcode no workflow Textos); os montados em código e os do motor usam `L(português, inglês)` (`CrunningCore/Idioma.swift`). A voz e o Coach de IA também seguem o idioma.

## Como é feito

- SwiftUI, Swift 6, SwiftData, iOS 26 (Liquid Glass nativo), sem dependências de terceiros.
- Projeto gerado por XcodeGen ([project.yml](project.yml)); o `.xcodeproj` não é versionado.
- Compilado num runner macOS do GitHub Actions ([.github/workflows/build.yml](.github/workflows/build.yml)), que testa o motor e publica um `.ipa` não assinado como artefato e Release. Roda só sob pedido (Run workflow) ou em tag `v*`.
- Instalado pelo Windows com Sideloadly e Apple ID gratuito ([docs/INSTALAR.md](docs/INSTALAR.md)).
- O conhecimento de treino mora no pacote [CrunningCore](CrunningCore) (motor determinístico e testado), com as fontes em `docs/CIENCIA.md` (fase 4).

## Pastas

| Pasta | O que tem |
|---|---|
| `App/` | O app: telas, design, modelo de dados, serviços do sistema. |
| `Widgets/` | Extensão da Live Activity (tela de bloqueio e Dynamic Island). |
| `Compartilhado/` | Código usado pelo app e pela extensão. |
| `CrunningCore/` | Pacote Swift sem UI: unidades, formatação, calendário e, depois, zonas, templates, planos. |
| `Suporte/` | Info.plist parciais (o resto vem das chaves `INFOPLIST_KEY_*`). |
| `design/` | Logo original. `tools/gerar_icone.py` gera ícone, símbolo e marca a partir dele. |
| `docs/` | Instalação, referência visual e, depois, ciência e análise de referência. |

Arquivos grandes (APKs, capturas, vídeos) ficam fora do OneDrive, em `C:\Users\caiog\crunning-artifacts\`, e nunca entram no repositório.

## Regras

- Nenhum dado pessoal real (casa, rotas, peso, saúde) no repositório, nos testes, nos commits ou nos logs. Só dados fictícios.
- Nenhuma chave ou token no repositório, no `.ipa` ou no CI. A chave da Anthropic é colada no app e fica no Keychain.
- Nada de outro app (código, imagens, sons, textos, marca) entra aqui sem licença que permita; código de terceiros entra com a atribuição exigida.
- O app não é aconselhamento médico.

Regerar o ícone depois de trocar o logo:

```bash
python -I tools/gerar_icone.py design/logo-crunning.png
```
