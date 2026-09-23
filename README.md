# proj

Atalhos de terminal pra abrir projetos no Windows. `proj add mrm -r MRM` cria o comando `mrm`, que entra em `E:\Roblox Projects\MRM` e abre o `claude` lá. Argumentos passam direto: `mrm -c` vira `claude -c`.

Funciona no cmd, no PowerShell 7 e no Windows PowerShell 5.1.

## Instalação

```powershell
git clone <url-do-repo> proj
cd proj
powershell -ExecutionPolicy Bypass -File install.ps1
```

Abra um terminal novo e rode `proj`.

## Pastas base

Cada pessoa configura as suas. A chave vira a flag usada no `add`.

```
proj base add r "E:\Roblox Projects"
proj base add w "E:\Projects"
proj base                  # lista
proj base rm w
```

## Atalhos

```
proj add mrm -r MRM          # E:\Roblox Projects\MRM
proj add novo -r             # E:\Roblox Projects\novo (sem pasta, usa o nome)
proj add kito -w KitoTask    # E:\Projects\KitoTask
proj add x "D:\qualquer"     # pasta qualquer
proj add x                   # pasta atual
proj list
proj rm mrm                  # apaga só o atalho, nunca a pasta do projeto
```

Se a pasta do projeto não existir, ela é criada.

## Configuração

Tudo fica em `%USERPROFILE%\.proj`, fora do repo:

- `config.json`: pastas base e o comando que os atalhos rodam (`"command": "claude"`; troque por `code .`, por exemplo).
- `bin\`: o `proj.bat` e os atalhos. O `install.ps1` coloca essa pasta no início do PATH do usuário.

Pra usar outro lugar, defina a variável `PROJ_HOME` antes de instalar.

## Testes

```powershell
pwsh -File test.ps1
```

## Desinstalar

Apague `%USERPROFILE%\.proj` e tire `%USERPROFILE%\.proj\bin` do PATH do usuário.
