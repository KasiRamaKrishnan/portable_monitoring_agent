# =============================================================================
# EC2 — Windows Worker Node (Windows Server 2022)
# Grafana Alloy is deployed here by Ansible (playbook-windows.yml)
# after Terraform creates the infrastructure.
#
# user_data enables WinRM so Ansible can connect immediately.
# =============================================================================

resource "aws_instance" "windows_worker" {
  count                  = var.windows_worker_count
  ami                    = data.aws_ami.windows.id
  instance_type          = var.windows_worker_instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.windows_worker.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50  # Windows needs more space
    delete_on_termination = true
    encrypted             = true
  }

  # Bootstrap: enable WinRM and set Administrator password
  # This runs as EC2 user_data via EC2Launch (Windows bootstrap agent)
  user_data = <<-EOF
    <powershell>
    # ── Set Administrator password ────────────────────────────────────────────
    $password = ConvertTo-SecureString "${var.windows_admin_password}" -AsPlainText -Force
    Set-LocalUser -Name "Administrator" -Password $password
    Enable-LocalUser -Name "Administrator"

    # ── Enable and configure WinRM ────────────────────────────────────────────
    winrm quickconfig -force
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
    Set-Item -Path WSMan:\localhost\MaxTimeoutms -Value 1800000

    # ── Open WinRM firewall ports ─────────────────────────────────────────────
    New-NetFirewallRule -DisplayName "WinRM HTTP"  -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

    # ── Open Alloy UI firewall port ───────────────────────────────────────────
    New-NetFirewallRule -DisplayName "Grafana Alloy UI" -Direction Inbound -LocalPort 12345 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

    # ── Restart WinRM ─────────────────────────────────────────────────────────
    Restart-Service WinRM

    Write-Output "Windows worker bootstrap complete" | Out-File C:\bootstrap.log
    </powershell>
    <persist>true</persist>
  EOF

  tags = { Name = "windows-worker-${count.index + 1}-${var.environment}" }
}
