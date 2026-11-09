# Índice de artefatos (fora do repositório)

Arquivos grandes ou de terceiros ficam em `C:\Users\caiog\crunning-artifacts\` e nunca entram aqui. Este índice guarda só o que identifica cada um: origem, hash e onde está.

| Artefato | Origem | SHA-256 | Onde está | Observação |
|---|---|---|---|---|
| `rea-main.zip` (REA, Reverse Engineer Anything) | Baixado por você em 26/10/2026 (`Downloads`) | `48831d234eb1ec541892957dd9a0d0ddbbf1d3e371fc5b3f9df81ae6891a8b8a` | `crunning-artifacts\rea\rea-main\` | Tratado como não confiável: extraído com checagem de caminhos, só lido (skill `reverse-engineer-anything`, versão 49). Nenhum script de dentro dele foi executado. |
| `com.runbuddy.prod-8.55.0-APK4Fun.com.apk` (Runna 8.55.0, só o APK base) | Baixado por você do APK4Fun em 08/11/2026 | `e58425da349220950acf55513f8b6175c7de9c3ced56a7260f509377a0469ae2` | `crunning-artifacts\apk\` | Assinatura declarada (REA, sem verificação criptográfica): v2/v3 `3eaaa885…4e7864`, v3.1 `fad6269b…a15ab9` (rotação), selo de origem `3257d599…bbd6d`. O Android recusou instalar sozinho: faltam os splits (`INSTALL_FAILED_MISSING_SPLIT`). |
| `index.android.bundle` (Runna 8.55.0, bytecode Hermes v96) | Extraído do APK base acima | `c6baefaede22d53adacfaabefe8e1c3802a35f86173fecafd3984985670fddcb` | `crunning-artifacts\analise-runna\` | Junto: resultado do REA (`pacote.yaml`, evidência `ev_aa9fb113…`), resumo do manifesto, textos filtrados (sem chaves, tokens e endereços) e índice por assunto. Conclusões em [analise-runna.md](analise-runna.md). |
| Ferramentas da fase 1 | Node 24.22.2 (nodejs.org), JDK 21.0.13 (Microsoft), JADX headless MCP 0.7.1 (GitHub do autor, hash fixado pelo REA), emulador e imagem Android 15 copiados do Treinapp | Node e JADX conferidos pelo hash publicado; JDK pelo `.sha256sum.txt` da Microsoft | `crunning-artifacts\ferramentas\`, `crunning-artifacts\android-sdk\` | Uso pela linha de comando, com variáveis só no processo; nada registrado no Windows nem no Claude. |
| `CRUNNING-build-N.ipa` | GitHub Actions deste repositório (Release `build-N`) | Publicado junto da Release (`CRUNNING.ipa.sha256`) | `crunning-artifacts\ipa\` | Cópia local dos builds instalados. |
