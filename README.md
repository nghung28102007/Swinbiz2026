# 🤖 SavageBot — Trợ Lý Tài Chính Hành Vi Gen Z & Chia Tiền VietQR Khép Kín
**(Swin-Biz Rockstar 2026 • Season 6)**

> **SavageBot** là ứng dụng quản lý tài chính cá nhân & quỹ nhóm ở ghép dành cho sinh viên và Gen Z Việt Nam. Ứng dụng kết hợp **AI đa nhân cách** (*🔥 Mỏ Hỗn Roast* vs *🌱 Quân Sư Coach*), **Bóc tách ngôn ngữ tự nhiên tiếng Việt 2 tầng (Hybrid NLP)** không tốn phí API cho giao dịch thường ngày, cùng **Vòng lặp chia tiền EMVCo VietQR NAPAS 247 khép kín**.

---

## 🌐 Trải Nghiệm Nhanh (Live Demo)

- **Bản Web trực tuyến (GitHub Pages)**: [https://nghung28102007.github.io/Swinbiz2026/](https://nghung28102007.github.io/Swinbiz2026/)
- **Repository**: [https://github.com/nghung28102007/Swinbiz2026](https://github.com/nghung28102007/Swinbiz2026)

---

## ✨ Tính Năng Cốt Lõi

### 1. ⚡ Bóc tách ngôn ngữ tự nhiên tiếng Việt 2 tầng (2-Tier Hybrid NLP)
- **Tier-1 Local Regex Engine (`0đ API`, độ trễ `< 2ms`)**: Xử lý 85%+ câu nhập chi tiêu hàng ngày bằng tiếng lóng sinh viên & giọng nói tiếng Việt:
  - Hỗ trợ hậu tố tiền tệ: `45k`, `50 cành`, `150 lúa`, `1 củ 2`, `1tr5`, `45.000đ`.
  - Hỗ trợ chữ số tiếng Việt từ Speech-to-Text: `"bún bò bốn mươi lăm nghìn"`, `"trà sữa năm mươi lăm ngàn"`, `"mua áo hai trăm nghìn"`.
  - Tự động nhận diện **Danh mục** (`🍜 Ăn uống`, `🧋 Trà sữa & Cafe`, `🛵 Di chuyển`, `🏠 Hóa đơn & Trọ`, `🎮 Giải trí & Mua sắm`), **Người chi** (VD: *"Hưng mua nước giặt 90k"*) và **Khoản chi chung** (VD: *"tiền điện phòng 350k"*).
- **Tier-2 Vision OCR / LLM (`~110đ/lượt`)**: Quét hóa đơn nhiều món (WinMart+, Phê La, Điện lực EVN) và tự động đẩy các khoản chung sang tab Chia Tiền QR.

### 2. 🔥 AI Đa Nhân Cách & Tài Chính Hành Vi (Behavioral Finance)
- **Chế độ 🔥 Mỏ Hỗn (Roast)**: "Khịa" văn minh khi bạn vung tay quá trán hoặc uống trà sữa liên tục, kèm tính năng **Chạm để copy thẻ Roast AI** khoe vào nhóm chat.
- **Chế độ 🌱 Quân Sư (Coach)**: Đưa lời khuyên phân bổ dòng tiền thực tế theo hạn mức ngày.
- **Pin Ví Ngày (`Daily Safe-to-Spend`) & Đường Băng Sinh Tồn (`Survival Runway`)**: Tự động tính toán số tiền được phép tiêu thêm trong hôm nay và dự báo số ngày sống khỏe đến cuối tháng.

### 3. 💸 Chia Tiền Phòng & EMVCo VietQR NAPAS 247 Khép Kín
- Sinh chuỗi **EMVCo VietQR NAPAS 247** chuẩn ngân hàng Việt Nam kèm mã kiểm tra **CRC-16/CCITT-FALSE (`0x1021`)** động theo từng thành viên.
- Tự động gắn mã đối soát không dấu vào **Tag 62** (VD: `SB PHONG302 HUNG`) để gạch nợ chính xác.
- Hỗ trợ **Copy tin nhắn đòi nợ nhóm** ra Zalo/Messenger 1 chạm, phóng to QR để quét từ xa, và chạm để đánh dấu gạch nợ thủ công hoặc qua Deep-link ngân hàng.

### 4. 📊 Bảng Điều Khiển Phân Tích Ví (Executive KPI & Group Ledger)
- **3 Thẻ KPI**: Tổng đã chi (% ngân sách), Trung bình / Giao dịch, và Danh mục ngốn tiền nhất.
- **Biểu đồ Đóng góp chi tiêu theo thành viên** & **Cơ cấu danh mục**: Chạm trực tiếp vào từng mục để lọc Sổ Giao Dịch.
- **Thao tác hiện đại**: Tìm kiếm theo thời gian thực, **Vuốt sang trái để xóa nhanh (`Swipe-to-Delete`)** kèm nút **Hoàn tác (`Undo`)**, và xuất báo cáo tài chính.

---

## 🛠️ Yêu Cầu Hệ Thống (Prerequisites)

Trước khi clone và chạy dự án, máy tính của bạn cần cài đặt:

1. **[Git](https://git-scm.com/downloads)**
2. **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (Phiên bản `>= 3.2.0`, khuyến nghị kênh `stable` mới nhất)
3. **Trình duyệt Google Chrome** hoặc **Microsoft Edge** (để chạy nhanh bản Web), hoặc:
   - **Visual Studio 2022** (với workload *Desktop development with C++* nếu muốn build bản `.exe` trên Windows).
   - **Android Studio / Xcode** (nếu muốn chạy trên máy ảo Android / iOS).

Kiểm tra nhanh môi trường trên máy của bạn bằng lệnh:
```bash
flutter doctor
```

---

## 🚀 Hướng Dẫn Clone & Chạy Dự Án (Step-by-Step)

### Bước 1: Clone kho mã nguồn về máy
Mở **Terminal** (macOS/Linux) hoặc **PowerShell / Command Prompt** (Windows) và chạy:

```bash
git clone https://github.com/nghung28102007/Swinbiz2026.git
cd Swinbiz2026
```

### Bước 2: Cài đặt các thư viện phụ thuộc (Dependencies)
```bash
flutter pub get
```

### Bước 3: Chạy ứng dụng

#### 🌐 Cách 1: Chạy trên trình duyệt Web (Nhanh nhất & Khuyến nghị khi Demo)
Ứng dụng đã tích hợp sẵn khung điện thoại thông minh (`ResponsiveMobileFrame`) tự động căn giữa trên màn hình máy tính/máy chiếu:
```bash
flutter run -d chrome
```
*(Hoặc dùng Microsoft Edge nếu máy chưa cài Chrome: `flutter run -d edge`)*

#### 💻 Cách 2: Chạy ứng dụng Native trên Windows Desktop
```bash
flutter run -d windows
```

#### 📱 Cách 3: Chạy trên Điện thoại thật hoặc Máy ảo Android / iOS
1. Cắm cáp USB điện thoại (đã bật *USB Debugging*) hoặc mở máy ảo Android/iOS.
2. Kiểm tra danh sách thiết bị đang kết nối:
   ```bash
   flutter devices
   ```
3. Chạy ứng dụng lên thiết bị:
   ```bash
   flutter run
   ```

---

## 🧪 Kiểm Thử Tự Động & Kiểm Tra Chất Lượng Code

Dự án đi kèm bộ **12 Unit & Integration Tests** kiểm tra toàn diện bộ giải mã tiếng Việt NLP, chuẩn mã hóa CRC-16 EMVCo VietQR và tính toàn vẹn số dư ví:

```bash
# 1. Kiểm tra lỗi cú pháp & quy chuẩn code (Linter)
flutter analyze

# 2. Chạy toàn bộ bộ kiểm thử tự động (Unit & State Tests)
flutter test
```

---

## 📦 Hướng Dẫn Build Bản Phân Phối (Production Build)

- **Build bản Web tĩnh (để host lên GitHub Pages / Netlify / Vercel)**:
  ```bash
  flutter build web --release
  ```
  *(Kết quả nằm tại thư mục `build/web`)*

- **Build file cài đặt `.apk` cho Android**:
  ```bash
  flutter build apk --release
  ```
  *(File APK nằm tại `build/app/outputs/flutter-apk/app-release.apk`)*

---

## 🎯 Kịch Bản Trải Nghiệm Nhanh Cho Giám Khảo / Tester

1. **Khởi tạo Ví Mới hoặc Nạp Demo**:
   - Lần đầu mở app, bạn có thể tạo **Ví Trắng 0đ** (chế độ Cá nhân hoặc Ở ghép) trong 10 giây, hoặc bấm **"Hoặc nạp kịch bản Demo Phòng 302"** (hoặc nút 🔄 góc trên bên phải) để có sẵn dữ liệu thuyết trình.
2. **Thử gõ hoặc nói tiếng Việt tự nhiên ở Tab 1 (`AI Trợ Lý`)**:
   - Gõ thử: `"bún bò huế 45k"`, `"trà sữa phê la năm mươi lăm nghìn"`, `"Hưng mua nước giặt 90k"`, `"tiền điện phòng 350 cành"`.
   - Quan sát thanh **Live NLP Preview** bóc tách tức thì với chi phí `0đ API`.
   - Chạm vào bong bóng phản hồi của AI để copy **Thẻ Roast AI**, hoặc **vuốt sang trái** trên giao dịch để xóa nhanh / hoàn tác.
3. **Thử Quét Hóa Đơn AI (`Quét Bill AI`)**:
   - Bấm chip **`Quét Bill AI`** phía trên ô nhập chat → Chọn hóa đơn mẫu (*WinMart+*, *Phê La*, hoặc *Hóa đơn EVN*).
4. **Thử Chia Tiền & Quét VietQR ở Tab 2 (`Chia Tiền QR`)**:
   - Chạm vào tên từng thành viên (*Minh*, *Hưng*, *Linh*) để xem mã **VietQR NAPAS 247** tự động đổi số tiền và nội dung chuyển khoản.
   - Bấm **`Copy đòi nợ`** để lấy bản tổng kết gửi nhóm Zalo/Messenger, hoặc bấm **`Mở App Ngân Hàng`** để trải nghiệm luồng tự động đối soát gạch nợ.
5. **Mở Bảng Điều Khiển Giám Khảo (`Judge Console`)**:
   - Bấm biểu tượng chiếc khiên 🛡️ trên góc phải thanh tiêu đề để xem mô hình kinh tế đơn vị (*Unit Economics*), kiến trúc kỹ thuật và bảng kiểm chứng trực tiếp.

---

## 📂 Cấu Trúc Thư Mục Chính

```text
Swinbiz2026/
├── lib/
│   ├── main.dart                        # Entry point, Theme Sáng/Tối, Navigation Shell & Cấu hình nhóm
│   ├── providers/
│   │   └── savage_bot_provider.dart     # Quản lý trạng thái Riverpod, tính toán KPI & lưu trữ bền vững
│   ├── screens/
│   │   ├── onboarding_screen.dart       # Màn hình thiết lập Ví Trắng (Cá nhân / Ở ghép)
│   │   ├── home_screen.dart             # Tab 1: AI Trợ Lý, Pin Ví, Voice STT & Vision OCR
│   │   ├── split_vietqr_screen.dart     # Tab 2: Chia hóa đơn phòng & Sinh mã VietQR NAPAS 247
│   │   ├── analytics_screen.dart        # Tab 3: Dự báo đường băng, KPI, Biểu đồ & Sổ giao dịch
│   │   └── judge_pitch_sheet.dart       # Bảng thuyết trình kỹ thuật & Unit Economics cho Giám khảo
│   ├── services/
│   │   ├── hybrid_nlp_service.dart      # Động cơ NLP tiếng Việt 2 tầng (Regex + Số chữ STT + Phân loại)
│   │   └── vietqr_service.dart          # Bộ tạo chuỗi EMVCo VietQR NAPAS 247 & thuật toán CRC-16
│   ├── theme/
│   │   └── app_tokens.dart              # Hệ thống màu sắc, bo góc và Design Tokens
│   └── widgets/
│       └── edit_transaction_dialog.dart # Hộp thoại chỉnh sửa / xóa chi tiết giao dịch
├── test/
│   └── hybrid_nlp_service_test.dart     # Bộ 12 bài kiểm thử tự động (NLP, VietQR CRC-16, State)
└── .github/workflows/
    └── deploy-web.yml                   # CI/CD tự động kiểm thử và deploy lên GitHub Pages
```
