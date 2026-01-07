#!/bin/bash

# ============================================
# АВТОМАТИЧЕСКАЯ УСТАНОВКА VSFTPD SERVER
# Ubuntu 24.04 | Пользователь: ftptest | Пароль: ooaiiiej38437
# ============================================

echo "=== Начинаем установку FTP сервера ==="

# 1. Обновление системы
echo "Шаг 1: Обновление пакетов..."
sudo apt update && sudo apt upgrade -y

# 2. Установка vsftpd
echo "Шаг 2: Установка vsftpd..."
sudo apt install -y vsftpd

# 3. Создание резервной копии конфига
echo "Шаг 3: Создание backup конфигурации..."
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.backup.original

# 4. Создание пользователя ftptest
echo "Шаг 4: Создание пользователя ftptest..."
sudo useradd -m ftptest -s /usr/sbin/nologin
echo "ftptest:ooaiiiej38437" | sudo chpasswd

# 5. Настройка домашней директории
echo "Шаг 5: Настройка домашней директории..."
sudo mkdir -p /home/ftptest/ftp
sudo chown ftptest:ftptest /home/ftptest/ftp
sudo chmod 755 /home/ftptest/ftp

# Создание тестовых папок
sudo mkdir -p /home/ftptest/ftp/upload
sudo mkdir -p /home/ftptest/ftp/download
sudo chown ftptest:ftptest /home/ftptest/ftp/upload
sudo chown ftptest:ftptest /home/ftptest/ftp/download
sudo chmod 775 /home/ftptest/ftp/upload

# Тестовый файл
echo "Добро пожаловать на FTP сервер!" | sudo tee /home/ftptest/ftp/welcome.txt
sudo chown ftptest:ftptest /home/ftptest/ftp/welcome.txt

# 6. Получение внешнего IP
echo "Шаг 6: Определение внешнего IP..."
EXTERNAL_IP=$(curl -s ifconfig.me)
echo "Внешний IP: $EXTERNAL_IP"

# 7. Создание SSL сертификата
echo "Шаг 7: Создание SSL сертификата..."
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/ssl/private/vsftpd.key \
  -out /etc/ssl/certs/vsftpd.crt \
  -subj "/C=NL/ST=NH/L=Amsterdam/O=FTP Server/CN=$EXTERNAL_IP" 2>/dev/null

sudo chmod 600 /etc/ssl/private/vsftpd.key

# 8. Настройка конфигурационного файла vsftpd
echo "Шаг 8: Настройка vsftpd.conf..."
sudo tee /etc/vsftpd.conf > /dev/null << EOF
# ========== БАЗОВЫЕ НАСТРОЙКИ ==========
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

# ========== БЕЗОПАСНОСТЬ ==========
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd

# Контроль доступа пользователей
userlist_enable=YES
userlist_file=/etc/vsftpd.user_list
userlist_deny=NO

# Таймауты и ограничения
idle_session_timeout=600
data_connection_timeout=120
max_clients=20
max_per_ip=5

# ========== SSL/TLS ШИФРОВАНИЕ ==========
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
rsa_cert_file=/etc/ssl/certs/vsftpd.crt
rsa_private_key_file=/etc/ssl/private/vsftpd.key
require_ssl_reuse=NO
ssl_ciphers=HIGH

# ========== ПАССИВНЫЙ РЕЖИМ ==========
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=41000
pasv_address=$EXTERNAL_IP
pasv_promiscuous=NO

# ========== ЛОГИРОВАНИЕ ==========
dual_log_enable=YES
vsftpd_log_file=/var/log/vsftpd.log
log_ftp_protocol=YES
xferlog_file=/var/log/vsftpd-transfer.log
xferlog_std_format=YES

# ========== ДОПОЛНИТЕЛЬНО ==========
seccomp_sandbox=NO
EOF

# 9. Создание списка пользователей
echo "Шаг 9: Создание списка пользователей..."
echo "ftptest" | sudo tee /etc/vsftpd.user_list

# 10. Настройка PAM
echo "Шаг 10: Настройка PAM..."
echo "/usr/sbin/nologin" | sudo tee -a /etc/shells

# 11. Настройка фаервола
echo "Шаг 11: Настройка фаервола..."
# Проверяем установлен ли ufw
if command -v ufw > /dev/null; then
    sudo ufw allow 21/tcp comment 'FTP Control'
    sudo ufw allow 40000:41000/tcp comment 'FTP Passive Ports'
    sudo ufw reload
else
    echo "UFW не установлен, пропускаем настройку фаервола"
fi

# 12. Перезапуск службы
echo "Шаг 12: Запуск службы vsftpd..."
sudo systemctl restart vsftpd
sudo systemctl enable vsftpd

# 13. Проверка установки
echo "=== ПРОВЕРКА УСТАНОВКИ ==="

# Проверка статуса службы
echo "1. Статус службы vsftpd:"
if sudo systemctl is-active --quiet vsftpd; then
    echo "   ✅ vsftpd запущен"
else
    echo "   ❌ vsftpd не запущен"
    sudo systemctl status vsftpd --no-pager
fi

# Проверка портов
echo "2. Проверка открытых портов:"
sudo ss -tulpn | grep -E ":21|vsftpd" | head -5

# Проверка пользователя
echo "3. Проверка пользователя ftptest:"
if id ftptest &>/dev/null; then
    echo "   ✅ Пользователь ftptest создан"
else
    echo "   ❌ Пользователь ftptest не создан"
fi

# Проверка SSL сертификата
echo "4. Проверка SSL сертификата:"
if [ -f "/etc/ssl/certs/vsftpd.crt" ]; then
    echo "   ✅ SSL сертификат создан"
else
    echo "   ❌ SSL сертификат не создан"
fi

# 14. Вывод информации для подключения
echo ""
echo "=== ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ ==="
echo "Сервер: $EXTERNAL_IP"
echo "Порт: 21"
echo "Пользователь: ftptest"
echo "Пароль: ooaiiiej38437"
echo ""
echo "=== НАСТРОЙКИ ДЛЯ FileZilla ==="
echo "1. Хост: $EXTERNAL_IP"
echo "2. Порт: 21"
echo "3. Протокол: FTP - File Transfer Protocol"
echo "4. Шифрование: Требуется явный FTP over TLS"
echo "5. Пользователь: ftptest"
echo "6. Пароль: ooaiiiej38437"
echo "7. Режим передачи: Пассивный"
echo ""
echo "=== ПУТИ И ФАЙЛЫ ==="
echo "Домашняя директория: /home/ftptest/ftp"
echo "Конфиг: /etc/vsftpd.conf"
echo "Backup конфига: /etc/vsftpd.conf.backup.original"
echo "Логи: /var/log/vsftpd.log"
echo "Логи передач: /var/log/vsftpd-transfer.log"
echo ""
echo "=== КОМАНДЫ ДЛЯ УПРАВЛЕНИЯ ==="
echo "Перезапуск: sudo systemctl restart vsftpd"
echo "Статус: sudo systemctl status vsftpd"
echo "Логи: sudo tail -f /var/log/vsftpd.log"
echo "Добавить пользователя: echo 'новый_пользователь' | sudo tee -a /etc/vsftpd.user_list"
echo ""
echo "Установка завершена! ✅"
