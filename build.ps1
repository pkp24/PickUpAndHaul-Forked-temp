#!/usr/bin/env pwsh

# PickUpAndHaul Build Script
# This script builds both projects in the correct order

param(
    [string]$Configuration = "Debug",
    [switch]$Clean,
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output
$Green = "Green"
$Red = "Red"
$Yellow = "Yellow"
$Cyan = "Cyan"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if dotnet is available
function Test-DotNet {
    try {
        $null = dotnet --version
        return $true
    }
    catch {
        return $false
    }
}

# Function to get detailed .NET information
function Get-DotNetInfo {
    Write-ColorOutput "=== .NET Version Information ===" $Cyan
    
    # Get the default SDK version
    $sdkVersion = dotnet --version
    Write-ColorOutput "Default SDK Version: $sdkVersion" $Yellow
    
    # Get all installed SDKs
    Write-ColorOutput "Installed SDKs:" $Yellow
    $sdks = dotnet --list-sdks
    foreach ($sdk in $sdks) {
        Write-ColorOutput "  $sdk" $Cyan
    }
    
    # Get all installed runtimes
    Write-ColorOutput "Installed Runtimes:" $Yellow
    $runtimes = dotnet --list-runtimes
    foreach ($runtime in $runtimes) {
        Write-ColorOutput "  $runtime" $Cyan
    }
    
    # Get detailed info about the current SDK
    Write-ColorOutput "Detailed SDK Info:" $Yellow
    $sdkInfo = dotnet --info
    foreach ($line in $sdkInfo) {
        if ($line -match "SDK Version" -or $line -match "Runtime Version" -or $line -match "Framework") {
            Write-ColorOutput "  $line" $Green
        }
    }
    
    Write-ColorOutput ""
}

# Function to build a project
function Build-Project {
    param(
        [string]$ProjectPath,
        [string]$ProjectName
    )
    
    Write-ColorOutput "Building $ProjectName..." $Cyan
    
    # Show what framework we're targeting
    $projectContent = Get-Content $ProjectPath -Raw
    if ($projectContent -match '<TargetFramework>([^<]+)</TargetFramework>') {
        $targetFramework = $matches[1]
        Write-ColorOutput "Target Framework: $targetFramework" $Yellow
    }
    
    $buildArgs = @("build", $ProjectPath, "-c", $Configuration)
    
    if ($Verbose) {
        $buildArgs += "--verbosity", "detailed"
    }
    
    try {
        # Capture the output and exit code
        $output = & dotnet $buildArgs 2>&1
        $exitCode = $LASTEXITCODE
        
        # Display the build output
        foreach ($line in $output) {
            # Color-code different types of output
            if ($line -match "error CS\d+:") {
                Write-ColorOutput $line $Red
            }
            elseif ($line -match "warning CS\d+:") {
                Write-ColorOutput $line $Yellow
            }
            elseif ($line -match "Build succeeded") {
                Write-ColorOutput $line $Green
            }
            elseif ($line -match "Build failed") {
                Write-ColorOutput $line $Red
            }
            elseif ($line -match "Restore complete") {
                Write-ColorOutput $line $Green
            }
            elseif ($line -match "Determining projects to restore") {
                Write-ColorOutput $line $Cyan
            }
            # Add detection for .NET version in build output
            elseif ($line -match "Microsoft\.NET\.Core\.App" -or $line -match "Microsoft\.NET\.Framework") {
                Write-ColorOutput "  [Runtime] $line" $Green
            }
            elseif ($line -match "SDK Version" -or $line -match "Runtime Version") {
                Write-ColorOutput "  [Version] $line" $Green
            }
            else {
                Write-Host $line
            }
        }
        
        if ($exitCode -eq 0) {
            Write-ColorOutput "✓ $ProjectName built successfully!" $Green
            return $true
        }
        else {
            Write-ColorOutput "✗ Failed to build $ProjectName" $Red
            return $false
        }
    }
    catch {
        Write-ColorOutput "✗ Error building $ProjectName : $($_.Exception.Message)" $Red
        return $false
    }
}

# Function to clean projects
function Clean-Projects {
    Write-ColorOutput "Cleaning projects..." $Yellow
    
    $projects = @(
        "Source/IHoldMultipleThings/IHoldMultipleThings.csproj",
        "Source/PickUpAndHaul/PickUpAndHaul16.csproj"
    )
    
    foreach ($project in $projects) {
        Write-ColorOutput "Cleaning $project..." $Cyan
        try {
            & dotnet clean $project -c $Configuration
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✓ Cleaned $project" $Green
            }
            else {
                Write-ColorOutput "✗ Failed to clean $project" $Red
            }
        }
        catch {
            Write-ColorOutput "✗ Error cleaning $project : $($_.Exception.Message)" $Red
        }
    }
}

# Main execution
Write-ColorOutput "=== PickUpAndHaul Build Script ===" $Cyan
Write-ColorOutput "Configuration: $Configuration" $Yellow

# Check if dotnet is available
if (-not (Test-DotNet)) {
    Write-ColorOutput "✗ .NET SDK is not installed or not in PATH" $Red
    Write-ColorOutput "Please install .NET SDK and try again." $Yellow
    exit 1
}

Write-ColorOutput "✓ .NET SDK found: $(dotnet --version)" $Green

# Show detailed .NET information
Get-DotNetInfo

# Change to the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Clean if requested
if ($Clean) {
    Clean-Projects
    Write-ColorOutput ""
}

# Build projects in order (IHoldMultipleThings first, then PickUpAndHaul)
Write-ColorOutput "Starting build process..." $Cyan
Write-ColorOutput ""

# Build IHoldMultipleThings first
$iholdSuccess = Build-Project "Source/IHoldMultipleThings/IHoldMultipleThings.csproj" "IHoldMultipleThings"

if (-not $iholdSuccess) {
    Write-ColorOutput ""
    Write-ColorOutput "✗ Build failed! IHoldMultipleThings must be built before PickUpAndHaul." $Red
    exit 1
}

Write-ColorOutput ""

# Build PickUpAndHaul
$pickupSuccess = Build-Project "Source/PickUpAndHaul/PickUpAndHaul16.csproj" "PickUpAndHaul"

if (-not $pickupSuccess) {
    Write-ColorOutput ""
    Write-ColorOutput "✗ Build failed! PickUpAndHaul build failed." $Red
    exit 1
}

Write-ColorOutput ""
Write-ColorOutput "=== Build Summary ===" $Cyan
Write-ColorOutput "✓ IHoldMultipleThings: Built successfully" $Green
Write-ColorOutput "✓ PickUpAndHaul: Built successfully" $Green
Write-ColorOutput ""
Write-ColorOutput "Output location: 1.6/Assemblies/" $Yellow
Write-ColorOutput "Configuration: $Configuration" $Yellow
Write-ColorOutput ""
Write-ColorOutput "🎉 All projects built successfully!" $Green 