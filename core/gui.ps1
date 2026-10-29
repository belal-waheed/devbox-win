# ==============================================================================
# devbox-win :: Windows 11 Developer Utility (WPF GUI)
# Path: core/gui.ps1
# Description: Modern Windows Desktop GUI inspired by Chris Titus Tech winutil.
# Provides visual categorized checklists, preset selectors, and action triggers.
# Zero external runtime dependencies: uses native Windows Presentation Foundation.
# Standard: Zero emojis. Catppuccin Mocha aesthetic with clean typography.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

# Ensure WPF assemblies are loaded
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

. (Join-Path $PSScriptRoot "config.ps1")

# Pre-detect system capabilities for badge display
$devModeReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
$devModeVal = (Get-ItemProperty -Path $devModeReg -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
$isDevMode = ($devModeVal -eq 1)
$devModeText = if ($isDevMode) { "Dev Mode: Enabled" } else { "Dev Mode: Disabled" }
$osBuild = [Environment]::OSVersion.Version.Build
$psVer = $PSVersionTable.PSVersion.ToString(3)

# Build XAML string for WPF Window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="devbox-win :: Windows 11 Developer Utility"
        Height="720" Width="920" MinHeight="620" MinWidth="820"
        WindowStartupLocation="CenterScreen"
        Background="#181825" Foreground="#cdd6f4"
        FontFamily="Segoe UI Variable Text, Segoe UI, sans-serif">

    <Window.Resources>
        <!-- TabItem Style -->
        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#1e1e2e"/>
            <Setter Property="Foreground" Value="#a6adc8"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="BorderThickness" Value="0,0,0,2"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="TabBorder" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}" Margin="0,0,4,0" CornerRadius="6,6,0,0">
                            <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="TabBorder" Property="Background" Value="#252538"/>
                                <Setter TargetName="TabBorder" Property="BorderBrush" Value="#cba6f7"/>
                                <Setter Property="Foreground" Value="#cba6f7"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="TabBorder" Property="Background" Value="#252538"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- CheckBox Style -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,6,0,6"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>

        <!-- GroupBox Style -->
        <Style TargetType="GroupBox">
            <Setter Property="Foreground" Value="#cba6f7"/>
            <Setter Property="BorderBrush" Value="#313244"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12"/>
            <Setter Property="Margin" Value="0,0,10,12"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Header -->
            <RowDefinition Height="Auto"/> <!-- Presets Bar -->
            <RowDefinition Height="Auto"/> <!-- Custom Install Path -->
            <RowDefinition Height="*"/>    <!-- Tab Content -->
            <RowDefinition Height="Auto"/> <!-- Action Footer -->
        </Grid.RowDefinitions>

        <!-- ============================================================== -->
        <!-- HEADER -->
        <!-- ============================================================== -->
        <Border Grid.Row="0" Background="#1e1e2e" BorderBrush="#313244" BorderThickness="0,0,0,1" Padding="20,16">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="DEVBOX-WIN" FontSize="20" FontWeight="Black" Foreground="#cba6f7" VerticalAlignment="Center"/>
                        <Border Background="#313244" CornerRadius="4" Padding="6,2" Margin="12,0,0,0" VerticalAlignment="Center">
                            <TextBlock Text="Windows 11 Developer Utility" FontSize="11" FontWeight="SemiBold" Foreground="#89b4fa"/>
                        </Border>
                    </StackPanel>
                    <TextBlock Text="Select packages, tiling window manager, runtimes, and system configurations."
                               FontSize="12" Foreground="#a6adc8" Margin="0,4,0,0"/>
                </StackPanel>

                <!-- System Stats Badges -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Background="#252538" BorderBrush="#313244" BorderThickness="1" CornerRadius="6" Padding="10,6" Margin="4,0">
                        <TextBlock Text="Win 11 ($osBuild)" FontSize="11" Foreground="#cdd6f4"/>
                    </Border>
                    <Border Background="#252538" BorderBrush="#313244" BorderThickness="1" CornerRadius="6" Padding="10,6" Margin="4,0">
                        <TextBlock Text="pwsh $psVer" FontSize="11" Foreground="#94e2d5"/>
                    </Border>
                    <Border Background="#252538" BorderBrush="#313244" BorderThickness="1" CornerRadius="6" Padding="10,6" Margin="4,0">
                        <TextBlock Text="$devModeText" FontSize="11" Foreground="#f9e2af"/>
                    </Border>
                </StackPanel>
            </Grid>
        </Border>

        <!-- ============================================================== -->
        <!-- PRESETS BAR -->
        <!-- ============================================================== -->
        <Border Grid.Row="1" Background="#181825" BorderBrush="#313244" BorderThickness="0,0,0,1" Padding="20,10">
            <WrapPanel VerticalAlignment="Center">
                <TextBlock Text="Presets:" FontSize="12" FontWeight="Bold" Foreground="#a6adc8" VerticalAlignment="Center" Margin="0,0,10,0"/>
                <Button x:Name="btnPresetCatppuccin" Content="Belal Catppuccin Rice" Background="#252538" Foreground="#cba6f7" BorderBrush="#cba6f7" BorderThickness="1" Padding="12,5" Margin="0,0,6,0" Cursor="Hand"/>
                <Button x:Name="btnPresetFullstack" Content="Fullstack Dev" Background="#252538" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="12,5" Margin="0,0,6,0" Cursor="Hand"/>
                <Button x:Name="btnPresetFrontend" Content="Frontend" Background="#252538" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="12,5" Margin="0,0,6,0" Cursor="Hand"/>
                <Button x:Name="btnPresetBackend" Content="Backend" Background="#252538" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="12,5" Margin="0,0,6,0" Cursor="Hand"/>
                <Button x:Name="btnPresetMinimal" Content="Minimal" Background="#252538" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="12,5" Margin="0,0,12,0" Cursor="Hand"/>
                <Button x:Name="btnSelectAll" Content="Select All" Background="#1e1e2e" Foreground="#94e2d5" BorderBrush="#313244" BorderThickness="1" Padding="10,5" Margin="0,0,6,0" Cursor="Hand"/>
                <Button x:Name="btnClearAll" Content="Clear All" Background="#1e1e2e" Foreground="#f38ba8" BorderBrush="#313244" BorderThickness="1" Padding="10,5" Cursor="Hand"/>
            </WrapPanel>
        </Border>

        <!-- ============================================================== -->
        <!-- CUSTOM INSTALLATION PATH BAR -->
        <!-- ============================================================== -->
        <Border Grid.Row="2" Background="#181825" BorderBrush="#313244" BorderThickness="0,0,0,1" Padding="20,8">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="Custom Install Path:" FontSize="12" FontWeight="Bold" Foreground="#a6adc8" VerticalAlignment="Center" Margin="0,0,10,0"/>
                <TextBox x:Name="txtCustomPath" Grid.Column="1" Background="#1e1e2e" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="8,4" VerticalAlignment="Center" FontSize="12"/>
                <Button x:Name="btnBrowsePath" Grid.Column="2" Content="Browse..." Background="#252538" Foreground="#cba6f7" BorderBrush="#313244" BorderThickness="1" Padding="12,4" Margin="8,0,0,0" VerticalAlignment="Center" Cursor="Hand"/>
            </Grid>
        </Border>

        <!-- ============================================================== -->
        <!-- TABBED CONTENT -->
        <!-- ============================================================== -->
        <TabControl Grid.Row="3" Background="#1e1e2e" BorderThickness="0" Margin="16,12,16,12">
            <!-- TAB 1: EDITORS & CORE TOOLCHAIN -->
            <TabItem Header="Editors &amp; CLI Tools">
                <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Left Column: Editors & IDEs -->
                        <StackPanel Grid.Column="0">
                            <GroupBox Header="Code Editors">
                                <StackPanel>
                                    <CheckBox x:Name="chk_zed" Content="Zed Editor (Ultra-fast Rust GPU editor)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_vscode" Content="Visual Studio Code" IsChecked="True"/>
                                    <CheckBox x:Name="chk_neovim" Content="Neovim CLI Editor" IsChecked="False"/>
                                </StackPanel>
                            </GroupBox>

                            <GroupBox Header="Terminal &amp; Prompt">
                                <StackPanel>
                                    <CheckBox x:Name="chk_terminal" Content="Microsoft Windows Terminal" IsChecked="True"/>
                                    <CheckBox x:Name="chk_starship" Content="Starship Cross-Shell Prompt" IsChecked="True"/>
                                    <CheckBox x:Name="chk_nerdfont" Content="JetBrainsMono Nerd Font (DEVCOM)" IsChecked="True"/>
                                </StackPanel>
                            </GroupBox>
                        </StackPanel>

                        <!-- Right Column: CLI & Browsers -->
                        <StackPanel Grid.Column="1">
                            <GroupBox Header="Version Control &amp; Shell Tools">
                                <StackPanel>
                                    <CheckBox x:Name="chk_git" Content="Git SCM (Distributed Version Control)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_gh" Content="GitHub CLI (gh official binary)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_7zip" Content="7-Zip File Archiver" IsChecked="True"/>
                                    <CheckBox x:Name="chk_sshkey" Content="Generate Non-interactive Ed25519 SSH Key" IsChecked="True"/>
                                </StackPanel>
                            </GroupBox>

                            <GroupBox Header="Web Browsers">
                                <StackPanel>
                                    <CheckBox x:Name="chk_chrome" Content="Google Chrome" IsChecked="True"/>
                                    <CheckBox x:Name="chk_firefox" Content="Mozilla Firefox" IsChecked="False"/>
                                    <CheckBox x:Name="chk_brave" Content="Brave Browser" IsChecked="False"/>
                                </StackPanel>
                            </GroupBox>
                        </StackPanel>
                    </Grid>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 2: TILING DESKTOP & RICE -->
            <TabItem Header="Tiling Desktop &amp; Rice">
                <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Left Column: Window Manager -->
                        <StackPanel Grid.Column="0">
                            <GroupBox Header="Tiling Window Manager">
                                <StackPanel>
                                    <CheckBox x:Name="chk_glazewm" Content="GlazeWM (i3/bspwm Tiling for Windows 11)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_zebar" Content="Zebar (Modern Customizable Status Bar)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_dwm_cloak" Content="DWM Hardware Cloaking (Zero window flicker)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_lavender_border" Content="Catppuccin Lavender (#cba6f7) Active Border" IsChecked="True"/>
                                    <CheckBox x:Name="chk_nord_pack" Content="Zebar Nord Frosted Glass Widget Pack" IsChecked="True"/>
                                </StackPanel>
                            </GroupBox>
                        </StackPanel>

                        <!-- Right Column: Shortcuts & Dotfiles -->
                        <StackPanel Grid.Column="1">
                            <GroupBox Header="Shortcuts &amp; Desktop Productivity">
                                <StackPanel>
                                    <CheckBox x:Name="chk_ahk" Content="AutoHotkey v2 Hotkeys (Super+HJKL Window tiling)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_powertoys" Content="Microsoft PowerToys (FancyZones, PowerToys Run)" IsChecked="True"/>
                                </StackPanel>
                            </GroupBox>

                            <GroupBox Header="Symlinked Dotfiles Coordinator">
                                <StackPanel>
                                    <CheckBox x:Name="chk_dotfiles" Content="Symlink all dotfiles to repository (.gitconfig, Starship, Zed, etc.)" IsChecked="True"/>
                                    <TextBlock Text="Uses unprivileged NTFS symbolic links with automatic timestamped backups."
                                               FontSize="11" Foreground="#a6adc8" Margin="20,0,0,0" TextWrapping="Wrap"/>
                                </StackPanel>
                            </GroupBox>
                        </StackPanel>
                    </Grid>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 3: RUNTIMES & DATABASES -->
            <TabItem Header="Runtimes &amp; Databases">
                <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Left Column: Language Runtimes -->
                        <StackPanel Grid.Column="0">
                            <GroupBox Header="Language Runtimes &amp; SDKs">
                                <StackPanel>
                                    <CheckBox x:Name="chk_node" Content="Node.js (LTS Runtime + npm)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_python" Content="Python 3.12+ Runtime &amp; pip" IsChecked="True"/>
                                    <CheckBox x:Name="chk_rust" Content="Rust Toolchain (rustup, rustc, cargo)" IsChecked="False"/>
                                    <CheckBox x:Name="chk_dotnet" Content=".NET 9 SDK (Core Developer SDK)" IsChecked="False"/>
                                </StackPanel>
                            </GroupBox>
                        </StackPanel>

                        <!-- Right Column: Databases & Containers -->
                        <StackPanel Grid.Column="1">
                            <GroupBox Header="Databases &amp; Container Engines">
                                <StackPanel>
                                    <CheckBox x:Name="chk_docker" Content="Docker Desktop (Containers &amp; Compose)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_postgres" Content="PostgreSQL Client (psql &amp; engine tools)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_redis" Content="Redis (In-memory cache &amp; redis-cli)" IsChecked="True"/>
                                    <CheckBox x:Name="chk_mongodb" Content="MongoDB Database &amp; mongosh CLI" IsChecked="False"/>
                                    <CheckBox x:Name="chk_sqlite" Content="SQLite 3 CLI Database Engine" IsChecked="True"/>
                                </StackPanel>
                            </GroupBox>
                        </StackPanel>
                    </Grid>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 4: COMMUNITY MODULES -->
            <TabItem Header="AI &amp; Community Tools">
                <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Left Column: Local AI Workstation -->
                        <StackPanel Grid.Column="0">
                            <GroupBox Header="Local AI Workstation Stack">
                                <StackPanel>
                                    <CheckBox x:Name="chk_ollama" Content="Ollama (Local LLM CLI &amp; API Server)" IsChecked="False"/>
                                    <CheckBox x:Name="chk_lmstudio" Content="LM Studio (Local GUI LLM Playground)" IsChecked="False"/>
                                </StackPanel>
                            </GroupBox>
                        </StackPanel>

                        <!-- Right Column: Gaming & Media -->
                        <StackPanel Grid.Column="1">
                            <GroupBox Header="Gaming &amp; Content Creation">
                                <StackPanel>
                                    <CheckBox x:Name="chk_steam" Content="Valve Steam Client" IsChecked="False"/>
                                    <CheckBox x:Name="chk_obs" Content="OBS Studio (Screen Recording &amp; Streaming)" IsChecked="False"/>
                                    <CheckBox x:Name="chk_discord" Content="Discord Desktop Client" IsChecked="False"/>
                                </StackPanel>
                            </GroupBox>
                        </StackPanel>
                    </Grid>
                </ScrollViewer>
            </TabItem>

            <!-- TAB 5: SYSTEM & MAINTENANCE -->
            <TabItem Header="Maintenance &amp; Tools">
                <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16">
                    <StackPanel>
                        <GroupBox Header="Day-2 System Utilities">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="Machine Health Doctor (-Doctor)" FontSize="13" FontWeight="Bold" Foreground="#89b4fa"/>
                                    <TextBlock Text="Executes 17-point health and environment audit (Windows build, Developer mode, winget, path variables, symlink integrity)." FontSize="11" Foreground="#a6adc8"/>
                                </StackPanel>
                                <Button x:Name="btnLaunchDoctor" Grid.Column="1" Content="Run Health Doctor" Background="#252538" Foreground="#89b4fa" BorderBrush="#89b4fa" BorderThickness="1" Padding="12,6" VerticalAlignment="Center" Cursor="Hand"/>
                            </Grid>
                        </GroupBox>

                        <GroupBox Header="Disaster Recovery &amp; State Backup">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="Create Disaster Recovery Archive (-Backup)" FontSize="13" FontWeight="Bold" Foreground="#94e2d5"/>
                                    <TextBlock Text="Generates SHA256 checksummed zip backup of configs, manifests, and active dotfiles." FontSize="11" Foreground="#a6adc8"/>
                                </StackPanel>
                                <Button x:Name="btnLaunchBackup" Grid.Column="1" Content="Create Backup Archive" Background="#252538" Foreground="#94e2d5" BorderBrush="#94e2d5" BorderThickness="1" Padding="12,6" VerticalAlignment="Center" Cursor="Hand"/>
                            </Grid>
                        </GroupBox>

                        <GroupBox Header="Workstation State Exporter">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="Reverse-Engineer Workstation (-Export)" FontSize="13" FontWeight="Bold" Foreground="#f9e2af"/>
                                    <TextBlock Text="Scans installed winget packages and machine tools into a portable declarative YAML config." FontSize="11" Foreground="#a6adc8"/>
                                </StackPanel>
                                <Button x:Name="btnLaunchExport" Grid.Column="1" Content="Export to YAML" Background="#252538" Foreground="#f9e2af" BorderBrush="#f9e2af" BorderThickness="1" Padding="12,6" VerticalAlignment="Center" Cursor="Hand"/>
                            </Grid>
                        </GroupBox>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <!-- ============================================================== -->
        <!-- ACTION FOOTER -->
        <!-- ============================================================== -->
        <Border Grid.Row="4" Background="#1e1e2e" BorderBrush="#313244" BorderThickness="0,1,0,0" Padding="20,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- Left: Status Summary -->
                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                    <TextBlock x:Name="txtStatusSummary" Text="Ready to configure workstation." FontSize="12" Foreground="#a6adc8"/>
                </StackPanel>

                <!-- Right: Action Buttons -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Button x:Name="btnDryRun" Content="Simulate (Dry-Run)" Background="#252538" Foreground="#94e2d5" BorderBrush="#94e2d5" BorderThickness="1" Padding="14,8" Margin="0,0,10,0" FontWeight="SemiBold" Cursor="Hand"/>
                    <Button x:Name="btnApply" Content="Install Selected" Background="#cba6f7" Foreground="#181825" BorderThickness="0" Padding="20,8" FontWeight="Bold" FontSize="14" Cursor="Hand"/>
                    <Button x:Name="btnCancel" Content="Cancel" Background="#181825" Foreground="#a6adc8" BorderBrush="#313244" BorderThickness="1" Padding="14,8" Margin="10,0,0,0" Cursor="Hand"/>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Element References
$chk_zed = $window.FindName("chk_zed")
$chk_vscode = $window.FindName("chk_vscode")
$chk_neovim = $window.FindName("chk_neovim")
$chk_terminal = $window.FindName("chk_terminal")
$chk_starship = $window.FindName("chk_starship")
$chk_nerdfont = $window.FindName("chk_nerdfont")
$chk_git = $window.FindName("chk_git")
$chk_gh = $window.FindName("chk_gh")
$chk_7zip = $window.FindName("chk_7zip")
$chk_sshkey = $window.FindName("chk_sshkey")
$chk_chrome = $window.FindName("chk_chrome")
$chk_firefox = $window.FindName("chk_firefox")
$chk_brave = $window.FindName("chk_brave")

$chk_glazewm = $window.FindName("chk_glazewm")
$chk_zebar = $window.FindName("chk_zebar")
$chk_dwm_cloak = $window.FindName("chk_dwm_cloak")
$chk_lavender_border = $window.FindName("chk_lavender_border")
$chk_nord_pack = $window.FindName("chk_nord_pack")
$chk_ahk = $window.FindName("chk_ahk")
$chk_powertoys = $window.FindName("chk_powertoys")
$chk_dotfiles = $window.FindName("chk_dotfiles")

$chk_node = $window.FindName("chk_node")
$chk_python = $window.FindName("chk_python")
$chk_rust = $window.FindName("chk_rust")
$chk_dotnet = $window.FindName("chk_dotnet")
$chk_docker = $window.FindName("chk_docker")
$chk_postgres = $window.FindName("chk_postgres")
$chk_redis = $window.FindName("chk_redis")
$chk_mongodb = $window.FindName("chk_mongodb")
$chk_sqlite = $window.FindName("chk_sqlite")

$chk_ollama = $window.FindName("chk_ollama")
$chk_lmstudio = $window.FindName("chk_lmstudio")
$chk_steam = $window.FindName("chk_steam")
$chk_obs = $window.FindName("chk_obs")
$chk_discord = $window.FindName("chk_discord")

$txtStatusSummary = $window.FindName("txtStatusSummary")
$txtCustomPath = $window.FindName("txtCustomPath")
$btnBrowsePath = $window.FindName("btnBrowsePath")

# All package checkboxes mapped to winget IDs
$allCheckboxes = @(
    $chk_zed, $chk_vscode, $chk_neovim,
    $chk_terminal, $chk_starship, $chk_nerdfont,
    $chk_git, $chk_gh, $chk_7zip,
    $chk_chrome, $chk_firefox, $chk_brave,
    $chk_glazewm, $chk_zebar, $chk_ahk, $chk_powertoys,
    $chk_node, $chk_python, $chk_rust, $chk_dotnet,
    $chk_docker, $chk_postgres, $chk_redis, $chk_mongodb, $chk_sqlite,
    $chk_ollama, $chk_lmstudio, $chk_steam, $chk_obs, $chk_discord
)

# Preset Application Functions
function Apply-PresetState([string]$PresetName) {
    switch ($PresetName) {
        "catppuccin" {
            $chk_zed.IsChecked = $true
            $chk_vscode.IsChecked = $true
            $chk_neovim.IsChecked = $false
            $chk_terminal.IsChecked = $true
            $chk_starship.IsChecked = $true
            $chk_nerdfont.IsChecked = $true
            $chk_git.IsChecked = $true
            $chk_gh.IsChecked = $true
            $chk_7zip.IsChecked = $true
            $chk_chrome.IsChecked = $true
            $chk_firefox.IsChecked = $false
            $chk_brave.IsChecked = $false
            $chk_glazewm.IsChecked = $true
            $chk_zebar.IsChecked = $true
            $chk_dwm_cloak.IsChecked = $true
            $chk_lavender_border.IsChecked = $true
            $chk_nord_pack.IsChecked = $true
            $chk_ahk.IsChecked = $true
            $chk_powertoys.IsChecked = $true
            $chk_dotfiles.IsChecked = $true
            $chk_node.IsChecked = $true
            $chk_python.IsChecked = $true
            $chk_rust.IsChecked = $false
            $chk_dotnet.IsChecked = $false
            $chk_docker.IsChecked = $true
            $chk_postgres.IsChecked = $true
            $chk_redis.IsChecked = $true
            $chk_mongodb.IsChecked = $false
            $chk_sqlite.IsChecked = $true
            $chk_ollama.IsChecked = $false
            $chk_lmstudio.IsChecked = $false
            $chk_steam.IsChecked = $false
            $chk_obs.IsChecked = $false
            $chk_discord.IsChecked = $false
            $txtStatusSummary.Text = "Preset applied: Belal Catppuccin Signature Rice (Zed + GlazeWM + Zebar)."
        }
        "fullstack" {
            $chk_zed.IsChecked = $false
            $chk_vscode.IsChecked = $true
            $chk_terminal.IsChecked = $true
            $chk_starship.IsChecked = $true
            $chk_nerdfont.IsChecked = $true
            $chk_git.IsChecked = $true
            $chk_gh.IsChecked = $true
            $chk_7zip.IsChecked = $true
            $chk_chrome.IsChecked = $true
            $chk_glazewm.IsChecked = $true
            $chk_zebar.IsChecked = $true
            $chk_ahk.IsChecked = $true
            $chk_powertoys.IsChecked = $true
            $chk_dotfiles.IsChecked = $true
            $chk_node.IsChecked = $true
            $chk_python.IsChecked = $true
            $chk_docker.IsChecked = $true
            $chk_postgres.IsChecked = $true
            $chk_redis.IsChecked = $true
            $chk_sqlite.IsChecked = $true
            $txtStatusSummary.Text = "Preset applied: Fullstack Developer."
        }
        "frontend" {
            $chk_zed.IsChecked = $true
            $chk_vscode.IsChecked = $true
            $chk_terminal.IsChecked = $true
            $chk_starship.IsChecked = $true
            $chk_nerdfont.IsChecked = $true
            $chk_git.IsChecked = $true
            $chk_gh.IsChecked = $true
            $chk_7zip.IsChecked = $true
            $chk_chrome.IsChecked = $true
            $chk_firefox.IsChecked = $true
            $chk_node.IsChecked = $true
            $chk_python.IsChecked = $false
            $chk_docker.IsChecked = $false
            $chk_postgres.IsChecked = $false
            $chk_redis.IsChecked = $false
            $chk_sqlite.IsChecked = $false
            $txtStatusSummary.Text = "Preset applied: Frontend Web Developer."
        }
        "backend" {
            $chk_zed.IsChecked = $false
            $chk_vscode.IsChecked = $true
            $chk_neovim.IsChecked = $true
            $chk_terminal.IsChecked = $true
            $chk_starship.IsChecked = $true
            $chk_nerdfont.IsChecked = $true
            $chk_git.IsChecked = $true
            $chk_gh.IsChecked = $true
            $chk_7zip.IsChecked = $true
            $chk_node.IsChecked = $true
            $chk_python.IsChecked = $true
            $chk_rust.IsChecked = $true
            $chk_dotnet.IsChecked = $true
            $chk_docker.IsChecked = $true
            $chk_postgres.IsChecked = $true
            $chk_redis.IsChecked = $true
            $chk_mongodb.IsChecked = $true
            $chk_sqlite.IsChecked = $true
            $txtStatusSummary.Text = "Preset applied: Backend & Cloud Engineer."
        }
        "minimal" {
            foreach ($cb in $allCheckboxes) { $cb.IsChecked = $false }
            $chk_terminal.IsChecked = $true
            $chk_git.IsChecked = $true
            $chk_7zip.IsChecked = $true
            $chk_nerdfont.IsChecked = $true
            $txtStatusSummary.Text = "Preset applied: Minimal / CLI Only."
        }
        "selectall" {
            foreach ($cb in $allCheckboxes) { $cb.IsChecked = $true }
            $txtStatusSummary.Text = "All packages and features selected."
        }
        "clearall" {
            foreach ($cb in $allCheckboxes) { $cb.IsChecked = $false }
            $txtStatusSummary.Text = "All selections cleared."
        }
    }
}

# Attach Preset Button Handlers
($window.FindName("btnPresetCatppuccin")).Add_Click({ Apply-PresetState "catppuccin" })
($window.FindName("btnPresetFullstack")).Add_Click({ Apply-PresetState "fullstack" })
($window.FindName("btnPresetFrontend")).Add_Click({ Apply-PresetState "frontend" })
($window.FindName("btnPresetBackend")).Add_Click({ Apply-PresetState "backend" })
($window.FindName("btnPresetMinimal")).Add_Click({ Apply-PresetState "minimal" })
($window.FindName("btnSelectAll")).Add_Click({ Apply-PresetState "selectall" })
($window.FindName("btnClearAll")).Add_Click({ Apply-PresetState "clearall" })

# Attach Browse Custom Path Handler
if ($btnBrowsePath) {
    $btnBrowsePath.Add_Click({
        $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
        $dialog.Description = "Select custom application installation directory"
        $dialog.UseDescriptionForTitle = $true
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            if ($txtCustomPath) {
                $txtCustomPath.Text = $dialog.SelectedPath
            }
        }
    })
}

# Compilation Function: Converts Checked State into devbox-win Config Hashtable
function Get-CompiledConfigFromUI {
    $packages = [System.Collections.Generic.List[string]]::new()

    # Editors & CLI
    if ($chk_zed.IsChecked)      { $packages.Add("Zed.Zed") }
    if ($chk_vscode.IsChecked)   { $packages.Add("Microsoft.VisualStudioCode") }
    if ($chk_neovim.IsChecked)   { $packages.Add("Neovim.Neovim") }
    if ($chk_terminal.IsChecked) { $packages.Add("Microsoft.WindowsTerminal") }
    if ($chk_starship.IsChecked) { $packages.Add("Starship.Starship") }
    if ($chk_nerdfont.IsChecked) { $packages.Add("DEVCOM.JetBrainsMonoNerdFont") }
    if ($chk_git.IsChecked)      { $packages.Add("Git.Git") }
    if ($chk_gh.IsChecked)       { $packages.Add("GitHub.cli") }
    if ($chk_7zip.IsChecked)     { $packages.Add("7zip.7zip") }
    if ($chk_chrome.IsChecked)   { $packages.Add("Google.Chrome") }
    if ($chk_firefox.IsChecked)  { $packages.Add("Mozilla.Firefox") }
    if ($chk_brave.IsChecked)    { $packages.Add("Brave.Brave") }

    # Tiling & Rice
    if ($chk_glazewm.IsChecked)  { $packages.Add("glzr-io.glazewm") }
    if ($chk_zebar.IsChecked)    { $packages.Add("glzr-io.zebar") }
    if ($chk_ahk.IsChecked)      { $packages.Add("AutoHotkey.AutoHotkey") }
    if ($chk_powertoys.IsChecked){ $packages.Add("Microsoft.PowerToys") }

    # Databases
    $databases = [System.Collections.Generic.List[string]]::new()
    if ($chk_docker.IsChecked)   { $packages.Add("Docker.DockerDesktop") }
    if ($chk_postgres.IsChecked) { $databases.Add("PostgreSQL.PostgreSQL") }
    if ($chk_redis.IsChecked)    { $databases.Add("Redis.Redis") }
    if ($chk_mongodb.IsChecked)  { $databases.Add("MongoDB.Server") }
    if ($chk_sqlite.IsChecked)   { $databases.Add("SQLite.SQLite") }

    # Community Modules
    $commModules = [System.Collections.Generic.List[string]]::new()
    if ($chk_ollama.IsChecked -or $chk_lmstudio.IsChecked) {
        $commModules.Add("ai-tools")
        if ($chk_ollama.IsChecked)   { $packages.Add("Ollama.Ollama") }
        if ($chk_lmstudio.IsChecked) { $packages.Add("ElementLabs.LMStudio") }
    }
    if ($chk_steam.IsChecked -or $chk_obs.IsChecked -or $chk_discord.IsChecked) {
        $commModules.Add("gaming")
        if ($chk_steam.IsChecked)   { $packages.Add("Valve.Steam") }
        if ($chk_obs.IsChecked)     { $packages.Add("OBSProject.OBSStudio") }
        if ($chk_discord.IsChecked) { $packages.Add("Discord.Discord") }
    }

    $primaryEditor = if ($chk_zed.IsChecked) { "zed" } elseif ($chk_vscode.IsChecked) { "vscode" } else { "none" }

    $config = [ordered]@{
        user = [ordered]@{
            name            = $env:USERNAME
            email           = "$($env:USERNAME)@localhost"
            github_username = ""
        }
        preset = "custom"
        modules = [ordered]@{
            packages    = ($packages.Count -gt 0)
            fonts       = [bool]$chk_nerdfont.IsChecked
            git         = [bool]$chk_git.IsChecked
            shell       = [bool]$chk_terminal.IsChecked
            editor      = ($chk_zed.IsChecked -or $chk_vscode.IsChecked)
            runtimes    = ($chk_node.IsChecked -or $chk_python.IsChecked -or $chk_rust.IsChecked -or $chk_dotnet.IsChecked)
            databases   = ($databases.Count -gt 0)
            envvars     = $true
            keybindings = ($chk_ahk.IsChecked -or $chk_powertoys.IsChecked)
            glazewm     = [bool]$chk_glazewm.IsChecked
            zebar       = [bool]$chk_zebar.IsChecked
            dotfiles    = [bool]$chk_dotfiles.IsChecked
        }
        packages = @($packages)
        databases = @($databases)
        community_modules = @($commModules)
        editor = [ordered]@{
            primary            = $primaryEditor
            sync_settings      = $true
            install_extensions = $true
        }
        git = [ordered]@{
            default_branch   = "main"
            autocrlf         = "input"
            generate_ssh_key = [bool]$chk_sshkey.IsChecked
            ssh_key_type     = "ed25519"
        }
        runtimes = [ordered]@{
            node   = [bool]$chk_node.IsChecked
            python = [bool]$chk_python.IsChecked
            rust   = [bool]$chk_rust.IsChecked
            dotnet = [bool]$chk_dotnet.IsChecked
        }
        glazewm = [ordered]@{
            install            = [bool]$chk_glazewm.IsChecked
            autostart          = [bool]$chk_glazewm.IsChecked
            hide_method        = if ($chk_dwm_cloak.IsChecked) { "cloak" } else { "none" }
            border_color       = if ($chk_lavender_border.IsChecked) { "#cba6f7" } else { "#89b4fa" }
        }
        zebar = [ordered]@{
            install            = [bool]$chk_zebar.IsChecked
            autostart          = [bool]$chk_zebar.IsChecked
            pack               = if ($chk_nord_pack.IsChecked) { "nord" } else { "starter" }
        }
    }

    if ($txtCustomPath -and -not [string]::IsNullOrWhiteSpace($txtCustomPath.Text)) {
        $customLoc = $txtCustomPath.Text.Trim()
        $config["paths"] = [ordered]@{
            apps = $customLoc
        }
        $config["install_location"] = $customLoc
    }

    return $config
}

# Action Results
$script:GuiResult = [PSCustomObject]@{
    Action = "Cancel"
    Config = $null
    DryRun = $false
}

# Button Actions
($window.FindName("btnApply")).Add_Click({
    $script:GuiResult.Action = "Install"
    $script:GuiResult.Config = Get-CompiledConfigFromUI
    $script:GuiResult.DryRun = $false
    $window.Close()
})

($window.FindName("btnDryRun")).Add_Click({
    $script:GuiResult.Action = "DryRun"
    $script:GuiResult.Config = Get-CompiledConfigFromUI
    $script:GuiResult.DryRun = $true
    $window.Close()
})

($window.FindName("btnCancel")).Add_Click({
    $script:GuiResult.Action = "Cancel"
    $window.Close()
})

# Maintenance buttons
($window.FindName("btnLaunchDoctor")).Add_Click({
    $script:GuiResult.Action = "Doctor"
    $window.Close()
})

($window.FindName("btnLaunchBackup")).Add_Click({
    $script:GuiResult.Action = "Backup"
    $window.Close()
})

($window.FindName("btnLaunchExport")).Add_Click({
    $script:GuiResult.Action = "Export"
    $window.Close()
})

# Show Dialog
$null = $window.ShowDialog()

return $script:GuiResult
