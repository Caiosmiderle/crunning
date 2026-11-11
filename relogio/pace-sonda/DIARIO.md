# Diário da sonda do Pace

Registro do que foi feito e descoberto no Amazfit Pace, para retomar sem precisar reconstruir a história.

## 09/11/2026: o relógio aceita app de fora

- O Pace aparece no USB como Android com depuração (18D1:4EE2). O ADB funciona sem root. Ele roda Android 5.1 (API 22) com processador MIPS, firmware de 2019 e tela 320x300.
- Sensores: batimento padrão do Android (tipo 21), barômetro e GPS liberado a apps.
- Sonda 1 e 2: app Java puro, compilado no GitHub sem Gradle. Grava um CSV por segundo, sem coordenadas, em `/sdcard/CRUNNING-sonda`.

## 11/11/2026: interface, GPS e ícone

**Interface (feita pelo Codex):** visual do CRUNNING adaptado à tela transflexiva. Ritmo atual suavizado em 12 s como número principal, depois médio, tempo, batimento, distância, status, Começar/Parar com confirmação e tela sempre acesa.

**Bug do launcher (versão 4):** o manifesto forçava retrato. Como o Pace é paisagem natural, abrir o app mudava a tela para 230x300 e recriava o launcher da Huami, que travava ("Launcher has stopped"). Corrigido na versão 5. Regra: nunca forçar orientação.

**Batimento:** funciona no pulso. Houve leitura em cerca de 75% dos segundos, começando uns 15 s depois de iniciar.

**Gravação com a tela apagada:** aguentou nos testes curtos de 6 a 7 min (a tela ficou ligada só 26 dos 341 s). O teste de 30 min correndo ainda não foi feito.

**GPS:**
- Dentro de casa ele quase não vê satélite.
- Ao ar livre, a primeira posição veio entre 1 e 3 min (primeiro fix registrado: 186 s), vendo de 4 a 11 satélites com sinal forte (SNR máx. 37 a 40).
- O sistema da Huami entrega a posição sem precisão (`acc=???`) e sem satélites "em uso" para apps de fora. Só a velocidade vem.
- A versão 1 da conta descartava essas posições, e a distância ficava em 0. A versão 6 (Codex) soma a distância pela velocidade Doppler × tempo, ignorando abaixo de 0,5 m/s (parado) e acima de 10 m/s (erro).
- Teste parado na versão 6: 2,5 m de deriva em 66 s com sinal, desprezível.
- Teste em movimento: falta.

**Dados de apoio do GPS:** o toque longo no status (ou `--es acao apagar_agps`) pede ao sistema para apagar os dados de apoio. O sistema aceitou ("pedido aceito") em 11/11. Efeito: a próxima busca começa do zero, então espere uns 3 a 5 min ao ar livre.

**Controle pelo ADB:** `adb shell am start -n io.github.caiosmiderle.crunning.sonda/.Principal --es acao comecar|parar|apagar_agps|tela_sempre|tela_normal`.

**Ícone:** o "C" do app do iPhone em `res/mipmap-*`, com o nome "CRUNNING". Ele aparece na última página do launcher do Pace (deslizando para a esquerda a partir do mostrador), então dá para abrir sem o PC.

**Ferramentas:** registros copiados para `crunning-artifacts/pace-sonda/registros`. O GitHub Actions teve um incidente em 11/11 (duas falhas na partida que não eram do código).

## Próximo teste (na rua)

1. Fora de casa, abra o CRUNNING no relógio (última página), toque em **Começar** e espere **GPS ok** (3 a 5 min na primeira vez) antes de correr.
2. Corra 30 min sem mexer no relógio.
3. Em casa, toque em **Parar** duas vezes e ligue no PC.

O que medir com isso: se o app sobrevive à corrida inteira, se a distância pela velocidade bate com um percurso conhecido, quanto de bateria gasta e o que a tela mostra com a luz apagada.
