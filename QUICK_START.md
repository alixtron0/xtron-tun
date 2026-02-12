# راهنمای شروع سریع XTRON-TUN ⚡

## نصب (30 ثانیه) 🚀

### روش 1: نصب یک‌خطی (پیشنهادی)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alixtron0/xtron-tun/main/install.sh)
```

### روش 2: با wget

```bash
bash <(wget -qO- https://raw.githubusercontent.com/alixtron0/xtron-tun/main/install.sh)
```

---

## راه‌اندازی در 5 دقیقه 🎯

### سرور خارج (Kharej) - 2 دقیقه

```bash
# 1. اجرای اسکریپت
xtron-tun

# 2. انتخاب: 1 (سرور خارج)
# 3. انتخاب: 1 (راه‌اندازی تونل جدید)

# 4. وارد کردن اطلاعات:
نام تونل: smtp-tunnel
سرور SMTP: smtp.gmail.com
پورت اول: 25
پورت دوم: 587
پورت SOCKS5: 1080
نام کاربری: myuser      # اختیاری
رمز عبور: mypassword     # اختیاری

# 5. صادرات تنظیمات
# انتخاب: 3 (صادرات تنظیمات)
# فایل ZIP در /tmp/ ایجاد می‌شود
```

### انتقال فایل ZIP به سرور ایران

```bash
# از سرور خارج
scp /tmp/xtron-smtp-tunnel-config.zip user@iran-server-ip:/tmp/
```

### سرور ایران (Iran) - 3 دقیقه

```bash
# 1. اجرای اسکریپت
xtron-tun

# 2. انتخاب: 2 (سرور ایران)
# 3. انتخاب: 1 (راه‌اندازی تونل)
# 4. انتخاب: 1 (استفاده از فایل ZIP)

# 5. وارد کردن اطلاعات:
مسیر فایل ZIP: /tmp/xtron-smtp-tunnel-config.zip
IP سرور خارج: 1.2.3.4

# 6. ایجاد Port Forward
# انتخاب: 2 (Port Forward)
# انتخاب: 1 (ایجاد Port Forward جدید)

# 7. تنظیمات Port Forward:
تونل: smtp-tunnel
موتور: 1 (GOST) - پیشنهادی
پورت محلی: 2087
پورت مقصد: 25
آدرس مقصد: smtp.gmail.com
```

---

## تست اتصال ✅

### از سرور ایران

```bash
# تست پورت محلی
nc -zv localhost 2087

# تست با telnet
telnet localhost 2087

# تست SMTP
curl telnet://localhost:2087
```

### تست کامل SMTP

```bash
# ارسال تست SMTP
echo "EHLO test" | nc localhost 2087
```

---

## مثال واقعی: Gmail SMTP 📧

### سرور خارج

```
نام تونل: gmail
سرور SMTP: smtp.gmail.com
پورت‌ها: 587, 465
SOCKS5: 1080
کاربر: tunnel-user
رمز: Str0ng!Pass123
```

### سرور ایران

```
Port Forward 1:
  پورت محلی: 2587 → smtp.gmail.com:587

Port Forward 2:
  پورت محلی: 2465 → smtp.gmail.com:465
```

### استفاده در برنامه

```php
// PHP Example
$mail->Host = 'localhost';
$mail->Port = 2587;
$mail->SMTPAuth = true;
$mail->Username = 'your-gmail@gmail.com';
$mail->Password = 'your-app-password';
```

```python
# Python Example
import smtplib

server = smtplib.SMTP('localhost', 2587)
server.starttls()
server.login('your-gmail@gmail.com', 'your-app-password')
```

---

## دستورات مفید 🛠️

```bash
# نمایش وضعیت سرویس‌ها
systemctl status xtron-*

# مشاهده لاگ‌های زنده
tail -f /var/log/xtron-tun/*.log

# ریستارت تمام سرویس‌ها
systemctl restart xtron-*

# لیست پورت‌های باز
ss -tuln | grep -E "1080|2087|2052"

# بررسی استفاده پورت
lsof -i :2087

# تست SOCKS5 از سرور ایران
curl --socks5 kharej-ip:1080 https://ifconfig.me
```

---

## عیب‌یابی سریع 🔧

### تونل متصل نمی‌شود؟

```bash
# 1. بررسی سرویس
systemctl status xtron-smtp-tunnel.service

# 2. بررسی لاگ
journalctl -u xtron-smtp-tunnel.service -n 50

# 3. ریستارت
systemctl restart xtron-smtp-tunnel.service

# 4. بررسی فایروال
ufw status
```

### Port Forward کار نمی‌کند؟

```bash
# 1. بررسی سرویس
systemctl status xtron-pf-*

# 2. تست پورت محلی
nc -zv localhost 2087

# 3. تست SOCKS5
curl --socks5 kharej-ip:1080 https://google.com

# 4. ریستارت Port Forward
systemctl restart xtron-pf-pf-smtp-tunnel-2087.service
```

---

## نکات مهم ⚠️

1. ✅ همیشه **فایروال** را پیکربندی کنید
2. ✅ از **رمزهای قوی** برای SOCKS5 استفاده کنید
3. ✅ **لاگ‌ها** را به طور منظم بررسی کنید
4. ✅ **Backup** از تنظیمات بگیرید
5. ✅ پورت‌های غیرضروری را **ببندید**

---

## پشتیبانی 💬

مشکل دارید؟
- 📖 [مستندات کامل](README.md)
- 🐛 [گزارش باگ](https://github.com/alixtron0/xtron-tun/issues)
- 💬 [تلگرام](https://t.me/xtron_support)

---

**موفق باشید! 🎉**
