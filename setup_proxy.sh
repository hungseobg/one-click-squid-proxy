#!/bin/bash

# Script để tự động hóa cài đặt proxy HTTPS với Squid trên VPS Ubuntu
# Đảm bảo chạy với quyền root

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần chạy với quyền root. Vui lòng sử dụng sudo."
   exit 1
fi

# Cập nhật hệ thống
echo "Cập nhật hệ thống..."
apt-get update && apt-get upgrade -y

# Cài đặt Squid và công cụ tạo mật khẩu
echo "Cài đặt Squid..."
apt-get install -y squid apache2-utils

# Tạo tên người dùng và mật khẩu ngẫu nhiên
USERNAME="proxyuser"
PASSWORD=$(openssl rand -base64 12)
PORT=3128

# Tạo file mật khẩu xác thực
echo "Tạo file mật khẩu xác thực..."
htpasswd -bc /etc/squid/passwd $USERNAME "$PASSWORD"

# Lấy địa chỉ IP của VPS
IP=$(curl -s http://ifconfig.me)

# Sao lưu file cấu hình gốc của Squid
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Tạo file cấu hình Squid
echo "Tạo file cấu hình Squid..."
cat > /etc/squid/squid.conf <<EOF
# Cấu hình cơ bản
http_port $PORT
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl CONNECT method CONNECT

# Xác thực người dùng
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED

# Quy tắc truy cập
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow authenticated
http_access deny all

# Tối ưu hóa
forwarded_for off
request_header_access X-Forwarded-For deny all
request_header_access Via deny all
EOF

# Cấu hình firewall (ufw)
echo "Cấu hình firewall..."
apt-get install -y ufw
ufw allow $PORT/tcp
ufw --force enable

# Khởi động và kích hoạt Squid
echo "Khởi động Squid..."
systemctl enable squid
systemctl restart squid

# Kiểm tra trạng thái dịch vụ
if systemctl is-active --quiet squid; then
    echo "Squid đang chạy!"
else
    echo "Lỗi: Squid không khởi động được. Vui lòng kiểm tra log."
    exit 1
fi

# In thông tin kết nối
echo "Cài đặt hoàn tất! Thông tin proxy HTTPS của bạn:"
echo "----------------------------------------"
echo "IP: $IP"
echo "Port: $PORT"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo "----------------------------------------"
echo "Sử dụng thông tin trên để cấu hình client proxy (hỗ trợ HTTP/HTTPS)."
