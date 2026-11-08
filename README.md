# CRUNNING

App nativo de iPhone para planejar e executar treinos de corrida. Uso pessoal, um único usuário, dados no aparelho, sem servidor.

## Situação

Fase 3 (corrida livre com GPS): gravação em segundo plano com pausa manual e automática, tempo em movimento, ritmo atual, parciais, recuperação se o iOS fechar o app, histórico com mapa colorido pelo ritmo, gráficos de ritmo e altitude, esforço percebido e exportação em GPX. Simulação de GPS para testar em casa. Instalar: [docs/INSTALAR.md](docs/INSTALAR.md). Testar na rua: [docs/TESTES-NA-RUA.md](docs/TESTES-NA-RUA.md).

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
