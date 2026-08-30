#!/usr/bin/env bash
set -euo pipefail

# Setup-скрипт для Docker (MiniPay Data Platform, Sprint 2)
# Перед первым запуском на НОВОЙ машине: вручную проверить `ip addr` / `ip route`
# и убедиться, что 10.10.0.0/16 и 10.20.0.0/16 не пересекаются с сетями,
# уже используемыми на этой машине (VPN, локальная сеть и т.д.).

echo "==> Обновляем список пакетов"
sudo apt-get update

echo "==> Ставим зависимости (ca-certificates, curl)"
sudo apt-get install -y ca-certificates curl

echo "==> Добавляем официальный GPG-ключ Docker"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "==> Добавляем официальный репозиторий Docker"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

echo "==> Пишем daemon.json ДО установки Docker (чтобы docker0 никогда не поднимался на 172.17.0.0/16)"
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "bip": "10.10.0.1/16",
  "default-address-pools": [
    {
      "base": "10.20.0.0/16",
      "size": 24
    }
  ]
}
EOF

echo "==> Устанавливаем Docker Engine"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Перезапускаем демон, чтобы daemon.json точно применился"
sudo systemctl restart docker

echo "==> Проверяем, что docker0 поднялся на ожидаемом диапазоне"
ip addr show docker0 | grep "10.10.0.1" || {
  echo "ВНИМАНИЕ: docker0 НЕ на 10.10.0.1! daemon.json не применился как надо."
  exit 1
}

echo "==> Добавляем текущего пользователя ($USER) в группу docker"
sudo usermod -aG docker "$USER"

echo ""
echo "Готово. Перелогинься в SSH-сессию, затем проверь:"
echo "  groups              (должна появиться docker)"
echo "  docker run hello-world   (без sudo)"
