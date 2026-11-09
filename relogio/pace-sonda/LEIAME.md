# Sonda do CRUNNING para o Amazfit Pace

App de teste, não é o app de corrida. Responde três perguntas antes de investir num app de verdade para o relógio:

1. Um app de terceiros consegue ler o **batimento** (sensor padrão do Android, tipo 21) e o **GPS** do Pace?
2. Ele **continua vivo** com a tela apagada durante uma corrida inteira, ou o sistema da Huami o mata?
3. O que a **tela** mostra depois que a luz apaga (14 s): o app continua visível ou volta o mostrador?

## O relógio

Amazfit Pace, Android 5.1 (API 22), processador MIPS (por isso Java puro, sem código nativo), tela 320x300. O ADB funciona pelo cabo de carga sem root nem desbloqueio; instalar pelo `adb install` é o caminho normal de desenvolvedor.

## O que ela grava

Uma linha por segundo em `/sdcard/CRUNNING-sonda/sonda-AAAAMMDD-HHMMSS.csv`:
segundos, batimento (vazio se não chegou leitura nos últimos 5 s), se havia sinal de GPS, precisão, velocidade, satélites usados e vistos, bateria, tela ligada e app visível. Linhas que começam com `#` são eventos (início, fim, sistema com pouca memória, serviço recriado).

**Não grava latitude nem longitude.** O arquivo fica no relógio e no PC (`crunning-artifacts`), nunca no repositório.

## Instalar e rodar (PC com o relógio no cabo)

O ADB fica em `C:\Users\caiog\crunning-artifacts\ferramentas\platform-tools`.

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
adb pull /sdcard/CRUNNING-sonda C:\Users\caiog\crunning-artifacts\pace-sonda
```

## O que já foi conferido (09/11/2026, relógio no cabo)

- Instala pelo ADB e abre; a tela aparece certa (320x300).
- **Começar** sobe o serviço em primeiro plano; o sensor encontrado é "Heart Rate Sensor / Huami Tech"; o CSV recebe uma linha por segundo e **Parar** grava o evento "fim".
- No carregador, a tela de carga da Huami cobre o app quando a tela acorda, e depois que a luz apaga volta o mostrador. Por isso o batimento e o GPS só dá para testar fora do cabo.

## O teste na rua

1. Fora do cabo, procure **CRUNNING sonda** na lista de apps do relógio. Se não aparecer, ligue no PC e inicie por lá (`adb shell am start ...` e toque em Começar). Com o app aberto, toque em **Começar**. Espere o GPS ficar "ok" e o batimento aparecer.
2. Deixe a luz apagar sozinha e anote o que a tela mostra.
3. Corra 30 minutos sem mexer no relógio (pode olhar o pulso).
4. Em casa, toque em **Parar** (se o app ainda estiver lá) e ligue o relógio no PC.

O botão **Tela: sempre** testa a tela sempre acesa; deixe em "normal" no primeiro teste.
