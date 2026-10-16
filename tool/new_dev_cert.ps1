# 生成 Windows MSIX 打包用的本地开发签名证书（自签）。
#
# 证书文件 certs/l78z-dev.pfx 不入库（.gitignore 已忽略），本地首次
# 打包与 CI 都跑这一个脚本；Subject 固定为 CN=com.l78z.desktop，
# 与 pubspec msix_config 的 identity 对齐——每次生成的证书不同但
# publisher 相同，系统仍视为同一应用，可覆盖安装。
#
# 密码与 pubspec.yaml msix_config.certificate_password 保持一致。
$ErrorActionPreference = 'Stop'

$pwdText = 'l78z-dev-2026'
$certDir = Join-Path $PSScriptRoot '..\certs'
New-Item -ItemType Directory -Force $certDir | Out-Null

$cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject 'CN=com.l78z.desktop' `
    -KeyUsage DigitalSignature `
    -FriendlyName 'l78z dev' `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -NotAfter (Get-Date).AddYears(5)

$secPwd = ConvertTo-SecureString -String $pwdText -Force -AsPlainText
$pfxPath = Join-Path $certDir 'l78z-dev.pfx'
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $secPwd | Out-Null
Write-Host "已生成 $pfxPath"

# 注意：不要在这里把 pfx 导入 Cert:\CurrentUser\Root 来规避 msix 的「安装证书」
# 交互提示——CI runner（交互式会话）上 Import-PfxCertificate 导入 Root 会弹
# 信任确认 UI 并永久挂起（三跑实测 step5 卡 70+ 分钟）。msix 的交互提示改由
# CI 在构建步骤管道喂 "n" 跳过（见 workflow 的构建 MSIX 步骤）。
