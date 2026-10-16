# Towers of Ages

Cooperative first-person tower defense across the ages (1–5 players).

## Jogar

1. Baixe o **`TowersOfAges-Launcher.exe`** na [última release](https://github.com/vitorrubi/towers-of-ages/releases/latest).
2. Coloque numa pasta só dele (ex: `Documentos\Towers of Ages\`) e abra.
3. O launcher baixa o jogo na pasta `game\` ao lado dele e, a cada abertura, atualiza sozinho quando sai versão nova.

## Como funciona

Este repositório contém só o launcher (projeto Godot 4.6). O código do jogo é privado; as Releases daqui hospedam os builds.

Ao abrir, o launcher consulta `api.github.com/repos/vitorrubi/towers-of-ages/releases/latest`, compara a tag com `game/version.txt` e, se mudou, baixa o asset `TowersOfAges-*.zip` e extrai em `game/`.

## Publicar uma versão nova do jogo

1. Suba `config/version` no `project.godot` do jogo e exporte (`build/TowersOfAges.exe`).
2. Zipe o `.exe` (e o `.bat` de modo compatível) como `TowersOfAges-vX.Y.Z.zip`.
3. Crie a release com tag `X.Y.Z` e anexe o zip (e o launcher, se mudou):

```
gh release create 0.9.0 TowersOfAges-v0.9.0.zip TowersOfAges-Launcher.exe -R vitorrubi/towers-of-ages --title "Towers of Ages 0.9.0"
```

A release mais recente sempre precisa ter o zip do jogo — é dela que o launcher baixa.
