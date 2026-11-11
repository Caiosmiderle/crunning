# Sonda do CRUNNING para o Amazfit Pace

App de teste e base visual do futuro app de corrida do relógio. Responde três perguntas antes de investir no app completo:

1. Um app de terceiros consegue ler o **batimento** (sensor padrão do Android, tipo 21) e o **GPS** do Pace?
2. Ele **continua vivo** com a tela apagada durante uma corrida inteira, ou o sistema da Huami o mata?
3. O que a **tela** mostra depois que a luz apaga (14 s): o app continua visível ou volta o mostrador?

## O relógio

Amazfit Pace, Android 5.1 (API 22), processador MIPS (por isso Java puro, sem código nativo), tela 320x300, paisagem natural. **Nunca force orientação** no manifesto ou no Java: forçar retrato reduziu a área para 230x300 e derrubou o launcher Huami. O ADB funciona pelo cabo de carga sem root nem desbloqueio; instalar pelo `adb install` é o caminho normal de desenvolvedor.

Na rodada 2, ao ar livre, parado e no cabo, o GPS entregou posições a 1 Hz após cerca de 60 s, com velocidade, mas sem precisão (`hasAccuracy()` falso). Os satélites vistos chegaram a 8, enquanto `usedInFix()` ficou falso para todos. Por isso precisão e satélites usados deixam de ser condições para medir distância/ritmo. O sensor de batimento começou em cerca de 15 s e entregou leituras em aproximadamente 75% do tempo no pulso.

## O que ela grava

Uma linha por segundo em `/sdcard/CRUNNING-sonda/sonda-AAAAMMDD-HHMMSS.csv`.

As dez colunas originais continuam com os mesmos nomes, ordem e significado:

```text
segundos,bpm,gps_fixo,precisao_m,velocidade_mps,satelites_usados,satelites_vistos,bateria,tela_ligada,app_visivel
```

`bpm` fica vazio sem leitura nos últimos 5 s. `gps_fixo` indica chegada de leitura GPS nos últimos 3 s, inclusive uma leitura rejeitada pelo cálculo: é o diagnóstico bruto do teste e agora também determina o texto "GPS ok" na tela. Precisão e velocidade continuam brutas: sem o respectivo atributo, mantêm os valores anteriores de ausência (`-1` e `-1.0`); sem posição recente, ficam vazias. `satelites_usados` mantém a leitura bruta de `usedInFix()` por compatibilidade, mesmo que o Pace sempre informe zero. Esse número não aparece na tela nem participa do cálculo.

As três colunas da rodada anterior mantêm suas posições (11 a 13):

| Coluna nova | Conteúdo |
| --- | --- |
| `distancia_m` | Distância acumulada filtrada, em metros, com 2 casas decimais. Começa em zero. |
| `pace_atual_s_km` | Ritmo atual suavizado, em segundos/km, com 1 casa; vazio sem amostra aceita recente, durante o aquecimento da janela ou com média abaixo de 0,5 m/s. |
| `pace_medio_s_km` | Tempo total gravado dividido pela distância, em segundos/km, com 1 casa; vazio antes de acumular 1 metro. Inclui esperas e períodos sem GPS. |

Nesta rodada, mais quatro colunas são acrescentadas **ao fim**, nesta ordem, totalizando **17**:

| Coluna nova | Conteúdo |
| --- | --- |
| `tem_precisao` | 1 se a posição recente tem `hasAccuracy()`, 0 se não tem ou não há posição recente. Não significa que passou no filtro. |
| `tem_velocidade` | 1 se a posição recente tem `hasSpeed()`, 0 se não tem ou não há posição recente. Não significa que passou no filtro. |
| `snr_max` | Maior SNR finito e não negativo entre os satélites do último status recebido, com 1 casa; zero sem valor disponível. |
| `sat_snr_30` | Quantidade de satélites vistos com SNR ≥ 30 no último status recebido. |

O CSV usa ponto decimal e vírgula entre campos. Linhas que começam com `#` continuam sendo eventos (início, fim, sistema com pouca memória, serviço recriado). O evento `GPS_EVENT_FIRST_FIX` consulta `getTimeToFirstFix()` (milissegundos) e grava `# <s> primeiro fix em <N> s`, com N em segundos e uma casa decimal. Esse tempo pertence ao motor GPS desde a última partida, podendo anteceder a sessão se outro app já o usava. A limpeza do AGPS também grava um evento com o resultado, quando há serviço e arquivo abertos.

**Não grava latitude, longitude nem altitude** no CSV, no log ou na tela. O arquivo fica no relógio e no PC (`crunning-artifacts`), nunca no repositório.

O serviço continua em primeiro plano, com wake lock parcial, `START_STICKY` e sensor padrão `TYPE_HEART_RATE`. O pulso de gravação de 1 Hz continua funcionando com a Activity pausada/tela apagada. Se o processo for morto e recriado, abre outra sessão/CSV e zera as métricas em memória; não recupera a distância anterior.

## A tela (320 × 300 px; densidade 1,5)

De cima para baixo, sem rolagem:

1. **Ritmo atual · min/km**, com o maior número (76 px, negrito). Mostra `--:--` sem dados utilizáveis.
2. **Médio · min/km** e **Tempo**, lado a lado. Tempo em `mm:ss`, passando a `h:mm:ss` após uma hora.
3. **♥ Batimento** e **distância em km com 2 casas**. A FC fica verde com leitura recente, cinza com `--` após 5 s sem leitura.
4. **GPS procurando · N sat** em amarelo ou **GPS ok** em verde quando chegou posição nos últimos 3 s. Com precisão informada válida, mostra **GPS ok ±N m**; sem precisão, **GPS ok · N sat**. Não mostra satélites usados. Junto fica a bateria; abaixo, contadores de leituras **FC** e **GPS**, incluindo as leituras GPS descartadas do cálculo. "GPS ok" indica recepção recente; o ritmo ainda pode estar aquecendo ou a leitura pode ter sido rejeitada.
5. **Começar** (verde/texto preto) ou **Parar** (vermelho/texto preto), junto do alternador **Tela: normal / Tela: sempre**. Cada alvo mede 76 × 66 px (aproximadamente 51 × 44 dp), recuado das bordas curvas. O modo sempre usa `FLAG_KEEP_SCREEN_ON`; o padrão é normal.

Para parar, toque em **Parar**, espere aparecer **Confirmar** e "Toque de novo para parar", e toque novamente dentro de 3 s contados do primeiro toque. Um toque repetido antes de aparecer a confirmação é ignorado. A confirmação expira, e também é cancelada ao sair da tela ou tocar no alternador. Durante a confirmação, o aviso ocupa temporariamente a linha dos contadores. Depois de parar, médio, tempo e distância ficam visíveis até começar outra gravação; FC e ritmo atual ficam sem leitura.

**Limpar os dados de apoio do GPS:** segure a linha do status do GPS, espere "Apagar AGPS? Segure GPS (3 s)" e faça outro toque longo nessa linha em até 3 s contados do primeiro. Uma única pressão longa não apaga nada. A confirmação expira e é cancelada ao sair da tela ou usar outro controle. A linha mostra o resultado durante 5 s, com atualização no pulso visual de 1 Hz. O pedido chama `sendExtraCommand(GPS_PROVIDER, "delete_aiding_data", null)` com `ACCESS_LOCATION_EXTRA_COMMANDS`. "Pedido aceito" significa retorno `true` do provedor; é preciso conferir no firmware se os dados foram apagados. Retorno falso, falta de gerenciador/permissão e falha do provedor têm mensagens próprias. O resultado vai sempre para `Log.i("CRUNNING", ...)` e também para o CSV se a gravação estiver aberta. Um pedido aceito descarta a referência/janela GPS em RAM, sem zerar distância, tempo ou ritmo médio; a próxima posição inicia outra referência.

Fundo preto, números brancos, fonte **sans-serif-condensed em negrito do Android**, sem fontes externas. A atualização visual é de 1 Hz, inclusive o retorno dos controles (até 1 s); não há animação, sombra, degradê ou transparência. `onDraw` reutiliza um `Paint`, desenha textos já formatados e reduz a fonte quando necessário para caber. As dimensões são pixels físicos de referência, evitando multiplicar fontes por 1,5 e estourar o visor.

`Cores.java` documenta a origem de cada cor em `App/Design/Paleta.swift`: verde da marca **#8BE105** preservado; amarelo **#FFCC00** a partir de `foraLeve` (#FFC53D); vermelho **#FF3030** a partir de `foraForte` (#FF4D4F). As cores de `TipoTreino.hex` ficam definidas na mesma ordem do iPhone, com os tons frios claros convertidos para ciano/azul saturado e os demais saturados. São reservadas para os futuros treinos: a sonda livre não inventa tipo de treino ou faixa-alvo do `MedidorRitmo`.

## Como distância e ritmo são calculados

- Só entram amostras com tempo monotônico crescente, idade de até **3 s** e a partir do começo da sessão. Não usa o relógio civil para medir intervalos. A precisão é filtrada **somente se `hasAccuracy()` for verdadeiro**: precisa ser finita, não negativa e de até **25 m**. Ausência de precisão não impede distância nem ritmo.
- Com `hasSpeed()`, a distância soma **velocidade GPS (Doppler) × intervalo** entre amostras aceitas. A velocidade precisa ser finita, não negativa e **≤ 10 m/s** (36 km/h). Abaixo de **0,5 m/s**, é tratada como zero tanto na distância como na janela de ritmo. Nesse caminho, deriva ou salto das coordenadas não veta velocidade válida; não se usa `distanceTo`.
- Sem velocidade, soma `Location.distanceTo` entre posições aceitas, desde que distância/intervalo seja **≤ 10 m/s**. Um salto isolado não vira referência para contar a volta dele; o último ponto bom vale por até 3 s. Sem velocidade informada, a deriva de coordenadas ainda pode somar metros parado.
- Intervalos de até **3 s** são integrados; se forem maiores, **nenhuma parte do buraco é integrada**, nem mesmo os primeiros 3 s: o próximo ponto só fixa referência. Após precisão/velocidade inválida, a referência também é descartada. Rajadas com menos de 0,5 s são ignoradas, como antes, sem dominar a janela.
- O ritmo atual usa a média de velocidade **ponderada pelo tempo** dos trechos dos últimos **12 s**, calculados pela mesma regra da distância (Doppler ou distância/tempo). Começa após pelo menos 3 s de trechos válidos. Abaixo de 0,5 m/s na média, mostra `--:--`. Ao parar de correr, a janela pode levar até 12 s para refletir o repouso.
- O **ritmo médio mantém a definição anterior: tempo total desde Começar dividido pela distância acumulada**, em segundos/km. Inclui a espera do primeiro fix, paradas e períodos sem GPS; fica vazio até acumular 1 m. Ao parar a sessão, congela com o tempo final.
- Um único `Location` anterior é mantido transitoriamente em RAM e descartado ao perder referência/parar. O buffer fixo de 32 trechos guarda só tempos e velocidades. Não há rota, coordenadas em CSV, tela ou logs, nem impressão de objetos `Location`/exceções do GPS.

São estimativas para a sonda: deriva GPS sem velocidade informada ainda pode somar distância parado; o filtro pode perder metros em curvas, sinal ruim ou interrupções. Confira numa corrida conhecida antes de usar como medição de treino.

## Instalar e rodar (PC com o relógio no cabo)

Use o ADB de `crunning-artifacts/ferramentas/platform-tools` ou adicione essa pasta ao PATH.

```bash
adb install crunning-sonda.apk
adb shell am start -n io.github.caiosmiderle.crunning.sonda/.Principal
```

Controle remoto, sem tocar no relógio (extra String `acao`):

```bash
adb shell am start -n io.github.caiosmiderle.crunning.sonda/.Principal --es acao comecar
adb shell am start -n io.github.caiosmiderle.crunning.sonda/.Principal --es acao parar
adb shell am start -n io.github.caiosmiderle.crunning.sonda/.Principal --es acao apagar_agps
adb shell am start -n io.github.caiosmiderle.crunning.sonda/.Principal --es acao tela_sempre
adb shell am start -n io.github.caiosmiderle.crunning.sonda/.Principal --es acao tela_normal
adb logcat -s CRUNNING:I
```

`parar` e `apagar_agps` via ADB executam diretamente, sem confirmação na tela. Começar novamente com o serviço já rodando mantém a sessão; parar sem sessão é inofensivo. As ações são tratadas em `onCreate` e `onNewIntent`, com `launchMode="singleTop"`. O extra é consumido para evitar repetição ao recriar a Activity. Cada ação recebida é registrada em `Log.i("CRUNNING", ...)`; valores desconhecidos são ignorados e registrados apenas como "desconhecida".

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

1. Fora do cabo, procure **CRUNNING** na lista de apps do relógio. Se não aparecer, ligue no PC e inicie por lá (`adb shell am start ... --es acao comecar`). Com o app aberto, toque em **Começar**. Espere o GPS ficar "ok" e o batimento aparecer.
2. Deixe a luz apagar sozinha e anote o que a tela mostra.
3. Corra 30 minutos sem mexer no relógio (pode olhar o pulso).
4. Em casa, toque em **Parar**, espere a confirmação e toque em **Confirmar** em até 3 s do primeiro toque (se o app ainda estiver lá); ligue o relógio no PC.

O botão **Tela: sempre** testa a tela sempre acesa; deixe em "normal" no primeiro teste.

## Ícone e compilação dos recursos

O ícone vem de `App/Recursos/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, o mesmo do iPhone, criado por `tools/gerar_icone.py` a partir de `design/logo-crunning.png`. A marca ocupa os 60% centrais do original; o fundo escuro e a margem preservam o símbolo quando o launcher corta o quadrado em círculo. Aplicação e Activity têm nome **CRUNNING**; a aplicação usa `@mipmap/ic_launcher`.

Gerador Python + Pillow (não modifica o ícone de origem):

```bash
python -I relogio/pace-sonda/ferramentas/gerar_icone.py
```

Gera `res/mipmap-mdpi/ic_launcher.png` (48×48), `mipmap-hdpi` (72×72), `mipmap-xhdpi` (96×96) e `mipmap-xxhdpi` (144×144). Nesta máquina, `python -I` falhou porque não há Python no PATH. O registro do Windows aponta um Python 3.13 da Store, mas executar esse caminho também falhou com acesso negado; não foi possível executar/verificar Pillow. Os quatro PNG já foram gerados a partir do original com `System.Drawing` do Windows (redução bicúbica de alta qualidade); o gerador fica pronto para regenerá-los com Pillow/Lanczos em ambiente com Python. Não há dependência de Python/Pillow na compilação do APK.

O `compilar.sh` agora compila `res/` para `saida/res.zip` com `aapt2 compile --dir "$AQUI/res" -o "$SAIDA/res.zip"` e inclui `-R "$SAIDA/res.zip" --auto-add-overlay` no link. A combinação permite adicionar os mipmaps como recursos novos. Referência de sintaxe: [AAPT2](https://developer.android.com/tools/aapt2). Não é necessário gerar `R.java`: o Java não referencia recursos próprios.

## Revisão da rodada 2

Java 8 sem AndroidX, bibliotecas, lambdas ou streams; apenas APIs disponíveis no Android 22. Revisão manual dedicada de imports, tipos, classes anônimas, ciclos da Activity/serviço, nulos (`local`, `log`, `energia` e Intent/extras), divisores/valores não finitos, expiração de sinal, consumo de comandos e limpeza de referências ao parar. Nenhum objeto/formatação foi acrescentado a `onDraw`; continuam apenas os dois pulsos de 1 Hz existentes (tela e serviço), sem timer novo para confirmação ou resultado. O toque longo usa o reconhecimento padrão de `View`.

As APIs de diagnóstico são antigas: `GpsStatus.GPS_EVENT_FIRST_FIX`, `getTimeToFirstFix()` e `GpsSatellite.getSnr()` (API 3); `sendExtraCommand()` e `onNewIntent()` (API 1); `getElapsedRealtimeNanos()` (API 17); `PowerManager.isInteractive()` e remoção de animação/elevação dos botões (API 20/21). Referências: [GpsStatus](https://developer.android.com/reference/android/location/GpsStatus), [GpsSatellite](https://developer.android.com/reference/android/location/GpsSatellite), [LocationManager](https://developer.android.com/reference/android/location/LocationManager).

Passaram `bash -n`, a leitura XML do manifesto e as checagens de UTF-8 sem BOM, finais LF do Bash e dimensões dos quatro PNG. Simulações numéricas em Node executaram os corpos dos métodos de cálculo extraídos do Java, substituindo tipos, relógio e `Location` por posições sintéticas: Doppler sem precisão com coordenadas instáveis, repouso, limites de 0,5/10 m/s e 3 s, buracos, fallback, salto/retorno, precisão ruim/ausente, NaN/infinito, amostras antigas/duplicadas/futuras, janela de 12 s, volta do buffer e média incluindo espera. Cabeçalho e linha gerada têm 17 colunas. Também passaram simulações das cinco ações ADB, consumo do extra, Intent nulo, extra inválido/ação desconhecida, parada direta, SNR máximo/limiar 30/NaN, conversão de primeiro fix e limpeza do status GPS. Isso valida a lógica simulada, não a compilação Java ou a integração Android. O `apksigner verify` agora passa por `sed`, que consome toda a saída e evita o risco de SIGPIPE de `head` sob `pipefail`.

**Esta versão ainda precisa compilar no GitHub Actions e ser conferida no Pace.** A máquina de edição não tem JDK/Android SDK. Confira o ícone recortado no launcher, a tela natural 320×300, o toque longo duplo, os cinco comandos ADB, as 17 colunas e os eventos de primeiro fix/AGPS. Teste distância/ritmo em percurso conhecido e repouso com GPS sem precisão, e 30 min de gravação com tela apagada. Limpar AGPS pode prolongar o próximo fix; o retorno do comando não comprova o comportamento interno da Huami. Os 3 s de confirmação exigem uma segunda pressão após o aviso aparecer; se expirar, tente novamente.
