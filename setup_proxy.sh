#!/bin/bash

# Script tự động cài đặt proxy HTTPS (Squid) trên cổng 3128
# Yêu cầu: Ubuntu/Debian, quyền sudo, kết nối internet
# Tài khoản proxy: proxyuser, Mật khẩu: P@ssw0rd123

# Kiểm tra quyền sudo
if [ "$EUID" -ne 0 ]; then
    echo "Lỗi: Vui lòng chạy script với quyền sudo."
    exit 1
fi

# Kiểm tra kết nối internet
if ! ping -c 1 google.com &> /dev/null; then
    echo "Lỗi: Không có kết nối internet. Vui lòng kiểm tra mạng và thử lại."
    exit 1
fi

# Cập nhật hệ thống và cài đặt gói cần thiết
echo "Đang cập nhật hệ thống và cài đặt Squid, apache2-utils..."
apt-get update -y
apt-get install -y squid apache2-utils

# Kiểm tra cài đặt Squid
if ! command -v squid &> /dev/null; then
    echo "Lỗi: Không thể cài đặt Squid. Vui lòng kiểm tra log: /var/log/apt/term.log"
    exit 1
fi

# Tạo tài khoản proxyuser với mật khẩu mặc định 'P@ssw0rd123'
echo "Đang tạo tài khoản proxyuser..."
echo "proxyuser:$(openssl passwd -apr1 P@ssw0rd123)" > /etc/squid/passwd
chmod 600 /etc/squid/passwd

# Sao lưu file cấu hình Squid
echo "Đang sao lưu file cấu hình Squid..."
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Cấu hình Squid cho proxy HTTPS
echo "Đang cấu hình Squid..."
cat <<EOL > /etc/squid/squid.conf
auth_param basic program /usr/lib/squid3/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm Squid Basic Authentication
auth_param basic credentialsttl 2 hours
acl auth_users proxy_auth REQUIRED
http_access allow auth_users
http_access deny all
http_port 3128
EOL

# Khởi động và kích hoạt Squid
echo "Đang khởi động Squid..."
systemctl restart squid
systemctl enable squid

# Kiểm tra trạng thái Squid và hiển thị thông tin proxy
if systemctl is-active --quiet squid; then
    IP=$(curl -s ifconfig.me)
    echo "====================================="
    echo "Proxy HTTPS đã được cài đặt thành công!"
    echo "Thông tin proxy:"
    echo "  - IP: $IP"
    echo "  - Cổng: 3128"
    echo "  - Tài khoản: proxyuser"
    echo "  - Mật khẩu: P@ssw0rd123"
    echo "====================================="
    echo "Hướng dẫn sử dụng:"
    echo "1. Cấu hình proxy trên trình duyệt:"
    echo "   - HTTP Proxy: $IP:3128"
    echo "   - Tên người dùng: proxyuser"
    echo "   - Mật khẩu: P@ssw0rd123"
    echo "2. Kiểm tra proxy bằng lệnh:"
    echo "   curl -x http://proxyuser:P@ssw0rd123@$IP:3128 https://ipinfo.io"
    echo "====================================="
    echo "Khuyến nghị bảo mật:"
    echo "Giới hạn truy cập cổng 3128 chỉ cho IP cụ thể:"
    echo "sudo ufw allow from <IP_client> to any port 3128"
else
    echo "Lỗi: Không thể khởi động Squid. Kiểm tra chi tiết: sudo systemctl status squid"
    exit 1
fi

# Mở cổng 3128 trên tường lửa (nếu ufw được cài đặt)
if command -v ufw &> /dev/null; then
    echo "Đang mở cổng 3128 trên tường lửa..."
    ufw allow 3128
fi
