# Sonda do CRUNNING para o Amazfit Pace

App de teste e base visual do futuro app de corrida do relógio. Responde três perguntas antes de investir no app completo:

1. Um app de terceiros consegue ler o **batimento** (sensor padrão do Android, tipo 21) e o **GPS** do Pace?
2. Ele **continua vivo** com a tela apagada durante uma corrida inteira, ou o sistema da Huami o mata?
3. O que a **tela** mostra depois que a luz apaga (14 s): o app continua visível ou volta o mostrador?

## O relógio

Amazfit Pace, Android 5.1 (API 22), processador MIPS (por isso Java puro, sem código nativo), tela 320x300. O ADB funciona pelo cabo de carga sem root nem desbloqueio; instalar pelo `adb install` é o caminho normal de desenvolvedor.

## O que ela grava

Uma linha por segundo em `/sdcard/CRUNNING-sonda/sonda-AAAAMMDD-HHMMSS.csv`.

As dez colunas originais continuam com os mesmos nomes, ordem e significado:

```text
segundos,bpm,gps_fixo,precisao_m,velocidade_mps,satelites_usados,satelites_vistos,bateria,tela_ligada,app_visivel
```

`bpm` fica vazio sem leitura nos últimos 5 s. `gps_fixo` indica chegada de leitura GPS nos últimos 3 s, inclusive uma leitura imprecisa: é o diagnóstico bruto do teste. Precisão e velocidade também continuam brutas. A tela exige sinal recente **e aceito pelo filtro**, então pode mostrar "GPS procurando" enquanto `gps_fixo` vale 1.

Três colunas foram acrescentadas **ao fim**, nesta ordem (13 colunas no total):

| Coluna nova | Conteúdo |
| --- | --- |
| `distancia_m` | Distância acumulada filtrada, em metros, com 2 casas decimais. Começa em zero. |
| `pace_atual_s_km` | Ritmo atual suavizado, em segundos/km, com 1 casa; vazio sem sinal bom recente, durante o aquecimento da janela ou abaixo de 1 km/h. |
| `pace_medio_s_km` | Tempo total gravado dividido pela distância, em segundos/km, com 1 casa; vazio antes de acumular 1 metro. Inclui esperas e períodos sem GPS. |

O CSV usa ponto decimal e vírgula entre campos. Linhas que começam com `#` continuam sendo eventos (início, fim, sistema com pouca memória, serviço recriado).

**Não grava latitude nem longitude.** O arquivo fica no relógio e no PC (`crunning-artifacts`), nunca no repositório.

O serviço continua em primeiro plano, com wake lock parcial, `START_STICKY` e sensor padrão `TYPE_HEART_RATE`. O pulso de gravação de 1 Hz continua funcionando com a Activity pausada/tela apagada. Se o processo for morto e recriado, abre outra sessão/CSV e zera as métricas em memória; não recupera a distância anterior.

## A tela (320 × 300 px; densidade 1,5)

De cima para baixo, sem rolagem:

1. **Ritmo atual · min/km**, com o maior número (76 px, negrito). Mostra `--:--` sem dados utilizáveis.
2. **Médio · min/km** e **Tempo**, lado a lado. Tempo em `mm:ss`, passando a `h:mm:ss` após uma hora.
3. **♥ Batimento** e **distância em km com 2 casas**. A FC fica verde com leitura recente, cinza com `--` após 5 s sem leitura.
4. **GPS procurando** em amarelo ou **GPS ok ±N m** em verde, junto da bateria; abaixo, contadores de leituras **FC** e **GPS**, incluindo as leituras GPS descartadas do cálculo.
5. **Começar** (verde/texto preto) ou **Parar** (vermelho/texto preto), junto do alternador **Tela: normal / Tela: sempre**. Cada alvo mede 76 × 66 px (aproximadamente 51 × 44 dp), recuado das bordas curvas. O modo sempre usa `FLAG_KEEP_SCREEN_ON`; o padrão é normal.

Para parar, toque em **Parar**, espere aparecer **Confirmar** e "Toque de novo para parar", e toque novamente dentro de 3 s contados do primeiro toque. Um toque repetido antes de aparecer a confirmação é ignorado. A confirmação expira, e também é cancelada ao sair da tela ou tocar no alternador. Durante a confirmação, o aviso ocupa temporariamente a linha dos contadores. Depois de parar, médio, tempo e distância ficam visíveis até começar outra gravação; FC e ritmo atual ficam sem leitura.

Fundo preto, números brancos, fonte **sans-serif-condensed em negrito do Android**, sem fontes externas. A atualização visual é de 1 Hz, inclusive o retorno dos controles (até 1 s); não há animação, sombra, degradê ou transparência. `onDraw` reutiliza um `Paint`, desenha textos já formatados e reduz a fonte quando necessário para caber. As dimensões são pixels físicos de referência, evitando multiplicar fontes por 1,5 e estourar o visor.

`Cores.java` documenta a origem de cada cor em `App/Design/Paleta.swift`: verde da marca **#8BE105** preservado; amarelo **#FFCC00** a partir de `foraLeve` (#FFC53D); vermelho **#FF3030** a partir de `foraForte` (#FF4D4F). As cores de `TipoTreino.hex` ficam definidas na mesma ordem do iPhone, com os tons frios claros convertidos para ciano/azul saturado e os demais saturados. São reservadas para os futuros treinos: a sonda livre não inventa tipo de treino ou faixa-alvo do `MedidorRitmo`.

## Como distância e ritmo são calculados

- Só entram amostras com precisão informada de até **25 m**, tempo monotônico crescente, idade de até **3 s** e posteriores ao começo da sessão. Não usa o relógio civil para medir intervalos.
- A distância soma `Location.distanceTo` entre pontos bons. Descarta deslocamentos acima de **12 m/s** (43,2 km/h), velocidades inválidas e amostras em rajada com intervalo menor que 0,5 s. Um salto isolado não vira referência para contar a volta dele; o último ponto bom vale por até 3 s.
- Sem referência recente ou após precisão ruim, o próximo ponto só fixa a referência: não liga o buraco de GPS. Quando a velocidade fornecida pelo GPS indica menos de 1 km/h, não acumula a pequena deriva das coordenadas.
- O ritmo atual usa a média de velocidade **ponderada pelo tempo** dos trechos dos últimos **12 s**. Usa a velocidade do GPS quando disponível; senão, distância/tempo. Começa após pelo menos 3 s de trechos válidos. Abaixo de 1 km/h na média, mostra `--:--`. Ao parar de correr, a janela pode levar até 12 s para refletir o repouso.
- Um único `Location` anterior é mantido transitoriamente em RAM e descartado ao perder referência/parar. O buffer fixo de 32 trechos guarda só tempos e velocidades. Não há rota, coordenadas em CSV, tela ou logs, nem impressão de objetos `Location`/exceções do GPS.

São estimativas para a sonda: deriva GPS sem velocidade informada ainda pode somar distância parado; o filtro pode perder metros em curvas, sinal ruim ou interrupções. Confira numa corrida conhecida antes de usar como medição de treino.

## Instalar e rodar (PC com o relógio no cabo)

Use o ADB de `crunning-artifacts/ferramentas/platform-tools` ou adicione essa pasta ao PATH.

```bash
adb install crunning-sonda.apk
adb shell am start -n io.github.caiosmiderle.crunning.sonda/.Principal
```

Cada compilação usa uma chave nova; para atualizar, desinstale antes (os registros em `/sdcard/CRUNNING-sonda` ficam):

```bash
adb uninstall io.github.caiosmiderle.crunning.sonda
```

Trazer os registros para o PC:

```bash
adb pull /sdcard/CRUNNING-sonda ./crunning-artifacts/pace-sonda
```

## O que já foi conferido na versão anterior (09/11/2026, relógio no cabo)

- Instala pelo ADB e abre; a tela aparece certa (320x300).
- **Começar** sobe o serviço em primeiro plano; o sensor encontrado é "Heart Rate Sensor / Huami Tech"; o CSV recebe uma linha por segundo e **Parar** grava o evento "fim".
- No carregador, a tela de carga da Huami cobre o app quando a tela acorda, e depois que a luz apaga volta o mostrador. Por isso o batimento e o GPS só dá para testar fora do cabo.

## O teste na rua

1. Fora do cabo, procure **CRUNNING sonda** na lista de apps do relógio. Se não aparecer, ligue no PC e inicie por lá (`adb shell am start ...` e toque em Começar). Com o app aberto, toque em **Começar**. Espere o GPS ficar "ok" e o batimento aparecer.
2. Deixe a luz apagar sozinha e anote o que a tela mostra.
3. Corra 30 minutos sem mexer no relógio (pode olhar o pulso).
4. Em casa, toque em **Parar**, espere a confirmação e toque em **Confirmar** em até 3 s do primeiro toque (se o app ainda estiver lá); ligue o relógio no PC.

O botão **Tela: sempre** testa a tela sempre acesa; deixe em "normal" no primeiro teste.

## Revisão desta interface

Implementação sem `res/`, AndroidX, bibliotecas, lambdas ou streams; manifesto e `compilar.sh` continuam sem alterações. O script já inclui todos os `.java` de `src`, portanto inclui `Cores.java` automaticamente.

Revisão manual dedicada: imports, tipos, inicialização dos campos/classes anônimas, ciclos da Activity/serviço, serviços nulos, log indisponível, divisores e valores não finitos, expiração dos sinais, reinício e limites de largura. As APIs novas são anteriores à API 22: desenho/medição de texto e `Location.set/reset/distanceTo` (API 1), `getElapsedRealtimeNanos` (API 17), remoção de animação/elevação dos botões (API 21). Referências oficiais: [Location](https://developer.android.com/reference/android/location/Location), [Canvas](https://developer.android.com/reference/android/graphics/Canvas), [Paint](https://developer.android.com/reference/android/graphics/Paint), [View](https://developer.android.com/reference/android/view/View).

Também passaram simulações numéricas em Node dos métodos de cálculo extraídos do Java, substituindo somente o relógio e `Location` por leituras sintéticas em metros: início sem dados, corrida constante, aceleração e janela de 12 s, volta completa do buffer, repouso, menos de 1 km/h, GPS sem velocidade, precisão ruim/ausente, salto e retorno, perda/retomada de sinal, amostra antiga/duplicada e valores NaN/infinito. Checagens estáticas conferiram UTF-8 sem BOM nos Java, delimitadores, as 13 colunas, ausência de serialização de coordenadas, ausência de criação de objetos/formatação em `onDraw`, os dois pulsos de 1 Hz já existentes (tela e serviço) e os botões dentro de uma elipse conservadora de 320 × 300 px, com altura de 44 dp.

**Esta versão ainda precisa compilar no GitHub Actions e ser conferida no Pace.** A máquina de edição não tem JDK/Android SDK; revisão e simulações numéricas não substituem a compilação contra `android-22` nem o teste do firmware Huami. Confira especialmente os textos/botões no visor, o glifo ♥, o ritmo em movimento, as 13 colunas do CSV e a gravação durante 30 min com tela apagada. Os 3 s de confirmação exigem um segundo toque; se o aviso expirar, tente novamente.
