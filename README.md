# 凛月记账

本地清冷像素风记账本。数据仅保存在本机，无账号、不上云。

## 目录结构

```
lib/
  main.dart                 # 入口
  app/app.dart              # MaterialApp / 启动分流
  core/
    theme/                  # 主题色与字体
    widgets/                # 通用 Frost 组件
  data/
    database.dart           # SQLite
    models.dart             # 数据模型
    repository.dart         # 仓储
    presets/                # 人群分类 / 续费模板
  screens/                  # 页面
  state/app_state.dart      # 全局状态
assets/icons/               # 应用图标
docs/                       # 设计书与环境说明
android/                    # Android 工程（签名密钥不入库）
```

## 开发

```bash
flutter pub get
flutter run
```

更完整的环境说明见 [docs/开发环境说明.md](docs/开发环境说明.md)。

## 正式版 APK

1. 复制 `android/key.properties.example` → `android/key.properties`，填入密钥信息  
2. 将 `linyue-release.jks` 放在 `android/` 下（勿提交到 Git）  
3. 打包：

```bash
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

## 主要功能

- 多账本、多资金账户（微信 / 支付宝 / 银行卡等）
- 记账、分类预算、霜匣存钱目标
- 自动续费提醒与快捷模板
- 流水筛选、统计、月报
- 本地导出 / 导入备份
