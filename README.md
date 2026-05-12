# 🏋️ KiviFit — AI Тренер по движению

Высокопроизводительное приложение для iOS с определением позы в реальном времени через **MediaPipe Pose Landmarker Heavy** (GPU/Metal), анализом ошибок в технике упражнений и **голосовыми подсказками в наушники**.

---

## 📱 Возможности

| Функция | Детали |
|---|---|
| Модель позы | `pose_landmarker_heavy.task` — 33 ориентира, 3D координаты |
| Ускорение | GPU (Metal) через `BaseOptions.delegate = .GPU` |
| Пропуск кадров | Каждый 2-й кадр (настраивается в `PoseDetectorManager.Config`) |
| Сглаживание | Скользящее среднее по 4 кадрам |
| Скелет | Зелёные кости + красные суставы поверх видео |
| Голос | TTS на русском языке, вывод в наушники через AVAudioSession `.playback` |
| Упражнения | Приседание, Отжимание, Планка, Выпад, Становая тяга, Жим плечами |

---

## 🗂️ Структура проекта

```
kivifit/
├── KiviFit.xcodeproj/
│   └── project.pbxproj
├── KiviFit/
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── KiviFitApp.swift          # @main точка входа
│   │   │   ├── ContentView.swift         # Роутер Home ↔ Workout
│   │   │   └── WorkoutViewModel.swift    # Оркестратор (ViewModel)
│   │   ├── Views/
│   │   │   ├── HomeView.swift            # Главный экран с кнопкой
│   │   │   ├── WorkoutView.swift         # Экран тренировки + HUD
│   │   │   ├── SkeletonOverlayView.swift # Canvas-наложение скелета
│   │   │   └── CameraPreviewView.swift   # AVFoundation превью
│   │   └── Managers/
│   │       ├── PoseDetectorManager.swift # MediaPipe + GPU + сглаживание
│   │       ├── CameraManager.swift       # AVCaptureSession (фронтальная)
│   │       ├── ExerciseAnalyzer.swift    # Анализ углов + ошибки
│   │       ├── VoiceCoach.swift          # TTS голосовые подсказки
│   │       └── PermissionManager.swift   # Камера + микрофон
│   ├── Resources/
│   │   ├── pose_landmarker_heavy.task    # ← скачать (см. ниже)
│   │   └── pose_landmarker_lite.task     # ← запасная модель
│   └── Supporting Files/
│       └── Info.plist
├── Podfile
├── Package.swift
├── codemagic.yaml                        # CI/CD → unsigned IPA
└── README.md
```

---

## 🚀 Быстрый старт (локально)

### 1. Клонировать репозиторий
```bash
git clone https://github.com/YOUR_USERNAME/kivifit.git
cd kivifit
```

### 2. Скачать модели MediaPipe
```bash
mkdir -p KiviFit/Resources

# Heavy model (наибольшая точность, ~29 MB)
curl -L "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/latest/pose_landmarker_heavy.task" \
  -o KiviFit/Resources/pose_landmarker_heavy.task

# Lite model (резервная, ~4.5 MB)
curl -L "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task" \
  -o KiviFit/Resources/pose_landmarker_lite.task
```

### 3. Установить CocoaPods
```bash
sudo gem install cocoapods
pod install
```

### 4. Открыть в Xcode
```bash
open KiviFit.xcworkspace
```

> ⚠️ Открывать **`.xcworkspace`**, не `.xcodeproj`!

### 5. Собрать для устройства (без подписи)
В Xcode: **Product → Build** (⌘B)

---

## 📦 Сборка через Codemagic + установка через Sideloadly

### Шаг 1 — Подключить к Codemagic
1. Зайти на [codemagic.io](https://codemagic.io)
2. Нажать **Add application** → выбрать GitHub репозиторий `kivifit`
3. Codemagic автоматически найдёт `codemagic.yaml`
4. Запустить workflow `kivifit-unsigned-ipa`

### Шаг 2 — Скачать IPA
После успешной сборки скачать `KiviFit-unsigned.ipa` из артефактов.

### Шаг 3 — Установить через Sideloadly
1. Скачать [Sideloadly](https://sideloadly.io) для Windows или macOS
2. Подключить iPhone кабелем
3. Перетащить `KiviFit-unsigned.ipa` в Sideloadly
4. Ввести Apple ID (бесплатный, без Developer Program)
5. Нажать **Start** — Sideloadly подпишет IPA через бесплатный provisioning

> ⚠️ Бесплатный Apple ID: приложение работает **7 дней**, затем нужно переподписать.
> Платный Apple Developer ($99/год) → 1 год без переподписи.

---

## 🏗️ Архитектура

```
Camera (AVCaptureSession)
    ↓ CMSampleBuffer
CameraManager
    ↓ delegate
WorkoutViewModel
    ↓
PoseDetectorManager
  ├── MediaPipe PoseLandmarker (GPU/Metal)
  ├── Frame skip (каждый 2-й кадр)
  └── Smoothing filter (скользящее среднее)
    ↓ [NormalizedLandmark] x33
WorkoutViewModel
  ├── SkeletonOverlayView (Canvas, зелёные линии + красные точки)
  ├── ExerciseAnalyzer (углы суставов → FormError)
  └── VoiceCoach (AVSpeechSynthesizer → наушники)
```

---

## 🎯 Детекция ошибок

| Упражнение | Ошибки |
|---|---|
| Приседание | Колени внутрь, спина вперёд, мелкая глубина, пятки отрываются |
| Отжимание | Локти развёрнуты, таз провисает, голова вниз |
| Планка | Таз высоко/низко |
| Выпад | Колено за носок, корпус вперёд, слишком глубокий |
| Становая тяга | Округление спины, штанга далеко от тела |
| Жим плечами | Неполное выпрямление, прогиб поясницы |

---

## ⚙️ Настройка

В `PoseDetectorManager.Config`:
```swift
var frameSkip: Int = 2          // 2 = каждый 2-й кадр, 3 = каждый 3-й
var smoothingWindowSize: Int = 5 // больше = плавнее, но с задержкой
```

В `VoiceCoach`:
```swift
var cooldownSeconds: TimeInterval = 4.0  // интервал между голосовыми подсказками
```

---

## 📋 Требования

- iPhone с фронтальной камерой
- iOS 16.0+
- Metal GPU (все современные iPhone поддерживают)
- Xcode 15+

---

## 📄 Лицензия

MIT License — используйте свободно.
