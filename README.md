# سامانه مدیریت کاربران SSH VPN (پنل وب شیک + دور زدن DPI)

این پروژه یک سیستم کامل و ماژولار برای مدیریت کاربران SSH VPN بر روی سرورهای لینوکس (اوبونتو/دبیان) است. این سیستم دارای یک وب‌پنل مدیریت شیک با طراحی دارک‌مود (Glassmorphism)، پروکسی وب‌سوکت برای عبور از سد فیلترینگ DPI، مانیتورینگ دقیق ترافیک و سیستم هوشمند محدودسازی ورود همزمان (تک‌کاربره کردن اکانت‌ها) می‌باشد.

---

## ویژگی‌های اصلی

1. **وب‌پنل مدیریت شیک و مدرن**:
   - داشبورد زیبا با طراحی دارک‌مود و انیمیشن‌های روان.
   - نمایش آمار کلی (تعداد کاربران کل، فعال، غیرفعال و کل ترافیک مصرفی).
   - مدیریت کامل کاربران (ایجاد، ویرایش محدودیت‌ها، فعال/غیرفعال‌سازی موقت و حذف کامل).
   - تعریف محدودیت حجمی مشخص یا **ترافیک بی‌نهایت (نامحدود)**.
   - تعیین زمان انقضای اکانت بر حسب روز.

2. **عبور از فیلترینگ DPI (DPI Bypass)**:
   - مجهز به یک پروکسی وب‌سوکت داخلی (`websocket_proxy.py`) روی پورت `8880` جهت کپسوله‌سازی ترافیک SSH در قالب وب‌سوکت استاندارد.
   - قابلیت اتصال کاربران از طریق کلاینت‌هایی مانند NapsternetV، HTTP Injector و غیره از طریق CDN (مانند کلودفلر با استفاده از ساب‌دامین خاکستری/ابری).

3. **سیستم هوشمند تک‌کاربره (Single Login Enforcement)**:
   - تضمین اینکه هر اکانت در لحظه فقط توسط یک کلاینت استفاده شود.
   - برخلاف محدودیت‌های سنتی لینوکس که در صورت قطعی ناگهانی اینترنت کاربر را تا مدت‌ها قفل می‌کنند، این سیستم به محض ورود جدید، **اتصال قدیمی را قطع کرده** و به اتصال جدید اجازه ورود می‌دهد.

4. **مانیتورینگ دقیق ترافیک**:
   - شمارش دقیق ترافیک ورودی و خروجی هر کاربر با استفاده از زنجیره‌های `iptables` لینوکس بر اساس شناسه کاربری (UID).
   - اجرای اسکریپت مانیتورینگ به صورت خودکار هر ۵ دقیقه یک‌بار از طریق Cron Job.

5. **امنیت بالا (HTTPS)**:
   - استفاده از Nginx به عنوان Reverse Proxy برای وب‌پنل فلسک.
   - استفاده از پروتکل امن HTTPS با گواهی رایگان و خودکار Let's Encrypt بر روی پورت اختصاصی وب‌پنل.

---

## ساختار پوشه‌ها و فایل‌ها

- `webapp/`: پروژه وب‌پنل (فرانت‌اند HTML/CSS/JS زیبای تک‌صفحه‌ای و بک‌اند Flask پایتون).
- `nginx_panel.conf`: فایل پیکربندی Nginx برای فعال‌سازی HTTPS روی پورت `8080`.
- `websocket_proxy.py`: اسکریپت پایتون پروکسی وب‌سوکت برای عبور از فیلترینگ.
- `enforce_single_login.sh`: دیمون هوشمند لینوکس برای بررسی و قطع اتصال‌های همزمان.
- `enforce_limits.sh`: اسکریپت بررسی محدودیت حجم و زمان انقضای کاربران (غیرفعال‌سازی خودکار در صورت اتمام دیت یا زمان).
- `monitor_traffic.py`: اسکریپت خواندن اطلاعات پهنای باند از iptables و ثبت در دیتابیس.
- `iptables_rules.sh`: اسکریپت تعریف زنجیره‌های محاسباتی ترافیک در فایروال لینوکس.
- `db_setup.sh` و `db_init.sql`: راه‌اندازی و ساخت جداول دیتابیس MariaDB.
- `setup_venv.sh`: نصب پیش‌نیازها و محیط مجازی پایتون.
- `vpn-webapp.service`: سرویس سیستم‌دی جهت اجرای مداوم وب‌پنل در پس‌زمینه.
- `vpn-websocket.service`: سرویس سیستم‌دی جهت اجرای مداوم پروکسی وب‌سوکت.
- `vpn-single-login.service`: سرویس سیستم‌دی جهت اجرای مداوم محدودکننده ورود همزمان.

---

## راهنمای نصب و راه‌اندازی روی سرور (VPS)

### ۱. کلون کردن پروژه روی سرور
ابتدا فایل‌های پروژه را در مسیر `/opt/vpn_manager` قرار دهید:
```bash
git clone https://github.com/AmirNaderi1997/SSH-VPN-WebPanel.git /opt/vpn_manager
cd /opt/vpn_manager
```

### ۲. راه‌اندازی دیتابیس
اسکریپت ساخت دیتابیس را به عنوان کاربر ریشه (root) اجرا کنید تا دیتابیس ماریا دی‌بی نصب و راه‌اندازی شود:
```bash
chmod +x db_setup.sh
./db_setup.sh
```

### ۳. نصب وابستگی‌های پایتون
محیط مجازی پایتون را ساخته و کتابخانه‌های مورد نیاز را نصب کنید:
```bash
chmod +x setup_venv.sh
./setup_venv.sh
```

### ۴. راه‌اندازی سرویس‌های سیستم‌دی (Systemd Services)
فایل‌های سرویس را به مسیر خدمات سیستم کپی کرده و آن‌ها را فعال و اجرا کنید:

```bash
# کپی سرویس‌ها
cp vpn-webapp.service vpn-websocket.service vpn-single-login.service /etc/systemd/system/
systemctl daemon-reload

# فعال‌سازی و استارت وب‌پنل
systemctl enable vpn-webapp.service
systemctl start vpn-webapp.service

# فعال‌سازی و استارت پروکسی وب‌سوکت (DPI Bypass)
systemctl enable vpn-websocket.service
systemctl start vpn-websocket.service

# فعال‌سازی و استارت محدودکننده ورود همزمان (تک‌کاربره)
chmod +x enforce_single_login.sh
systemctl enable vpn-single-login.service
systemctl start vpn-single-login.service
```

### ۵. تنظیم زمان‌بندی فایروال و کرون‌جاب (Cron Jobs)
قوانین محاسباتی iptables را اعمال کنید و زمان‌بندی را بنویسید تا ترافیک کاربران هر ۵ دقیقه ثبت و محدودیت‌ها بررسی شوند:

```bash
# اجرای دستی اسکریپت فایروال برای بار اول
chmod +x iptables_rules.sh enforce_limits.sh
./iptables_rules.sh

# باز کردن کرون‌جاب سیستم
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/vpn_manager/venv/bin/python /opt/vpn_manager/monitor_traffic.py >> /var/log/vpn_traffic.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/vpn_manager/enforce_limits.sh >> /var/log/vpn_manager.log 2>&1") | crontab -
```

---

## راه‌اندازی SSL و HTTPS روی پورت ۸۰۸۰ با Nginx

برای امنیت ارتباط شما با وب‌پنل، حتماً اتصال رمزنگاری شده HTTPS را با Nginx فعال کنید.

### ۱. نصب Certbot و Nginx
```bash
apt update && apt install -y nginx certbot
systemctl stop nginx
```

### ۲. دریافت گواهینامه SSL برای دامنه شما
سلب مسئولیت: مطمئن شوید رکورد A دامنه شما (مثال: `panel.ip-ping.ir`) به آی‌پی سرورتان اشاره می‌کند.
```bash
certbot certonly --standalone -d panel.ip-ping.ir --non-interactive --agree-tos -m your-email@gmail.com
```

### ۳. اعمال پیکربندی Nginx
فایل پیکربندی Nginx را ساخته و لینک کنید:
```bash
rm -f /etc/nginx/sites-enabled/default
cp /opt/vpn_manager/nginx_panel.conf /etc/nginx/sites-available/panel.conf
ln -sf /etc/nginx/sites-available/panel.conf /etc/nginx/sites-enabled/panel.conf

# تست صحت فایل پیکربندی Nginx
nginx -t

# اجرای مجدد سرویس وب‌پنل و وب‌سرور Nginx
systemctl restart vpn-webapp.service
systemctl start nginx
systemctl enable nginx
```

اکنون می‌توانید به جای اتصال ناامن HTTP، از طریق آدرس امن **`https://panel.ip-ping.ir:8080`** به وب‌پنل متصل شوید.

***
---

## توسعه‌دهندگان و لایسنس
این سیستم برای مصارف شخصی و دور زدن فیلترینگ اینترنت توسعه یافته است. استفاده تجاری غیراخلاقی مسئولیت آن بر عهده خود کاربر است.
