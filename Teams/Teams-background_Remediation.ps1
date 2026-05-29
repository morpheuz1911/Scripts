    <#
        .SYNOPSIS
        Adds Teams background to each users individual folder

        .DESCRIPTION
        Fetches wallpapers from a specified location and copies it to
        each users Teams installation, located in $env:LOCALAPPDATA, but this runs
        in computer context.
        Also creates necessary thumbnails using Resize-Image function.
        Thumbnails are also created separately in case of failure on an earlier
        occasion.
        
        .AUTHOR
        Alexander Vattnadal
    #>

# Import System.Drawing assembly
Add-Type -AssemblyName System.Drawing

# Function to resize image
function Resize-Image {
    param (
        [string]$sourcePath,  # Path to the source image
        [string]$outputPath,  # Path to save the resized image
        [int]$width,          # Desired width of the resized image
        [int]$height          # Desired height of the resized image
    )

    # Load the image from the source file
    $image = [System.Drawing.Image]::FromFile($sourcePath)

    # Calculate the aspect ratio of the original image
    $aspectRatio = $image.Width / $image.Height

    # If width is provided but not height, calculate height based on the aspect ratio
    if ($width -ne 0 -and $height -eq 0) {
        $height = [math]::Round($width / $aspectRatio)
    }
    # If height is provided but not width, calculate width based on the aspect ratio
    elseif ($height -ne 0 -and $width -eq 0) {
        $width = [math]::Round($height * $aspectRatio)
    }

    # Ensure both width and height are non-zero
    if ($width -eq 0 -or $height -eq 0) {
        Write-Host "Error: You must provide at least one dimension (width or height)."
        return
    }

    # Create a new bitmap with the calculated width and height
    $resizedImage = New-Object System.Drawing.Bitmap $image, $width, $height

    # Save the resized image to the output path
    $resizedImage.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)

    # Clean up
    $image.Dispose()
    $resizedImage.Dispose()

    Write-Host "Image resized and saved to $outputPath"
}

# Wallpaper source variable

$ImageSource = "$env:ProgramData\Images\Teams background"

#Invocation

# Enumerate users
$Users = Get-CimInstance -ClassName Win32_UserProfile -Filter "Special != 'True'"
foreach($User in $Users) {
    # Fetch each users local path
    $UserPath = $User.LocalPath
    $userteamsbgpath = "$UserPath\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"
    if(!$(Get-ChildItem -Path "$userteamsbgpath\*" -Include "*thumb.jpg")){
        Get-ChildItem -Path $userteamsbgpath -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    # Create Uploads folder if missing
    if (!(Test-Path $userteamsbgpath)) {
        New-item -type Directory -Path "$User\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds" -Name "Uploads" -Force | Out-Null
    }
    # Test source path. Exit if missing.
    if(!(Test-Path -Path $ImageSource)) {
    exit 1
    }

    # Start processing files in source path.
    foreach ($file in (Get-ChildItem -Path $ImageSource)) {
        # Get hashes
        $hash = Get-FileHash -Path $file.FullName
        $hashlist = Get-ChildItem -Path $userteamsbgpath | Get-FileHash
        # Evaluate hashes and copy files if missing. Also create thumbnail.
        if($hash.Hash -notin $hashlist.Hash) {
            $GUID = New-Guid
            $ext = $file.Extension
            $PictureName = "$GUID{0}" -f $ext
            Copy-Item $file.FullName -Destination "$userteamsbgpath\$PictureName" -Force
            $filename = Split-Path -Path "$userteamsbgpath\$PictureName" -Leaf
            $destinationpath = Split-Path "$userteamsbgpath\$PictureName" -Parent
            $thumbname = $filename -replace ".jpg","_thumb.jpg"
            $thumbpath = Join-Path -Path $destinationpath -ChildPath $thumbname
            Resize-Image -sourcePath "$userteamsbgpath\$PictureName" -outputPath $thumbpath -width 0 -height 280
            #Resize-Image -Height 280 -MaintainRatio -ImagePath "$userteamsbgpath\$PictureName"

        }
        
        # Clear folder if no thumbnails. Something went wrong.
        if(!$(Get-ChildItem -Path "$userteamsbgpath\*" -Include "*thumb.jpg")){
            Get-ChildItem -Path $userteamsbgpath -ErrorAction SilentlyContinue | Remove-Item -Force
        }
    }
    # Start processing separate check for thumbnails in case first generation went wrong.
    foreach ($file in (Get-ChildItem -Path $ImageSource)) {
        $hash = Get-FileHash -Path $file.FullName
        foreach($hashlistitem in $hashlist){
            # Compare hash with reference item, to get specific file and check if it has a thumbnail.
            if((Compare-Object -ReferenceObject $hash.Hash -DifferenceObject $hashlistitem.Hash -IncludeEqual).SideIndicator -eq "=="){
                $thumbname = (Get-Item -Path $hashlistitem.Path).Name -replace ".jpg","_thumb.jpg"
                if(!(Test-Path -Path $(Join-Path -Path $userteamsbgpath -ChildPath $thumbname))){
                    # If thumbnail is missing, generate one using Resize-Image
                    Resize-Image -sourcePath $hashlistitem.Path -outputPath $(Join-Path -Path $userteamsbgpath -ChildPath $thumbname) -width 0 -height 280
                }
            }
        }
    }
}
