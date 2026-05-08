<#
.SYNOPSIS
    Detecta e remove ativadores ilegais do Windows, e/ou reseta a ativacao atual.

.DESCRIPTION
    Verifica a presenca de ferramentas ilegais de ativacao do Windows (KMSpico,
    KMSAuto, AAct, AutoKMS, entre outros), exibe relatorio detalhado, e oferece
    opcoes para remocao dos artefatos e/ou reset da ativacao para novo processo.

.NOTES
    Autor   : Bruno Araujo
    Versao  : 1.0.0
    Criado  : 2026-05-06
    Requer  : PowerShell 5.1+, Windows 10/11, privilegios de Administrador

.EXAMPLE
    .\Invoke-ActivationCompliance.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# ============================================================
# CONSTANTES VISUAIS
# ============================================================
$COR_TITULO    = 'Cyan'
$COR_SECAO     = 'White'
$COR_OK        = 'Green'
$COR_AVISO     = 'Yellow'
$COR_AMEACA    = 'Red'
$COR_INFO      = 'DarkCyan'
$COR_DESTAQUE  = 'Magenta'

# ============================================================
# LISTA DE AMEACAS CONHECIDAS
# ============================================================
$ArquivosIlegais = @(
    'C:\Windows\KMSpico',
    'C:\Windows\KMSELDI.exe',
    'C:\Windows\System32\KMSELDI.exe',
    'C:\Windows\SECOH-QAD.exe',
    'C:\Windows\AAct.exe',
    'C:\Windows\AAct_x64.exe',
    'C:\Windows\AutoKMS',
    'C:\Windows\KMS_VL_ALL',
    'C:\ProgramData\KMSpico',
    'C:\ProgramData\KMSELDI',
    'C:\ProgramData\AAct Network',
    'C:\Program Files\KMSAuto Net',
    'C:\Program Files (x86)\KMSAuto Net',
    'C:\Program Files\KMSAuto Lite',
    'C:\Program Files (x86)\KMSAuto Lite',
    'C:\Program Files\KMSpico',
    'C:\Program Files (x86)\KMSpico'
)

$TarefasIlegais = @(
    'KMSAutoS',
    'AutoKMS',
    'KMS_VL_ALL_AIO',
    'KMSAuto',
    'KMSClientSchedule'
)

$ServicosIlegais = @(
    'KMService',
    'KMSELDI',
    'AAct',
    'AAct_x64',
    'AActNetworkService'
)

$ChavesRegistroIlegais = @(
    'HKLM:\SOFTWARE\KMSAuto',
    'HKLM:\SOFTWARE\KMSpico',
    'HKLM:\SOFTWARE\KMS_VL_ALL',
    'HKLM:\SYSTEM\CurrentControlSet\Services\KMService',
    'HKLM:\SYSTEM\CurrentControlSet\Services\KMSELDI'
)

# ============================================================
# LOG
# ============================================================
$LogDir  = 'C:\Windows\Logs'
$LogFile = Join-Path $LogDir ("ActivationCompliance_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Log {
    param([string]$Mensagem, [string]$Nivel = 'INFO')
    $linha = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Nivel, $Mensagem
    Add-Content -Path $LogFile -Value $linha -Encoding UTF8 -ErrorAction SilentlyContinue
}

# ============================================================
# FUNCOES VISUAIS
# ============================================================
function Write-Header {
    Clear-Host
    $largura = 72
    $borda   = '=' * $largura

    Write-Host ''
    Write-Host $borda -ForegroundColor $COR_TITULO
    Write-Host ('  {0,-70}' -f ' ') -ForegroundColor $COR_TITULO
    Write-Host ('  {0,-70}' -f '  FIEPB Scripts - Sanitizador de Ativacao do Windows') -ForegroundColor $COR_TITULO
    Write-Host ('  {0,-70}' -f ' ') -ForegroundColor $COR_TITULO
    Write-Host ('  {0,-45}{1,25}' -f '  Autor: Bruno Araujo', 'v1.0.0') -ForegroundColor $COR_TITULO
    Write-Host ('  {0,-70}' -f ' ') -ForegroundColor $COR_TITULO
    Write-Host $borda -ForegroundColor $COR_TITULO
    Write-Host ''

    $maquina = $env:COMPUTERNAME
    $usuario = $env:USERNAME
    $data    = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
    Write-Host "  Maquina : $maquina" -ForegroundColor $COR_INFO
    Write-Host "  Usuario : $usuario" -ForegroundColor $COR_INFO
    Write-Host "  Data    : $data"    -ForegroundColor $COR_INFO
    Write-Host "  Log     : $LogFile" -ForegroundColor $COR_INFO
    Write-Host ''
}

function Write-Section {
    param([string]$Titulo)
    $linha = '-' * 72
    Write-Host ''
    Write-Host $linha -ForegroundColor $COR_SECAO
    Write-Host "  $Titulo" -ForegroundColor $COR_SECAO
    Write-Host $linha -ForegroundColor $COR_SECAO
}

function Write-StatusLine {
    param(
        [string]$Rotulo,
        [string]$Valor,
        [ValidateSet('OK','AVISO','AMEACA','INFO')]
        [string]$Status = 'INFO'
    )
    $cores = @{ OK = $COR_OK; AVISO = $COR_AVISO; AMEACA = $COR_AMEACA; INFO = $COR_INFO }
    $tag   = "[$Status]".PadRight(8)
    Write-Host "  $tag " -ForegroundColor $cores[$Status] -NoNewline
    Write-Host "$Rotulo" -ForegroundColor $COR_SECAO -NoNewline
    if ($Valor) {
        Write-Host " : " -NoNewline
        Write-Host $Valor -ForegroundColor $cores[$Status]
    } else {
        Write-Host ''
    }
}

function Request-Confirmacao {
    param([string]$Pergunta)
    Write-Host ''
    Write-Host "  >> $Pergunta" -ForegroundColor $COR_AVISO
    Write-Host "     Digite S para confirmar, qualquer outra tecla para cancelar: " -ForegroundColor $COR_AVISO -NoNewline
    $resp = Read-Host
    return ($resp -match '^[Ss]$')
}

function Pause-Continuar {
    Write-Host ''
    Write-Host '  Pressione ENTER para continuar...' -ForegroundColor DarkGray
    $null = Read-Host
}

# ============================================================
# DETECCAO
# ============================================================
function Get-StatusAtivacao {
    $resultado = @{
        Descricao   = 'Desconhecido'
        Status      = 'Desconhecido'
        Ativado     = $false
        ServidorKMS = ''
        KMSSuspeito = $false
    }

    $statusMap = @{
        0 = 'Nao licenciado'
        1 = 'Licenciado'
        2 = 'Graca inicial (OOB)'
        3 = 'Graca por tolerancia'
        4 = 'Graca nao genuino'
        5 = 'Notificacao'
        6 = 'Graca estendida'
    }

    $appId   = '55c92734-d682-4d71-983e-d6ec3f16059f'
    $filtroCompleto = "PartialProductKey IS NOT NULL AND ApplicationId = '$appId'"
    $filtroSimples  = 'PartialProductKey IS NOT NULL'
    $produto = $null

    # Tentativa 1: Get-CimInstance com filtro por ApplicationId
    try {
        $produto = Get-CimInstance -ClassName SoftwareLicensingProduct `
                   -Filter $filtroCompleto -ErrorAction Stop |
                   Select-Object -First 1
        if ($produto) { Write-Log "Ativacao: CimInstance (filtro completo) OK" }
    } catch { Write-Log "CimInstance (filtro completo) falhou: $_" 'AVISO' }

    # Tentativa 2: Get-WmiObject com filtro por ApplicationId
    if (-not $produto) {
        try {
            $produto = Get-WmiObject -Query "SELECT Name, LicenseStatus FROM SoftwareLicensingProduct WHERE $filtroCompleto" `
                       -ErrorAction Stop | Select-Object -First 1
            if ($produto) { Write-Log "Ativacao: WmiObject (filtro completo) OK" }
        } catch { Write-Log "WmiObject (filtro completo) falhou: $_" 'AVISO' }
    }

    # Tentativa 3: Get-CimInstance sem filtro por ApplicationId, filtrando por nome
    if (-not $produto) {
        try {
            $produto = Get-CimInstance -ClassName SoftwareLicensingProduct `
                       -Filter $filtroSimples -ErrorAction Stop |
                       Where-Object { $_.Name -match 'Windows' } |
                       Select-Object -First 1
            if ($produto) { Write-Log "Ativacao: CimInstance (filtro simples) OK" }
        } catch { Write-Log "CimInstance (filtro simples) falhou: $_" 'AVISO' }
    }

    # Tentativa 4: Get-WmiObject sem filtro por ApplicationId
    if (-not $produto) {
        try {
            $produto = Get-WmiObject -Query "SELECT Name, LicenseStatus FROM SoftwareLicensingProduct WHERE $filtroSimples" `
                       -ErrorAction Stop |
                       Where-Object { $_.Name -match 'Windows' } |
                       Select-Object -First 1
            if ($produto) { Write-Log "Ativacao: WmiObject (filtro simples) OK" }
        } catch { Write-Log "WmiObject (filtro simples) falhou: $_" 'AVISO' }
    }

    if ($produto) {
        $resultado.Descricao = $produto.Name
        $n = [int]$produto.LicenseStatus
        $resultado.Status  = if ($statusMap.ContainsKey($n)) { $statusMap[$n] } else { "Codigo $n" }
        $resultado.Ativado = ($n -eq 1)
    } else {
        # Tentativa 5: fallback slmgr com encoding OEM correto
        Write-Log "Todos os metodos WMI falharam — usando slmgr /dli" 'AVISO'
        try {
            $prevEnc = [Console]::OutputEncoding
            [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(850)
            $saida = (& "$env:SystemRoot\System32\cscript.exe" //NoLogo "$env:SystemRoot\System32\slmgr.vbs" /dli 2>&1) -join "`n"
            [Console]::OutputEncoding = $prevEnc
            Write-Log "slmgr /dli: $saida"

            if ($saida -match '(?m)^\s*(?:Nome|Name):\s*(.+)') {
                $resultado.Descricao = $Matches[1].Trim()
            }
            # Padrao flexivel: casa "Estado da Licenca", "License Status", etc. sem depender de acentos
            if ($saida -match '(?i)(?:estado|status)[^\n:]*licen[^\n:]*:\s*([^\n\r]+)') {
                $st = $Matches[1].Trim()
                $resultado.Status  = $st
                $resultado.Ativado = ($st -match 'Licenciad|Licensed|Ativad|Activated')
            } elseif ($saida -match '(?i)license\s+status[^\n:]*:\s*([^\n\r]+)') {
                $st = $Matches[1].Trim()
                $resultado.Status  = $st
                $resultado.Ativado = ($st -match 'Licensed|Activated')
            }
        } catch {
            Write-Log "Fallback slmgr falhou: $_" 'ERRO'
        }
    }

    # Servidor KMS — tenta CimInstance depois WmiObject
    $sls = $null
    try {
        $sls = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
    } catch {
        try {
            $sls = Get-WmiObject -Class SoftwareLicensingService -ErrorAction SilentlyContinue
        } catch {}
    }
    if ($sls -and $sls.KeyManagementServiceName) {
        $resultado.ServidorKMS = $sls.KeyManagementServiceName
        if ($resultado.ServidorKMS -match '^(127\.0\.0\.1|localhost|::1)$') {
            $resultado.KMSSuspeito = $true
        }
    }

    return $resultado
}

function Find-ArquivosIlegais {
    $encontrados = [System.Collections.Generic.List[string]]::new()
    foreach ($caminho in $ArquivosIlegais) {
        if (Test-Path $caminho) {
            $encontrados.Add($caminho)
            Write-Log "Arquivo/pasta ilegal encontrado: $caminho" 'AMEACA'
        }
    }

    # Busca em perfis de usuarios
    try {
        Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $appdata = Join-Path $_.FullName 'AppData'
            @('Local', 'Roaming', 'LocalLow') | ForEach-Object {
                $base = Join-Path $appdata $_
                @('KMSpico', 'KMSAuto', 'AAct', 'AutoKMS') | ForEach-Object {
                    $alvo = Join-Path $base $_
                    if (Test-Path $alvo) {
                        $encontrados.Add($alvo)
                        Write-Log "Arquivo/pasta ilegal em perfil: $alvo" 'AMEACA'
                    }
                }
            }
        }
    } catch {}

    return ,$encontrados
}

function Find-TarefasIlegais {
    $encontradas = [System.Collections.Generic.List[string]]::new()
    foreach ($nome in $TarefasIlegais) {
        $tarefa = Get-ScheduledTask -TaskName $nome -ErrorAction SilentlyContinue
        if ($tarefa) {
            $encontradas.Add($nome)
            Write-Log "Tarefa agendada ilegal encontrada: $nome" 'AMEACA'
        }
    }
    return ,$encontradas
}

function Find-ServicosIlegais {
    $encontrados = [System.Collections.Generic.List[string]]::new()
    foreach ($nome in $ServicosIlegais) {
        $servico = Get-Service -Name $nome -ErrorAction SilentlyContinue
        if ($servico) {
            $encontrados.Add($nome)
            Write-Log "Servico ilegal encontrado: $nome (Status: $($servico.Status))" 'AMEACA'
        }
    }
    return ,$encontrados
}

function Find-RegistroIlegal {
    $encontradas = [System.Collections.Generic.List[string]]::new()
    foreach ($chave in $ChavesRegistroIlegais) {
        if (Test-Path $chave) {
            $encontradas.Add($chave)
            Write-Log "Chave de registro ilegal encontrada: $chave" 'AMEACA'
        }
    }
    return ,$encontradas
}

function Invoke-Scan {
    Write-Section "ESCANEANDO COMPUTADOR"
    Write-Host ''
    Write-Host "  Aguarde, verificando ameacas conhecidas..." -ForegroundColor $COR_INFO
    Write-Host ''

    Write-Log "Inicio do scan em $env:COMPUTERNAME"

    $status     = Get-StatusAtivacao
    $arquivos   = Find-ArquivosIlegais
    $tarefas    = Find-TarefasIlegais
    $servicos   = Find-ServicosIlegais
    $registro   = Find-RegistroIlegal

    $totalAmeacas = $arquivos.Count + $tarefas.Count + $servicos.Count + $registro.Count

    Write-Log "Scan concluido. Total de ameacas: $totalAmeacas"

    return @{
        StatusAtivacao = $status
        Arquivos       = $arquivos
        Tarefas        = $tarefas
        Servicos       = $servicos
        Registro       = $registro
        TotalAmeacas   = $totalAmeacas
    }
}

function Show-RelatorioScan {
    param($Resultado)

    Write-Section "RELATORIO DE ATIVACAO"

    $s = $Resultado.StatusAtivacao
    Write-Host ''
    Write-Host "  Sistema    : $($s.Descricao)" -ForegroundColor $COR_INFO

    $statusNivel = if ($s.Ativado) { 'OK' } else { 'AVISO' }
    Write-StatusLine -Rotulo 'Status atual' -Valor $s.Status -Status $statusNivel

    if ($s.ServidorKMS) {
        $kmsNivel = if ($s.KMSSuspeito) { 'AMEACA' } else { 'INFO' }
        Write-StatusLine -Rotulo 'Servidor KMS' -Valor $s.ServidorKMS -Status $kmsNivel
        if ($s.KMSSuspeito) {
            Write-Host '         ^ KMS local (localhost/127.0.0.1) e indicador de ativador ilegal!' -ForegroundColor $COR_AMEACA
        }
    }

    Write-Section "ARTEFATOS ILEGAIS DETECTADOS"
    Write-Host ''

    if ($Resultado.Arquivos.Count -gt 0) {
        Write-StatusLine -Rotulo "Arquivos/pastas ilegais ($($Resultado.Arquivos.Count) encontrados)" -Valor '' -Status 'AMEACA'
        foreach ($f in $Resultado.Arquivos) {
            Write-Host "         $f" -ForegroundColor $COR_AMEACA
        }
    } else {
        Write-StatusLine -Rotulo 'Arquivos/pastas ilegais' -Valor 'Nenhum encontrado' -Status 'OK'
    }

    if ($Resultado.Tarefas.Count -gt 0) {
        Write-StatusLine -Rotulo "Tarefas agendadas ilegais ($($Resultado.Tarefas.Count) encontradas)" -Valor '' -Status 'AMEACA'
        foreach ($t in $Resultado.Tarefas) {
            Write-Host "         $t" -ForegroundColor $COR_AMEACA
        }
    } else {
        Write-StatusLine -Rotulo 'Tarefas agendadas ilegais' -Valor 'Nenhuma encontrada' -Status 'OK'
    }

    if ($Resultado.Servicos.Count -gt 0) {
        Write-StatusLine -Rotulo "Servicos ilegais ($($Resultado.Servicos.Count) encontrados)" -Valor '' -Status 'AMEACA'
        foreach ($sv in $Resultado.Servicos) {
            Write-Host "         $sv" -ForegroundColor $COR_AMEACA
        }
    } else {
        Write-StatusLine -Rotulo 'Servicos ilegais' -Valor 'Nenhum encontrado' -Status 'OK'
    }

    if ($Resultado.Registro.Count -gt 0) {
        Write-StatusLine -Rotulo "Chaves de registro ilegais ($($Resultado.Registro.Count) encontradas)" -Valor '' -Status 'AMEACA'
        foreach ($r in $Resultado.Registro) {
            Write-Host "         $r" -ForegroundColor $COR_AMEACA
        }
    } else {
        Write-StatusLine -Rotulo 'Chaves de registro ilegais' -Valor 'Nenhuma encontrada' -Status 'OK'
    }

    Write-Host ''
    $borda = '=' * 72
    if ($Resultado.TotalAmeacas -gt 0) {
        Write-Host $borda -ForegroundColor $COR_AMEACA
        Write-Host ("  RESULTADO: {0} artefato(s) ilegal(is) encontrado(s)!" -f $Resultado.TotalAmeacas) -ForegroundColor $COR_AMEACA
        Write-Host $borda -ForegroundColor $COR_AMEACA
    } else {
        Write-Host $borda -ForegroundColor $COR_OK
        Write-Host '  RESULTADO: Nenhum ativador ilegal detectado.' -ForegroundColor $COR_OK
        Write-Host $borda -ForegroundColor $COR_OK
    }
}

# ============================================================
# REMOCAO
# ============================================================
function Remove-ArtefatosIlegais {
    param($Resultado)

    if ($Resultado.TotalAmeacas -eq 0) {
        Write-StatusLine -Rotulo 'Nenhum artefato ilegal para remover.' -Status 'INFO'
        Write-Log "Remocao solicitada, mas nenhum artefato encontrado."
        return $false
    }

    Write-Section "REMOCAO DE ARTEFATOS ILEGAIS"
    Write-Host ''
    Write-Host "  Serao removidos:" -ForegroundColor $COR_AVISO
    Write-Host "    - $($Resultado.Arquivos.Count) arquivo(s)/pasta(s)" -ForegroundColor $COR_AVISO
    Write-Host "    - $($Resultado.Tarefas.Count) tarefa(s) agendada(s)" -ForegroundColor $COR_AVISO
    Write-Host "    - $($Resultado.Servicos.Count) servico(s)" -ForegroundColor $COR_AVISO
    Write-Host "    - $($Resultado.Registro.Count) chave(s) de registro" -ForegroundColor $COR_AVISO

    if (-not (Request-Confirmacao 'Confirma a remocao de todos os artefatos ilegais listados?')) {
        Write-Host '  Remocao cancelada pelo usuario.' -ForegroundColor $COR_AVISO
        Write-Log "Remocao cancelada pelo usuario."
        return $false
    }

    $erros = 0

    # Servicos: parar antes de remover arquivos
    foreach ($nome in $Resultado.Servicos) {
        try {
            $svc = Get-Service -Name $nome -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.Status -eq 'Running') {
                    Stop-Service -Name $nome -Force -ErrorAction Stop
                }
                $null = sc.exe delete $nome 2>&1
                Write-StatusLine -Rotulo "Servico removido: $nome" -Status 'OK'
                Write-Log "Servico removido: $nome"
            }
        } catch {
            Write-StatusLine -Rotulo "Falha ao remover servico: $nome" -Valor $_.Exception.Message -Status 'AVISO'
            Write-Log "Falha ao remover servico $nome`: $_" 'ERRO'
            $erros++
        }
    }

    # Tarefas agendadas
    foreach ($nome in $Resultado.Tarefas) {
        try {
            Unregister-ScheduledTask -TaskName $nome -Confirm:$false -ErrorAction Stop
            Write-StatusLine -Rotulo "Tarefa removida: $nome" -Status 'OK'
            Write-Log "Tarefa agendada removida: $nome"
        } catch {
            Write-StatusLine -Rotulo "Falha ao remover tarefa: $nome" -Valor $_.Exception.Message -Status 'AVISO'
            Write-Log "Falha ao remover tarefa $nome`: $_" 'ERRO'
            $erros++
        }
    }

    # Arquivos e pastas
    foreach ($caminho in $Resultado.Arquivos) {
        try {
            if (Test-Path $caminho) {
                Remove-Item -Path $caminho -Recurse -Force -ErrorAction Stop
                Write-StatusLine -Rotulo "Removido: $caminho" -Status 'OK'
                Write-Log "Arquivo/pasta removido: $caminho"
            }
        } catch {
            Write-StatusLine -Rotulo "Falha ao remover: $caminho" -Valor $_.Exception.Message -Status 'AVISO'
            Write-Log "Falha ao remover $caminho`: $_" 'ERRO'
            $erros++
        }
    }

    # Chaves de registro
    foreach ($chave in $Resultado.Registro) {
        try {
            if (Test-Path $chave) {
                Remove-Item -Path $chave -Recurse -Force -ErrorAction Stop
                Write-StatusLine -Rotulo "Registro removido: $chave" -Status 'OK'
                Write-Log "Chave de registro removida: $chave"
            }
        } catch {
            Write-StatusLine -Rotulo "Falha ao remover registro: $chave" -Valor $_.Exception.Message -Status 'AVISO'
            Write-Log "Falha ao remover chave $chave`: $_" 'ERRO'
            $erros++
        }
    }

    Write-Host ''
    if ($erros -eq 0) {
        Write-Host ('  ' + '=' * 70) -ForegroundColor $COR_OK
        Write-Host '  Remocao concluida sem erros.' -ForegroundColor $COR_OK
        Write-Host ('  ' + '=' * 70) -ForegroundColor $COR_OK
    } else {
        Write-Host ('  ' + '=' * 70) -ForegroundColor $COR_AVISO
        Write-Host "  Remocao concluida com $erros falha(s). Verifique o log." -ForegroundColor $COR_AVISO
        Write-Host ('  ' + '=' * 70) -ForegroundColor $COR_AVISO
    }
    Write-Log "Remocao concluida. Erros: $erros"
    return $true
}

# ============================================================
# RESET DE ATIVACAO
# ============================================================
function Reset-Ativacao {
    param([switch]$SemConfirmacao)

    Write-Section "RESET DE ATIVACAO DO WINDOWS"
    Write-Host ''

    $slmgr = "$env:SystemRoot\System32\slmgr.vbs"

    Write-Host '  Esta operacao ira:' -ForegroundColor $COR_AVISO
    Write-Host '    1. Remover a chave de produto instalada (slmgr /upk)' -ForegroundColor $COR_AVISO
    Write-Host '    2. Limpar o servidor KMS configurado (slmgr /ckms)' -ForegroundColor $COR_AVISO
    Write-Host '    3. Resetar o contador de licenciamento (slmgr /rearm)' -ForegroundColor $COR_AVISO
    Write-Host ''
    Write-Host '  Apos a conclusao, o Windows entrara em periodo de graca e' -ForegroundColor $COR_INFO
    Write-Host '  estara pronto para receber uma nova ativacao.' -ForegroundColor $COR_INFO

    if (-not $SemConfirmacao) {
        if (-not (Request-Confirmacao 'Confirma o reset completo da ativacao do Windows?')) {
            Write-Host '  Reset cancelado pelo usuario.' -ForegroundColor $COR_AVISO
            Write-Log "Reset de ativacao cancelado pelo usuario."
            return $false
        }
    }

    Write-Host ''
    Write-Log "Inicio do reset de ativacao"

    # Passo 1: remover chave de produto
    Write-Host '  [1/3] Removendo chave de produto...' -ForegroundColor $COR_INFO -NoNewline
    $saida1 = cscript //NoLogo $slmgr /upk 2>&1
    if ($LASTEXITCODE -eq 0 -or ($saida1 -join '') -match 'Uninstall|removida|sucesso') {
        Write-Host ' OK' -ForegroundColor $COR_OK
        Write-Log "slmgr /upk: $($saida1 -join ' ')"
    } else {
        Write-Host " AVISO: $($saida1 -join ' ')" -ForegroundColor $COR_AVISO
        Write-Log "slmgr /upk resultado: $($saida1 -join ' ')" 'AVISO'
    }

    # Passo 2: limpar servidor KMS
    Write-Host '  [2/3] Limpando configuracao de servidor KMS...' -ForegroundColor $COR_INFO -NoNewline
    $saida2 = cscript //NoLogo $slmgr /ckms 2>&1
    Write-Host ' OK' -ForegroundColor $COR_OK
    Write-Log "slmgr /ckms: $($saida2 -join ' ')"

    # Passo 3: rearm
    Write-Host '  [3/3] Resetando contador de licenciamento...' -ForegroundColor $COR_INFO -NoNewline
    $saida3 = cscript //NoLogo $slmgr /rearm 2>&1
    $saidaStr = $saida3 -join ' '
    if ($saidaStr -match 'Erro|Error|0x8') {
        Write-Host " AVISO: $saidaStr" -ForegroundColor $COR_AVISO
        Write-Log "slmgr /rearm: $saidaStr" 'AVISO'
    } else {
        Write-Host ' OK' -ForegroundColor $COR_OK
        Write-Log "slmgr /rearm: $saidaStr"
    }

    Write-Host ''
    Write-Host ('  ' + '=' * 70) -ForegroundColor $COR_OK
    Write-Host '  Reset de ativacao concluido.' -ForegroundColor $COR_OK
    Write-Host '  O computador esta pronto para um novo processo de ativacao.' -ForegroundColor $COR_OK
    Write-Host ('  ' + '=' * 70) -ForegroundColor $COR_OK
    Write-Host ''
    Write-Host '  IMPORTANTE: Reinicie o computador antes de ativar novamente.' -ForegroundColor $COR_DESTAQUE
    Write-Log "Reset de ativacao concluido com sucesso."
    return $true
}

# ============================================================
# LOG
# ============================================================
function Show-Log {
    Write-Section "LOG DA SESSAO ATUAL"
    Write-Host ''
    Write-Host "  Arquivo: $LogFile" -ForegroundColor $COR_INFO
    Write-Host ''

    if (-not (Test-Path $LogFile)) {
        Write-Host '  Nenhuma entrada de log registrada ainda nesta sessao.' -ForegroundColor $COR_AVISO
        Pause-Continuar
        return
    }

    $linhas = Get-Content $LogFile -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $linhas) {
        Write-Host '  Log vazio.' -ForegroundColor $COR_AVISO
        Pause-Continuar
        return
    }

    foreach ($linha in $linhas) {
        if     ($linha -match '\[ERRO\]')  { Write-Host "  $linha" -ForegroundColor $COR_AMEACA  }
        elseif ($linha -match '\[AVISO\]') { Write-Host "  $linha" -ForegroundColor $COR_AVISO   }
        else                               { Write-Host "  $linha" -ForegroundColor $COR_INFO     }
    }

    Write-Host ''
    Write-Host '  Abrir log no Bloco de Notas? (S/N): ' -ForegroundColor $COR_AVISO -NoNewline
    if ((Read-Host) -match '^[Ss]$') {
        Start-Process notepad.exe $LogFile
    }

    Pause-Continuar
}

# ============================================================
# MENU PRINCIPAL
# ============================================================
function Show-Menu {
    while ($true) {
        Write-Header

        Write-Host '  Selecione uma opcao:' -ForegroundColor $COR_SECAO
        Write-Host ''
        Write-Host '  [1]  Escanear computador          (somente deteccao, sem alteracoes)' -ForegroundColor $COR_INFO
        Write-Host '  [2]  Remover ativadores ilegais   + resetar ativacao do Windows'      -ForegroundColor $COR_AMEACA
        Write-Host '  [3]  Resetar ativacao do Windows  (qualquer ativacao, legitima ou nao)' -ForegroundColor $COR_AVISO
        Write-Host '  [4]  Ver log da sessao atual'                                           -ForegroundColor $COR_INFO
        Write-Host '  [5]  Sair'                                                              -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '  Opcao: ' -ForegroundColor $COR_SECAO -NoNewline
        $opcao = Read-Host

        switch ($opcao.Trim()) {
            '1' {
                $resultado = Invoke-Scan
                Show-RelatorioScan -Resultado $resultado
                Pause-Continuar
            }
            '2' {
                $resultado = Invoke-Scan
                Show-RelatorioScan -Resultado $resultado
                Write-Host ''
                $removeu = Remove-ArtefatosIlegais -Resultado $resultado
                if ($removeu -or $resultado.TotalAmeacas -eq 0) {
                    Reset-Ativacao
                }
                Pause-Continuar
            }
            '3' {
                $resultado = Invoke-Scan
                Show-RelatorioScan -Resultado $resultado
                Write-Host ''
                Reset-Ativacao
                Pause-Continuar
            }
            '4' {
                Show-Log
            }
            '5' {
                Write-Host ''
                Write-Host '  Encerrando. Ate logo, ' -ForegroundColor $COR_INFO -NoNewline
                Write-Host $env:USERNAME -ForegroundColor $COR_DESTAQUE -NoNewline
                Write-Host '!' -ForegroundColor $COR_INFO
                Write-Host ''
                Write-Log "Script encerrado pelo usuario."
                return
            }
            default {
                Write-Host '  Opcao invalida. Tente novamente.' -ForegroundColor $COR_AMEACA
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ============================================================
# PONTO DE ENTRADA
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ''
    Write-Host '  Este script requer privilegios de Administrador.' -ForegroundColor Yellow
    Write-Host '  Solicitando elevacao via UAC...' -ForegroundColor DarkCyan
    Write-Host ''
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
        -Verb RunAs
    exit
}

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

Write-Log "=== Script iniciado por $env:USERNAME em $env:COMPUTERNAME ==="
Show-Menu
