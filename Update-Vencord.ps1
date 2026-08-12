# ============================================================
# Vencord Auto Updater
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

$DocumentsPath = [Environment]::GetFolderPath("MyDocuments")
$VencordPath   = Join-Path $DocumentsPath "Vencord"
$PluginsPath   = Join-Path $VencordPath "src\userplugins"

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function Write-Header {
    param (
        [string]$Text
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step {
    param (
        [string]$Text
    )

    Write-Host "[*] $Text" -ForegroundColor Yellow
}

function Write-Success {
    param (
        [string]$Text
    )

    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Failure {
    param (
        [string]$Text
    )

    Write-Host "[ERROR] $Text" -ForegroundColor Red
}

function Test-CommandExists {
    param (
        [string]$CommandName
    )

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Invoke-CommandChecked {
    param (
        [string]$Command,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory

    try {
        Write-Host ""
        Write-Host ">>> $Command $($Arguments -join ' ')" -ForegroundColor DarkCyan
        Write-Host ""

        & $Command @Arguments

        if ($LASTEXITCODE -ne 0) {
            throw "Command '$Command' завершилась с кодом $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

Clear-Host

Write-Header "Vencord Auto Updater"

Write-Host "Documents : $DocumentsPath"
Write-Host "Vencord   : $VencordPath"
Write-Host "Plugins   : $PluginsPath"

# ------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------

Write-Header "Проверка зависимостей"

if (-not (Test-CommandExists "git")) {
    Write-Failure "Git не найден в PATH."
    Write-Host "Установи Git и убедись, что команда 'git' работает в терминале."
    exit 1
}

Write-Success "Git найден."

if (-not (Test-CommandExists "pnpm")) {
    Write-Failure "pnpm не найден в PATH."
    Write-Host "Установи pnpm и убедись, что команда 'pnpm' работает в терминале."
    exit 1
}

Write-Success "pnpm найден."

# ------------------------------------------------------------
# Check Vencord
# ------------------------------------------------------------

Write-Header "Проверка Vencord"

if (-not (Test-Path $VencordPath)) {
    Write-Failure "Папка Vencord не найдена:"
    Write-Host $VencordPath
    exit 1
}

if (-not (Test-Path (Join-Path $VencordPath ".git"))) {
    Write-Failure "Папка Vencord найдена, но это не Git-репозиторий:"
    Write-Host $VencordPath
    exit 1
}

Write-Success "Vencord найден."

if (-not (Test-Path $PluginsPath)) {
    Write-Failure "Папка userplugins не найдена:"
    Write-Host $PluginsPath
    exit 1
}

Write-Success "Папка userplugins найдена."

# ------------------------------------------------------------
# Update Vencord itself
# ------------------------------------------------------------

Write-Header "Обновление Vencord"

try {

    Write-Step "Проверяем обновления Vencord..."

    Push-Location $VencordPath

    # Получаем информацию о новых коммитах,
    # но пока ничего не изменяем.
    git fetch

    if ($LASTEXITCODE -ne 0) {
        throw "git fetch завершился с ошибкой."
    }

    # Получаем текущую ветку
    $CurrentBranch = git branch --show-current

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($CurrentBranch)) {
        throw "Не удалось определить текущую Git-ветку Vencord."
    }

    Write-Host "Текущая ветка: $CurrentBranch" -ForegroundColor DarkGray

    # Проверяем, есть ли изменения на remote
    $BehindCount = git rev-list --count "HEAD..origin/$CurrentBranch"

    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось проверить наличие обновлений Vencord."
    }

    if ([int]$BehindCount -gt 0) {

        Write-Host ""
        Write-Host "Доступно обновлений коммитов: $BehindCount" -ForegroundColor Yellow
        Write-Host ""

        Write-Step "Обновляем Vencord..."

        git pull

        if ($LASTEXITCODE -ne 0) {
            throw "git pull Vencord завершился с ошибкой."
        }

        Write-Success "Vencord обновлён."
    }
    else {
        Write-Success "Vencord уже актуален."
    }
}
catch {

    Write-Failure "Не удалось обновить Vencord."
    Write-Host $_.Exception.Message -ForegroundColor Red

    Pop-Location
    exit 1
}
finally {

    # Защита от ситуации, когда Push-Location ещё активен
    try {
        Pop-Location
    }
    catch {
        # Ничего не делаем
    }
}

# ------------------------------------------------------------
# Find plugins
# ------------------------------------------------------------

Write-Header "Поиск userplugins"

$Plugins = Get-ChildItem `
    -Path $PluginsPath `
    -Directory `
    -ErrorAction Stop |
    Where-Object {
        Test-Path (Join-Path $_.FullName ".git")
    }

if ($Plugins.Count -eq 0) {
    Write-Failure "Git-репозитории в userplugins не найдены."
    exit 1
}

Write-Host "Найдено репозиториев: $($Plugins.Count)" -ForegroundColor Green
Write-Host ""

foreach ($Plugin in $Plugins) {
    Write-Host "  - $($Plugin.Name)"
}

# ------------------------------------------------------------
# Update plugins
# ------------------------------------------------------------

Write-Header "Обновление userplugins"

$FailedPlugins = @()

foreach ($Plugin in $Plugins) {

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "PLUGIN: $($Plugin.Name)" -ForegroundColor Magenta
    Write-Host "PATH:   $($Plugin.FullName)" -ForegroundColor DarkGray
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

    try {

        # ----------------------------------------------------
        # Git pull
        # ----------------------------------------------------

        Write-Step "git pull"

        Invoke-CommandChecked `
            -Command "git" `
            -Arguments @("pull") `
            -WorkingDirectory $Plugin.FullName

        Write-Success "$($Plugin.Name): git pull завершён."

        # ----------------------------------------------------
        # pnpm install
        # ----------------------------------------------------

        Write-Step "pnpm i"

        Invoke-CommandChecked `
            -Command "pnpm" `
            -Arguments @("i") `
            -WorkingDirectory $Plugin.FullName

        Write-Success "$($Plugin.Name): pnpm i завершён."
    }
    catch {

        Write-Failure "$($Plugin.Name): ошибка!"
        Write-Host $_.Exception.Message -ForegroundColor Red

        $FailedPlugins += $Plugin.Name
    }
}

# ------------------------------------------------------------
# Check plugin update results
# ------------------------------------------------------------

Write-Header "Результат обновления плагинов"

if ($FailedPlugins.Count -gt 0) {

    Write-Failure "Некоторые плагины не удалось обновить:"

    foreach ($PluginName in $FailedPlugins) {
        Write-Host "  - $PluginName" -ForegroundColor Red
    }

    Write-Host ""
    Write-Failure "Сборка Vencord остановлена."
    Write-Host "Исправь ошибки выше и запусти скрипт снова."

    exit 1
}

Write-Success "Все userplugins успешно обновлены."

# ------------------------------------------------------------
# Build Vencord
# ------------------------------------------------------------

Write-Header "Сборка Vencord"

try {

    Write-Step "pnpm build"

    Invoke-CommandChecked `
        -Command "pnpm" `
        -Arguments @("build") `
        -WorkingDirectory $VencordPath

    Write-Success "Vencord успешно собран."
}
catch {

    Write-Failure "Сборка Vencord завершилась ошибкой."
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}

# ------------------------------------------------------------
# Inject Vencord
# ------------------------------------------------------------

Write-Header "Inject Vencord"

try {

    Write-Step "pnpm inject"

    Invoke-CommandChecked `
        -Command "pnpm" `
        -Arguments @("inject") `
        -WorkingDirectory $VencordPath

    Write-Success "Vencord успешно injected."
}
catch {

    Write-Failure "pnpm inject завершился ошибкой."
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------

Write-Header "ГОТОВО"

Write-Host "Vencord обновлён/проверен." -ForegroundColor Green
Write-Host "Все userplugins обновлены." -ForegroundColor Green
Write-Host "Vencord собран." -ForegroundColor Green
Write-Host "Vencord injected." -ForegroundColor Green

Write-Host ""
Write-Host "Можно запускать Discord." -ForegroundColor Cyan
Write-Host ""

Read-Host "Нажми Enter для выхода"