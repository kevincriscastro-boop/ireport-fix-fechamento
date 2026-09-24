# iReport 4.0.1 fecha sozinho ao abrir .jrxml — correção

Correção para o **Jaspersoft iReport Designer 4.0.1** que, no Windows 10/11 atualizado,
**fecha sem nenhuma mensagem de erro** ao abrir ou editar um arquivo `.jrxml`.

A causa é uma incompatibilidade entre o Java 6 embutido no iReport e a versão atual da
fonte **Arial** do Windows. O conteúdo do relatório não tem nada a ver com o problema.

## Sintoma

- O iReport abre normalmente.
- Ao abrir um `.jrxml` (pelo menu *Arquivo > Abrir* ou por plugin de integração com ERP),
  a janela **fecha na hora**, sem aviso.

## Confirme que é este problema

Na pasta de instalação do iReport (onde fica o `ireport.exe`), abra o `hs_err_pid*.log`
mais recente. Se aparecer algo assim, é este bug:

```
# EXCEPTION_ACCESS_VIOLATION (0xc0000005) at pc=0x...
# JRE version: 6.0_45-b06
# Problematic frame:
# C  [fontmanager.dll+0x...]  Java_sun_font_FileFontStrike__1getGlyphImageFromWindows
```

> Se o `hs_err_pid*.log` mostrar outra coisa (falta de memória, outro tipo de exceção),
> a causa é diferente e esta correção **não** se aplica.

## Causa

1. Relatórios sem fonte explícita usam a fonte lógica `SansSerif` do JasperReports.
2. O Java 6 embutido (`jdk1.6.0_45`) mapeia `SansSerif` para a **Arial** do Windows,
   no arquivo interno `fontconfig.properties`.
3. O Windows Update trouxe uma versão nova do arquivo da Arial, e o renderizador de fontes
   do Java 6 (de 2013) não consegue processá-la: ele trava com acesso inválido à memória
   ao desenhar texto em negrito.

## Solução

Apontar `SansSerif` para as fontes **Lucida Sans**, que já vêm dentro do próprio Java 6
(`jdk1.6.0_45\jre\lib\fonts`) e são compatíveis com ele.

### Opção 1: script automático

Feche o iReport e rode no PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\aplicar-correcao.ps1 -IReportDir "C:\caminho\do\iReport-4.0.1"
```

O script:

- cria o `fontconfig.properties` a partir do `.src`, fazendo backup de um que já exista;
- troca as 4 linhas da fonte;
- desativa os caches `.bfc`.

Para desfazer, rode o mesmo comando com `-Reverter` no final.

### Opção 2: manual

Na pasta `<instalação do iReport>\jdk1.6.0_45\jre\lib\`:

1. Copie `fontconfig.properties.src` para um novo arquivo chamado `fontconfig.properties`.
2. Renomeie os caches binários para o Java deixar de usá-los:
   - `fontconfig.bfc` → `fontconfig.bfc.DISABLED`
   - `fontconfig.98.bfc` → `fontconfig.98.bfc.DISABLED`
3. No `fontconfig.properties`, altere **apenas** estas 4 linhas (veja também
   [`fontconfig.patch`](fontconfig.patch)):

   | Antes | Depois |
   |---|---|
   | `sansserif.plain.alphabetic=Arial` | `sansserif.plain.alphabetic=Lucida Sans Regular` |
   | `sansserif.bold.alphabetic=Arial Bold` | `sansserif.bold.alphabetic=Lucida Sans Demibold` |
   | `sansserif.italic.alphabetic=Arial Italic` | `sansserif.italic.alphabetic=Lucida Sans Italic` |
   | `sansserif.bolditalic.alphabetic=Arial Bold Italic` | `sansserif.bolditalic.alphabetic=Lucida Sans Demibold Italic` |

4. Salve o arquivo, feche **todas** as janelas do iReport e abra-o de novo.

> **Importante:** a mudança afeta só a fonte que aparece na **tela de design** do iReport,
> para textos sem fonte explícita. A fonte da impressão final continua definida pelo
> servidor ou sistema que gera o relatório.

## O que NÃO funcionou

Fica registrado aqui para ninguém repetir:

- **Trocar o Java embutido por Java 8** (`jdkhome` no `etc\ireport.conf`): o lançador
  NetBeans antigo não aceita Java mais novo, e o iReport fecha antes de abrir a janela.
- **Desativar a aceleração gráfica e aumentar a memória** (`-Dsun.java2d.d3d=false`,
  `-Dsun.java2d.noddraw=true`, `-Dsun.java2d.ddoffscreen=false`, `-Xmx` maior): o crash
  continua no mesmo ponto.

## Ambiente testado

- Jaspersoft iReport Designer 4.0.1 com JRE embutido 6.0_45-b06 (64 bits)
- Windows 11
