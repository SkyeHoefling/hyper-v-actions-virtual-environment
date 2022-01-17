Write-Host "Installing Virtual Environment ""win20199"""
Write-Host "Validating packer script ""hv_win2019_g2.pkr.hcl"" . . ."

$validate = packer validate -var-file variables_win2019_std.pkvars.hcl win2019_g2.pkr.hcl
if ($validate[-1] -eq "The configuration is valid.")
{
    Write-Host $validate[-1] -ForegroundColor Green
}
else
{
    Write-Host $validate -ForegroundColor Red
}

Write-Host "Building virtual machine . . ."
Write-Host "This may take a long time"

packer build -force -var-file variables_win2019_std.pkvars.hcl win2019_g2.pkr.hcl

$vhd = Test-Path ".\output-windows-2019-g2\Virtual Hard Disks\packer-windows2019-g2.vhdx"
$readme = Test-Path .\output-windows-2019-g2\Windows2019-Readme.md
if ($vhd -and $readme)
{
    Write-Host "Virtual machine created successfully" -ForegroundColor Green
    Write-Host "Artifacts: "".\output-windows-2019-g2\Virtual Hard Disks\packer-windows2019-g2.vhdx""" -ForegroundColor Green
    Write-Host "Artifacts: "".\output-windows-2019-g2\Windows2019-Readme.md""" -ForegroundColor Green
}
else
{
    Write-Host "Failed to create virtual machine! See build logs above" -ForegroundColor Red
}