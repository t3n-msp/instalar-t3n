# instalar-t3n

Prepara um PC Windows para os plugins da t3n no Claude: instala, por usuário, sem admin e
sem PowerShell, o que faltar entre o Git for Windows, o Claude desktop e o Claude Code CLI.

No Prompt de Comando (cmd):

```bat
curl -fsSL --ssl-revoke-best-effort -o "%TEMP%\instalar-t3n.cmd" https://raw.githubusercontent.com/t3n-msp/instalar-t3n/main/instalar-t3n.cmd && "%TEMP%\instalar-t3n.cmd"
```

O `--ssl-revoke-best-effort` só tolera um servidor de revogação fora do alcance (comum em rede
corporativa); o certificado continua sendo conferido.

Atrás de um proxy, passe o proxy aos dois: `curl -x http://<proxy>:<porta> ...` e
`instalar-t3n.cmd /proxy http://<proxy>:<porta>/`. Sem o `/proxy`, o instalador usa o proxy
do ambiente ou o do Windows, quando ele está no formato `host:porta`.
`/conferir` só baixa e confere o Git, sem instalar.

Gerado a partir do repo de plugins da t3n: não edite aqui, a próxima publicação substitui tudo.
