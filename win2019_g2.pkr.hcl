
variable "disk_size" {
  type    = string
  default = ""
}

variable "iso_checksum" {
  type    = string
  default = ""
}

variable "iso_checksum_type" {
  type    = string
  default = ""
}

variable "iso_url" {
  type    = string
  default = ""
}

variable "output_directory" {
  type    = string
  default = ""
}

variable "output_vagrant" {
  type    = string
  default = ""
}

variable "secondary_iso_image" {
  type    = string
  default = ""
}

variable "switch_name" {
  type    = string
  default = ""
}

variable "sysprep_unattended" {
  type    = string
  default = ""
}

variable "upgrade_timeout" {
  type    = string
  default = ""
}

variable "vlan_id" {
  type    = string
  default = ""
}

variable "vm_name" {
  type    = string
  default = ""
}

variable "admin_user" {
  type    = string
  default = "Administrator"
}

variable "admin_password" {
  type    = string
  default = "password"
}

variable "image_version" {
  type    = string
  default = "dev"
}

variable "image_os" {
  type    = string
  default = "win19"
}

variable "imagedata_file" {
  type    = string
  default = "C:\\imagedata.json"
}

variable "agent_tools_directory" {
  type    = string
  default = "C:\\hostedtoolcache\\windows"
}

variable "image_folder" {
  type    = string
  default = "C:\\image"
}

variable "submodule_files" {
  type    = string
  default = "./virtual-environments/images/win"
}

source "hyperv-iso" "vm" {
  boot_command          = ["a<enter><wait>a<enter><wait>a<enter><wait>a<enter>"]
  boot_wait             = "1s"
  communicator          = "winrm"
  cpus                  = 4
  disk_size             = "${var.disk_size}"
  enable_dynamic_memory = "true"
  enable_secure_boot    = false
  generation            = 2
  guest_additions_mode  = "disable"
  iso_checksum          = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_url               = "${var.iso_url}"
  memory                = 8192
  output_directory      = "${var.output_directory}"
  secondary_iso_images  = ["${var.secondary_iso_image}"]
  shutdown_timeout      = "30m"
  skip_export           = true
  switch_name           = "${var.switch_name}"
  temp_path             = "."
  vlan_id               = "${var.vlan_id}"
  vm_name               = "${var.vm_name}"
  winrm_password        = "${var.admin_password}"
  winrm_timeout         = "8h"
  winrm_username        = "${var.admin_user}"
}

build {
  sources = ["source.hyperv-iso.vm"]

  provisioner "powershell" {
    inline = ["New-Item -Path ${var.image_folder} -ItemType Directory -Force"]
  }

  provisioner "file" {
    source = "${var.submodule_files}/scripts/ImageHelpers"
    destination =  "C:\\Program Files\\WindowsPowerShell\\Modules\\"
  }

  provisioner "file" {
    source = "${var.submodule_files}/scripts/SoftwareReport"
    destination = "${var.image_folder}"
  }

  provisioner "file" {
    source = "${var.submodule_files}/post-generation"
    destination = "C:\\"
  }

  provisioner "file" {
    source = "${var.submodule_files}/scripts/Tests"
    destination = "${var.image_folder}"
  }

  provisioner "file" {
    source = "${var.submodule_files}/toolsets/toolset-2019.json"
    destination = "${var.image_folder}\\toolset.json"
  }

  provisioner "windows-shell" {
    inline = [
      "net user ${var.admin_user} ${var.admin_password} /add /passwordchg:no /passwordreq:yes /active:yes /Y",
      "net localgroup Administrators ${var.admin_user} /add",
      "winrm set winrm/config/service/auth @{Basic=\"true\"}",
      "winrm get winrm/config/service/auth",
    ]
  }

  provisioner "powershell" {
    inline = [
      "if (-not ((net localgroup Administrators) -contains '${var.admin_user}')) { exit 1 }"
    ]
  }

  provisioner "powershell" {
    inline = [
      "bcdedit.exe /set TESTSIGNING ON"
    ]
    elevated_user = "${var.admin_user}"
    elevated_password = "${var.admin_password}"
  }

  provisioner "powershell" {
    environment_vars = [
      "IMAGE_VERSION=${var.image_version}",
      "IMAGE_OS=${var.image_os}",
      "AGENT_TOOLSDIRECTORY=${var.agent_tools_directory}",
      "IMAGEDATA_FILE=${var.imagedata_file}"
    ]
    scripts = [
      "${var.submodule_files}/scripts/Installers/Configure-Antivirus.ps1",
      "${var.submodule_files}/scripts/Installers/Install-PowerShellModules.ps1",
      "${var.submodule_files}/scripts/Installers/Install-WindowsFeatures.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Choco.ps1",
// We can remove the Resize-Partition statements from this. It isn't needed for our purposes
      "${var.submodule_files}/scripts/Installers/Initialize-VM.ps1",
      "${var.submodule_files}/scripts/Installers/Update-ImageData.ps1",
      "${var.submodule_files}/scripts/Installers/Update-DotnetTLS.ps1"
    ]
    execution_policy = "unrestricted"
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    scripts = [
      "${var.submodule_files}/scripts/Installers/Install-VCRedist.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Docker.ps1",
      "${var.submodule_files}/scripts/Installers/Install-PowershellCore.ps1",
      "${var.submodule_files}/scripts/Installers/Install-WebPlatformInstaller.ps1"
    ]
  }

  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  provisioner "powershell" {
    valid_exit_codes = [
      0,
      3010
    ]
    scripts = [
      // This fails for windows sdk 14393, might be related to server os version
      "${var.submodule_files}/scripts/Installers/Install-VS.ps1",
      "${var.submodule_files}/scripts/Installers/Install-KubernetesTools.ps1",
      "${var.submodule_files}/scripts/Installers/Install-NET48.ps1"
    ]
    elevated_user = "${var.admin_user}"
    elevated_password = "${var.admin_password}"
  }

  provisioner "powershell" {
    scripts = [
      "${var.submodule_files}/scripts/Installers/Install-Wix.ps1",
      "${var.submodule_files}/scripts/Installers/Install-WDK.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Vsix.ps1",
      "${var.submodule_files}/scripts/Installers/Install-AzureCli.ps1",
      "${var.submodule_files}/scripts/Installers/Install-AzureDevOpsCli.ps1",
      "${var.submodule_files}/scripts/Installers/Install-NodeLts.ps1",
      "${var.submodule_files}/scripts/Installers/Install-CommonUtils.ps1",
      "${var.submodule_files}/scripts/Installers/Install-JavaTools.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Kotlin.ps1"
    ]
  }

  provisioner "powershell" {
    scripts = [
      "${var.submodule_files}/scripts/Installers/Install-ServiceFabricSDK.ps1"
    ]
    execution_policy = "remotesigned"
  }

  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  provisioner "windows-shell" {
    inline = [
      "wmic product where \"name like '%%microsoft azure powershell%%'\" call uninstall /nointeractive"
    ]
  }

  provisioner "powershell" {
    scripts = [
      "${var.submodule_files}/scripts/Installers/Install-Ruby.ps1",
      "${var.submodule_files}/scripts/Installers/Install-PyPy.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Toolset.ps1",
      "${var.submodule_files}/scripts/Installers/Configure-Toolset.ps1",
      "${var.submodule_files}/scripts/Installers/Install-AndroidSDK.ps1",
      "${var.submodule_files}/scripts/Installers/Install-AzureModules.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Pipx.ps1",
      "${var.submodule_files}/scripts/Installers/Install-PipxPackages.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Git.ps1",
      "${var.submodule_files}/scripts/Installers/Install-GitHub-CLI.ps1",
      "${var.submodule_files}/scripts/Installers/Install-PHP.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Rust.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Sbt.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Chrome.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Edge.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Firefox.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Selenium.ps1",
      "${var.submodule_files}/scripts/Installers/Install-IEWebDriver.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Apache.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Nginx.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Msys2.ps1",
      "${var.submodule_files}/scripts/Installers/Install-WinAppDriver.ps1",
      "${var.submodule_files}/scripts/Installers/Install-R.ps1",
      "${var.submodule_files}/scripts/Installers/Install-AWS.ps1",
      "${var.submodule_files}/scripts/Installers/Install-DACFx.ps1",
      "${var.submodule_files}/scripts/Installers/Install-MysqlCli.ps1",
      "${var.submodule_files}/scripts/Installers/Install-SQLPowerShellTools.ps1",
      "${var.submodule_files}/scripts/Installers/Install-DotnetSDK.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Mingw64.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Haskell.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Stack.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Miniconda.ps1",
      "${var.submodule_files}/scripts/Installers/Install-AzureCosmosDbEmulator.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Mercurial.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Zstd.ps1",
      "${var.submodule_files}/scripts/Installers/Install-NSIS.ps1",
      "${var.submodule_files}/scripts/Installers/Install-CloudFoundryCli.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Vcpkg.ps1",
      "${var.submodule_files}/scripts/Installers/Install-PostgreSQL.ps1",
      "${var.submodule_files}/scripts/Installers/Install-Bazel.ps1",
      "${var.submodule_files}/scripts/Installers/Install-AliyunCli.ps1",
      "${var.submodule_files}/scripts/Installers/Install-RootCA.ps1",
      "${var.submodule_files}/scripts/Installers/Install-MongoDB.ps1",
      "${var.submodule_files}/scripts/Installers/Install-GoogleCloudSDK.ps1",
      "${var.submodule_files}/scripts/Installers/Install-CodeQLBundle.ps1",
      "${var.submodule_files}/scripts/Installers/Install-BizTalkBuildComponent.ps1",
      "${var.submodule_files}/scripts/Installers/Disable-JITDebugger.ps1",
      "${var.submodule_files}/scripts/Installers/Configure-DynamicPort.ps1",
      "${var.submodule_files}/scripts/Installers/Configure-GDIProcessHandleQuota.ps1",
      "${var.submodule_files}/scripts/Installers/Configure-Shell.ps1",
      "${var.submodule_files}/scripts/Installers/Enable-DeveloperMode.ps1",
      "${var.submodule_files}/scripts/Installers/Install-LLVM.ps1"
    ]
  }

  provisioner "powershell" {
    scripts = [
      "${var.submodule_files}/scripts/Installers/Install-WindowsUpdates.ps1"
    ]
    elevated_user = "${var.admin_user}"
    elevated_password = "${var.admin_password}"
  }

  provisioner "windows-restart" {
    check_registry = true
    restart_check_command = "powershell -command \"& {if ((-not (Get-Process TiWorker.exe -ErrorAction SilentlyContinue)) -and (-not [System.Environment]::HasShutdownStarted) ) { Write-Output 'Restart complete' }}\""
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    pause_before = "2m"
    scripts = [
      "${var.submodule_files}/scripts/Installers/Wait-WindowsUpdatesForInstall.ps1",
      "${var.submodule_files}/scripts/Tests/RunAll-Tests.ps1"
    ]
  }

  provisioner "powershell" {
    inline = [ 
      "if (-not (Test-Path ${var.image_folder}\\Tests\\testResults.xml)) { throw '${var.image_folder}\\Tests\\testResults.xml not found' }"
    ]
  }

  provisioner "powershell" {
    inline = [
      "pwsh -File '${var.image_folder}\\SoftwareReport\\SoftwareReport.Generator.ps1'"
    ]
    environment_vars = [
      "IMAGE_VERSION=${var.image_version}"
    ]
  }

  provisioner "powershell" {
    inline = [
      "if (-not (Test-Path C:\\InstalledSoftware.md)) { throw 'C:\\InstalledSoftware.md not found' }"
    ]
  }

  provisioner "file" {
    source = "C:\\InstalledSoftware.md"
    destination = "./${var.output_directory}/Windows2019-Readme.md"
    direction = "download"
  }

  provisioner "powershell" {
    skip_clean = true
    scripts = [
      "${var.submodule_files}/scripts/Installers/Run-NGen.ps1",
      "${var.submodule_files}/scripts/Installers/Finalize-VM.ps1"
    ]
  }

  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  provisioner "powershell" {
    inline = [
      "if( Test-Path $Env:SystemRoot\\System32\\Sysprep\\unattend.xml ){ rm $Env:SystemRoot\\System32\\Sysprep\\unattend.xml -Force}",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"
    ]
  }
}
