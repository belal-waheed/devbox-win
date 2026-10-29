# ==============================================================================
# devbox-win :: PowerShell 7 Profile
# Path: dotfiles/pwsh/Microsoft.PowerShell_profile.ps1
# Standard: Zero emojis. High performance, UTF-8 standard, Starship/PSReadLine.
# ==============================================================================

# Force UTF-8 Encoding
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

# Configure PSReadLine if present
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -Colors @{
        Command            = "`e[96m"
        Parameter          = "`e[90m"
        Operator           = "`e[93m"
        Variable           = "`e[92m"
        String             = "`e[33m"
        Number             = "`e[95m"
        InlinePrediction   = "`e[90m"
    }

    # Up/Down history search by prefix
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# Prompt initialization: Starship preferred, fallback Oh My Posh
if (Get-Command "starship" -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
} elseif (Get-Command "oh-my-posh" -ErrorAction SilentlyContinue) {
    Invoke-Expression (&oh-my-posh init pwsh)
}

# Aliases and quality-of-life shortcuts
Set-Alias -Name g -Value git -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name v -Value code -Option AllScope -ErrorAction SilentlyContinue

function ll { Get-ChildItem -Path $args }
function la { Get-ChildItem -Path $args -Force }
function .. { Set-Location .. }
function ... { Set-Location ../.. }

function which {
    param([string]$Name)
    Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}
