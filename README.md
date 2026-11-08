# CRUNNING

App nativo de iPhone para planejar e executar treinos de corrida. Uso pessoal, um único usuário, dados no aparelho, sem servidor.

## Situação

Fase 0 (pasta e perguntas iniciais). Ver o histórico de commits para o andamento.

## Como é feito

- SwiftUI, Swift 6, SwiftData, Swift Charts, MapKit, sem dependências de terceiros.
- Projeto gerado por XcodeGen (`project.yml`), sem precisar abrir o Xcode.
- Compilado num runner macOS do GitHub Actions, que publica um `.ipa` não assinado.
- Instalado no iPhone pelo Windows com Sideloadly. Passo a passo em `docs/INSTALAR.md` (fase 2).
- O conhecimento de treino mora no pacote `CrunningCore` (motor determinístico e testado), com as fontes em `docs/CIENCIA.md` (fase 4).

## Pastas

- `docs/` documentação do projeto. `docs/referencia-design.md` é só referência visual.
- Arquivos grandes (APKs, capturas, vídeos) ficam fora do OneDrive, em `C:\Users\caiog\crunning-artifacts\`, e nunca entram no repositório.

## Regras

- Nenhum dado pessoal real (casa, rotas, peso, saúde) no repositório, nos testes, nos commits ou nos logs. Só dados fictícios.
- Nenhuma chave ou token no repositório, no `.ipa` ou no CI. A chave da Anthropic é colada no app e fica no Keychain.
- Nada de outro app (código, imagens, sons, textos, marca) entra aqui.
- O app não é aconselhamento médico.
