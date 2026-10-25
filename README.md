# Sound Mix

Sound Mix é um aplicativo gratuito para macOS que reúne o controle de áudio do Mac em uma janela e em um painel na barra de menus. Ele é feito com SwiftUI e Core Audio.

## O que o app faz

- Ajusta o volume geral e silencia a saída de áudio padrão, quando o dispositivo permite.
- Mostra os aplicativos com áudio ativo e oferece controle de volume individual.
- Alterna entre as saídas de áudio disponíveis no Mac.
- Permite editar as cenas Foco, Reunião e Descanso, escolhendo apps em destaque e os volumes geral e dos demais apps.
- Oferece acesso rápido pela barra de menus.
- Acompanha a aparência do macOS ou permite escolher os temas claro e escuro em Ajustes.

Em **Cenas**, use **Editar** para escolher os apps em destaque, o volume geral e o volume dos demais apps. Apps em destaque ficam em 100% do controle individual quando emitem áudio; os demais ficam no nível configurado. É possível selecionar apps abertos ou adicionar um app instalado para que a escolha funcione mesmo quando ele iniciar depois. As escolhas são salvas no Mac. Ao desativar uma cena, o mix anterior é restaurado; ao alternar entre cenas, o mix anterior continua guardado até a desativação. Os valores iniciais são: Foco 64% geral e 65% demais; Reunião 72% geral e 35% demais; Descanso 38% geral e 80% demais. Nenhum app vem selecionado inicialmente.

Saídas sem controle de volume geral ainda podem receber os ajustes por aplicativo. O controle por aplicativo depende dos recursos de captura de áudio do macOS e pode exigir permissão do sistema na primeira utilização.

## Requisitos

- macOS 14.2 ou mais recente.
- Xcode com suporte ao SDK do macOS correspondente.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) para gerar o projeto do Xcode.

## Desenvolver

Na pasta deste repositório:

```sh
brew install xcodegen
xcodegen generate --spec project.yaml
open soundMix-app.xcodeproj
```

Para compilar pela linha de comando:

```sh
xcodebuild -project soundMix-app.xcodeproj \
  -scheme soundMix-app \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  build
```

O arquivo `project.yaml` é a fonte de configuração do projeto. A pasta `soundMix-app.xcodeproj` é gerada localmente e fica fora do Git.

## Estrutura

| Caminho | Conteúdo |
| --- | --- |
| `SoundMix/` | Interface SwiftUI, controle de áudio e recursos visuais. |
| `Info.plist` | Metadados do aplicativo e descrição da permissão de áudio. |
| `project.yaml` | Configuração do projeto XcodeGen. |
| `scripts/generate_icon.swift` | Geração dos ícones do app. |
| `scripts/install-app.sh` | Geração, compilação Release e instalação local do app. |

O código C em `SoundMix/RealtimeGain.c` faz parte do processamento de áudio por aplicativo e é exposto ao Swift pelo bridging header.

## Instalação local

Para compilar e instalar em `/Applications`, execute `./scripts/install-app.sh`. O script gera o projeto antes do build. Use `SOUNDMIX_INSTALL_DIR` para escolher outra pasta de instalação.

Em **Ajustes**, a opção **Iniciar com o sistema** registra o app instalado para abrir no próximo início de sessão. Se o macOS exigir aprovação, use o atalho exibido pelo Sound Mix para autorizá-lo nos Itens de Início de Sessão.

## Licença

O código deste repositório é distribuído sob a [licença MIT](LICENSE).
