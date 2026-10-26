# Otimizador Windows 7

Script em lote (`otimizar-win7.bat`) com menu para deixar um PC com Windows 7 mais leve.

## Como usar

1. Copie `otimizar-win7.bat` para o PC.
2. Botão direito no arquivo → **Executar como administrador**.
3. Escolha a opção **1 (Otimização rápida)** e reinicie o PC no final.

## O que cada opção faz

| Opção | O que faz |
|---|---|
| 1 | Roda as opções 2 a 7 em sequência |
| 2 | Cria um ponto de restauração "Antes do Otimizador Win7" |
| 3 | Apaga temporários do usuário e do Windows, cache do IE, miniaturas, downloads antigos do Windows Update, relatórios de erro e esvazia a lixeira |
| 4 | Limpeza de Disco do Windows marcada em todas as categorias (inclui "Limpeza do Windows Update", que costuma liberar vários GB) |
| 5 | Efeitos visuais em "melhor desempenho" (mantém fontes suavizadas), menus mais rápidos, sem transparência do Aero, desligamento mais rápido |
| 6 | Plano de energia "Alto desempenho" |
| 7 | Desativa Registro Remoto, Fax, compartilhamento do WMP, Painel de Tablet, Relatório de Erros, telemetria e Assistente de Compatibilidade; pergunta se desativa a Indexação |
| 8 | Limpa DNS e reseta Winsock/TCP-IP (ajuda em internet lenta ou com falhas) |
| 9 | Desfragmenta o C: — **só HD**, pergunta antes |
| 10 | Ajustes para SSD: desliga desfragmentação agendada e Superfetch/Prefetch, confirma TRIM |
| 11 | Desativa a hibernação (apaga o `hiberfil.sys`, do tamanho da RAM) |
| 12 | `sfc /scannow` para reparar arquivos do sistema |
| 13 | Lista os programas da inicialização e abre o `msconfig` para desmarcar |
| 14 | Desfaz as opções 5, 6, 7 e 10 |

Grava um log `otimizar-win7.log` na mesma pasta do script. Para voltar tudo de uma vez, use a Restauração do Sistema no ponto criado pela opção 2.

## Dicas além do script

- O que mais pesa num PC com Windows 7 costuma ser o HD mecânico e pouca RAM: trocar por um SSD e ir para 4 GB ou mais dá muito mais ganho do que qualquer ajuste.
- Desmarque na opção 13 os atualizadores (Java, Adobe, Google, etc.) e programas que você não usa toda hora.
- O Windows 7 não recebe mais atualizações de segurança: mantenha um antivírus que ainda suporte o sistema e evite usar o PC para banco.
