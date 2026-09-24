<#
.SYNOPSIS
    Corrige o crash do iReport Designer 4.0.1 (fecha sozinho ao abrir .jrxml)
    redirecionando a fonte SansSerif do Java 6 embutido de Arial para Lucida Sans.

.DESCRIPTION
    1. Copia fontconfig.properties.src -> fontconfig.properties (com backup se ja existir)
    2. Troca as 4 linhas sansserif.*.alphabetic de Arial para Lucida Sans
    3. Renomeia os caches binarios fontconfig*.bfc para *.bfc.DISABLED

    Com -Reverter, desfaz tudo (restaura os .bfc e remove o fontconfig.properties).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\aplicar-correcao.ps1 -IReportDir "C:\iReport-4.0.1"

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\aplicar-correcao.ps1 -IReportDir "C:\iReport-4.0.1" -Reverter
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$IReportDir,
    [switch]$Reverter
)

$ErrorActionPreference = "Stop"

$lib = Join-Path $IReportDir "jdk1.6.0_45\jre\lib"
$src = Join-Path $lib "fontconfig.properties.src"
$dst = Join-Path $lib "fontconfig.properties"
$caches = @("fontconfig.bfc", "fontconfig.98.bfc")

if (-not (Test-Path $lib)) {
    Write-Host "[ERRO] Pasta nao encontrada: $lib" -ForegroundColor Red
    Write-Host "       Informe em -IReportDir a pasta onde fica o ireport.exe." -ForegroundColor Red
    exit 1
}

# O Java so le o fontconfig na inicializacao - com o iReport aberto a mudanca
# nao teria efeito (e o Windows pode travar a renomeacao dos .bfc).
$rodando = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and $_.Path.StartsWith($IReportDir, [StringComparison]::OrdinalIgnoreCase)
}
if ($rodando) {
    Write-Host "[ERRO] O iReport esta aberto. Feche todas as janelas dele e rode de novo." -ForegroundColor Red
    exit 1
}

if ($Reverter) {
    foreach ($c in $caches) {
        $desativado = Join-Path $lib "$c.DISABLED"
        if (Test-Path $desativado) {
            Rename-Item $desativado $c
            Write-Host "[OK] Restaurado $c"
        }
    }
    if (Test-Path $dst) {
        Remove-Item $dst
        Write-Host "[OK] Removido fontconfig.properties"
    }
    Write-Host "Correcao desfeita. Reinicie o iReport." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $src)) {
    Write-Host "[ERRO] Arquivo nao encontrado: $src" -ForegroundColor Red
    exit 1
}

if (Test-Path $dst) {
    $backup = "$dst.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item $dst $backup
    Write-Host "[OK] Backup do fontconfig.properties existente em $(Split-Path $backup -Leaf)"
}

$trocas = [ordered]@{
    "sansserif.plain.alphabetic"      = "Lucida Sans Regular"
    "sansserif.bold.alphabetic"       = "Lucida Sans Demibold"
    "sansserif.italic.alphabetic"     = "Lucida Sans Italic"
    "sansserif.bolditalic.alphabetic" = "Lucida Sans Demibold Italic"
}

$texto = [IO.File]::ReadAllText($src)
foreach ($chave in $trocas.Keys) {
    $padrao = "(?m)^" + [regex]::Escape($chave) + "=[^\r\n]*"
    if (-not [regex]::IsMatch($texto, $padrao)) {
        Write-Host "[ERRO] Linha '$chave' nao encontrada no fontconfig.properties.src - nada foi alterado." -ForegroundColor Red
        exit 1
    }
    $texto = [regex]::Replace($texto, $padrao, "$chave=$($trocas[$chave])")
}
[IO.File]::WriteAllText($dst, $texto, [Text.Encoding]::ASCII)
Write-Host "[OK] fontconfig.properties criado com SansSerif -> Lucida Sans"

foreach ($c in $caches) {
    $cache = Join-Path $lib $c
    if (Test-Path $cache) {
        $desativado = "$cache.DISABLED"
        if (Test-Path $desativado) { Remove-Item $desativado }
        Rename-Item $cache "$c.DISABLED"
        Write-Host "[OK] Cache $c desativado"
    }
}

Write-Host "Correcao aplicada. Abra o iReport de novo pelo atalho." -ForegroundColor Green
