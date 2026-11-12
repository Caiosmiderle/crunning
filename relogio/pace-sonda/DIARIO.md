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

## 11/11/2026 (noite): as páginas do launcher sumiram e voltaram

**O que o Caio viu:** só sobraram Esportes, Batimento, Clima, Música, Atividades e a página do CRUNNING. Sumiram Timer, Cronômetro, Bússola, Alarme, Dados (passos), Sono, Central de treino e Local.

**Nada foi desinstalado.** Os apps da Huami ficam em `/system` e não saem sem root. O que mudou foi a configuração de páginas do launcher.

**Onde fica a configuração:** na tabela `system` do Android.
- `springboard_widget_order_in`: a lista que o launcher segue. Formato JSON `{"data":[{pkg, cls, title, srl, enable}]}`, em que `srl` é a ordem e `enable` vale 1 ou 0. A primeira página fica à esquerda do mostrador e as outras à direita.
- `springboard_widget_order_out`: as 14 páginas que existem neste relógio.

A lista `_in` estava no padrão de fábrica: títulos em chinês, apps chineses que nem existem no Pace, e só 5 páginas ligadas.

**Causa provável:** o travamento do launcher com a versão 4, que forçava retrato. Ao recriar o launcher, ele voltou para a lista de fábrica. A montagem das 19:34 (logo depois) já mostrava a lista reduzida.

**Correção:** um `settings put system springboard_widget_order_in '<json>'`, mantendo o formato e ligando de novo as 8 páginas instaladas, na ordem do `_out`.
- O launcher aplicou na hora, sem reiniciar (log `Hmspringboard: mark 即将ENABLE widget`).
- Ele também salvou a lista em `l.widget.sort`, que vai para o app do celular.
- Nenhuma falha no log. As 13 páginas e o CRUNNING aparecem (`crunning-artifacts/pace-sonda/paginas-restauradas.png`).

**Cópias:** `crunning-artifacts/pace-sonda/launcher-backup/` guarda a lista resetada, a restaurada, a `_out` e o script que montou a nova.

**Regra daqui em diante:** depois de instalar ou atualizar o app no Pace, conferir `adb shell settings get system springboard_widget_order_in`. Se voltar ao padrão, dar push do `.restaurado.txt` dentro de um `settings put` (por script em `/data/local/tmp`, por causa das aspas).

## Próximo teste (na rua)

1. Fora de casa, abra o CRUNNING no relógio (última página), toque em **Começar** e espere **GPS ok** (3 a 5 min na primeira vez) antes de correr.
2. Corra 30 min sem mexer no relógio.
3. Em casa, toque em **Parar** duas vezes e ligue no PC.

O que medir com isso: se o app sobrevive à corrida inteira, se a distância pela velocidade bate com um percurso conhecido, quanto de bateria gasta e o que a tela mostra com a luz apagada.
