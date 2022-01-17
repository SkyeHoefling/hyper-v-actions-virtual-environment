# Hyper-V - GitHub Action Virtual Machines
A series of [packer](https://github.com/hashicorp/packer) scripts that generate identical virtual machines to what is being used by GitHub Actions in the hosted build agents.

## Getting Started
🚧 I am working on adding support for various versions of Windows and Linux. At the moment the script will only generate a Windows Server 2019 virtual machine.

### Dependencies
* Copy `en-us_windows_server_2019_updated_jul_2021_x64_dvd_01319f3c.iso` to the `iso` directory of this repository. We do not provide the official Windows Server 2019 iso and you must include it.
* install [packer](https://github.com/hashicorp/packer) to the CLI

### Run
Run the following commands from an elevated powershell prompt
```bash
git clone --recurse-submodules https://github.com/ahoefling/hyper-v-actions-virtual-environment
cd hyper-v-actions-virtual-environment
start.ps1
```
Once the script has completed, you will have 2 generated files. A readme file containing documentation of all installed tools, and the Hyper-V virtual hard disk. To use your virtual machine you will need to create a new Virtual Machine and use the existing vhdx file.

## Supported Environments
| Environment         | Status |
|---------------------|--------|
| Windows Server 2019 | ✅ |
| Windows Server 2022 | 🔃 |
| Windows 10          | 🚧 |
| Windows 11          | 🚧 |
| Windows ARM64       | 🚧 |

## How It works?
Using [packer](https://github.com/hashicorp/packer) this repository runs a series of scripts that automatically install the environment into your Hyper-V instance and install the necessary software.

This is accomplished by a fork of the official scripts at [https://github.com/ahoefling/virtual-environments](https://github.com/ahoefling/virtual-environments). This repository contains all the necessary build scripts that install all software dependencies. As GitHub pushes changes we will pull latest and make sure it is compatible.

Learn more - [How It Works](HOW_IT_WORKS.md)

