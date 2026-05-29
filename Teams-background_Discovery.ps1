$check = $true
$ImageSource = "$env:ProgramData\Images\Teams background"
$Users = Get-CimInstance -ClassName Win32_UserProfile -Filter "Special != 'True'"
foreach($User in $Users) {
    $UserPath = $User.LocalPath
    $userteamsbgpath = "$UserPath\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"

    if (!(Test-Path $userteamsbgpath)) {
        New-item -type Directory -Path "$User\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds" -Name "Uploads" -Force | Out-Null
    }
    if(!(Test-Path -Path $ImageSource)) {
    $check = $false
    }

    foreach ($file in (Get-ChildItem -Path $ImageSource)) {
            
        $hash = Get-FileHash -Path $file.FullName
        if (!(Test-Path (Join-Path $userteamsbgpath $file.name)) -and ($file.Extension -ne ".db")) {
                
            $hashlist = Get-ChildItem -Path $userteamsbgpath | Get-FileHash
            
            foreach($hashlistitem in $hashlist){
                if((Compare-Object -ReferenceObject $hash.Hash -DifferenceObject $hashlistitem.Hash -IncludeEqual).SideIndicator -eq "=="){
                    $thumbname = (Get-Item -Path $hashlistitem.Path).Name -replace ".jpg","_thumb.jpg"
                    if(!(Test-Path -Path (Join-Path -Path $userteamsbgpath -ChildPath $thumbname))){
                        $check = $false
                    }
                }
            }

            if($hash.Hash -notin $hashlist.Hash) {
                $check = $false
            }
        }
    }
    if(!$(Get-ChildItem -Path "$userteamsbgpath\*" -Include "*thumb.jpg")){
        $check = $false
    }

}
return $check
