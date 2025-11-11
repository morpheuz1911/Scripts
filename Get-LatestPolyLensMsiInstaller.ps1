<#
.SYNOPSIS
Retrieves the latest Poly Lens Desktop MSI link by querying the Poly Lens internal API.

.DESCRIPTION
This method bypasses the unreliable JavaScript-rendered HTML by mimicking the
GraphQL API call that the Poly website uses to fetch the latest download information.
It is highly recommended over simple HTML scraping for long-term use.

.PARAMETER DestinationPath
The directory where the resulting MSI file should be saved.
Defaults to the current user's Downloads folder.

.EXAMPLE
C:\PS> Get-LatestPolyLensMsiInstaller
# Queries the API, gets the latest version, and downloads it to C:\Users\User\Downloads

.NOTES
The Product ID (pid) 'lens-desktop-windows' is an educated guess and may require
adjustment if the API changes.

.CREDIT
ChatGPT
Prompts by morpheuz1911
#>
function Get-LatestPolyLensMsiInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$DestinationPath = "$env:USERPROFILE\Downloads"
    )

    Write-Host "--- Poly Lens API Discovery Initiated ---" -ForegroundColor Yellow

    # --- API Configuration (Inferred from website network traffic) ---
    $ApiUri = "https://api.silica-prod01.io.lens.poly.com/graphql"
    $ProductId = "lens-desktop-windows" # Windows MSI Product ID (best guess)

    $Headers = @{
        "Host" = "api.silica-prod01.io.lens.poly.com"
        "Content-Type" = "application/json"
        "apollographql-client-name" = "poly.com-website"
        "Origin" = "https://www.poly.com"
    }
    
    # GraphQL Query to retrieve the latest version details and the direct archiveUrl
    $GraphQLQuery = @"
{
  "query": "query { availableProductSoftwareByPid(pid:\"$ProductId\") { name version publishDate productBuild { archiveUrl } } }"
}
"@
    
    # Set Security Protocol for modern HTTPS
    [Net.ServicePointManager]::SecurityProtocol = [Net.Net.SecurityProtocolType]::Tls12 -bor [Net.Net.SecurityProtocolType]::Tls13

    # 1. Query the API
    Write-Host "1. Querying Poly Lens API for latest version..." -ForegroundColor Cyan
    try {
        $Response = Invoke-RestMethod -Uri $ApiUri -Method Post -Headers $Headers -Body $GraphQLQuery -ContentType 'application/json' -ErrorAction Stop
        $SoftwareInfo = $Response.data.availableProductSoftwareByPid
        
        if (-not $SoftwareInfo) {
            Write-Error "API response was successful but contained no software data for PID '$ProductId'. The Product ID may be incorrect."
            return $null
        }

        $LatestVersion = $SoftwareInfo.version
        $DownloadUrl = $SoftwareInfo.productBuild.archiveUrl

        if (-not $DownloadUrl) {
            Write-Error "Could not extract a valid download URL from the API response for version $LatestVersion."
            return $null
        }

        Write-Host "✅ Found Latest Version: $LatestVersion" -ForegroundColor Green
        Write-Host "   Download URL: $DownloadUrl" -ForegroundColor Green
    }
    catch {
        Write-Error "API Query Failed. This often happens if the API endpoint or headers have changed: $($_.Exception.Message)"
        return $null
    }


    # 2. Download the File
    $MsiFilename = "PolyLens-$LatestVersion.msi"
    $FullDestinationPath = Join-Path -Path $DestinationPath -ChildPath $MsiFilename

    if (-not (Test-Path -Path $DestinationPath -PathType Container)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }
    
    if (Test-Path -Path $FullDestinationPath -PathType Leaf) {
        Write-Warning "File already exists at $FullDestinationPath. Skipping download."
        return $FullDestinationPath
    }

    Write-Host "`n2. Downloading MSI installer..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $FullDestinationPath -ErrorAction Stop
        Write-Host "`n✅ Download complete!" -ForegroundColor Green
        Write-Host "File saved to $FullDestinationPath" -ForegroundColor Green
        return $FullDestinationPath
    }
    catch {
        Write-Error "Download Failed: $($_.Exception.Message)"
        return $null
    }
}

# Execute the function to find the link and download the file
Get-LatestPolyLensMsiInstaller -DestinationPath "$env:TEMP\PolyLensDownloads"
