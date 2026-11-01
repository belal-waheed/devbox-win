# ==============================================================================
# devbox-win :: Windows 11 Developer Utility (WPF GUI)
# Path: core/gui.ps1
# Description: Modern Windows 11 2-column Fluent Desktop GUI.
# Features left sidebar navigation rail, interactive package cards, live package
# detection badges (INSTALLED vs AVAILABLE), real-time search, filter chips,
# and ergonomic action dock.
# Zero external runtime dependencies: uses native Windows Presentation Foundation.
# Standard: Zero emojis. Catppuccin Mocha aesthetic with clean typography.
# ==============================================================================

[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [switch]$DryRun,
    [string]$Preset = "",
    [switch]$NoShow
)

Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

# Ensure WPF assemblies are loaded
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

. (Join-Path $PSScriptRoot "config.ps1")
. (Join-Path $PSScriptRoot "state.ps1")

# Pre-detect system capabilities for telemetry badges
$devModeReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
$devModeVal = $null
$devModeItem = Get-ItemProperty -Path $devModeReg -ErrorAction SilentlyContinue
if ($null -ne $devModeItem -and ($devModeItem.PSObject.Properties.Match('AllowDevelopmentWithoutDevLicense').Count -gt 0)) {
    $devModeVal = $devModeItem.AllowDevelopmentWithoutDevLicense
}
$isDevMode = ($devModeVal -eq 1)
$devModeText = if ($isDevMode) { "Dev Mode: Enabled" } else { "Dev Mode: Disabled" }
$osBuild = [Environment]::OSVersion.Version.Build
$psVer = ($PSVersionTable.PSVersion.ToString() -split '\.')[0..2] -join '.'

# Build XAML string for Modern 2-Column WPF Window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="devbox-win :: Windows 11 Developer Utility"
        Height="720" Width="980" MinHeight="640" MinWidth="880"
        WindowStartupLocation="CenterScreen"
        Background="#11111b" Foreground="#cdd6f4"
        FontFamily="Segoe UI Variable Text, Segoe UI, sans-serif">

    <Window.Resources>
        <!-- CheckBox Style -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>

        <!-- Base Button Style -->
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="Background" Value="#252538"/>
            <Setter Property="BorderBrush" Value="#313244"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                              VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="230"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- ============================================================== -->
        <!-- COLUMN 0: SIDEBAR NAVIGATION RAIL -->
        <!-- ============================================================== -->
        <Border Grid.Column="0" Background="#181825" BorderBrush="#313244" BorderThickness="0,0,1,0">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/> <!-- Header -->
                    <RowDefinition Height="*"/>    <!-- Navigation Rail -->
                    <RowDefinition Height="Auto"/> <!-- System Telemetry -->
                </Grid.RowDefinitions>

                <!-- Brand Header -->
                <Border Grid.Row="0" Padding="18,18,18,12">
                    <StackPanel>
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="DEVBOX-WIN" FontSize="18" FontWeight="Black" Foreground="#cba6f7" VerticalAlignment="Center"/>
                            <Border Background="#252538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="6,2" Margin="8,0,0,0" VerticalAlignment="Center">
                                <TextBlock Text="v1.3.2" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                            </Border>
                        </StackPanel>
                        <TextBlock Text="Windows 11 Developer Utility" FontSize="11" Foreground="#a6adc8" Margin="0,4,0,0"/>
                        <Border Height="1" Background="#313244" Margin="0,14,0,0"/>
                    </StackPanel>
                </Border>

                <!-- Navigation Rail Menu -->
                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="14,0">
                    <StackPanel>
                        <TextBlock Text="CATEGORIES" FontSize="10" FontWeight="Bold" Foreground="#6c7086" Margin="6,4,0,8"/>
                        
                        <Button x:Name="btnNavToolchain" Content="Core Toolchain" HorizontalContentAlignment="Left"
                                Background="#252538" Foreground="#cba6f7" BorderBrush="#cba6f7"
                                Padding="12,10" Margin="0,0,0,4" FontSize="13" FontWeight="SemiBold"/>

                        <Button x:Name="btnNavTiling" Content="Tiling Desktop" HorizontalContentAlignment="Left"
                                Background="Transparent" Foreground="#a6adc8" BorderBrush="Transparent"
                                Padding="12,10" Margin="0,0,0,4" FontSize="13" FontWeight="SemiBold"/>

                        <Button x:Name="btnNavRuntimes" Content="Runtimes &amp; DBs" HorizontalContentAlignment="Left"
                                Background="Transparent" Foreground="#a6adc8" BorderBrush="Transparent"
                                Padding="12,10" Margin="0,0,0,4" FontSize="13" FontWeight="SemiBold"/>

                        <Button x:Name="btnNavAI" Content="AI &amp; Media" HorizontalContentAlignment="Left"
                                Background="Transparent" Foreground="#a6adc8" BorderBrush="Transparent"
                                Padding="12,10" Margin="0,0,0,4" FontSize="13" FontWeight="SemiBold"/>

                        <Button x:Name="btnNavMaintenance" Content="Maintenance" HorizontalContentAlignment="Left"
                                Background="Transparent" Foreground="#a6adc8" BorderBrush="Transparent"
                                Padding="12,10" Margin="0,0,0,4" FontSize="13" FontWeight="SemiBold"/>
                    </StackPanel>
                </ScrollViewer>

                <!-- Bottom System Telemetry Card -->
                <Border Grid.Row="2" Background="#11111b" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="14,10,14,14">
                    <StackPanel>
                        <TextBlock Text="SYSTEM TELEMETRY" FontSize="10" FontWeight="Bold" Foreground="#6c7086" Margin="0,0,0,6"/>
                        <Border Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="4" Padding="6,3" Margin="0,0,0,4">
                            <TextBlock Text="Win 11 ($osBuild)" FontSize="11" Foreground="#cdd6f4"/>
                        </Border>
                        <Border Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="4" Padding="6,3" Margin="0,0,0,4">
                            <TextBlock Text="pwsh $psVer" FontSize="11" Foreground="#94e2d5"/>
                        </Border>
                        <Border Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="4" Padding="6,3">
                            <TextBlock Text="$devModeText" FontSize="11" Foreground="#f9e2af"/>
                        </Border>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <!-- ============================================================== -->
        <!-- COLUMN 1: MAIN CONTENT WORKSPACE -->
        <!-- ============================================================== -->
        <Grid Grid.Column="1">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/> <!-- Top Controls & Search Bar -->
                <RowDefinition Height="Auto"/> <!-- Custom Install Location Bar -->
                <RowDefinition Height="*"/>    <!-- Scrollable Panels -->
                <RowDefinition Height="Auto"/> <!-- Action Footer Dock -->
            </Grid.RowDefinitions>

            <!-- ROW 0: TOP CONTROLS & ACTIONS -->
            <Border Grid.Row="0" Background="#181825" BorderBrush="#313244" BorderThickness="0,0,0,1" Padding="18,12">
                <StackPanel>
                    <!-- Presets Row -->
                    <WrapPanel Margin="0,0,0,10" VerticalAlignment="Center">
                        <TextBlock Text="Presets:" FontSize="12" FontWeight="Bold" Foreground="#a6adc8" VerticalAlignment="Center" Margin="0,0,8,0"/>
                        <Button x:Name="btnPresetCatppuccin" Content="Belal Catppuccin Rice" Background="#252538" Foreground="#cba6f7" BorderBrush="#cba6f7" BorderThickness="1" Padding="10,4" Margin="0,0,6,4"/>
                        <Button x:Name="btnPresetFullstack" Content="Fullstack Dev" Background="#1e1e2e" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="10,4" Margin="0,0,6,4"/>
                        <Button x:Name="btnPresetFrontend" Content="Frontend" Background="#1e1e2e" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="10,4" Margin="0,0,6,4"/>
                        <Button x:Name="btnPresetBackend" Content="Backend" Background="#1e1e2e" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="10,4" Margin="0,0,6,4"/>
                        <Button x:Name="btnPresetMinimal" Content="Minimal" Background="#1e1e2e" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="10,4" Margin="0,0,6,4"/>
                    </WrapPanel>

                    <!-- Action Row: Scan Installed, Quick Select, Filter Chips, Live Search -->
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/> <!-- Scan Installed -->
                            <ColumnDefinition Width="Auto"/> <!-- Quick Select -->
                            <ColumnDefinition Width="Auto"/> <!-- Filter Chips -->
                            <ColumnDefinition Width="*"/>    <!-- Live Search Box -->
                        </Grid.ColumnDefinitions>

                        <!-- Scan Installed Packages Button -->
                        <Button x:Name="btnScanInstalled" Grid.Column="0" Content="Scan Installed Packages"
                                Background="#1e3328" BorderBrush="#a6e3a1" Foreground="#a6e3a1" FontWeight="SemiBold"
                                Padding="12,5" Margin="0,0,10,0"/>

                        <!-- Quick Select Buttons -->
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,10,0">
                            <Button x:Name="btnSelectAll" Content="Select All" Background="#1e1e2e" Foreground="#94e2d5" BorderBrush="#313244" Padding="8,4" Margin="0,0,4,0"/>
                            <Button x:Name="btnClearAll" Content="Clear All" Background="#1e1e2e" Foreground="#f38ba8" BorderBrush="#313244" Padding="8,4"/>
                        </StackPanel>

                        <!-- Filter Chips -->
                        <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,10,0">
                            <Button x:Name="btnFilterAll" Content="All" Background="#252538" Foreground="#cba6f7" BorderBrush="#cba6f7" Padding="10,4" Margin="0,0,4,0"/>
                            <Button x:Name="btnFilterInstalled" Content="Installed" Background="#1e1e2e" Foreground="#a6adc8" BorderBrush="#313244" Padding="10,4" Margin="0,0,4,0"/>
                            <Button x:Name="btnFilterAvailable" Content="Available" Background="#1e1e2e" Foreground="#a6adc8" BorderBrush="#313244" Padding="10,4"/>
                        </StackPanel>

                        <!-- Live Search Box -->
                        <TextBox x:Name="txtSearch" Grid.Column="3" Background="#11111b" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1"
                                 Padding="8,5" VerticalAlignment="Center" FontSize="12" ToolTip="Search packages (e.g. zed, git, docker)..."/>
                    </Grid>
                </StackPanel>
            </Border>

            <!-- ROW 1: CUSTOM INSTALL PATH BAR -->
            <Border Grid.Row="1" Background="#14141e" BorderBrush="#313244" BorderThickness="0,0,0,1" Padding="18,8">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" Text="Custom Install Path:" FontSize="12" FontWeight="SemiBold" Foreground="#a6adc8" VerticalAlignment="Center" Margin="0,0,10,0"/>
                    <TextBox x:Name="txtCustomPath" Grid.Column="1" Background="#181825" Foreground="#cdd6f4" BorderBrush="#313244" BorderThickness="1" Padding="8,4" VerticalAlignment="Center" FontSize="12"/>
                    <Button x:Name="btnBrowsePath" Grid.Column="2" Content="Browse..." Background="#252538" Foreground="#cba6f7" BorderBrush="#313244" BorderThickness="1" Padding="12,4" Margin="8,0,0,0" VerticalAlignment="Center"/>
                </Grid>
            </Border>

            <!-- ROW 2: SCROLLABLE MAIN CONTENT AREA -->
            <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="18,14">
                <StackPanel>
                    <!-- ============================================================== -->
                    <!-- PANEL 1: CORE TOOLCHAIN -->
                    <!-- ============================================================== -->
                    <StackPanel x:Name="panelToolchain" Visibility="Visible">
                        <TextBlock Text="Code Editors &amp; IDEs" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,0,0,8"/>
                        
                        <!-- Zed Editor -->
                        <Border x:Name="card_zed" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_zed" Content="Zed Editor" IsChecked="True"/>
                                    <TextBlock Text="Ultra-fast Rust GPU code editor (Zed.Zed)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_zed" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_zed" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- VS Code -->
                        <Border x:Name="card_vscode" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_vscode" Content="Visual Studio Code" IsChecked="True"/>
                                    <TextBlock Text="Extensible code editor with rich ecosystem (Microsoft.VisualStudioCode)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_vscode" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_vscode" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Neovim -->
                        <Border x:Name="card_neovim" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_neovim" Content="Neovim CLI Editor" IsChecked="False"/>
                                    <TextBlock Text="Vim-fork focused on extensibility and usability (Neovim.Neovim)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_neovim" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_neovim" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <TextBlock Text="Terminal &amp; Prompt" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,10,0,8"/>

                        <!-- Windows Terminal -->
                        <Border x:Name="card_terminal" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_terminal" Content="Microsoft Windows Terminal" IsChecked="True"/>
                                    <TextBlock Text="Modern tabbed terminal with GPU acceleration (Microsoft.WindowsTerminal)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_terminal" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_terminal" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Starship Prompt -->
                        <Border x:Name="card_starship" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_starship" Content="Starship Cross-Shell Prompt" IsChecked="True"/>
                                    <TextBlock Text="Fast, customizable prompt for any shell (Starship.Starship)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_starship" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_starship" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- JetBrainsMono Nerd Font -->
                        <Border x:Name="card_nerdfont" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_nerdfont" Content="JetBrainsMono Nerd Font" IsChecked="True"/>
                                    <TextBlock Text="Developer font with patched powerline glyphs (DEVCOM.JetBrainsMonoNerdFont)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_nerdfont" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_nerdfont" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <TextBlock Text="CLI Utilities &amp; Version Control" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,10,0,8"/>

                        <!-- Git SCM -->
                        <Border x:Name="card_git" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_git" Content="Git SCM" IsChecked="True"/>
                                    <TextBlock Text="Distributed version control system (Git.Git)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_git" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_git" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- GitHub CLI -->
                        <Border x:Name="card_gh" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_gh" Content="GitHub CLI" IsChecked="True"/>
                                    <TextBlock Text="GitHub's official command line tool (GitHub.cli)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_gh" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_gh" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- 7-Zip -->
                        <Border x:Name="card_7zip" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_7zip" Content="7-Zip File Archiver" IsChecked="True"/>
                                    <TextBlock Text="High-compression file packaging utility (7zip.7zip)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_7zip" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_7zip" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Non-interactive SSH Key -->
                        <Border x:Name="card_sshkey" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_sshkey" Content="Generate Non-interactive Ed25519 SSH Key" IsChecked="True"/>
                                    <TextBlock Text="Creates cryptographic SSH authentication keypair without prompts" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_sshkey" Grid.Column="1" Background="#252538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_sshkey" Text="CONFIG" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <TextBlock Text="Web Browsers" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,10,0,8"/>

                        <!-- Google Chrome -->
                        <Border x:Name="card_chrome" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_chrome" Content="Google Chrome" IsChecked="True"/>
                                    <TextBlock Text="Fast, secure web browser by Google (Google.Chrome)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_chrome" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_chrome" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Mozilla Firefox -->
                        <Border x:Name="card_firefox" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_firefox" Content="Mozilla Firefox" IsChecked="False"/>
                                    <TextBlock Text="Privacy-focused open-source browser (Mozilla.Firefox)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_firefox" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_firefox" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Brave Browser -->
                        <Border x:Name="card_brave" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_brave" Content="Brave Browser" IsChecked="False"/>
                                    <TextBlock Text="Privacy browser with built-in ad and tracker blocking (Brave.Brave)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_brave" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_brave" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>
                    </StackPanel>

                    <!-- ============================================================== -->
                    <!-- PANEL 2: TILING DESKTOP & RICE -->
                    <!-- ============================================================== -->
                    <StackPanel x:Name="panelTiling" Visibility="Collapsed">
                        <TextBlock Text="Tiling Window Manager &amp; Status Bar" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,0,0,8"/>

                        <!-- GlazeWM -->
                        <Border x:Name="card_glazewm" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_glazewm" Content="GlazeWM Tiling Window Manager" IsChecked="True"/>
                                    <TextBlock Text="i3/bspwm inspired dynamic tiling for Windows 11 (glzr-io.glazewm)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_glazewm" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_glazewm" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Zebar Status Bar -->
                        <Border x:Name="card_zebar" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_zebar" Content="Zebar Status Bar" IsChecked="True"/>
                                    <TextBlock Text="Modern customizable desktop taskbar and widget surface (glzr-io.zebar)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_zebar" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_zebar" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- DWM Cloaking -->
                        <Border x:Name="card_dwm_cloak" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_dwm_cloak" Content="DWM Hardware Cloaking" IsChecked="True"/>
                                    <TextBlock Text="Zero window flicker cloaking for tiling manager" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_dwm_cloak" Grid.Column="1" Background="#252538" BorderBrush="#cba6f7" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_dwm_cloak" Text="FEATURE" FontSize="11" FontWeight="Bold" Foreground="#cba6f7"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Lavender Border -->
                        <Border x:Name="card_lavender_border" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_lavender_border" Content="Catppuccin Lavender Border" IsChecked="True"/>
                                    <TextBlock Text="Active window accent border in #cba6f7" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_lavender_border" Grid.Column="1" Background="#252538" BorderBrush="#cba6f7" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_lavender_border" Text="THEME" FontSize="11" FontWeight="Bold" Foreground="#cba6f7"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Zebar Nord Pack -->
                        <Border x:Name="card_nord_pack" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_nord_pack" Content="Zebar Nord Frosted Glass Widget Pack" IsChecked="True"/>
                                    <TextBlock Text="Frosted glass widgets with workspace indicators" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_nord_pack" Grid.Column="1" Background="#252538" BorderBrush="#cba6f7" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_nord_pack" Text="THEME" FontSize="11" FontWeight="Bold" Foreground="#cba6f7"/>
                                </Border>
                            </Grid>
                        </Border>

                        <TextBlock Text="Shortcuts &amp; Desktop Productivity" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,10,0,8"/>

                        <!-- AutoHotkey v2 -->
                        <Border x:Name="card_ahk" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_ahk" Content="AutoHotkey v2" IsChecked="True"/>
                                    <TextBlock Text="Super+HJKL window navigation and hotkey daemon (AutoHotkey.AutoHotkey)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_ahk" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_ahk" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Microsoft PowerToys -->
                        <Border x:Name="card_powertoys" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_powertoys" Content="Microsoft PowerToys" IsChecked="True"/>
                                    <TextBlock Text="FancyZones, PowerToys Run, and desktop utilities (Microsoft.PowerToys)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_powertoys" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_powertoys" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Dotfiles Symlink Coordinator -->
                        <Border x:Name="card_dotfiles" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_dotfiles" Content="Symlinked Dotfiles Coordinator" IsChecked="True"/>
                                    <TextBlock Text="Unprivileged NTFS symlinks for configs (.gitconfig, Starship, Zed, etc.)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_dotfiles" Grid.Column="1" Background="#252538" BorderBrush="#f9e2af" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_dotfiles" Text="SYSTEM" FontSize="11" FontWeight="Bold" Foreground="#f9e2af"/>
                                </Border>
                            </Grid>
                        </Border>
                    </StackPanel>

                    <!-- ============================================================== -->
                    <!-- PANEL 3: RUNTIMES & DATABASES -->
                    <!-- ============================================================== -->
                    <StackPanel x:Name="panelRuntimes" Visibility="Collapsed">
                        <TextBlock Text="Language Runtimes &amp; SDKs" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,0,0,8"/>

                        <!-- Node.js -->
                        <Border x:Name="card_node" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_node" Content="Node.js (LTS Runtime + npm)" IsChecked="True"/>
                                    <TextBlock Text="JavaScript runtime engine with npm package manager (OpenJS.NodeJS.LTS)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_node" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_node" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Python 3.12 -->
                        <Border x:Name="card_python" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_python" Content="Python 3.12+ Runtime &amp; pip" IsChecked="True"/>
                                    <TextBlock Text="Python programming language runtime and pip (Python.Python.3.12)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_python" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_python" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Rust Toolchain -->
                        <Border x:Name="card_rust" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_rust" Content="Rust Toolchain (rustup, rustc, cargo)" IsChecked="False"/>
                                    <TextBlock Text="rustup, rustc compiler, and cargo package manager (Rustlang.Rustup)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_rust" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_rust" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- .NET 9 SDK -->
                        <Border x:Name="card_dotnet" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_dotnet" Content=".NET 9 SDK (Core Developer SDK)" IsChecked="False"/>
                                    <TextBlock Text="Cross-platform .NET developer framework and CLI (Microsoft.DotNet.SDK.9)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_dotnet" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_dotnet" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <TextBlock Text="Databases &amp; Container Engines" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,10,0,8"/>

                        <!-- Docker Desktop -->
                        <Border x:Name="card_docker" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_docker" Content="Docker Desktop (Containers &amp; Compose)" IsChecked="True"/>
                                    <TextBlock Text="Container runtime, Docker Compose, and daemon (Docker.DockerDesktop)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_docker" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_docker" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- PostgreSQL -->
                        <Border x:Name="card_postgres" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_postgres" Content="PostgreSQL Client (psql &amp; engine tools)" IsChecked="True"/>
                                    <TextBlock Text="psql command line and database client tools (PostgreSQL.PostgreSQL)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_postgres" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_postgres" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Redis -->
                        <Border x:Name="card_redis" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_redis" Content="Redis (In-memory cache &amp; redis-cli)" IsChecked="True"/>
                                    <TextBlock Text="Key-value cache store and redis-cli tool (Redis.Redis)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_redis" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_redis" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- MongoDB -->
                        <Border x:Name="card_mongodb" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_mongodb" Content="MongoDB Database &amp; mongosh CLI" IsChecked="False"/>
                                    <TextBlock Text="Document database server and mongosh CLI (MongoDB.Server)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_mongodb" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_mongodb" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- SQLite -->
                        <Border x:Name="card_sqlite" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_sqlite" Content="SQLite 3 CLI Database Engine" IsChecked="True"/>
                                    <TextBlock Text="Self-contained, serverless SQL database engine (SQLite.SQLite)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_sqlite" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_sqlite" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>
                    </StackPanel>

                    <!-- ============================================================== -->
                    <!-- PANEL 4: AI & MEDIA -->
                    <!-- ============================================================== -->
                    <StackPanel x:Name="panelAI" Visibility="Collapsed">
                        <TextBlock Text="Local AI Workstation Stack" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,0,0,8"/>

                        <!-- Ollama -->
                        <Border x:Name="card_ollama" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_ollama" Content="Ollama (Local LLM CLI &amp; API Server)" IsChecked="False"/>
                                    <TextBlock Text="Run open models locally via CLI and API (Ollama.Ollama)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_ollama" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_ollama" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- LM Studio -->
                        <Border x:Name="card_lmstudio" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_lmstudio" Content="LM Studio (Local GUI LLM Playground)" IsChecked="False"/>
                                    <TextBlock Text="Desktop GUI to discover, download, and run LLMs (ElementLabs.LMStudio)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_lmstudio" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_lmstudio" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <TextBlock Text="Gaming &amp; Content Creation" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,10,0,8"/>

                        <!-- Steam -->
                        <Border x:Name="card_steam" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_steam" Content="Valve Steam Client" IsChecked="False"/>
                                    <TextBlock Text="Gaming platform and game library manager (Valve.Steam)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_steam" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_steam" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- OBS Studio -->
                        <Border x:Name="card_obs" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_obs" Content="OBS Studio (Screen Recording &amp; Streaming)" IsChecked="False"/>
                                    <TextBlock Text="High-performance video recording and live streaming (OBSProject.OBSStudio)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_obs" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_obs" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Discord -->
                        <Border x:Name="card_discord" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,8">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <CheckBox x:Name="chk_discord" Content="Discord Desktop Client" IsChecked="False"/>
                                    <TextBlock Text="Voice, video, and text communication platform (Discord.Discord)" FontSize="11" Foreground="#a6adc8" Margin="24,2,0,0"/>
                                </StackPanel>
                                <Border x:Name="border_badge_discord" Grid.Column="1" Background="#1e2538" BorderBrush="#89b4fa" BorderThickness="1" CornerRadius="4" Padding="8,3" VerticalAlignment="Center">
                                    <TextBlock x:Name="badge_discord" Text="AVAILABLE" FontSize="11" FontWeight="Bold" Foreground="#89b4fa"/>
                                </Border>
                            </Grid>
                        </Border>
                    </StackPanel>

                    <!-- ============================================================== -->
                    <!-- PANEL 5: MAINTENANCE & TOOLS -->
                    <!-- ============================================================== -->
                    <StackPanel x:Name="panelMaintenance" Visibility="Collapsed">
                        <TextBlock Text="Day-2 System Utilities &amp; Diagnostics" FontSize="13" FontWeight="Bold" Foreground="#cba6f7" Margin="0,0,0,8"/>

                        <!-- Doctor -->
                        <Border x:Name="card_maint_doctor" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="14,12" Margin="0,0,0,10">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <TextBlock Text="Machine Health Doctor (-Doctor)" FontSize="13" FontWeight="Bold" Foreground="#89b4fa"/>
                                    <TextBlock Text="Executes 17-point health and environment audit (Windows build, Developer mode, winget, path variables, symlink integrity)." FontSize="11" Foreground="#a6adc8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                                </StackPanel>
                                <Button x:Name="btnLaunchDoctor" Grid.Column="1" Content="Run Health Doctor" Background="#252538" Foreground="#89b4fa" BorderBrush="#89b4fa" BorderThickness="1" Padding="12,6" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>

                        <!-- Backup -->
                        <Border x:Name="card_maint_backup" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="14,12" Margin="0,0,0,10">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <TextBlock Text="Create Disaster Recovery Archive (-Backup)" FontSize="13" FontWeight="Bold" Foreground="#94e2d5"/>
                                    <TextBlock Text="Generates SHA256 checksummed zip backup of configs, manifests, and active dotfiles." FontSize="11" Foreground="#a6adc8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                                </StackPanel>
                                <Button x:Name="btnLaunchBackup" Grid.Column="1" Content="Create Backup Archive" Background="#252538" Foreground="#94e2d5" BorderBrush="#94e2d5" BorderThickness="1" Padding="12,6" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>

                        <!-- Export -->
                        <Border x:Name="card_maint_export" Background="#181825" BorderBrush="#313244" BorderThickness="1" CornerRadius="8" Padding="14,12" Margin="0,0,0,10">
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                    <TextBlock Text="Workstation State Exporter (-Export)" FontSize="13" FontWeight="Bold" Foreground="#f9e2af"/>
                                    <TextBlock Text="Scans installed winget packages and machine tools into a portable declarative YAML config." FontSize="11" Foreground="#a6adc8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                                </StackPanel>
                                <Button x:Name="btnLaunchExport" Grid.Column="1" Content="Export to YAML" Background="#252538" Foreground="#f9e2af" BorderBrush="#f9e2af" BorderThickness="1" Padding="12,6" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                    </StackPanel>
                </StackPanel>
            </ScrollViewer>

            <!-- ROW 3: BOTTOM ACTION DOCK -->
            <Border Grid.Row="3" Background="#181825" BorderBrush="#313244" BorderThickness="0,1,0,0" Padding="18,12">
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
                        <Button x:Name="btnDryRun" Content="Simulate (Dry-Run)" Background="#252538" Foreground="#94e2d5" BorderBrush="#94e2d5" BorderThickness="1" Padding="14,8" Margin="0,0,10,0" FontWeight="SemiBold"/>
                        <Button x:Name="btnApply" Content="Install Selected" Background="#cba6f7" Foreground="#11111b" BorderThickness="0" Padding="20,8" FontWeight="Bold" FontSize="13"/>
                        <Button x:Name="btnCancel" Content="Cancel" Background="#181825" Foreground="#a6adc8" BorderBrush="#313244" BorderThickness="1" Padding="14,8" Margin="10,0,0,0"/>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
"@

try {
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error "Failed to parse devbox-win GUI XAML: $($_.Exception.Message)"
    throw $_
}

# Sidebar Navigation Controls
$btnNavToolchain = $window.FindName("btnNavToolchain")
$btnNavTiling = $window.FindName("btnNavTiling")
$btnNavRuntimes = $window.FindName("btnNavRuntimes")
$btnNavAI = $window.FindName("btnNavAI")
$btnNavMaintenance = $window.FindName("btnNavMaintenance")

# Content Panels
$panelToolchain = $window.FindName("panelToolchain")
$panelTiling = $window.FindName("panelTiling")
$panelRuntimes = $window.FindName("panelRuntimes")
$panelAI = $window.FindName("panelAI")
$panelMaintenance = $window.FindName("panelMaintenance")

# Top Controls & Filter Elements
$btnScanInstalled = $window.FindName("btnScanInstalled")
$btnSelectAll = $window.FindName("btnSelectAll")
$btnClearAll = $window.FindName("btnClearAll")
$btnFilterAll = $window.FindName("btnFilterAll")
$btnFilterInstalled = $window.FindName("btnFilterInstalled")
$btnFilterAvailable = $window.FindName("btnFilterAvailable")
$txtSearch = $window.FindName("txtSearch")

# Custom Installation Path
$txtCustomPath = $window.FindName("txtCustomPath")
$btnBrowsePath = $window.FindName("btnBrowsePath")

# Action Dock
$txtStatusSummary = $window.FindName("txtStatusSummary")
$btnDryRun = $window.FindName("btnDryRun")
$btnApply = $window.FindName("btnApply")
$btnCancel = $window.FindName("btnCancel")

# Maintenance Actions
$btnLaunchDoctor = $window.FindName("btnLaunchDoctor")
$btnLaunchBackup = $window.FindName("btnLaunchBackup")
$btnLaunchExport = $window.FindName("btnLaunchExport")

# Toolchain Checkboxes & Badges
$chk_zed = $window.FindName("chk_zed")
$badge_zed = $window.FindName("badge_zed")
$border_badge_zed = $window.FindName("border_badge_zed")
$card_zed = $window.FindName("card_zed")

$chk_vscode = $window.FindName("chk_vscode")
$badge_vscode = $window.FindName("badge_vscode")
$border_badge_vscode = $window.FindName("border_badge_vscode")
$card_vscode = $window.FindName("card_vscode")

$chk_neovim = $window.FindName("chk_neovim")
$badge_neovim = $window.FindName("badge_neovim")
$border_badge_neovim = $window.FindName("border_badge_neovim")
$card_neovim = $window.FindName("card_neovim")

$chk_terminal = $window.FindName("chk_terminal")
$badge_terminal = $window.FindName("badge_terminal")
$border_badge_terminal = $window.FindName("border_badge_terminal")
$card_terminal = $window.FindName("card_terminal")

$chk_starship = $window.FindName("chk_starship")
$badge_starship = $window.FindName("badge_starship")
$border_badge_starship = $window.FindName("border_badge_starship")
$card_starship = $window.FindName("card_starship")

$chk_nerdfont = $window.FindName("chk_nerdfont")
$badge_nerdfont = $window.FindName("badge_nerdfont")
$border_badge_nerdfont = $window.FindName("border_badge_nerdfont")
$card_nerdfont = $window.FindName("card_nerdfont")

$chk_git = $window.FindName("chk_git")
$badge_git = $window.FindName("badge_git")
$border_badge_git = $window.FindName("border_badge_git")
$card_git = $window.FindName("card_git")

$chk_gh = $window.FindName("chk_gh")
$badge_gh = $window.FindName("badge_gh")
$border_badge_gh = $window.FindName("border_badge_gh")
$card_gh = $window.FindName("card_gh")

$chk_7zip = $window.FindName("chk_7zip")
$badge_7zip = $window.FindName("badge_7zip")
$border_badge_7zip = $window.FindName("border_badge_7zip")
$card_7zip = $window.FindName("card_7zip")

$chk_sshkey = $window.FindName("chk_sshkey")
$badge_sshkey = $window.FindName("badge_sshkey")
$border_badge_sshkey = $window.FindName("border_badge_sshkey")
$card_sshkey = $window.FindName("card_sshkey")

$chk_chrome = $window.FindName("chk_chrome")
$badge_chrome = $window.FindName("badge_chrome")
$border_badge_chrome = $window.FindName("border_badge_chrome")
$card_chrome = $window.FindName("card_chrome")

$chk_firefox = $window.FindName("chk_firefox")
$badge_firefox = $window.FindName("badge_firefox")
$border_badge_firefox = $window.FindName("border_badge_firefox")
$card_firefox = $window.FindName("card_firefox")

$chk_brave = $window.FindName("chk_brave")
$badge_brave = $window.FindName("badge_brave")
$border_badge_brave = $window.FindName("border_badge_brave")
$card_brave = $window.FindName("card_brave")

# Tiling Checkboxes & Badges
$chk_glazewm = $window.FindName("chk_glazewm")
$badge_glazewm = $window.FindName("badge_glazewm")
$border_badge_glazewm = $window.FindName("border_badge_glazewm")
$card_glazewm = $window.FindName("card_glazewm")

$chk_zebar = $window.FindName("chk_zebar")
$badge_zebar = $window.FindName("badge_zebar")
$border_badge_zebar = $window.FindName("border_badge_zebar")
$card_zebar = $window.FindName("card_zebar")

$chk_dwm_cloak = $window.FindName("chk_dwm_cloak")
$badge_dwm_cloak = $window.FindName("badge_dwm_cloak")
$border_badge_dwm_cloak = $window.FindName("border_badge_dwm_cloak")
$card_dwm_cloak = $window.FindName("card_dwm_cloak")

$chk_lavender_border = $window.FindName("chk_lavender_border")
$badge_lavender_border = $window.FindName("badge_lavender_border")
$border_badge_lavender_border = $window.FindName("border_badge_lavender_border")
$card_lavender_border = $window.FindName("card_lavender_border")

$chk_nord_pack = $window.FindName("chk_nord_pack")
$badge_nord_pack = $window.FindName("badge_nord_pack")
$border_badge_nord_pack = $window.FindName("border_badge_nord_pack")
$card_nord_pack = $window.FindName("card_nord_pack")

$chk_ahk = $window.FindName("chk_ahk")
$badge_ahk = $window.FindName("badge_ahk")
$border_badge_ahk = $window.FindName("border_badge_ahk")
$card_ahk = $window.FindName("card_ahk")

$chk_powertoys = $window.FindName("chk_powertoys")
$badge_powertoys = $window.FindName("badge_powertoys")
$border_badge_powertoys = $window.FindName("border_badge_powertoys")
$card_powertoys = $window.FindName("card_powertoys")

$chk_dotfiles = $window.FindName("chk_dotfiles")
$badge_dotfiles = $window.FindName("badge_dotfiles")
$border_badge_dotfiles = $window.FindName("border_badge_dotfiles")
$card_dotfiles = $window.FindName("card_dotfiles")

# Runtimes Checkboxes & Badges
$chk_node = $window.FindName("chk_node")
$badge_node = $window.FindName("badge_node")
$border_badge_node = $window.FindName("border_badge_node")
$card_node = $window.FindName("card_node")

$chk_python = $window.FindName("chk_python")
$badge_python = $window.FindName("badge_python")
$border_badge_python = $window.FindName("border_badge_python")
$card_python = $window.FindName("card_python")

$chk_rust = $window.FindName("chk_rust")
$badge_rust = $window.FindName("badge_rust")
$border_badge_rust = $window.FindName("border_badge_rust")
$card_rust = $window.FindName("card_rust")

$chk_dotnet = $window.FindName("chk_dotnet")
$badge_dotnet = $window.FindName("badge_dotnet")
$border_badge_dotnet = $window.FindName("border_badge_dotnet")
$card_dotnet = $window.FindName("card_dotnet")

$chk_docker = $window.FindName("chk_docker")
$badge_docker = $window.FindName("badge_docker")
$border_badge_docker = $window.FindName("border_badge_docker")
$card_docker = $window.FindName("card_docker")

$chk_postgres = $window.FindName("chk_postgres")
$badge_postgres = $window.FindName("badge_postgres")
$border_badge_postgres = $window.FindName("border_badge_postgres")
$card_postgres = $window.FindName("card_postgres")

$chk_redis = $window.FindName("chk_redis")
$badge_redis = $window.FindName("badge_redis")
$border_badge_redis = $window.FindName("border_badge_redis")
$card_redis = $window.FindName("card_redis")

$chk_mongodb = $window.FindName("chk_mongodb")
$badge_mongodb = $window.FindName("badge_mongodb")
$border_badge_mongodb = $window.FindName("border_badge_mongodb")
$card_mongodb = $window.FindName("card_mongodb")

$chk_sqlite = $window.FindName("chk_sqlite")
$badge_sqlite = $window.FindName("badge_sqlite")
$border_badge_sqlite = $window.FindName("border_badge_sqlite")
$card_sqlite = $window.FindName("card_sqlite")

# AI & Media Checkboxes & Badges
$chk_ollama = $window.FindName("chk_ollama")
$badge_ollama = $window.FindName("badge_ollama")
$border_badge_ollama = $window.FindName("border_badge_ollama")
$card_ollama = $window.FindName("card_ollama")

$chk_lmstudio = $window.FindName("chk_lmstudio")
$badge_lmstudio = $window.FindName("badge_lmstudio")
$border_badge_lmstudio = $window.FindName("border_badge_lmstudio")
$card_lmstudio = $window.FindName("card_lmstudio")

$chk_steam = $window.FindName("chk_steam")
$badge_steam = $window.FindName("badge_steam")
$border_badge_steam = $window.FindName("border_badge_steam")
$card_steam = $window.FindName("card_steam")

$chk_obs = $window.FindName("chk_obs")
$badge_obs = $window.FindName("badge_obs")
$border_badge_obs = $window.FindName("border_badge_obs")
$card_obs = $window.FindName("card_obs")

$chk_discord = $window.FindName("chk_discord")
$badge_discord = $window.FindName("badge_discord")
$border_badge_discord = $window.FindName("border_badge_discord")
$card_discord = $window.FindName("card_discord")

# All package checkboxes mapped to winget IDs (30 Core Packages)
$pkgCheckboxMap = @{
    $chk_zed = "Zed.Zed"
    $chk_vscode = "Microsoft.VisualStudioCode"
    $chk_neovim = "Neovim.Neovim"
    $chk_terminal = "Microsoft.WindowsTerminal"
    $chk_starship = "Starship.Starship"
    $chk_nerdfont = "DEVCOM.JetBrainsMonoNerdFont"
    $chk_git = "Git.Git"
    $chk_gh = "GitHub.cli"
    $chk_7zip = "7zip.7zip"
    $chk_chrome = "Google.Chrome"
    $chk_firefox = "Mozilla.Firefox"
    $chk_brave = "Brave.Brave"
    $chk_glazewm = "glzr-io.glazewm"
    $chk_zebar = "glzr-io.zebar"
    $chk_ahk = "AutoHotkey.AutoHotkey"
    $chk_powertoys = "Microsoft.PowerToys"
    $chk_node = "OpenJS.NodeJS.LTS"
    $chk_python = "Python.Python.3.12"
    $chk_rust = "Rustlang.Rustup"
    $chk_dotnet = "Microsoft.DotNet.SDK.9"
    $chk_docker = "Docker.DockerDesktop"
    $chk_postgres = "PostgreSQL.PostgreSQL"
    $chk_redis = "Redis.Redis"
    $chk_mongodb = "MongoDB.Server"
    $chk_sqlite = "SQLite.SQLite"
    $chk_ollama = "Ollama.Ollama"
    $chk_lmstudio = "ElementLabs.LMStudio"
    $chk_steam = "Valve.Steam"
    $chk_obs = "OBSProject.OBSStudio"
    $chk_discord = "Discord.Discord"
}

# All checkboxes list (30 packages)
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

# Comprehensive Package Card Index for live search, category routing, and dynamic badge updates
$script:PackageCardList = @(
    [PSCustomObject]@{ CheckBox = $chk_zed; Badge = $badge_zed; Border = $border_badge_zed; Card = $card_zed; PackageId = "Zed.Zed"; SearchIndex = "zed editor rust gpu zed.zed"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_vscode; Badge = $badge_vscode; Border = $border_badge_vscode; Card = $card_vscode; PackageId = "Microsoft.VisualStudioCode"; SearchIndex = "visual studio code vscode microsoft.visualstudiocode"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_neovim; Badge = $badge_neovim; Border = $border_badge_neovim; Card = $card_neovim; PackageId = "Neovim.Neovim"; SearchIndex = "neovim vim cli editor neovim.neovim"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_terminal; Badge = $badge_terminal; Border = $border_badge_terminal; Card = $card_terminal; PackageId = "Microsoft.WindowsTerminal"; SearchIndex = "microsoft windows terminal wt console microsoft.windowsterminal"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_starship; Badge = $badge_starship; Border = $border_badge_starship; Card = $card_starship; PackageId = "Starship.Starship"; SearchIndex = "starship prompt shell starship.starship"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_nerdfont; Badge = $badge_nerdfont; Border = $border_badge_nerdfont; Card = $card_nerdfont; PackageId = "DEVCOM.JetBrainsMonoNerdFont"; SearchIndex = "jetbrainsmono nerd font devcom.jetbrainsmononerdfont"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_git; Badge = $badge_git; Border = $border_badge_git; Card = $card_git; PackageId = "Git.Git"; SearchIndex = "git scm version control git.git"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_gh; Badge = $badge_gh; Border = $border_badge_gh; Card = $card_gh; PackageId = "GitHub.cli"; SearchIndex = "github cli gh github.cli"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_7zip; Badge = $badge_7zip; Border = $border_badge_7zip; Card = $card_7zip; PackageId = "7zip.7zip"; SearchIndex = "7-zip archiver zip 7zip.7zip"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_sshkey; Badge = $badge_sshkey; Border = $border_badge_sshkey; Card = $card_sshkey; PackageId = ""; SearchIndex = "generate ssh key ed25519 cryptography"; PanelName = "panelToolchain"; IsInstalled = $null },
    [PSCustomObject]@{ CheckBox = $chk_chrome; Badge = $badge_chrome; Border = $border_badge_chrome; Card = $card_chrome; PackageId = "Google.Chrome"; SearchIndex = "google chrome web browser google.chrome"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_firefox; Badge = $badge_firefox; Border = $border_badge_firefox; Card = $card_firefox; PackageId = "Mozilla.Firefox"; SearchIndex = "mozilla firefox browser mozilla.firefox"; PanelName = "panelToolchain"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_brave; Badge = $badge_brave; Border = $border_badge_brave; Card = $card_brave; PackageId = "Brave.Brave"; SearchIndex = "brave browser brave.brave"; PanelName = "panelToolchain"; IsInstalled = $false },
    
    [PSCustomObject]@{ CheckBox = $chk_glazewm; Badge = $badge_glazewm; Border = $border_badge_glazewm; Card = $card_glazewm; PackageId = "glzr-io.glazewm"; SearchIndex = "glazewm tiling window manager glzr-io.glazewm"; PanelName = "panelTiling"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_zebar; Badge = $badge_zebar; Border = $border_badge_zebar; Card = $card_zebar; PackageId = "glzr-io.zebar"; SearchIndex = "zebar status bar taskbar glzr-io.zebar"; PanelName = "panelTiling"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_dwm_cloak; Badge = $badge_dwm_cloak; Border = $border_badge_dwm_cloak; Card = $card_dwm_cloak; PackageId = ""; SearchIndex = "dwm hardware cloaking zero flicker"; PanelName = "panelTiling"; IsInstalled = $null },
    [PSCustomObject]@{ CheckBox = $chk_lavender_border; Badge = $badge_lavender_border; Border = $border_badge_lavender_border; Card = $card_lavender_border; PackageId = ""; SearchIndex = "catppuccin lavender border theme"; PanelName = "panelTiling"; IsInstalled = $null },
    [PSCustomObject]@{ CheckBox = $chk_nord_pack; Badge = $badge_nord_pack; Border = $border_badge_nord_pack; Card = $card_nord_pack; PackageId = ""; SearchIndex = "zebar nord frosted glass pack theme"; PanelName = "panelTiling"; IsInstalled = $null },
    [PSCustomObject]@{ CheckBox = $chk_ahk; Badge = $badge_ahk; Border = $border_badge_ahk; Card = $card_ahk; PackageId = "AutoHotkey.AutoHotkey"; SearchIndex = "autohotkey ahk v2 hotkeys autohotkey.autohotkey"; PanelName = "panelTiling"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_powertoys; Badge = $badge_powertoys; Border = $border_badge_powertoys; Card = $card_powertoys; PackageId = "Microsoft.PowerToys"; SearchIndex = "microsoft powertoys fancyzones microsoft.powertoys"; PanelName = "panelTiling"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_dotfiles; Badge = $badge_dotfiles; Border = $border_badge_dotfiles; Card = $card_dotfiles; PackageId = ""; SearchIndex = "symlinked dotfiles coordinator ntfs backup"; PanelName = "panelTiling"; IsInstalled = $null },

    [PSCustomObject]@{ CheckBox = $chk_node; Badge = $badge_node; Border = $border_badge_node; Card = $card_node; PackageId = "OpenJS.NodeJS.LTS"; SearchIndex = "node.js nodejs npm javascript openjs.nodejs.lts"; PanelName = "panelRuntimes"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_python; Badge = $badge_python; Border = $border_badge_python; Card = $card_python; PackageId = "Python.Python.3.12"; SearchIndex = "python pip runtime python.python.3.12"; PanelName = "panelRuntimes"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_rust; Badge = $badge_rust; Border = $border_badge_rust; Card = $card_rust; PackageId = "Rustlang.Rustup"; SearchIndex = "rust toolchain rustup cargo rustc rustlang.rustup"; PanelName = "panelRuntimes"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_dotnet; Badge = $badge_dotnet; Border = $border_badge_dotnet; Card = $card_dotnet; PackageId = "Microsoft.DotNet.SDK.9"; SearchIndex = "dotnet .net sdk 9 c# f# microsoft.dotnet.sdk.9"; PanelName = "panelRuntimes"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_docker; Badge = $badge_docker; Border = $border_badge_docker; Card = $card_docker; PackageId = "Docker.DockerDesktop"; SearchIndex = "docker desktop containers compose docker.dockerdesktop"; PanelName = "panelRuntimes"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_postgres; Badge = $badge_postgres; Border = $border_badge_postgres; Card = $card_postgres; PackageId = "PostgreSQL.PostgreSQL"; SearchIndex = "postgresql postgres psql database postgresql.postgresql"; PanelName = "panelRuntimes"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_redis; Badge = $badge_redis; Border = $border_badge_redis; Card = $card_redis; PackageId = "Redis.Redis"; SearchIndex = "redis cache in-memory database redis.redis"; PanelName = "panelRuntimes"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_mongodb; Badge = $badge_mongodb; Border = $border_badge_mongodb; Card = $card_mongodb; PackageId = "MongoDB.Server"; SearchIndex = "mongodb server mongosh database mongodb.server"; PanelName = "panelRuntimes"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_sqlite; Badge = $badge_sqlite; Border = $border_badge_sqlite; Card = $card_sqlite; PackageId = "SQLite.SQLite"; SearchIndex = "sqlite 3 cli database sqlite.sqlite"; PanelName = "panelRuntimes"; IsInstalled = $false },

    [PSCustomObject]@{ CheckBox = $chk_ollama; Badge = $badge_ollama; Border = $border_badge_ollama; Card = $card_ollama; PackageId = "Ollama.Ollama"; SearchIndex = "ollama local llm ai runner ollama.ollama"; PanelName = "panelAI"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_lmstudio; Badge = $badge_lmstudio; Border = $border_badge_lmstudio; Card = $card_lmstudio; PackageId = "ElementLabs.LMStudio"; SearchIndex = "lm studio local ai playground elementlabs.lmstudio"; PanelName = "panelAI"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_steam; Badge = $badge_steam; Border = $border_badge_steam; Card = $card_steam; PackageId = "Valve.Steam"; SearchIndex = "steam gaming valve library valve.steam"; PanelName = "panelAI"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_obs; Badge = $badge_obs; Border = $border_badge_obs; Card = $card_obs; PackageId = "OBSProject.OBSStudio"; SearchIndex = "obs studio streaming recording obsproject.obsstudio"; PanelName = "panelAI"; IsInstalled = $false },
    [PSCustomObject]@{ CheckBox = $chk_discord; Badge = $badge_discord; Border = $border_badge_discord; Card = $card_discord; PackageId = "Discord.Discord"; SearchIndex = "discord chat voice media discord.discord"; PanelName = "panelAI"; IsInstalled = $false }
)

# Color Brushes
$brushConverter = [System.Windows.Media.BrushConverter]::new()
$brushInstalledBg = $brushConverter.ConvertFromString("#1a3028")
$brushInstalledFg = $brushConverter.ConvertFromString("#a6e3a1")
$brushAvailableBg = $brushConverter.ConvertFromString("#1e2538")
$brushAvailableFg = $brushConverter.ConvertFromString("#89b4fa")

# Navigation & Filter State
$script:CurrentNavPanel = "toolchain"
$script:ActiveFilter = "all"
$script:InstalledCount = 0

function Switch-NavPanel([string]$PanelName) {
    $script:CurrentNavPanel = $PanelName

    $navButtons = @{
        "toolchain"   = $btnNavToolchain
        "tiling"      = $btnNavTiling
        "runtimes"    = $btnNavRuntimes
        "ai"          = $btnNavAI
        "maintenance" = $btnNavMaintenance
    }

    $navPanels = @{
        "toolchain"   = $panelToolchain
        "tiling"      = $panelTiling
        "runtimes"    = $panelRuntimes
        "ai"          = $panelAI
        "maintenance" = $panelMaintenance
    }

    $activeNavBg = $brushConverter.ConvertFromString("#252538")
    $activeNavFg = $brushConverter.ConvertFromString("#cba6f7")
    $activeNavBorder = $brushConverter.ConvertFromString("#cba6f7")
    $inactiveNavBg = [System.Windows.Media.Brushes]::Transparent
    $inactiveNavFg = $brushConverter.ConvertFromString("#a6adc8")
    $inactiveNavBorder = [System.Windows.Media.Brushes]::Transparent

    foreach ($key in $navButtons.Keys) {
        $btn = $navButtons[$key]
        $pnl = $navPanels[$key]
        if ($btn) {
            if ($key -eq $PanelName) {
                $btn.Background = $activeNavBg
                $btn.Foreground = $activeNavFg
                $btn.BorderBrush = $activeNavBorder
            } else {
                $btn.Background = $inactiveNavBg
                $btn.Foreground = $inactiveNavFg
                $btn.BorderBrush = $inactiveNavBorder
            }
        }
        if ($pnl) {
            $pnl.Visibility = if ($key -eq $PanelName) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }
    }
}

# Live Selection & Machine Detection Summary Updater
function Update-LiveSummary {
    if ($txtStatusSummary) {
        $selectedCount = @($allCheckboxes | Where-Object { $null -ne $_ -and $_.IsChecked }).Count
        $txtStatusSummary.Text = "Selected: $selectedCount packages | $($script:InstalledCount) already installed on machine"
    }
}

# Live Package Detection Engine
function Update-PackageInstallBadges {
    param([switch]$ForceRefresh)

    $installedSet = if ($ForceRefresh) {
        Get-DevboxInstalledPackageSet -ForceRefresh
    } else {
        Get-DevboxInstalledPackageSet
    }

    $detectedCount = 0

    foreach ($entry in $script:PackageCardList) {
        if ([string]::IsNullOrWhiteSpace($entry.PackageId)) {
            continue
        }

        $isInstalled = if ($installedSet -is [System.Collections.Generic.HashSet[string]]) {
            $installedSet.Contains($entry.PackageId)
        } else {
            $installedSet -contains $entry.PackageId
        }

        $entry.IsInstalled = [bool]$isInstalled

        if ($isInstalled) {
            $detectedCount++
            if ($entry.Badge) {
                $entry.Badge.Text = "INSTALLED"
                $entry.Badge.Foreground = $brushInstalledFg
            }
            if ($entry.Border) {
                $entry.Border.Background = $brushInstalledBg
                $entry.Border.BorderBrush = $brushInstalledFg
            }
        } else {
            if ($entry.Badge) {
                $entry.Badge.Text = "AVAILABLE"
                $entry.Badge.Foreground = $brushAvailableFg
            }
            if ($entry.Border) {
                $entry.Border.Background = $brushAvailableBg
                $entry.Border.BorderBrush = $brushAvailableFg
            }
        }
    }

    $script:InstalledCount = $detectedCount
    Update-LiveSummary
    Update-PackageFilter
}

# Filter Chips & Search Engine
function Set-PackageFilter([string]$FilterMode) {
    $script:ActiveFilter = $FilterMode

    $activeBg = $brushConverter.ConvertFromString("#252538")
    $inactiveBg = $brushConverter.ConvertFromString("#1e1e2e")
    $inactiveBorder = $brushConverter.ConvertFromString("#313244")
    $inactiveFg = $brushConverter.ConvertFromString("#a6adc8")

    if ($btnFilterAll) {
        $btnFilterAll.Background = if ($FilterMode -eq "all") { $activeBg } else { $inactiveBg }
        $btnFilterAll.BorderBrush = if ($FilterMode -eq "all") { $brushConverter.ConvertFromString("#cba6f7") } else { $inactiveBorder }
        $btnFilterAll.Foreground = if ($FilterMode -eq "all") { $brushConverter.ConvertFromString("#cba6f7") } else { $inactiveFg }
    }
    if ($btnFilterInstalled) {
        $btnFilterInstalled.Background = if ($FilterMode -eq "installed") { $activeBg } else { $inactiveBg }
        $btnFilterInstalled.BorderBrush = if ($FilterMode -eq "installed") { $brushConverter.ConvertFromString("#a6e3a1") } else { $inactiveBorder }
        $btnFilterInstalled.Foreground = if ($FilterMode -eq "installed") { $brushConverter.ConvertFromString("#a6e3a1") } else { $inactiveFg }
    }
    if ($btnFilterAvailable) {
        $btnFilterAvailable.Background = if ($FilterMode -eq "available") { $activeBg } else { $inactiveBg }
        $btnFilterAvailable.BorderBrush = if ($FilterMode -eq "available") { $brushConverter.ConvertFromString("#89b4fa") } else { $inactiveBorder }
        $btnFilterAvailable.Foreground = if ($FilterMode -eq "available") { $brushConverter.ConvertFromString("#89b4fa") } else { $inactiveFg }
    }

    Update-PackageFilter
}

function Update-PackageFilter {
    $searchTerm = if ($txtSearch) { $txtSearch.Text.Trim().ToLower() } else { "" }
    $hasSearch = -not [string]::IsNullOrWhiteSpace($searchTerm)

    foreach ($entry in $script:PackageCardList) {
        $matchesSearch = $true
        if ($hasSearch) {
            $matchesSearch = ($entry.SearchIndex -like "*$searchTerm*")
        }

        $matchesFilter = $true
        if ($script:ActiveFilter -eq "installed") {
            $matchesFilter = ($entry.IsInstalled -eq $true)
        } elseif ($script:ActiveFilter -eq "available") {
            $matchesFilter = ($entry.IsInstalled -eq $false)
        }

        if ($entry.Card) {
            if ($matchesSearch -and $matchesFilter) {
                $entry.Card.Visibility = [System.Windows.Visibility]::Visible
            } else {
                $entry.Card.Visibility = [System.Windows.Visibility]::Collapsed
            }
        }
    }

    if ($hasSearch) {
        foreach ($panelName in @("panelToolchain", "panelTiling", "panelRuntimes", "panelAI", "panelMaintenance")) {
            $panelObj = $window.FindName($panelName)
            if ($panelObj) {
                $hasVisible = $false
                foreach ($entry in $script:PackageCardList) {
                    if ($entry.PanelName -eq $panelName -and $entry.Card.Visibility -eq [System.Windows.Visibility]::Visible) {
                        $hasVisible = $true
                        break
                    }
                }
                $panelObj.Visibility = if ($hasVisible) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            }
        }
    } else {
        Switch-NavPanel $script:CurrentNavPanel
    }
}

# Attach Live Listeners to All Checkboxes
foreach ($cb in $allCheckboxes) {
    if ($cb) {
        $cb.Add_Checked({ Update-LiveSummary })
        $cb.Add_Unchecked({ Update-LiveSummary })
    }
}

# Wire Sidebar Navigation Buttons
if ($btnNavToolchain) { $btnNavToolchain.Add_Click({ Switch-NavPanel "toolchain" }) }
if ($btnNavTiling) { $btnNavTiling.Add_Click({ Switch-NavPanel "tiling" }) }
if ($btnNavRuntimes) { $btnNavRuntimes.Add_Click({ Switch-NavPanel "runtimes" }) }
if ($btnNavAI) { $btnNavAI.Add_Click({ Switch-NavPanel "ai" }) }
if ($btnNavMaintenance) { $btnNavMaintenance.Add_Click({ Switch-NavPanel "maintenance" }) }

# Wire Top Action Buttons
if ($btnScanInstalled) { $btnScanInstalled.Add_Click({ Update-PackageInstallBadges -ForceRefresh }) }
if ($btnFilterAll) { $btnFilterAll.Add_Click({ Set-PackageFilter "all" }) }
if ($btnFilterInstalled) { $btnFilterInstalled.Add_Click({ Set-PackageFilter "installed" }) }
if ($btnFilterAvailable) { $btnFilterAvailable.Add_Click({ Set-PackageFilter "available" }) }

# Wire Live Search Box
if ($txtSearch) {
    $txtSearch.Add_TextChanged({ Update-PackageFilter })
}

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
            Update-LiveSummary
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
            Update-LiveSummary
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
            Update-LiveSummary
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
            Update-LiveSummary
        }
        "minimal" {
            foreach ($cb in $allCheckboxes) { $cb.IsChecked = $false }
            $chk_terminal.IsChecked = $true
            $chk_git.IsChecked = $true
            $chk_7zip.IsChecked = $true
            $chk_nerdfont.IsChecked = $true
            Update-LiveSummary
        }
        "selectall" {
            foreach ($cb in $allCheckboxes) { $cb.IsChecked = $true }
            Update-LiveSummary
        }
        "clearall" {
            foreach ($cb in $allCheckboxes) { $cb.IsChecked = $false }
            Update-LiveSummary
        }
    }
}

# Attach Preset Button Handlers
if ($window.FindName("btnPresetCatppuccin")) { ($window.FindName("btnPresetCatppuccin")).Add_Click({ Apply-PresetState "catppuccin" }) }
if ($window.FindName("btnPresetFullstack"))   { ($window.FindName("btnPresetFullstack")).Add_Click({ Apply-PresetState "fullstack" }) }
if ($window.FindName("btnPresetFrontend"))    { ($window.FindName("btnPresetFrontend")).Add_Click({ Apply-PresetState "frontend" }) }
if ($window.FindName("btnPresetBackend"))     { ($window.FindName("btnPresetBackend")).Add_Click({ Apply-PresetState "backend" }) }
if ($window.FindName("btnPresetMinimal"))     { ($window.FindName("btnPresetMinimal")).Add_Click({ Apply-PresetState "minimal" }) }
if ($btnSelectAll)                           { $btnSelectAll.Add_Click({ Apply-PresetState "selectall" }) }
if ($btnClearAll)                            { $btnClearAll.Add_Click({ Apply-PresetState "clearall" }) }

# Pre-select preset if provided via parameter
if (-not [string]::IsNullOrWhiteSpace($Preset)) {
    $cleanPreset = $Preset.ToLower().Replace("belal-", "")
    Apply-PresetState $cleanPreset
}

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

# Initial Package Badges Scan
Update-PackageInstallBadges

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
if ($btnApply) {
    $btnApply.Add_Click({
        $script:GuiResult.Action = "Install"
        $script:GuiResult.Config = Get-CompiledConfigFromUI
        $script:GuiResult.DryRun = $false
        $window.Close()
    })
}

if ($btnDryRun) {
    $btnDryRun.Add_Click({
        $script:GuiResult.Action = "DryRun"
        $script:GuiResult.Config = Get-CompiledConfigFromUI
        $script:GuiResult.DryRun = $true
        $window.Close()
    })
}

if ($btnCancel) {
    $btnCancel.Add_Click({
        $script:GuiResult.Action = "Cancel"
        $window.Close()
    })
}

# Maintenance buttons
if ($btnLaunchDoctor) {
    $btnLaunchDoctor.Add_Click({
        $script:GuiResult.Action = "Doctor"
        $window.Close()
    })
}

if ($btnLaunchBackup) {
    $btnLaunchBackup.Add_Click({
        $script:GuiResult.Action = "Backup"
        $window.Close()
    })
}

if ($btnLaunchExport) {
    $btnLaunchExport.Add_Click({
        $script:GuiResult.Action = "Export"
        $window.Close()
    })
}

# Expose window references for headless testing & verification
$script:DevboxGuiWindow = $window
$global:DevboxGuiWindow = $window

# Show Dialog
if (-not $NoShow) {
    $null = $window.ShowDialog()
}

return $script:GuiResult
