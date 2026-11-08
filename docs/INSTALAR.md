# Instalar o CRUNNING no iPhone (pelo Windows, sem Mac)

Guia para quem não faz isso há tempo. Siga na ordem; cada passo diz o que conferir antes de seguir.
Conferido nas páginas oficiais em 08/11/2026 (Sideloadly 0.71.0, docs do SideStore, imagens de runner do GitHub). Essas ferramentas mudam com frequência: se uma tela estiver diferente, a seção "Problemas comuns" e as páginas oficiais têm a palavra final.

## Como funciona, em uma frase

O GitHub compila o app num Mac dele e entrega um arquivo `CRUNNING.ipa` **sem assinatura**; no seu PC, o **Sideloadly** assina esse arquivo com o **seu Apple ID gratuito** e instala no iPhone pelo cabo. A assinatura gratuita vale **7 dias**; depois é só reinstalar por cima (os dados ficam).

| Limite do Apple ID gratuito | O que significa para o CRUNNING |
|---|---|
| App funciona por 7 dias | Reinstalar por cima toda semana (passo 7). |
| Até 3 apps instalados "por fora" ao mesmo tempo | O CRUNNING ocupa 1 (a extensão da Live Activity pode contar como mais 1). |
| Até 10 App IDs a cada 7 dias | O app usa 2 (app + extensão). Reinstalar com o mesmo Apple ID não gasta novos. |
| Sem Apple Saúde | As corridas ficam no histórico do app e saem em GPX (Ajustes mostra o modo). |

---

## 1. Repositório no GitHub e envio do código

Você já tem conta no GitHub (`Caiosmiderle`). Se não tivesse, seria criar em github.com > Sign up.

1. Entre em https://github.com/new.
2. **Repository name**: `crunning`. Marque **Public**. **Não** marque README, .gitignore nem licença (o projeto já tem tudo). Clique em **Create repository**.
3. No Windows, abra o PowerShell **dentro da pasta do projeto** (`C:\Users\caiog\OneDrive\Área de Trabalho\Claude Code\crunning-app`) e rode:

```bash
git remote add origin https://github.com/Caiosmiderle/crunning.git
```

```bash
git push -u origin main
```

4. Se abrir uma janela de login do GitHub (Git Credential Manager), entre pelo navegador e autorize.

**Conferir:** a página `https://github.com/Caiosmiderle/crunning` mostra as pastas `App`, `CrunningCore`, `docs` e o arquivo `project.yml`.

> Por que público: no repositório público os builds no Mac do GitHub são grátis e sem limite. O código nunca tem dado pessoal nem chave, e o `.ipa` publicado não é assinado, então sozinho não instala em lugar nenhum.

## 2. Gerar o `.ipa` e baixar

1. No repositório, abra a aba **Actions**. Se aparecer um aviso para habilitar workflows, clique em **I understand my workflows, go ahead and enable them**.
2. À esquerda, clique em **Build**. À direita, **Run workflow** > deixe a branch `main` e a caixa "Publicar o .ipa também como Release" marcada > **Run workflow**.
3. Espere de 10 a 20 minutos. A execução fica com um círculo amarelo e termina com um ✓ verde.
4. Baixe o arquivo por um destes caminhos:
   - **Release (mais fácil):** na página inicial do repositório, coluna da direita, **Releases** > a mais recente (`CRUNNING build-N`) > clique em `CRUNNING.ipa`.
   - **Artefato:** na página da execução, role até **Artifacts** > `CRUNNING-build-N`. Vem um `.zip`; extraia para ter o `CRUNNING.ipa`. Artefatos somem depois de 30 dias; Releases ficam.
5. O navegador salva em `C:\Users\caiog\Downloads\CRUNNING.ipa`.

**Conferir:** o arquivo tem alguns MB. Opcional: confira se não corrompeu comparando o hash com o `CRUNNING.ipa.sha256` da Release:

```powershell
certutil -hashfile "$env:USERPROFILE\Downloads\CRUNNING.ipa" SHA256
```

Se o ✓ ficou vermelho (falhou), não precisa entender o log: me avise que eu leio e corrijo.

## 3. Preparar o Windows (iTunes, iCloud e Sideloadly)

O Sideloadly exige o iTunes e o iCloud **na versão baixada do site da Apple**, não a da Microsoft Store.

1. Em **Configurações > Aplicativos > Aplicativos instalados**, procure "iTunes" e "iCloud". Se algum veio da Microsoft Store, **desinstale**.
2. Abra https://sideloadly.io/faq e use os links de download do iTunes e do iCloud que estão lá (apontam para os servidores da Apple). Instale os dois e reinicie o PC se pedir.
3. Baixe o Sideloadly **só do site oficial** https://sideloadly.io (versão Windows) e instale.

**Conferir:** o iTunes abre normalmente e o Sideloadly abre mostrando os campos de iDevice, Apple ID e IPA.

## 4. Conectar o iPhone

1. Ligue o iPhone no PC pelo cabo e desbloqueie a tela.
2. No iPhone, toque em **Confiar neste computador** e digite o código.
3. **Modo de Desenvolvedor:** o iOS 26 exige para apps instalados assim. Vá em **Ajustes > Privacidade e Segurança > Modo de Desenvolvedor**, ative, reinicie quando pedir e, depois de reiniciar, confirme **Ativar**.
   - Se a opção não aparecer ainda, normal: ela costuma surgir depois da primeira instalação pelo Sideloadly. Faça o passo 5 e volte aqui.

**Conferir:** o iPhone aparece no iTunes e no campo **iDevice** do Sideloadly.

## 5. Assinar e instalar pelo Sideloadly

1. No Sideloadly, em **iDevice**, escolha o seu iPhone.
2. Arraste o `CRUNNING.ipa` para o ícone de IPA (ou clique nele e escolha o arquivo).
3. Em **Apple ID**, digite o e-mail do Apple ID que vai assinar o app.
4. **Não mexa** nas opções avançadas: não troque o Bundle ID nem remova extensões. O Bundle ID igual é o que permite reinstalar por cima sem perder dados, e a extensão é a da Live Activity.
5. Clique em **Start**. O Sideloadly pede a **senha do Apple ID** e, na primeira vez, o **código de verificação** (2FA) que aparece nos seus aparelhos Apple. Digite os dois.
6. Espere a mensagem **Done**.

Sobre a senha:
- Com Apple ID gratuito, a "senha de app" (app-specific password) **não funciona**; o próprio Sideloadly diz que ela só vale para conta de desenvolvedor paga. Precisa ser a senha normal.
- A senha vai para um programa de terceiros (o Sideloadly) que fala com a Apple. Se preferir não expor o Apple ID principal (fotos, compras, cartão), crie um **Apple ID secundário** gratuito só para isso em https://account.apple.com e use ele aqui. Funciona igual; o certificado só precisa ser sempre do mesmo Apple ID.

**Conferir:** o ícone verde do CRUNNING aparece na tela de início do iPhone.

## 6. Confiar no certificado e abrir

1. No iPhone: **Ajustes > Geral > VPN e Gerenciamento de Dispositivo**.
2. Em **App de Desenvolvedor**, toque no e-mail do Apple ID usado no Sideloadly > **Confiar** > **Confiar** (precisa de internet).
3. Abra o CRUNNING.

**Conferir (teste da fase 2):**
- Abre na aba **Hoje**, com o logo, a data no selo e o cartão "Nada planejado".
- As quatro abas funcionam: Hoje, Plano, Histórico, Ajustes. A barra de abas encolhe quando você rola.
- **Ajustes > Sobre** mostra "0.2.0 (build N)" e **Ajustes > Apple Saúde** mostra "Histórico local + GPX".
- Ligue **Ajustes > Modo de desenvolvimento**, vá em **Histórico > Gerar corrida de exemplo** duas ou três vezes: as corridas aparecem e o cartão "Esta semana" da aba Hoje soma os números.
- Feche o app (deslize para cima no seletor de apps), abra de novo: as corridas continuam lá.
- Troque **Distância** para Milhas e **Tema** para Claro: tudo muda na hora.
- Em **Hoje**, arraste o controle "Deslize para correr" até o fim: vibra e mostra o aviso. Solte no meio: ele volta.
- Opcional: **Ajustes do iPhone > Acessibilidade > Tela e Tamanho do Texto > Reduzir Transparência** deixa os cartões opacos; **Reduzir Movimento** tira a animação de entrada.

## 7. Renovar a cada 7 dias (sem perder dados)

A assinatura gratuita vence em 7 dias. Quando vence, o app não abre, mas **os dados continuam no iPhone** enquanto você não apagar o app.

1. Conecte o iPhone, abra o Sideloadly.
2. Mesmo **Apple ID**, mesmo `CRUNNING.ipa` (ou um mais novo) > **Start**.
3. Pronto: instala por cima, com os dados intactos. Não precisa confiar no certificado de novo enquanto for o mesmo Apple ID.

Regras de ouro: **nunca apague o app** do iPhone para reinstalar (apagar apaga os dados) e use **sempre o mesmo Apple ID**.

Renovar sem lembrar (opcional): o Sideloadly tem um serviço em segundo plano que renova sozinho os apps perto de vencer quando encontra o iPhone pelo cabo ou pelo Wi-Fi (o PC ligado e o iPhone na mesma rede, com a sincronização por Wi-Fi ativada no iTunes). Veja a opção na tela do Sideloadly.

### Alternativa: renovar no próprio iPhone (SideStore)

Se cansar de ligar no PC toda semana, o **SideStore** renova os apps pelo próprio iPhone. O PC só é necessário na primeira instalação.

- Na primeira vez, no Windows, instale o SideStore com o **iloader** (instalador oficial indicado pelo SideStore) e, no iPhone, o app **LocalDevVPN** da App Store. A VPN precisa estar ligada sempre que o SideStore instalar, atualizar ou renovar.
- Limites: o próprio SideStore ocupa 1 dos 3 apps. Sobram 2, o que basta para o CRUNNING com a extensão.
- Guias de terceiros relatam que a renovação ficou menos estável a partir do iOS 26.4. Por isso o caminho principal deste guia é o Sideloadly.
- Passo a passo oficial e sempre atualizado: https://docs.sidestore.io

## 8. Atualizar para uma versão nova

1. Quando eu avisar que há versão nova (ou você quiser gerar uma), repita o **passo 2** (Run workflow) e baixe o novo `CRUNNING.ipa`.
2. Repita o **passo 5** com o mesmo Apple ID. Instala por cima e mantém os dados.
3. Confira em **Ajustes > Sobre** que o número do build subiu.

Atualizar também renova os 7 dias.

## 9. Problemas comuns

**"Your maximum App ID limit has been reached. You may create up to 10 App IDs every 7 days."**
Cada Bundle ID diferente gasta um App ID; o CRUNNING usa 2. Acontece se você instalou muitos apps diferentes na semana ou trocou o Bundle ID. Espere alguns dias ou use outro Apple ID (mas aí o app conta como novo, e é preciso confiar no certificado de novo). Não troque o Bundle ID.

**Limite de 3 apps.**
Se você já tem outros apps instalados por fora, remova um. Se o Sideloadly reclamar de espaço por causa da extensão, me avise antes de usar "remover extensões": sem ela, a Live Activity (fase 6) não funciona.

**"Desenvolvedor Corporativo Não Confiável" ou "não foi possível verificar o app".**
Falta o passo 6 (confiar no certificado), ou o iPhone estava sem internet na hora. Refaça com Wi-Fi ou dados ligados.

**O app abre e fecha na hora, ou diz que "não está mais disponível".**
Assinatura vencida (passo 7) ou Modo de Desenvolvedor desligado (passo 4).

**O Sideloadly não vê o iPhone.**
Troque o cabo/porta, desbloqueie o iPhone e toque em Confiar de novo, confira se o iTunes é a versão do site da Apple (passo 3) e reinicie o PC. Se você instalou o app **Dispositivos Apple** (Apple Devices) da Microsoft Store, ele pode atrapalhar o iTunes: desinstale e teste de novo.

**Erro de login no Sideloadly.**
Confira a senha do Apple ID (não a senha de app), digite o código 2FA quando aparecer e atualize o Sideloadly para a versão mais nova do site oficial.

**Live Activity não aparece (a partir da fase 6).**
Ajustes do iPhone > CRUNNING > **Atividades ao Vivo** ligado; e Ajustes > Face ID e Código > permitir **Atividades ao Vivo** com o iPhone bloqueado. Confira também se a extensão não foi removida na instalação.

**GPS parando em segundo plano (a partir da fase 3).**
Dê a permissão de localização pedida pelo app, não feche o app à força durante a corrida (deslizar para cima no seletor mata a gravação) e evite o Modo de Pouca Energia em corridas longas.

**Apple Saúde indisponível.**
Esperado com Apple ID gratuito: a Apple não libera o Saúde nesse tipo de instalação. As corridas ficam no histórico e poderão ser exportadas em GPX. Com a conta paga (US$ 99/ano, decisão da fase 7), o Saúde passa a funcionar.

**O build no GitHub falhou (✓ vermelho).**
Abra a execução, veja o passo em vermelho e me mande o link da execução. Quando a compilação falha, o log completo fica em **Artifacts** (`xcodebuild-log-N`).
