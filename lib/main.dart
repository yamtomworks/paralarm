import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const ParalarmApp());
}

enum MonitorTarget { sound, vibration }

enum ThresholdRule { above, below }

enum AppMode { settings, countdown, monitoring, alerting }

enum AppLanguage {
  japanese,
  english,
  chinese,
  traditionalChinese,
  spanish,
  german,
  french,
  italian,
  korean,
  portuguese,
}

enum AlarmSoundOption { loudBeep, alert, click, off }

enum AlarmVibrationOption { urgent, pulse, long, off }

enum DangerAlertMode { sound, vibration, both }

enum SettingsError { microphoneDenied, soundReadFailed, vibrationReadFailed }

const _neonLime = Color(0xFFD7FF21);
const _electricYellow = Color(0xFFF3FF5A);
const _charcoal = Color(0xFF080A0C);
const _panelGray = Color(0xFF12161A);
const _panelBorder = Color(0xFF3A4438);
const _alarmSoundChannel = MethodChannel('codex_paralarm/alarm_sound');
const _settingsPresetStorageKey = 'settings_presets_v1';
const _lastStartedSettingsStorageKey = 'last_started_settings_v1';
const _premiumStorageKey = 'is_premium_v1';
const _completedMonitoringSessionsStorageKey =
    'completed_monitoring_sessions_v1';
const _hasRequestedReviewStorageKey = 'has_requested_review_v1';
const _hasSeenTutorialStorageKey = 'has_seen_tutorial_v1';
const _settingsPresetSlots = 3;
const _freeSettingsPresetSlots = 1;
const _maxDangerAlertTicks = 20;
const _premiumFeaturesEnabled = false;

class AppStrings {
  const AppStrings(this.appLanguage);

  final AppLanguage appLanguage;

  bool get isJapanese => appLanguage == AppLanguage.japanese;
  bool get isChinese => appLanguage == AppLanguage.chinese;
  bool get isTraditionalChinese =>
      appLanguage == AppLanguage.traditionalChinese;
  bool get isSpanish => appLanguage == AppLanguage.spanish;
  bool get isGerman => appLanguage == AppLanguage.german;
  bool get isFrench => appLanguage == AppLanguage.french;
  bool get isItalian => appLanguage == AppLanguage.italian;
  bool get isKorean => appLanguage == AppLanguage.korean;
  bool get isPortuguese => appLanguage == AppLanguage.portuguese;

  String _text(
    String japanese,
    String english,
    String chinese,
    String spanish, {
    String? traditionalChinese,
    String? german,
    String? french,
    String? italian,
    String? korean,
    String? portuguese,
  }) {
    return switch (appLanguage) {
      AppLanguage.japanese => japanese,
      AppLanguage.english => english,
      AppLanguage.chinese => chinese,
      AppLanguage.traditionalChinese => traditionalChinese ?? chinese,
      AppLanguage.spanish => spanish,
      AppLanguage.german => german ?? english,
      AppLanguage.french => french ?? english,
      AppLanguage.italian => italian ?? english,
      AppLanguage.korean => korean ?? english,
      AppLanguage.portuguese => portuguese ?? english,
    };
  }

  String get settings => _text(
    '設定',
    'Settings',
    '设置',
    'Ajustes',
    german: 'Einstellungen',
    french: 'Réglages',
    italian: 'Impostazioni',
    korean: '설정',
    traditionalChinese: '設定',
    portuguese: 'Ajustes',
  );
  String get tutorial => _text(
    'チュートリアル',
    'Tutorial',
    '教程',
    'Tutorial',
    german: 'Tutorial',
    french: 'Tutoriel',
    italian: 'Tutorial',
    korean: '튜토리얼',
    traditionalChinese: '教學',
    portuguese: 'Tutorial',
  );
  String get tutorialStartTitle => _text(
    '音量や振動を見張る',
    'Watch Volume or Vibration',
    '监测音量或振动',
    'Vigila volumen o vibración',
    german: 'Lautstärke oder Vibration überwachen',
    french: 'Surveiller le volume ou les vibrations',
    italian: 'Controlla volume o vibrazione',
    korean: '음량 또는 진동 감시',
    traditionalChinese: '監測音量或震動',
    portuguese: 'Monitore volume ou vibração',
  );
  String get tutorialStartBody => _text(
    'ターゲット、通知条件、閾値を決めてスタートします。現在値と閾値の関係はグラフで確認できます。',
    'Choose a target, condition, and threshold, then start. The chart shows how the current value relates to the threshold.',
    '选择目标、通知条件和阈值后开始。图表会显示当前值与阈值的关系。',
    'Elige objetivo, condición y umbral, y empieza. La gráfica muestra la relación entre el valor actual y el umbral.',
    german:
        'Wähle Ziel, Bedingung und Schwellenwert und starte. Das Diagramm zeigt das Verhältnis zwischen aktuellem Wert und Schwellenwert.',
    french:
        'Choisissez une cible, une condition et un seuil, puis démarrez. Le graphique montre le lien entre la valeur actuelle et le seuil.',
    italian:
        'Scegli target, condizione e soglia, poi avvia. Il grafico mostra il rapporto tra valore attuale e soglia.',
    korean: '대상, 조건, 임계값을 정하고 시작하세요. 그래프에서 현재값과 임계값의 관계를 확인할 수 있습니다.',
    traditionalChinese: '選擇目標、通知條件和閾值後開始。圖表會顯示目前值與閾值的關係。',
    portuguese:
        'Escolha um alvo, condição e limite, depois inicie. O gráfico mostra a relação entre o valor atual e o limite.',
  );
  String get tutorialGraphTitle => _text(
    'グラフで変化を確認',
    'Watch the Chart',
    '通过图表确认变化',
    'Observa la gráfica',
    german: 'Änderungen im Diagramm sehen',
    french: 'Suivre les changements',
    italian: 'Osserva il grafico',
    korean: '그래프로 변화 확인',
    traditionalChinese: '用圖表確認變化',
    portuguese: 'Veja as mudanças no gráfico',
  );
  String get tutorialGraphBody => _text(
    'リアルタイムの数値と閾値をグラフで確認できます。移動平均を強くすると、細かい揺れをなめらかにできます。',
    'The chart shows the live value and threshold together. Increase moving average strength to smooth small fluctuations.',
    '图表会同时显示实时数值和阈值。提高移动平均强度可以平滑细小波动。',
    'La gráfica muestra el valor en vivo y el umbral juntos. Aumenta la media móvil para suavizar pequeñas fluctuaciones.',
    german:
        'Das Diagramm zeigt Live-Wert und Schwellenwert zusammen. Erhöhe den gleitenden Durchschnitt, um kleine Schwankungen zu glätten.',
    french:
        'Le graphique affiche la valeur en direct et le seuil. Augmentez la moyenne mobile pour lisser les petites variations.',
    italian:
        'Il grafico mostra insieme valore live e soglia. Aumenta la media mobile per rendere più fluide le piccole variazioni.',
    korean: '그래프에는 실시간 값과 임계값이 함께 표시됩니다. 이동 평균을 높이면 작은 흔들림을 부드럽게 만들 수 있습니다.',
    traditionalChinese: '圖表會同時顯示即時數值和閾值。提高移動平均強度可以讓細小波動更平滑。',
    portuguese:
        'O gráfico mostra o valor ao vivo e o limite juntos. Aumente a média móvel para suavizar pequenas oscilações.',
  );
  String get tutorialAlertTitle => _text(
    '通知とプリセット',
    'Alerts and Presets',
    '通知与预设',
    'Alertas y preajustes',
    german: 'Alarme und Presets',
    french: 'Alertes et préréglages',
    italian: 'Avvisi e preset',
    korean: '알림과 프리셋',
    traditionalChinese: '通知與預設',
    portuguese: 'Alertas e predefinições',
  );
  String get tutorialAlertBody => _text(
    '閾値に達すると音や振動で通知します。よく使う設定はプリセットに保存して、次回すぐにロードできます。',
    'When the threshold is reached, the app alerts with sound or vibration. Save favorite settings as presets and load them quickly next time.',
    '达到阈值时，应用会通过声音或振动提醒。常用设置可保存为预设，下次快速加载。',
    'Al alcanzar el umbral, la app avisa con sonido o vibración. Guarda ajustes frecuentes como preajustes y cárgalos rápido la próxima vez.',
    german:
        'Wenn der Schwellenwert erreicht wird, warnt die App mit Ton oder Vibration. Häufige Einstellungen kannst du als Preset speichern.',
    french:
        'Quand le seuil est atteint, l’app alerte par son ou vibration. Enregistrez vos réglages favoris comme préréglages.',
    italian:
        'Quando viene raggiunta la soglia, l’app avvisa con suono o vibrazione. Salva le impostazioni preferite come preset.',
    korean: '임계값에 도달하면 소리나 진동으로 알립니다. 자주 쓰는 설정은 프리셋으로 저장해 빠르게 불러올 수 있습니다.',
    traditionalChinese: '達到閾值時，應用程式會透過聲音或震動提醒。常用設定可儲存為預設，下次快速載入。',
    portuguese:
        'Quando o limite é atingido, o app alerta com som ou vibração. Salve ajustes favoritos como predefinições.',
  );
  String get tutorialSafetyTitle => _text(
    '安全に使う',
    'Use Safely',
    '安全使用',
    'Uso seguro',
    german: 'Sicher verwenden',
    french: 'Utilisation sûre',
    italian: 'Usa in sicurezza',
    korean: '안전하게 사용',
    traditionalChinese: '安全使用',
    portuguese: 'Use com segurança',
  );
  String get tutorialSafetyBody => _text(
    '端末を投げたり、強く振り回したり、走行中や危険な場所で使用しないでください。事故や怪我、端末破損につながる可能性があります。',
    'Do not throw, swing, or use the device while running or in unsafe places. Misuse may cause accidents, injury, or device damage.',
    '请勿投掷、用力挥动设备，或在奔跑中、危险场所使用。本应用使用不当可能导致事故、受伤或设备损坏。',
    'No lances ni agites el dispositivo, ni lo uses mientras corres o en lugares peligrosos. Un uso indebido puede causar accidentes, lesiones o daños al dispositivo.',
    german:
        'Wirf oder schwenke das Gerät nicht und nutze es nicht beim Laufen oder an unsicheren Orten. Missbrauch kann Unfälle, Verletzungen oder Geräteschäden verursachen.',
    french:
        'Ne lancez pas et ne secouez pas fortement l’appareil. Ne l’utilisez pas en courant ou dans des lieux dangereux.',
    italian:
        'Non lanciare o agitare il dispositivo e non usarlo mentre corri o in luoghi pericolosi. Un uso improprio può causare incidenti, lesioni o danni.',
    korean:
        '기기를 던지거나 세게 흔들지 말고, 달리는 중이나 위험한 장소에서 사용하지 마세요. 사고, 부상 또는 기기 손상이 발생할 수 있습니다.',
    traditionalChinese: '請勿投擲、用力揮動裝置，或在奔跑中、危險場所使用。使用不當可能導致事故、受傷或裝置損壞。',
    portuguese:
        'Não jogue, balance com força nem use o dispositivo correndo ou em locais perigosos. O uso indevido pode causar acidentes, lesões ou danos.',
  );
  String get tutorialPrivacyTitle => _text(
    'データは端末内で処理',
    'Processed on Device',
    '在设备上处理',
    'Procesado en el dispositivo',
    german: 'Auf dem Gerät verarbeitet',
    french: 'Traitement sur l’appareil',
    italian: 'Elaborato sul dispositivo',
    korean: '기기 내에서 처리',
    traditionalChinese: '在裝置上處理',
    portuguese: 'Processado no dispositivo',
  );
  String get tutorialPrivacyBody => _text(
    'マイク音声やカメラ映像は録音・保存・外部送信しません。音量判定やQR読み取りのために端末内でだけ使います。',
    'Microphone audio and camera video are not recorded, saved, or sent outside the app. They are used on device only for volume detection and QR scanning.',
    '麦克风音频和相机画面不会录制、保存或发送到外部。它们仅在设备上用于音量判断和 QR 读取。',
    'El audio del micrófono y el video de la cámara no se graban, guardan ni envían fuera de la app. Solo se usan en el dispositivo para medir volumen y leer QR.',
    german:
        'Mikrofon-Audio und Kameravideo werden nicht aufgenommen, gespeichert oder gesendet. Sie werden nur auf dem Gerät für Lautstärke und QR-Scan genutzt.',
    french:
        'L’audio du micro et la vidéo de la caméra ne sont ni enregistrés, ni stockés, ni envoyés hors de l’app. Ils servent seulement au volume et au scan QR.',
    italian:
        'Audio del microfono e video della fotocamera non vengono registrati, salvati o inviati fuori dall’app. Sono usati solo sul dispositivo.',
    korean:
        '마이크 음성과 카메라 영상은 녹음, 저장, 외부 전송되지 않습니다. 음량 판단과 QR 읽기에만 기기 내에서 사용됩니다.',
    traditionalChinese: '麥克風音訊和相機畫面不會錄製、儲存或傳送到外部。僅在裝置上用於音量判斷和 QR 讀取。',
    portuguese:
        'Áudio do microfone e vídeo da câmera não são gravados, salvos nem enviados para fora do app. São usados apenas no dispositivo.',
  );
  String get tutorialPremiumTitle => _text(
    'Premiumでさらに便利に',
    'More with Premium',
    'Premium 提供更多功能',
    'Más con Premium',
    german: 'Mehr mit Premium',
    french: 'Plus avec Premium',
    italian: 'Di più con Premium',
    korean: 'Premium으로 더 편리하게',
    traditionalChinese: 'Premium 更方便',
    portuguese: 'Mais com Premium',
  );
  String get tutorialPremiumBody => _text(
    'Premiumでは危険域通知、3つの設定プリセット、QRコードでの設定共有、追加アラーム音が使えます。',
    'Premium unlocks danger zone alerts, three setting presets, QR setting sharing, and extra alarm sounds.',
    'Premium 可解锁危险区通知、3个设置预设、QR 设置分享以及更多警报音。',
    'Premium desbloquea alertas de zona de riesgo, tres preajustes, compartir ajustes por QR y sonidos de alarma adicionales.',
    german:
        'Premium schaltet Gefahrenzonen-Alarme, drei Presets, QR-Teilen und zusätzliche Alarmtöne frei.',
    french:
        'Premium débloque les alertes de zone à risque, trois préréglages, le partage QR et des sons d’alarme supplémentaires.',
    italian:
        'Premium sblocca avvisi di zona di rischio, tre preset, condivisione QR e suoni di allarme extra.',
    korean: 'Premium에서는 위험 영역 알림, 설정 프리셋 3개, QR 설정 공유, 추가 알람음을 사용할 수 있습니다.',
    traditionalChinese: 'Premium 可解鎖危險區通知、3 個設定預設、QR 設定分享以及更多警報音。',
    portuguese:
        'Premium desbloqueia alertas de zona de risco, três predefinições, compartilhamento por QR e sons extras.',
  );
  String get next => _text(
    '次へ',
    'Next',
    '下一步',
    'Siguiente',
    german: 'Weiter',
    french: 'Suivant',
    italian: 'Avanti',
    korean: '다음',
    traditionalChinese: '下一步',
    portuguese: 'Próximo',
  );
  String get begin => _text(
    'はじめる',
    'Begin',
    '开始',
    'Empezar',
    german: 'Beginnen',
    french: 'Commencer',
    italian: 'Inizia',
    korean: '시작하기',
    traditionalChinese: '開始',
    portuguese: 'Começar',
  );
  String get languageLabel => _text(
    '言語',
    'Language',
    '语言',
    'Idioma',
    german: 'Sprache',
    french: 'Langue',
    italian: 'Lingua',
    korean: '언어',
    traditionalChinese: '語言',
    portuguese: 'Idioma',
  );
  String get presets => _text(
    '設定プリセット',
    'Setting Presets',
    '设置预设',
    'Preajustes',
    german: 'Einstellungs-Presets',
    french: 'Préréglages',
    italian: 'Preset impostazioni',
    korean: '설정 프리셋',
    traditionalChinese: '設定預設',
    portuguese: 'Predefinições',
  );
  String get upgradeToPremium => _text(
    '有料版にアップグレード',
    'Upgrade to Premium',
    '升级到付费版',
    'Mejorar a Premium',
    german: 'Auf Premium upgraden',
    french: 'Passer à Premium',
    italian: 'Passa a Premium',
    korean: 'Premium으로 업그레이드',
    traditionalChinese: '升級到 Premium',
    portuguese: 'Atualizar para Premium',
  );
  String get premiumUnlocked => _text(
    '有料版が有効です',
    'Premium Enabled',
    '付费版已启用',
    'Premium activo',
    german: 'Premium aktiviert',
    french: 'Premium activé',
    italian: 'Premium attivo',
    korean: 'Premium 활성화됨',
    traditionalChinese: 'Premium 已啟用',
    portuguese: 'Premium ativado',
  );
  String get premiumRequired => _text(
    '有料版限定機能',
    'Premium Feature',
    '付费版功能',
    'Función Premium',
    german: 'Premium-Funktion',
    french: 'Fonction Premium',
    italian: 'Funzione Premium',
    korean: 'Premium 기능',
    traditionalChinese: 'Premium 功能',
    portuguese: 'Recurso Premium',
  );
  String get premiumRequiredBody => _text(
    'この機能を使うには有料版へのアップグレードが必要です。',
    'Upgrade to Premium to use this feature.',
    '使用此功能需要升级到付费版。',
    'Mejora a Premium para usar esta función.',
    german: 'Upgrade auf Premium, um diese Funktion zu nutzen.',
    french: 'Passez à Premium pour utiliser cette fonction.',
    italian: 'Passa a Premium per usare questa funzione.',
    korean: '이 기능을 사용하려면 Premium으로 업그레이드하세요.',
    traditionalChinese: '使用此功能需要升級到 Premium。',
    portuguese: 'Atualize para Premium para usar este recurso.',
  );
  String get upgradeDemoBody => _text(
    '現在は課金接続前のテスト実装です。OKを押すとこの端末で有料版として有効化します。',
    'This is a pre-store test implementation. Tap OK to enable Premium on this device.',
    '这是连接商店前的测试实现。点击 OK 将在此设备上启用付费版。',
    'Esta es una implementación de prueba antes de conectar la tienda. Toca OK para activar Premium en este dispositivo.',
    german:
        'Dies ist eine Testimplementierung vor der Store-Anbindung. Tippe OK, um Premium auf diesem Gerät zu aktivieren.',
    french:
        'Ceci est une implémentation de test avant la connexion au store. Touchez OK pour activer Premium sur cet appareil.',
    italian:
        'Questa è un’implementazione di test prima del collegamento allo store. Tocca OK per attivare Premium su questo dispositivo.',
    korean: '스토어 연결 전 테스트 구현입니다. OK를 누르면 이 기기에서 Premium이 활성화됩니다.',
    traditionalChinese: '這是連接商店前的測試實作。點選 OK 會在此裝置啟用 Premium。',
    portuguese:
        'Esta é uma implementação de teste antes da conexão com a loja. Toque em OK para ativar Premium neste dispositivo.',
  );
  String get qrShow => _text(
    'QR表示',
    'Show QR',
    '显示QR',
    'Mostrar QR',
    german: 'QR anzeigen',
    french: 'Afficher QR',
    italian: 'Mostra QR',
    korean: 'QR 표시',
    traditionalChinese: '顯示 QR',
    portuguese: 'Mostrar QR',
  );
  String get qrScan => _text(
    'QR読み取り',
    'Scan QR',
    '扫描QR',
    'Escanear QR',
    german: 'QR scannen',
    french: 'Scanner QR',
    italian: 'Scansiona QR',
    korean: 'QR 스캔',
    traditionalChinese: '掃描 QR',
    portuguese: 'Ler QR',
  );
  String get qrInvalid => _text(
    'QRコードを読み取れませんでした',
    'Invalid QR code',
    '无法读取QR码',
    'QR no válido',
    german: 'Ungültiger QR-Code',
    french: 'Code QR invalide',
    italian: 'Codice QR non valido',
    korean: '잘못된 QR 코드',
    traditionalChinese: '無效的 QR 碼',
    portuguese: 'Código QR inválido',
  );
  String get cameraPermissionTitle => _text(
    'カメラ利用の許可',
    'Camera Access',
    '相机权限',
    'Acceso a la cámara',
    german: 'Kamerazugriff',
    french: 'Accès à la caméra',
    italian: 'Accesso alla fotocamera',
    korean: '카메라 접근',
    traditionalChinese: '相機權限',
    portuguese: 'Acesso à câmera',
  );
  String get cameraPermissionBody => _text(
    'QRコードを読み取る時だけカメラを使用します。撮影した映像やQRコードの内容は外部へ送信せず、設定の読み込みにだけ使います。',
    'Camera access is used only while scanning QR codes. Video and QR contents are not sent outside the app and are used only to load settings.',
    '仅在扫描QR码时使用相机。视频和QR内容不会发送到应用外部，仅用于加载设置。',
    'La cámara se usa solo al escanear códigos QR. El video y el contenido del QR no se envían fuera de la app y solo se usan para cargar ajustes.',
    german:
        'Die Kamera wird nur beim Scannen von QR-Codes verwendet. Video und QR-Inhalte werden nicht außerhalb der App gesendet.',
    french:
        'La caméra est utilisée uniquement pour scanner les codes QR. La vidéo et le contenu QR ne sont pas envoyés hors de l’app.',
    italian:
        'La fotocamera viene usata solo per scansionare codici QR. Video e contenuto QR non vengono inviati fuori dall’app.',
    korean:
        '카메라는 QR 코드를 스캔할 때만 사용됩니다. 영상과 QR 내용은 앱 외부로 전송되지 않고 설정 불러오기에만 사용됩니다.',
    traditionalChinese: '僅在掃描 QR 碼時使用相機。影片和 QR 內容不會傳送到應用程式外部，僅用於載入設定。',
    portuguese:
        'A câmera é usada apenas ao ler códigos QR. Vídeo e conteúdo do QR não são enviados para fora do app.',
  );
  String get cameraPermissionSettingsBody => _text(
    'カメラの使用が拒否されています。QRコードを読み取るには端末の設定でカメラを許可してください。カメラ映像は端末内で読み取りにだけ使い、保存や外部送信はしません。',
    'Camera access is denied. Allow it in device settings to scan QR codes. Camera video is processed on device only for scanning and is not saved or sent outside the app.',
    '相机权限已被拒绝。请在设备设置中允许相机以扫描QR码。相机画面仅在设备上用于读取，不会保存或发送到外部。',
    'El acceso a la cámara está denegado. Actívalo en los ajustes del dispositivo para escanear códigos QR. El video se procesa en el dispositivo solo para escanear y no se guarda ni se envía fuera de la app.',
    german:
        'Kamerazugriff wurde verweigert. Erlaube die Kamera in den Geräteeinstellungen, um QR-Codes zu scannen.',
    french:
        'L’accès à la caméra est refusé. Autorisez-le dans les réglages de l’appareil pour scanner les codes QR.',
    italian:
        'L’accesso alla fotocamera è negato. Consentilo nelle impostazioni del dispositivo per scansionare codici QR.',
    korean: '카메라 접근이 거부되었습니다. QR 코드를 스캔하려면 기기 설정에서 카메라를 허용하세요.',
    traditionalChinese: '相機權限已被拒絕。若要掃描 QR 碼，請在裝置設定中允許相機。',
    portuguese:
        'O acesso à câmera foi negado. Permita a câmera nos ajustes do dispositivo para ler códigos QR.',
  );
  String get save => _text(
    '保存',
    'Save',
    '保存',
    'Guardar',
    german: 'Speichern',
    french: 'Enregistrer',
    italian: 'Salva',
    korean: '저장',
  );
  String get load => _text(
    'ロード',
    'Load',
    '加载',
    'Cargar',
    german: 'Laden',
    french: 'Charger',
    italian: 'Carica',
    korean: '불러오기',
  );
  String get rename => _text(
    '名前変更',
    'Rename',
    '重命名',
    'Renombrar',
    german: 'Umbenennen',
    french: 'Renommer',
    italian: 'Rinomina',
    korean: '이름 변경',
  );
  String get close => _text(
    '閉じる',
    'Close',
    '关闭',
    'Cerrar',
    german: 'Schließen',
    french: 'Fermer',
    italian: 'Chiudi',
    korean: '닫기',
  );
  String get ok => _text('OK', 'OK', 'OK', 'OK');
  String get cancel => _text(
    'キャンセル',
    'Cancel',
    '取消',
    'Cancelar',
    german: 'Abbrechen',
    french: 'Annuler',
    italian: 'Annulla',
    korean: '취소',
  );
  String get emptySlot => _text(
    '未保存',
    'Empty',
    '空',
    'Vacío',
    german: 'Leer',
    french: 'Vide',
    italian: 'Vuoto',
    korean: '비어 있음',
  );
  String get presetName => _text(
    '設定名',
    'Preset Name',
    '预设名称',
    'Nombre',
    german: 'Preset-Name',
    french: 'Nom du préréglage',
    italian: 'Nome preset',
    korean: '프리셋 이름',
  );
  String get saved => _text(
    '保存しました',
    'Saved',
    '已保存',
    'Guardado',
    german: 'Gespeichert',
    french: 'Enregistré',
    italian: 'Salvato',
    korean: '저장됨',
  );
  String get loaded => _text(
    'ロードしました',
    'Loaded',
    '已加载',
    'Cargado',
    german: 'Geladen',
    french: 'Chargé',
    italian: 'Caricato',
    korean: '불러옴',
  );
  String get renamed => _text(
    '名前を変更しました',
    'Renamed',
    '已重命名',
    'Renombrado',
    german: 'Umbenannt',
    french: 'Renommé',
    italian: 'Rinominato',
    korean: '이름 변경됨',
  );
  String get japanese => _text(
    '日本語',
    'Japanese',
    '日语',
    'Japonés',
    german: 'Japanisch',
    french: 'Japonais',
    italian: 'Giapponese',
    korean: '일본어',
    traditionalChinese: '日文',
    portuguese: 'Japonês',
  );
  String get english => _text(
    '英語',
    'English',
    '英语',
    'Inglés',
    german: 'Englisch',
    french: 'Anglais',
    italian: 'Inglese',
    korean: '영어',
    traditionalChinese: '英文',
    portuguese: 'Inglês',
  );
  String get chinese => _text(
    '中国語',
    'Chinese',
    '中文',
    'Chino',
    german: 'Chinesisch',
    french: 'Chinois',
    italian: 'Cinese',
    korean: '중국어',
    traditionalChinese: '簡體中文',
    portuguese: 'Chinês',
  );
  String get traditionalChinese => _text(
    '中国語（繁体字）',
    'Traditional Chinese',
    '繁体中文',
    'Chino tradicional',
    german: 'Traditionelles Chinesisch',
    french: 'Chinois traditionnel',
    italian: 'Cinese tradizionale',
    korean: '중국어 번체',
    traditionalChinese: '繁體中文',
    portuguese: 'Chinês tradicional',
  );
  String get spanish => _text(
    'スペイン語',
    'Spanish',
    '西班牙语',
    'Español',
    german: 'Spanisch',
    french: 'Espagnol',
    italian: 'Spagnolo',
    korean: '스페인어',
    traditionalChinese: '西班牙文',
    portuguese: 'Espanhol',
  );
  String get german => _text(
    'ドイツ語',
    'German',
    '德语',
    'Alemán',
    german: 'Deutsch',
    french: 'Allemand',
    italian: 'Tedesco',
    korean: '독일어',
    traditionalChinese: '德文',
    portuguese: 'Alemão',
  );
  String get french => _text(
    'フランス語',
    'French',
    '法语',
    'Francés',
    german: 'Französisch',
    french: 'Français',
    italian: 'Francese',
    korean: '프랑스어',
    traditionalChinese: '法文',
    portuguese: 'Francês',
  );
  String get italian => _text(
    'イタリア語',
    'Italian',
    '意大利语',
    'Italiano',
    german: 'Italienisch',
    french: 'Italien',
    italian: 'Italiano',
    korean: '이탈리아어',
    traditionalChinese: '義大利文',
    portuguese: 'Italiano',
  );
  String get korean => _text(
    '韓国語',
    'Korean',
    '韩语',
    'Coreano',
    german: 'Koreanisch',
    french: 'Coréen',
    italian: 'Coreano',
    korean: '한국어',
    traditionalChinese: '韓文',
    portuguese: 'Coreano',
  );
  String get portuguese => _text(
    'ポルトガル語',
    'Portuguese',
    '葡萄牙语',
    'Portugués',
    german: 'Portugiesisch',
    french: 'Portugais',
    italian: 'Portoghese',
    korean: '포르투갈어',
    traditionalChinese: '葡萄牙文',
    portuguese: 'Português',
  );
  String get monitorSettings => _text(
    '監視設定',
    'Monitor Settings',
    '监测设置',
    'Ajustes de monitoreo',
    german: 'Überwachung',
    french: 'Réglages de surveillance',
    italian: 'Impostazioni monitoraggio',
    korean: '모니터링 설정',
    traditionalChinese: '監測設定',
    portuguese: 'Ajustes de monitoramento',
  );
  String get target => _text(
    'ターゲット',
    'Target',
    '目标',
    'Objetivo',
    german: 'Ziel',
    french: 'Cible',
    italian: 'Target',
    korean: '대상',
    traditionalChinese: '目標',
    portuguese: 'Alvo',
  );
  String get sound => _text(
    '音量',
    'Volume',
    '音量',
    'Volumen',
    german: 'Lautstärke',
    french: 'Volume',
    italian: 'Volume',
    korean: '음량',
    traditionalChinese: '音量',
    portuguese: 'Volume',
  );
  String get soundNotification => _text(
    '音',
    'Sound',
    '声音',
    'Sonido',
    german: 'Ton',
    french: 'Son',
    italian: 'Suono',
    korean: '소리',
    traditionalChinese: '聲音',
    portuguese: 'Som',
  );
  String get vibration => _text(
    '振動',
    'Vibration',
    '振动',
    'Vibración',
    german: 'Vibration',
    french: 'Vibration',
    italian: 'Vibrazione',
    korean: '진동',
    traditionalChinese: '震動',
    portuguese: 'Vibração',
  );
  String get condition => _text(
    '通知条件',
    'Condition',
    '通知条件',
    'Condición',
    german: 'Bedingung',
    french: 'Condition',
    italian: 'Condizione',
    korean: '알림 조건',
    traditionalChinese: '通知條件',
    portuguese: 'Condição',
  );
  String get above => _text(
    '以上',
    'Above',
    '以上',
    'Mayor',
    german: 'Über',
    french: 'Au-dessus',
    italian: 'Sopra',
    korean: '이상',
    traditionalChinese: '高於',
    portuguese: 'Acima',
  );
  String get below => _text(
    '以下',
    'Below',
    '以下',
    'Menor',
    german: 'Unter',
    french: 'En dessous',
    italian: 'Sotto',
    korean: '이하',
    traditionalChinese: '低於',
    portuguese: 'Abaixo',
  );
  String get threshold => _text(
    '閾値',
    'Threshold',
    '阈值',
    'Umbral',
    german: 'Schwelle',
    french: 'Seuil',
    italian: 'Soglia',
    korean: '임계값',
    traditionalChinese: '閾值',
    portuguese: 'Limite',
  );
  String get start => _text(
    'スタート',
    'Start',
    '开始',
    'Iniciar',
    german: 'Start',
    french: 'Démarrer',
    italian: 'Avvia',
    korean: '시작',
    traditionalChinese: '開始',
    portuguese: 'Iniciar',
  );
  String get countdown => _text(
    '開始まで',
    'Starting In',
    '距离开始',
    'Comienza en',
    german: 'Start in',
    french: 'Début dans',
    italian: 'Inizia tra',
    korean: '시작까지',
    traditionalChinese: '距離開始',
    portuguese: 'Inicia em',
  );
  String get countdownTime => _text(
    'カウントダウン',
    'Countdown',
    '倒计时',
    'Cuenta regresiva',
    german: 'Countdown',
    french: 'Compte à rebours',
    italian: 'Conto alla rovescia',
    korean: '카운트다운',
    traditionalChinese: '倒數計時',
    portuguese: 'Contagem regressiva',
  );
  String get monitoring => _text(
    'モニタリング中',
    'Monitoring',
    '监测中',
    'Monitoreando',
    german: 'Überwachung',
    french: 'Surveillance',
    italian: 'Monitoraggio',
    korean: '모니터링 중',
    traditionalChinese: '監測中',
    portuguese: 'Monitorando',
  );
  String get realtimeTrend => _text(
    'リアルタイム推移',
    'Realtime Trend',
    '实时趋势',
    'Tendencia en vivo',
    german: 'Live-Verlauf',
    french: 'Tendance en direct',
    italian: 'Andamento live',
    korean: '실시간 추이',
    traditionalChinese: '即時趨勢',
    portuguese: 'Tendência em tempo real',
  );
  String get currentValue => _text(
    '現在値',
    'Current',
    '当前值',
    'Actual',
    german: 'Aktuell',
    french: 'Actuel',
    italian: 'Attuale',
    korean: '현재값',
    traditionalChinese: '目前值',
    portuguese: 'Atual',
  );
  String get detectedValue => _text(
    '検知値',
    'Detected',
    '检测值',
    'Detectado',
    german: 'Erkannt',
    french: 'Détecté',
    italian: 'Rilevato',
    korean: '감지값',
    traditionalChinese: '偵測值',
    portuguese: 'Detectado',
  );
  String get alerting => _text(
    '通知中',
    'Alerting',
    '通知中',
    'Alertando',
    german: 'Alarm',
    french: 'Alerte',
    italian: 'Avviso',
    korean: '알림 중',
    traditionalChinese: '通知中',
    portuguese: 'Alertando',
  );
  String get back => _text(
    '戻る',
    'Back',
    '返回',
    'Volver',
    german: 'Zurück',
    french: 'Retour',
    italian: 'Indietro',
    korean: '뒤로',
    traditionalChinese: '返回',
    portuguese: 'Voltar',
  );
  String get backToSettings => _text(
    '設定に戻る',
    'Back to Settings',
    '返回设置',
    'Volver a ajustes',
    german: 'Zurück zu Einstellungen',
    french: 'Retour aux réglages',
    italian: 'Torna alle impostazioni',
    korean: '설정으로 돌아가기',
    traditionalChinese: '返回設定',
    portuguese: 'Voltar aos ajustes',
  );
  String get advancedSettings => _text(
    '詳細設定',
    'Advanced Settings',
    '高级设置',
    'Ajustes avanzados',
    german: 'Erweiterte Einstellungen',
    french: 'Réglages avancés',
    italian: 'Impostazioni avanzate',
    korean: '상세 설정',
    traditionalChinese: '進階設定',
    portuguese: 'Ajustes avançados',
  );
  String get alarmSound => _text(
    'アラーム音',
    'Alarm Sound',
    '警报声音',
    'Sonido de alarma',
    german: 'Alarmton',
    french: 'Son d’alarme',
    italian: 'Suono allarme',
    korean: '알람음',
    traditionalChinese: '警報音',
    portuguese: 'Som do alarme',
  );
  String get vibrationPattern => _text(
    '振動パターン',
    'Vibration Pattern',
    '振动模式',
    'Patrón de vibración',
    german: 'Vibrationsmuster',
    french: 'Motif de vibration',
    italian: 'Schema vibrazione',
    korean: '진동 패턴',
    traditionalChinese: '震動模式',
    portuguese: 'Padrão de vibração',
  );
  String get previewSound => _text(
    '音を確認',
    'Preview Sound',
    '预览声音',
    'Probar sonido',
    german: 'Ton testen',
    french: 'Tester le son',
    italian: 'Prova suono',
    korean: '소리 미리듣기',
    traditionalChinese: '預覽聲音',
    portuguese: 'Testar som',
  );
  String get movingAverage => _text(
    '移動平均',
    'Moving Average',
    '移动平均',
    'Media móvil',
    german: 'Gleitender Durchschnitt',
    french: 'Moyenne mobile',
    italian: 'Media mobile',
    korean: '이동 평균',
    traditionalChinese: '移動平均',
    portuguese: 'Média móvel',
  );
  String get dangerAlert => _text(
    '危険域通知',
    'Danger Zone Alert',
    '危险区通知',
    'Alerta de zona de riesgo',
    german: 'Gefahrenzonen-Alarm',
    french: 'Alerte zone à risque',
    italian: 'Avviso zona rischio',
    korean: '위험 영역 알림',
    traditionalChinese: '危險區通知',
    portuguese: 'Alerta de zona de risco',
  );
  String get dangerAlertMethod => _text(
    '通知方法',
    'Alert Method',
    '通知方式',
    'Método',
    german: 'Alarmmethode',
    french: 'Méthode',
    italian: 'Metodo',
    korean: '알림 방법',
    traditionalChinese: '通知方法',
    portuguese: 'Método',
  );
  String get dangerAlertAcceleration => _text(
    '危険域通知加速',
    'Danger Alert Acceleration',
    '危险区通知加速',
    'Aceleración de alerta',
    german: 'Gefahrenalarm-Beschleunigung',
    french: 'Accélération d’alerte',
    italian: 'Accelerazione avviso',
    korean: '위험 알림 가속',
    traditionalChinese: '危險區通知加速',
    portuguese: 'Aceleração de alerta',
  );
  String get adPlaceholder => _text(
    '広告',
    'Ad',
    '广告',
    'Anuncio',
    german: 'Anzeige',
    french: 'Pub',
    italian: 'Annuncio',
    korean: '광고',
    traditionalChinese: '廣告',
    portuguese: 'Anúncio',
  );
  String get off => 'Off';
  String get soundLoudBeep => _text(
    '連続ビープ',
    'Loud Beep',
    '连续哔声',
    'Pitido fuerte',
    german: 'Lauter Piepton',
    french: 'Bip fort',
    italian: 'Bip forte',
    korean: '연속 비프',
    traditionalChinese: '連續嗶聲',
    portuguese: 'Bipe alto',
  );
  String get soundAlert => _text(
    'アラート',
    'Alert',
    '警报',
    'Alerta',
    german: 'Alarm',
    french: 'Alerte',
    italian: 'Allarme',
    korean: '알림',
    traditionalChinese: '警報',
    portuguese: 'Alerta',
  );
  String get soundClick => _text(
    'クリック',
    'Click',
    '点击',
    'Clic',
    german: 'Klick',
    french: 'Clic',
    italian: 'Clic',
    korean: '클릭',
    traditionalChinese: '點擊',
    portuguese: 'Clique',
  );
  String get vibrationUrgent => _text(
    '強い連続',
    'Urgent',
    '强连续',
    'Urgente',
    german: 'Dringend',
    french: 'Urgent',
    italian: 'Urgente',
    korean: '강한 연속',
    traditionalChinese: '強連續',
    portuguese: 'Urgente',
  );
  String get vibrationPulse => _text(
    '短いパルス',
    'Pulse',
    '短脉冲',
    'Pulso',
    german: 'Impuls',
    french: 'Impulsion',
    italian: 'Impulso',
    korean: '짧은 펄스',
    traditionalChinese: '短脈衝',
    portuguese: 'Pulso',
  );
  String get vibrationLong => _text(
    '長め',
    'Long',
    '较长',
    'Larga',
    german: 'Lang',
    french: 'Longue',
    italian: 'Lunga',
    korean: '길게',
    traditionalChinese: '較長',
    portuguese: 'Longa',
  );
  String get both => _text(
    '音＆振動',
    'Sound & Vibration',
    '声音＆振动',
    'Sonido y vibración',
    german: 'Ton & Vibration',
    french: 'Son et vibration',
    italian: 'Suono e vibrazione',
    korean: '소리 및 진동',
    traditionalChinese: '聲音與震動',
    portuguese: 'Som e vibração',
  );
  String get microphonePermissionTitle => _text(
    'マイク利用の許可',
    'Microphone Access',
    '麦克风权限',
    'Acceso al micrófono',
    german: 'Mikrofonzugriff',
    french: 'Accès au micro',
    italian: 'Accesso al microfono',
    korean: '마이크 접근',
    traditionalChinese: '麥克風權限',
    portuguese: 'Acesso ao microfone',
  );
  String get microphonePermissionBody => _text(
    '音量を監視するにはマイクの使用許可が必要です。音声は録音・保存せず、端末内で音量レベルの計算にだけ使います。次の確認で許可してください。',
    'Microphone access is required to monitor volume. Audio is not recorded or saved; it is used on device only to calculate volume level. Please allow it on the next prompt.',
    '监测音量需要麦克风权限。不会录音或保存音频，仅在设备上用于计算音量级别。请在接下来的提示中允许。',
    'Se necesita acceso al micrófono para monitorear el volumen. El audio no se graba ni se guarda; solo se usa en el dispositivo para calcular el nivel de volumen. Permítelo en el siguiente aviso.',
    german:
        'Zum Überwachen der Lautstärke ist Mikrofonzugriff erforderlich. Audio wird nicht aufgenommen oder gespeichert, sondern nur auf dem Gerät berechnet.',
    french:
        'L’accès au micro est nécessaire pour surveiller le volume. L’audio n’est ni enregistré ni stocké, il sert seulement au calcul sur l’appareil.',
    italian:
        'Per monitorare il volume serve l’accesso al microfono. L’audio non viene registrato o salvato, ma usato solo sul dispositivo.',
    korean: '음량을 모니터링하려면 마이크 접근이 필요합니다. 오디오는 녹음 또는 저장되지 않고 기기 내 음량 계산에만 사용됩니다.',
    traditionalChinese: '監測音量需要麥克風權限。音訊不會錄製或儲存，僅在裝置上用於計算音量級別。',
    portuguese:
        'O acesso ao microfone é necessário para monitorar o volume. O áudio não é gravado nem salvo; é usado apenas no dispositivo.',
  );
  String get microphonePermissionSettingsBody => _text(
    'マイクの使用が拒否されています。音量を監視するには端末の設定でマイクを許可してください。音声は録音・保存・外部送信せず、音量レベルの判定にだけ使います。',
    'Microphone access is denied. Allow it in device settings to monitor volume. Audio is not recorded, saved, or sent outside the app; it is used only to judge volume level.',
    '麦克风权限已被拒绝。请在设备设置中允许麦克风以监测音量。音频不会录制、保存或发送到外部，仅用于判断音量级别。',
    'El acceso al micrófono está denegado. Actívalo en los ajustes del dispositivo para monitorear el volumen. El audio no se graba, guarda ni se envía fuera de la app; solo se usa para medir el nivel de volumen.',
    german:
        'Mikrofonzugriff wurde verweigert. Erlaube das Mikrofon in den Geräteeinstellungen. Audio wird nicht gespeichert oder gesendet.',
    french:
        'L’accès au micro est refusé. Autorisez-le dans les réglages de l’appareil. L’audio n’est pas enregistré ni envoyé hors de l’app.',
    italian:
        'L’accesso al microfono è negato. Consentilo nelle impostazioni del dispositivo. L’audio non viene salvato o inviato fuori dall’app.',
    korean:
        '마이크 접근이 거부되었습니다. 음량을 모니터링하려면 기기 설정에서 마이크를 허용하세요. 오디오는 저장되거나 외부로 전송되지 않습니다.',
    traditionalChinese: '麥克風權限已被拒絕。若要監測音量，請在裝置設定中允許麥克風。音訊不會儲存或傳送到外部。',
    portuguese:
        'O acesso ao microfone foi negado. Permita o microfone nos ajustes do dispositivo. O áudio não é salvo nem enviado para fora do app.',
  );
  String get allow => _text(
    '許可する',
    'Allow',
    '允许',
    'Permitir',
    german: 'Erlauben',
    french: 'Autoriser',
    italian: 'Consenti',
    korean: '허용',
    traditionalChinese: '允許',
    portuguese: 'Permitir',
  );
  String get later => _text(
    'あとで',
    'Later',
    '稍后',
    'Más tarde',
    german: 'Später',
    french: 'Plus tard',
    italian: 'Più tardi',
    korean: '나중에',
    traditionalChinese: '稍後',
    portuguese: 'Mais tarde',
  );
  String get openSettings => _text(
    '設定を開く',
    'Open Settings',
    '打开设置',
    'Abrir ajustes',
    german: 'Einstellungen öffnen',
    french: 'Ouvrir les réglages',
    italian: 'Apri impostazioni',
    korean: '설정 열기',
    traditionalChinese: '開啟設定',
    portuguese: 'Abrir ajustes',
  );
  String get zeroVolumeTitle => _text(
    '音量がゼロです',
    'Volume Is Zero',
    '音量为零',
    'El volumen está en cero',
    german: 'Lautstärke ist null',
    french: 'Volume à zéro',
    italian: 'Volume a zero',
    korean: '음량이 0입니다',
    traditionalChinese: '音量為零',
    portuguese: 'Volume está zero',
  );
  String get zeroVolumeBody => _text(
    'アラーム音を鳴らす設定ですが、スマホの音量がゼロです。このまま開始しますか？',
    'Alarm sound is enabled, but the phone volume is zero. Start anyway?',
    '已启用警报声音，但手机音量为零。仍要开始吗？',
    'El sonido de alarma está activado, pero el volumen del teléfono está en cero. ¿Iniciar de todos modos?',
    german:
        'Alarmton ist aktiviert, aber die Lautstärke des Smartphones ist null. Trotzdem starten?',
    french:
        'Le son d’alarme est activé, mais le volume du téléphone est à zéro. Démarrer quand même ?',
    italian:
        'Il suono di allarme è attivo, ma il volume del telefono è a zero. Avviare comunque?',
    korean: '알람음이 켜져 있지만 휴대폰 음량이 0입니다. 그래도 시작할까요?',
    traditionalChinese: '已啟用警報音，但手機音量為零。仍要開始嗎？',
    portuguese:
        'O som do alarme está ativado, mas o volume do telefone está zero. Iniciar mesmo assim?',
  );

  String countdownLabel(int seconds) {
    if (seconds == 0) {
      return _text(
        '0秒 (Off)',
        '0 sec (Off)',
        '0秒 (Off)',
        '0 s (Off)',
        german: '0 Sek. (Off)',
        french: '0 s (Off)',
        italian: '0 s (Off)',
        korean: '0초 (Off)',
        traditionalChinese: '0秒 (Off)',
        portuguese: '0 s (Off)',
      );
    }
    return _text(
      '$seconds秒',
      '$seconds sec',
      '$seconds秒',
      '$seconds s',
      german: '$seconds Sek.',
      french: '$seconds s',
      italian: '$seconds s',
      korean: '$seconds초',
      traditionalChinese: '$seconds秒',
      portuguese: '$seconds s',
    );
  }

  String movingAverageLabel(int strength) {
    if (strength == 0) {
      return _text('Off', 'Off', 'Off', 'Off');
    }
    return _text(
      '強度 $strength',
      'Strength $strength',
      '强度 $strength',
      'Intensidad $strength',
      german: 'Stärke $strength',
      french: 'Intensité $strength',
      italian: 'Intensità $strength',
      korean: '강도 $strength',
      traditionalChinese: '強度 $strength',
      portuguese: 'Intensidade $strength',
    );
  }

  String presetSlot(int index) => _text(
    'スロット ${index + 1}',
    'Slot ${index + 1}',
    '槽位 ${index + 1}',
    'Ranura ${index + 1}',
    german: 'Slot ${index + 1}',
    french: 'Emplacement ${index + 1}',
    italian: 'Slot ${index + 1}',
    korean: '슬롯 ${index + 1}',
    traditionalChinese: '槽位 ${index + 1}',
    portuguese: 'Slot ${index + 1}',
  );

  String alarmSoundLabel(AlarmSoundOption option) {
    return switch (option) {
      AlarmSoundOption.loudBeep => soundLoudBeep,
      AlarmSoundOption.alert => soundAlert,
      AlarmSoundOption.click => soundClick,
      AlarmSoundOption.off => off,
    };
  }

  String alarmVibrationLabel(AlarmVibrationOption option) {
    return switch (option) {
      AlarmVibrationOption.urgent => vibrationUrgent,
      AlarmVibrationOption.pulse => vibrationPulse,
      AlarmVibrationOption.long => vibrationLong,
      AlarmVibrationOption.off => off,
    };
  }

  String dangerAlertModeLabel(DangerAlertMode mode) {
    return switch (mode) {
      DangerAlertMode.sound => soundNotification,
      DangerAlertMode.vibration => vibration,
      DangerAlertMode.both => both,
    };
  }

  String currentTarget(String targetLabel) => _text(
    '現在の$targetLabel',
    'Current $targetLabel',
    '当前$targetLabel',
    '$targetLabel actual',
    german: 'Aktuelle $targetLabel',
    french: '$targetLabel actuel',
    italian: '$targetLabel attuale',
    korean: '현재 $targetLabel',
    traditionalChinese: '目前$targetLabel',
    portuguese: '$targetLabel atual',
  );

  String alertRemaining(double remaining, String unit) => isJapanese
      ? '通知まであと ${remaining.toStringAsFixed(1)} $unit'
      : isChinese
      ? '距离通知还有 ${remaining.toStringAsFixed(1)} $unit'
      : isTraditionalChinese
      ? '距離通知還有 ${remaining.toStringAsFixed(1)} $unit'
      : isSpanish
      ? 'Faltan ${remaining.toStringAsFixed(1)} $unit para la alerta'
      : isGerman
      ? 'Noch ${remaining.toStringAsFixed(1)} $unit bis zum Alarm'
      : isFrench
      ? 'Encore ${remaining.toStringAsFixed(1)} $unit avant l’alerte'
      : isItalian
      ? 'Mancano ${remaining.toStringAsFixed(1)} $unit all’avviso'
      : isKorean
      ? '알림까지 ${remaining.toStringAsFixed(1)} $unit 남음'
      : isPortuguese
      ? 'Faltam ${remaining.toStringAsFixed(1)} $unit para o alerta'
      : '${remaining.toStringAsFixed(1)} $unit until alert';

  String conditionDescription(
    double threshold,
    String unit,
    String ruleLabel,
  ) => isJapanese
      ? '$threshold $unit $ruleLabel で通知します'
      : isChinese
      ? '当 $ruleLabel ${threshold.toStringAsFixed(1)} $unit 时通知'
      : isTraditionalChinese
      ? '當 $ruleLabel ${threshold.toStringAsFixed(1)} $unit 時通知'
      : isSpanish
      ? 'Alertar cuando sea $ruleLabel ${threshold.toStringAsFixed(1)} $unit'
      : isGerman
      ? 'Alarm bei $ruleLabel ${threshold.toStringAsFixed(1)} $unit'
      : isFrench
      ? 'Alerte si $ruleLabel ${threshold.toStringAsFixed(1)} $unit'
      : isItalian
      ? 'Avvisa quando $ruleLabel ${threshold.toStringAsFixed(1)} $unit'
      : isKorean
      ? '${threshold.toStringAsFixed(1)} $unit $ruleLabel 때 알림'
      : isPortuguese
      ? 'Alertar quando for $ruleLabel ${threshold.toStringAsFixed(1)} $unit'
      : 'Alert when $ruleLabel ${threshold.toStringAsFixed(1)} $unit';

  String alertMessage(String targetLabel, String ruleLabel) => isJapanese
      ? '$targetLabel が閾値$ruleLabelになりました'
      : isChinese
      ? '$targetLabel 已达到阈值$ruleLabel'
      : isTraditionalChinese
      ? '$targetLabel 已達到閾值$ruleLabel'
      : isSpanish
      ? '$targetLabel alcanzó el umbral $ruleLabel'
      : isGerman
      ? '$targetLabel hat die Schwelle $ruleLabel erreicht'
      : isFrench
      ? '$targetLabel a atteint le seuil $ruleLabel'
      : isItalian
      ? '$targetLabel ha raggiunto la soglia $ruleLabel'
      : isKorean
      ? '$targetLabel이 임계값 $ruleLabel에 도달했습니다'
      : isPortuguese
      ? '$targetLabel atingiu o limite $ruleLabel'
      : '$targetLabel reached the $ruleLabel threshold';

  String get microphoneDenied => isJapanese
      ? 'マイクの使用が許可されていません。音声は録音・保存せず音量判定にだけ使用します。端末の設定から許可してください。'
      : isChinese
      ? '未允许使用麦克风。音频不会录制或保存，仅用于音量判断。请在设备设置中允许。'
      : isTraditionalChinese
      ? '未允許使用麥克風。音訊不會錄製或儲存，僅用於音量判斷。請在裝置設定中允許。'
      : isSpanish
      ? 'El acceso al micrófono no está permitido. El audio no se graba ni se guarda; solo se usa para medir volumen. Actívalo en los ajustes del dispositivo.'
      : isGerman
      ? 'Mikrofonzugriff ist nicht erlaubt. Audio wird nicht aufgenommen oder gespeichert und nur zur Lautstärkebewertung genutzt. Bitte in den Geräteeinstellungen erlauben.'
      : isFrench
      ? 'L’accès au micro n’est pas autorisé. L’audio n’est ni enregistré ni stocké et sert seulement à mesurer le volume. Autorisez-le dans les réglages.'
      : isItalian
      ? 'L’accesso al microfono non è consentito. L’audio non viene registrato o salvato; serve solo a valutare il volume. Consentilo nelle impostazioni.'
      : isKorean
      ? '마이크 사용이 허용되지 않았습니다. 오디오는 녹음 또는 저장되지 않고 음량 판단에만 사용됩니다. 기기 설정에서 허용하세요.'
      : isPortuguese
      ? 'O acesso ao microfone não está permitido. O áudio não é gravado nem salvo; é usado apenas para medir o volume. Permita nos ajustes.'
      : 'Microphone access is not allowed. Audio is not recorded or saved; it is used only to judge volume level. Please allow it in device settings.';

  String soundError(Object error) => isJapanese
      ? '音の取得に失敗しました: $error'
      : isChinese
      ? '无法读取声音: $error'
      : isTraditionalChinese
      ? '無法讀取聲音: $error'
      : isSpanish
      ? 'No se pudo leer el sonido: $error'
      : isGerman
      ? 'Ton konnte nicht gelesen werden: $error'
      : isFrench
      ? 'Impossible de lire le son : $error'
      : isItalian
      ? 'Impossibile leggere il suono: $error'
      : isKorean
      ? '소리를 읽을 수 없습니다: $error'
      : isPortuguese
      ? 'Não foi possível ler o som: $error'
      : 'Could not read sound: $error';

  String get vibrationError => isJapanese
      ? '加速度センサーから振動を取得できませんでした。'
      : isChinese
      ? '无法从加速度传感器读取振动。'
      : isTraditionalChinese
      ? '無法從加速度感測器讀取震動。'
      : isSpanish
      ? 'No se pudo leer la vibración desde el acelerómetro.'
      : isGerman
      ? 'Vibration konnte nicht vom Beschleunigungssensor gelesen werden.'
      : isFrench
      ? 'Impossible de lire la vibration depuis l’accéléromètre.'
      : isItalian
      ? 'Impossibile leggere la vibrazione dall’accelerometro.'
      : isKorean
      ? '가속도 센서에서 진동을 읽을 수 없습니다.'
      : isPortuguese
      ? 'Não foi possível ler a vibração pelo acelerômetro.'
      : 'Could not read vibration from the accelerometer.';
}

class SettingsPreset {
  const SettingsPreset({
    required this.name,
    required this.target,
    required this.rule,
    required this.threshold,
    required this.alarmSound,
    required this.alarmVibration,
    required this.countdownSeconds,
    required this.movingAverageStrength,
    required this.dangerAlertStrength,
    required this.dangerAlertMode,
    required this.dangerAlertAcceleration,
  });

  final String name;
  final MonitorTarget target;
  final ThresholdRule rule;
  final double threshold;
  final AlarmSoundOption alarmSound;
  final AlarmVibrationOption alarmVibration;
  final int countdownSeconds;
  final int movingAverageStrength;
  final int dangerAlertStrength;
  final DangerAlertMode dangerAlertMode;
  final bool dangerAlertAcceleration;

  SettingsPreset copyWith({String? name}) {
    return SettingsPreset(
      name: name ?? this.name,
      target: target,
      rule: rule,
      threshold: threshold,
      alarmSound: alarmSound,
      alarmVibration: alarmVibration,
      countdownSeconds: countdownSeconds,
      movingAverageStrength: movingAverageStrength,
      dangerAlertStrength: dangerAlertStrength,
      dangerAlertMode: dangerAlertMode,
      dangerAlertAcceleration: dangerAlertAcceleration,
    );
  }

  Map<String, Object> toJson() {
    return {
      'name': name,
      'target': target.name,
      'rule': rule.name,
      'threshold': threshold,
      'alarmSound': alarmSound.name,
      'alarmVibration': alarmVibration.name,
      'countdownSeconds': countdownSeconds,
      'movingAverageStrength': movingAverageStrength,
      'dangerAlertStrength': dangerAlertStrength,
      'dangerAlertMode': dangerAlertMode.name,
      'dangerAlertAcceleration': dangerAlertAcceleration,
    };
  }

  Map<String, Object> toQrJson() {
    return {'type': 'paralarm-settings', 'version': 1, 'settings': toJson()};
  }

  static SettingsPreset? fromQrJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    if (raw['type'] == 'paralarm-settings' && raw['settings'] is Map) {
      return SettingsPreset.fromJson(raw['settings']);
    }
    return SettingsPreset.fromJson(raw);
  }

  static SettingsPreset? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }

    T enumValue<T extends Enum>(List<T> values, Object? name, T fallback) {
      return values.where((value) => value.name == name).firstOrNull ??
          fallback;
    }

    return SettingsPreset(
      name: raw['name'] is String ? raw['name'] as String : '',
      target: enumValue(
        MonitorTarget.values,
        raw['target'],
        MonitorTarget.sound,
      ),
      rule: enumValue(ThresholdRule.values, raw['rule'], ThresholdRule.above),
      threshold: raw['threshold'] is num
          ? (raw['threshold'] as num).toDouble()
          : 70,
      alarmSound: enumValue(
        AlarmSoundOption.values,
        raw['alarmSound'],
        AlarmSoundOption.loudBeep,
      ),
      alarmVibration: enumValue(
        AlarmVibrationOption.values,
        raw['alarmVibration'],
        AlarmVibrationOption.urgent,
      ),
      countdownSeconds: raw['countdownSeconds'] is num
          ? (raw['countdownSeconds'] as num).round()
          : 3,
      movingAverageStrength: raw['movingAverageStrength'] is num
          ? (raw['movingAverageStrength'] as num).round().clamp(0, 10)
          : 0,
      dangerAlertStrength: raw['dangerAlertStrength'] is num
          ? (raw['dangerAlertStrength'] as num).round().clamp(
              0,
              _maxDangerAlertTicks,
            )
          : 0,
      dangerAlertMode: enumValue(
        DangerAlertMode.values,
        raw['dangerAlertMode'],
        DangerAlertMode.both,
      ),
      dangerAlertAcceleration: raw['dangerAlertAcceleration'] == true,
    );
  }
}

class ParalarmApp extends StatelessWidget {
  const ParalarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Par-alarm',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: _neonLime,
          onPrimary: Color(0xFF111500),
          secondary: _electricYellow,
          onSecondary: Color(0xFF141700),
          surface: _charcoal,
          onSurface: Color(0xFFF4F7EE),
          surfaceContainerHighest: _panelGray,
          outline: _panelBorder,
          outlineVariant: Color(0xFF263022),
          error: Color(0xFFFFF36D),
          onError: Color(0xFF161400),
          errorContainer: Color(0xFF352F05),
          onErrorContainer: Color(0xFFFFF7B0),
        ),
        scaffoldBackgroundColor: _charcoal,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: _charcoal,
          foregroundColor: _neonLime,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFF4F7EE),
          displayColor: const Color(0xFFF4F7EE),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _neonLime,
            foregroundColor: const Color(0xFF111500),
            shadowColor: _neonLime.withValues(alpha: 0.75),
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _neonLime,
            side: const BorderSide(color: _neonLime),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? _neonLime
                  : _panelGray;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? const Color(0xFF111500)
                  : const Color(0xFFE8EEDF);
            }),
            side: WidgetStateProperty.resolveWith((states) {
              return BorderSide(
                color: states.contains(WidgetState.selected)
                    ? _neonLime
                    : _panelBorder,
              );
            }),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: _neonLime,
          inactiveTrackColor: _panelBorder,
          thumbColor: _electricYellow,
          overlayColor: _neonLime.withValues(alpha: 0.18),
          valueIndicatorColor: _neonLime,
          valueIndicatorTextStyle: const TextStyle(color: Color(0xFF111500)),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: _neonLime,
          linearTrackColor: _panelBorder,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _panelGray,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: const ParalarmHome(),
    );
  }
}

class ParalarmHome extends StatefulWidget {
  const ParalarmHome({super.key});

  @override
  State<ParalarmHome> createState() => _ParalarmHomeState();
}

class _ParalarmHomeState extends State<ParalarmHome>
    with WidgetsBindingObserver {
  final NoiseMeter _noiseMeter = NoiseMeter();

  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription<UserAccelerometerEvent>? _vibrationSubscription;
  Timer? _alarmTimer;
  Timer? _countdownTimer;

  AppMode _mode = AppMode.settings;
  AppLanguage _language = AppLanguage.japanese;
  MonitorTarget _target = MonitorTarget.sound;
  ThresholdRule _rule = ThresholdRule.above;
  AlarmSoundOption _alarmSound = AlarmSoundOption.loudBeep;
  AlarmVibrationOption _alarmVibration = AlarmVibrationOption.urgent;
  DangerAlertMode _dangerAlertMode = DangerAlertMode.both;
  bool _dangerAlertAcceleration = false;
  bool _isPremium = false;
  bool _hasSeenTutorial = false;
  int _countdownSeconds = 3;
  int _countdownRemaining = 0;
  int _movingAverageStrength = 0;
  int _dangerAlertStrength = 0;
  double _threshold = 70;
  double _currentValue = 0;
  final List<double> _history = [];
  final List<double> _movingAverageSamples = [];
  final List<SettingsPreset?> _settingsPresets = List<SettingsPreset?>.filled(
    _settingsPresetSlots,
    null,
  );
  SettingsError? _settingsError;
  Object? _settingsErrorDetail;
  bool _hasShownLaunchMicrophonePrompt = false;
  bool _screenshotFreezeEnabled = false;
  DateTime? _lastDangerAlertAt;

  AppStrings get _strings => AppStrings(_language);

  int get _availablePresetSlots => _premiumFeaturesEnabled && _isPremium
      ? _settingsPresetSlots
      : _freeSettingsPresetSlots;

  bool _isFreeAlarmSound(AlarmSoundOption option) {
    return option == AlarmSoundOption.loudBeep ||
        option == AlarmSoundOption.off;
  }

  String get _unit => _target == MonitorTarget.sound ? 'dB' : 'm/s²';

  String get _targetLabel =>
      _target == MonitorTarget.sound ? _strings.sound : _strings.vibration;

  String get _ruleLabel =>
      _rule == ThresholdRule.above ? _strings.above : _strings.below;

  double get _minThreshold => _target == MonitorTarget.sound ? 30 : 0.5;

  double get _maxThreshold => _target == MonitorTarget.sound ? 100 : 20;

  double get _defaultThreshold => _target == MonitorTarget.sound ? 70 : 6;

  int get _movingAverageWindowSize =>
      _movingAverageStrength == 0 ? 1 : _movingAverageStrength * 4 + 1;

  double get _dangerAlertWidth =>
      (_target == MonitorTarget.sound ? 2.5 : 0.5) * _dangerAlertStrength;

  bool get _isAlertStateEnabled =>
      _alarmSound != AlarmSoundOption.off ||
      _alarmVibration != AlarmVibrationOption.off;

  bool get _isTriggered {
    return _rule == ThresholdRule.above
        ? _currentValue >= _threshold
        : _currentValue <= _threshold;
  }

  bool get _isInDangerZone {
    if (_dangerAlertStrength == 0) {
      return false;
    }

    final width = _dangerAlertWidth;
    if (_isTriggered) {
      return !_isAlertStateEnabled;
    }

    return _rule == ThresholdRule.above
        ? _currentValue >= _threshold - width && _currentValue < _threshold
        : _currentValue <= _threshold + width && _currentValue > _threshold;
  }

  double get _dangerZoneProgress {
    if (_dangerAlertStrength == 0 || _dangerAlertWidth <= 0) {
      return 0;
    }
    if (_isTriggered) {
      return _isAlertStateEnabled ? 0 : 1;
    }

    final progress = _rule == ThresholdRule.above
        ? (_currentValue - (_threshold - _dangerAlertWidth)) / _dangerAlertWidth
        : ((_threshold + _dangerAlertWidth) - _currentValue) /
              _dangerAlertWidth;
    return progress.clamp(0.0, 1.0);
  }

  String? get _errorMessage {
    return switch (_settingsError) {
      SettingsError.microphoneDenied => _strings.microphoneDenied,
      SettingsError.soundReadFailed => _strings.soundError(
        _settingsErrorDetail ?? '',
      ),
      SettingsError.vibrationReadFailed => _strings.vibrationError,
      null => null,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeStartup();
  }

  Future<void> _initializeStartup() async {
    await _loadStartupState();
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_hasSeenTutorial) {
        await _showTutorial(markAsSeen: true);
      }
      if (mounted) {
        await _bootstrapSensorPreview();
      }
    });
  }

  Future<void> _loadStartupState() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool(_premiumStorageKey) ?? false;
    final hasSeenTutorial = prefs.getBool(_hasSeenTutorialStorageKey) ?? false;
    final rawPresets = prefs.getStringList(_settingsPresetStorageKey) ?? [];
    final lastStartedPreset = _decodeSettingsPreset(
      prefs.getString(_lastStartedSettingsStorageKey),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isPremium = _premiumFeaturesEnabled && isPremium;
      _hasSeenTutorial = hasSeenTutorial;

      for (var index = 0; index < _settingsPresetSlots; index++) {
        if (index >= rawPresets.length || rawPresets[index].isEmpty) {
          _settingsPresets[index] = null;
          continue;
        }

        _settingsPresets[index] = _decodeSettingsPreset(rawPresets[index]);
      }

      if (lastStartedPreset != null) {
        _applySettingsPresetValues(lastStartedPreset);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCountdown();
    _stopSensor();
    _stopAlarm();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _target != MonitorTarget.sound) {
      return;
    }

    _resumeSoundPreviewIfPermitted();
  }

  Future<void> _startCountdownOrMonitoring() async {
    final shouldContinue = await _confirmZeroVolumeIfNeeded();
    if (!shouldContinue) {
      return;
    }

    final isReady = await _ensureSensorRunning();
    if (!isReady) {
      return;
    }

    await _persistLastStartedSettings();

    if (_countdownSeconds == 0) {
      _startMonitoring();
      return;
    }

    _stopCountdown();
    setState(() {
      _mode = AppMode.countdown;
      _countdownRemaining = _countdownSeconds;
      _settingsError = null;
      _settingsErrorDetail = null;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isTriggered) {
        return;
      }

      if (_countdownRemaining <= 1) {
        timer.cancel();
        _countdownTimer = null;
        _startMonitoring();
        return;
      }

      setState(() {
        _countdownRemaining -= 1;
      });
    });
  }

  Future<bool> _confirmZeroVolumeIfNeeded() async {
    if (_alarmSound == AlarmSoundOption.off) {
      return true;
    }

    final volume = await _readAlarmVolume();
    if (volume == null || volume > 0.001) {
      return true;
    }
    if (!mounted) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_strings.zeroVolumeTitle),
        content: Text(_strings.zeroVolumeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_strings.ok),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<double?> _readAlarmVolume() async {
    try {
      final value = await _alarmSoundChannel.invokeMethod<num>('getVolume');
      return value?.toDouble();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  void _startMonitoring() {
    setState(() {
      _mode = AppMode.monitoring;
      _settingsError = null;
      _settingsErrorDetail = null;
      _lastDangerAlertAt = null;
    });
  }

  Future<void> _startSensorPreview() async {
    await _restartSensor();
  }

  Future<void> _bootstrapSensorPreview() async {
    if (_target == MonitorTarget.sound) {
      await _requestMicrophoneAccessOnLaunch();
      final status = await Permission.microphone.status;
      if (!mounted || !status.isGranted) {
        return;
      }
    }
    await _startSensorPreview();
  }

  Future<void> _resumeSoundPreviewIfPermitted() async {
    final status = await Permission.microphone.status;
    if (!mounted || !status.isGranted || _noiseSubscription != null) {
      return;
    }

    setState(() {
      _settingsError = null;
      _settingsErrorDetail = null;
    });
    await _startSensorPreview();
  }

  Future<void> _requestMicrophoneAccessOnLaunch() async {
    if (!mounted || _hasShownLaunchMicrophonePrompt) {
      return;
    }

    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return;
    }

    _hasShownLaunchMicrophonePrompt = true;

    if (status.isPermanentlyDenied || status.isRestricted) {
      if (mounted) {
        setState(() {
          _settingsError = SettingsError.microphoneDenied;
          _settingsErrorDetail = null;
        });
      }
      await _showMicrophoneSettingsDialog();
      return;
    }

    final shouldRequest = await _showMicrophonePermissionDialog();
    if (!mounted) {
      return;
    }
    if (!shouldRequest) {
      setState(() {
        _settingsError = SettingsError.microphoneDenied;
        _settingsErrorDetail = null;
      });
      return;
    }

    final requestedStatus = await Permission.microphone.request();
    if (!mounted) {
      return;
    }

    setState(() {
      _settingsError = requestedStatus.isGranted
          ? null
          : SettingsError.microphoneDenied;
      _settingsErrorDetail = null;
    });

    if (!requestedStatus.isGranted &&
        (requestedStatus.isPermanentlyDenied || requestedStatus.isRestricted)) {
      await _showMicrophoneSettingsDialog();
    }
  }

  Future<bool> _showMicrophonePermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_strings.microphonePermissionTitle),
        content: Text(_strings.microphonePermissionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_strings.later),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_strings.allow),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showMicrophoneSettingsDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_strings.microphonePermissionTitle),
        content: Text(_strings.microphonePermissionSettingsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_strings.later),
          ),
          FilledButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: Text(_strings.openSettings),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureSensorRunning() async {
    if (_noiseSubscription != null || _vibrationSubscription != null) {
      return true;
    }
    return _restartSensor();
  }

  Future<bool> _restartSensor() async {
    _stopSensor();
    _history.clear();
    _movingAverageSamples.clear();
    _screenshotFreezeEnabled = false;
    if (_target == MonitorTarget.sound) {
      return _startSoundSensor();
    } else {
      _startVibrationSensor();
      return true;
    }
  }

  Future<bool> _startSoundSensor() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted &&
        !status.isPermanentlyDenied &&
        !status.isRestricted) {
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _mode = AppMode.settings;
          _settingsError = SettingsError.microphoneDenied;
          _settingsErrorDetail = null;
        });
      }
      if (mounted && (status.isPermanentlyDenied || status.isRestricted)) {
        await _showMicrophoneSettingsDialog();
      }
      return false;
    }

    _noiseSubscription = _noiseMeter.noise.listen(
      (reading) => _handleSensorValue(reading.meanDecibel),
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _mode = AppMode.settings;
          _settingsError = SettingsError.soundReadFailed;
          _settingsErrorDetail = error;
        });
      },
    );
    return true;
  }

  void _startVibrationSensor() {
    _vibrationSubscription =
        userAccelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 120),
        ).listen(
          (event) {
            final strength = sqrt(
              event.x * event.x + event.y * event.y + event.z * event.z,
            );
            _handleSensorValue(strength);
          },
          onError: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _mode = AppMode.settings;
              _settingsError = SettingsError.vibrationReadFailed;
              _settingsErrorDetail = null;
            });
          },
        );
  }

  void _handleSensorValue(double value) {
    if (!mounted || !value.isFinite || _mode == AppMode.alerting) {
      return;
    }

    if (_screenshotFreezeEnabled) {
      _applyScreenshotFreezeValue();
      return;
    }

    setState(() {
      final filteredValue = _filteredSensorValue(value);
      _currentValue = filteredValue.clamp(0, _maxThreshold * 1.25);
      _history.add(_currentValue);
      if (_history.length > 80) {
        _history.removeAt(0);
      }
    });

    if (_mode == AppMode.monitoring && _isTriggered && _isAlertStateEnabled) {
      _enterAlertState();
      return;
    }

    if (_mode == AppMode.monitoring && _isInDangerZone) {
      _notifyDangerZoneIfNeeded();
    }
  }

  double _filteredSensorValue(double value) {
    if (_movingAverageStrength == 0) {
      _movingAverageSamples
        ..clear()
        ..add(value);
      return value;
    }

    _movingAverageSamples.add(value);
    while (_movingAverageSamples.length > _movingAverageWindowSize) {
      _movingAverageSamples.removeAt(0);
    }

    final total = _movingAverageSamples.fold<double>(
      0,
      (sum, sample) => sum + sample,
    );
    return total / _movingAverageSamples.length;
  }

  double get _screenshotFreezeValue {
    final margin = max(
      _target == MonitorTarget.sound ? 4.0 : 0.8,
      (_maxThreshold - _minThreshold) * 0.08,
    );
    final value = _rule == ThresholdRule.above
        ? _threshold - margin
        : _threshold + margin;
    return value.clamp(_minThreshold, _maxThreshold);
  }

  void _applyScreenshotFreezeValue() {
    final value = _screenshotFreezeValue;
    setState(() {
      _currentValue = value;
      _history
        ..clear()
        ..addAll(List<double>.filled(80, value));
      _movingAverageSamples
        ..clear()
        ..add(value);
      _settingsError = null;
      _settingsErrorDetail = null;
    });
  }

  void _toggleScreenshotFreeze() {
    setState(() {
      _screenshotFreezeEnabled = !_screenshotFreezeEnabled;
    });

    if (_screenshotFreezeEnabled) {
      _applyScreenshotFreezeValue();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_screenshotFreezeEnabled ? '撮影用固定値: ON' : '撮影用固定値: OFF'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _enterAlertState() {
    _stopCountdown();
    _stopSensor();
    setState(() {
      _mode = AppMode.alerting;
    });
    _playAlarm();
    _alarmTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _playAlarm(),
    );
  }

  void _notifyDangerZoneIfNeeded() {
    final now = DateTime.now();
    final interval = _dangerAlertAcceleration
        ? Duration(
            milliseconds: (2000 - 1200 * _dangerZoneProgress).round().clamp(
              800,
              2000,
            ),
          )
        : const Duration(seconds: 2);
    final lastAlertAt = _lastDangerAlertAt;
    if (lastAlertAt != null && now.difference(lastAlertAt) < interval) {
      return;
    }

    _lastDangerAlertAt = now;
    unawaited(_playDangerAlert());
  }

  Future<void> _playDangerAlert() async {
    if (_dangerAlertMode == DangerAlertMode.sound ||
        _dangerAlertMode == DangerAlertMode.both) {
      await _playNativeAlarmSound('danger', SystemSoundType.click);
    }

    if (_dangerAlertMode == DangerAlertMode.vibration ||
        _dangerAlertMode == DangerAlertMode.both) {
      HapticFeedback.selectionClick();
      unawaited(_playNativeVibration('pulse'));
    }
  }

  Future<void> _playAlarm() async {
    await _playAlarmSoundOption(_alarmSound);
    await _playAlarmVibrationOption(_alarmVibration);
  }

  Future<void> _previewAlarmSound() async {
    await _playAlarmSoundOption(_alarmSound);
  }

  Future<void> _playAlarmSoundOption(AlarmSoundOption option) async {
    switch (option) {
      case AlarmSoundOption.loudBeep:
        await _playNativeAlarmSound('loudBeep', SystemSoundType.alert);
      case AlarmSoundOption.alert:
        await _playNativeAlarmSound('alert', SystemSoundType.alert);
      case AlarmSoundOption.click:
        await _playNativeAlarmSound('click', SystemSoundType.click);
      case AlarmSoundOption.off:
        break;
    }
  }

  Future<void> _playAlarmVibrationOption(AlarmVibrationOption option) async {
    if (option == AlarmVibrationOption.off) {
      return;
    }
    switch (option) {
      case AlarmVibrationOption.urgent:
        await _playNativeVibration('urgent');
        unawaited(
          _tryVibrate(
            pattern: const [0, 500, 180, 500, 180, 700],
            intensities: const [0, 255, 0, 255, 0, 255],
          ),
        );
      case AlarmVibrationOption.pulse:
        await _playNativeVibration('pulse');
        unawaited(
          _tryVibrate(
            pattern: const [0, 140, 120, 140, 120, 140],
            intensities: const [0, 210, 0, 210, 0, 210],
          ),
        );
      case AlarmVibrationOption.long:
        await _playNativeVibration('long');
        unawaited(_tryVibrate(duration: 1400, amplitude: 230));
      case AlarmVibrationOption.off:
        break;
    }
  }

  Future<void> _tryVibrate({
    int? duration,
    int? amplitude,
    List<int>? pattern,
    List<int>? intensities,
  }) async {
    try {
      if (!await Vibration.hasVibrator()) {
        return;
      }
      if (pattern != null) {
        await Vibration.vibrate(pattern: pattern, intensities: intensities!);
      } else {
        await Vibration.vibrate(duration: duration!, amplitude: amplitude!);
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _playNativeAlarmSound(
    String sound,
    SystemSoundType fallback,
  ) async {
    try {
      await _alarmSoundChannel.invokeMethod<void>('play', {'sound': sound});
    } on PlatformException {
      await SystemSound.play(fallback);
    } on MissingPluginException {
      await SystemSound.play(fallback);
    }
  }

  Future<void> _playNativeVibration(String pattern) async {
    try {
      await _alarmSoundChannel.invokeMethod<void>('vibrate', {
        'pattern': pattern,
      });
    } on PlatformException {
      await HapticFeedback.vibrate();
    } on MissingPluginException {
      await HapticFeedback.vibrate();
    }
  }

  void _backToSettings() {
    final previousMode = _mode;
    _stopCountdown();
    _stopAlarm();
    setState(() {
      _mode = AppMode.settings;
      _settingsError = null;
      _settingsErrorDetail = null;
    });
    _startSensorPreview();
    if (previousMode == AppMode.monitoring ||
        previousMode == AppMode.alerting) {
      unawaited(_recordCompletedSessionAndMaybeRequestReview());
    }
  }

  void _stopSensor() {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _vibrationSubscription?.cancel();
    _vibrationSubscription = null;
  }

  void _stopAlarm() {
    _alarmTimer?.cancel();
    _alarmTimer = null;
    Vibration.cancel();
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _changeTarget(Set<MonitorTarget> selected) {
    final next = selected.first;
    setState(() {
      _target = next;
      _threshold = _defaultThreshold;
      _currentValue = 0;
      _history.clear();
      _movingAverageSamples.clear();
      _lastDangerAlertAt = null;
      _settingsError = null;
      _settingsErrorDetail = null;
    });
    _restartSensor();
  }

  SettingsPreset _currentSettingsPreset(String name) {
    return SettingsPreset(
      name: name,
      target: _target,
      rule: _rule,
      threshold: _threshold,
      alarmSound: _alarmSound,
      alarmVibration: _alarmVibration,
      countdownSeconds: _countdownSeconds,
      movingAverageStrength: _movingAverageStrength,
      dangerAlertStrength: _dangerAlertStrength,
      dangerAlertMode: _dangerAlertMode,
      dangerAlertAcceleration: _dangerAlertAcceleration,
    );
  }

  SettingsPreset? _decodeSettingsPreset(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return SettingsPreset.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> _persistSettingsPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = [
      for (final preset in _settingsPresets)
        preset == null ? '' : jsonEncode(preset.toJson()),
    ];
    await prefs.setStringList(_settingsPresetStorageKey, encoded);
  }

  Future<void> _persistLastStartedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastStartedSettingsStorageKey,
      jsonEncode(_currentSettingsPreset('last-started').toJson()),
    );
  }

  Future<void> _recordCompletedSessionAndMaybeRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_hasRequestedReviewStorageKey) ?? false) {
      return;
    }

    final completedSessions =
        (prefs.getInt(_completedMonitoringSessionsStorageKey) ?? 0) + 1;
    await prefs.setInt(
      _completedMonitoringSessionsStorageKey,
      completedSessions,
    );

    if (completedSessions < 3) {
      return;
    }

    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) {
        return;
      }

      await prefs.setBool(_hasRequestedReviewStorageKey, true);
      await review.requestReview();
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _showTutorial({required bool markAsSeen}) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TutorialDialog(strings: _strings),
    );

    if (!markAsSeen || !mounted) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenTutorialStorageKey, true);
    if (!mounted) {
      return;
    }
    setState(() {
      _hasSeenTutorial = true;
    });
  }

  Future<void> _saveSettingsPreset(int index) async {
    if (!_isPremium && index >= _freeSettingsPresetSlots) {
      _showPremiumDialog();
      return;
    }

    final name = _settingsPresets[index]?.name.trim().isNotEmpty == true
        ? _settingsPresets[index]!.name
        : _strings.presetSlot(index);
    setState(() {
      _settingsPresets[index] = _currentSettingsPreset(name);
    });
    await _persistSettingsPresets();
    _showSettingsSnackBar(_strings.saved);
  }

  Future<void> _loadSettingsPreset(int index) async {
    final preset = _settingsPresets[index];
    if (preset == null) {
      return;
    }

    await _applySettingsPreset(preset);
    _showSettingsSnackBar(_strings.loaded);
  }

  Future<void> _renameSettingsPreset(int index) async {
    if (!_isPremium && index >= _freeSettingsPresetSlots) {
      _showPremiumDialog();
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) {
      return;
    }

    final strings = _strings;
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenamePresetDialog(
        strings: strings,
        initialName:
            _settingsPresets[index]?.name ?? _strings.presetSlot(index),
      ),
    );

    final trimmedName = newName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return;
    }

    setState(() {
      _settingsPresets[index] =
          _settingsPresets[index]?.copyWith(name: trimmedName) ??
          _currentSettingsPreset(trimmedName);
    });
    await _persistSettingsPresets();
    _showSettingsSnackBar(_strings.renamed);
  }

  void _showSettingsSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _showPremiumDialog() async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_strings.premiumRequired),
        content: Text(_strings.premiumRequiredBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_strings.close),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _upgradeToPremium();
            },
            child: Text(_strings.upgradeToPremium),
          ),
        ],
      ),
    );
  }

  Future<void> _upgradeToPremium() async {
    final shouldUpgrade = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_strings.upgradeToPremium),
        content: Text(_strings.upgradeDemoBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_strings.ok),
          ),
        ],
      ),
    );
    if (shouldUpgrade != true || !mounted) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumStorageKey, true);
    if (!mounted) {
      return;
    }
    setState(() {
      _isPremium = true;
    });
    _showSettingsSnackBar(_strings.premiumUnlocked);
  }

  void _showPresetQr(SettingsPreset preset) {
    final data = jsonEncode(preset.toQrJson());
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(preset.name),
        content: SizedBox(
          width: 260,
          child: QrImageView(
            data: data,
            size: 260,
            backgroundColor: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_strings.close),
          ),
        ],
      ),
    );
  }

  Future<void> _scanPresetQr() async {
    if (!_isPremium) {
      _showPremiumDialog();
      return;
    }

    final strings = _strings;
    var status = await Permission.camera.status;
    if (!mounted) {
      return;
    }

    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (!mounted) {
      return;
    }
    if (!status.isGranted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.cameraPermissionTitle),
          content: Text(
            status.isPermanentlyDenied || status.isRestricted
                ? strings.cameraPermissionSettingsBody
                : strings.cameraPermissionBody,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.close),
            ),
            FilledButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: Text(strings.openSettings),
            ),
          ],
        ),
      );
      return;
    }

    final raw = await showDialog<String>(
      context: context,
      builder: (context) => _QrScanDialog(strings: _strings),
    );
    if (raw == null || !mounted) {
      return;
    }

    try {
      final preset = SettingsPreset.fromQrJson(jsonDecode(raw));
      if (preset == null) {
        _showSettingsSnackBar(_strings.qrInvalid);
        return;
      }

      await _applySettingsPreset(preset);
      _showSettingsSnackBar(_strings.loaded);
    } on FormatException {
      _showSettingsSnackBar(_strings.qrInvalid);
    }
  }

  Future<void> _applySettingsPreset(SettingsPreset preset) async {
    final shouldRestartSensor = preset.target != _target;
    setState(() {
      _applySettingsPresetValues(preset);
    });
    if (shouldRestartSensor) {
      await _restartSensor();
    }
  }

  void _applySettingsPresetValues(SettingsPreset preset) {
    _target = preset.target;
    _rule = preset.rule;
    _threshold = preset.threshold.clamp(_minThreshold, _maxThreshold);
    _alarmSound =
        (_premiumFeaturesEnabled && _isPremium) ||
            _isFreeAlarmSound(preset.alarmSound)
        ? preset.alarmSound
        : AlarmSoundOption.loudBeep;
    _alarmVibration = preset.alarmVibration;
    _countdownSeconds = preset.countdownSeconds;
    _movingAverageStrength = preset.movingAverageStrength.clamp(0, 10);
    _dangerAlertStrength = _premiumFeaturesEnabled && _isPremium
        ? preset.dangerAlertStrength.clamp(0, _maxDangerAlertTicks)
        : 0;
    _dangerAlertMode = preset.dangerAlertMode;
    _dangerAlertAcceleration = preset.dangerAlertAcceleration;
    _currentValue = 0;
    _history.clear();
    _movingAverageSamples.clear();
    _lastDangerAlertAt = null;
    _settingsError = null;
    _settingsErrorDetail = null;
  }

  Future<void> _openSettingsMenu() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final strings = _strings;
        return AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(strings.settings)),
              IconButton(
                tooltip: strings.close,
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: min(MediaQuery.sizeOf(context).width - 48, 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LanguageMenuRow(
                        strings: strings,
                        language: _language,
                        onChanged: (value) {
                          setState(() {
                            _language = value;
                          });
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _showTutorial(markAsSeen: false);
                            }
                          });
                        },
                        icon: const Icon(Icons.school_outlined, size: 18),
                        label: Text(strings.tutorial),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        strings.presets,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: _neonLime,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      if (_premiumFeaturesEnabled && _isPremium)
                        OutlinedButton.icon(
                          onPressed: _scanPresetQr,
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: Text(strings.qrScan),
                        ),
                      if (_premiumFeaturesEnabled && _isPremium)
                        const SizedBox(height: 10),
                      for (
                        var index = 0;
                        index < _availablePresetSlots;
                        index++
                      ) ...[
                        _PresetSlotTile(
                          slotLabel: strings.presetSlot(index),
                          presetName:
                              _settingsPresets[index]?.name ??
                              strings.presetSlot(index),
                          isEmpty: _settingsPresets[index] == null,
                          saveLabel: strings.save,
                          loadLabel: strings.load,
                          renameLabel: strings.rename,
                          qrLabel: strings.qrShow,
                          isPremium: _premiumFeaturesEnabled && _isPremium,
                          onSave: () async {
                            await _saveSettingsPreset(index);
                            setDialogState(() {});
                          },
                          onLoad: _settingsPresets[index] == null
                              ? null
                              : () async {
                                  await _loadSettingsPreset(index);
                                  setDialogState(() {});
                                },
                          onRename: _settingsPresets[index] == null
                              ? null
                              : () {
                                  Navigator.of(dialogContext).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      _renameSettingsPreset(index);
                                    }
                                  });
                                },
                          onShowQr: _settingsPresets[index] == null
                              ? null
                              : () => _showPresetQr(_settingsPresets[index]!),
                        ),
                        if (index != _availablePresetSlots - 1)
                          const SizedBox(height: 10),
                      ],
                      if (_premiumFeaturesEnabled) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _isPremium
                              ? null
                              : () async {
                                  await _upgradeToPremium();
                                  setDialogState(() {});
                                },
                          icon: Icon(
                            _isPremium
                                ? Icons.verified
                                : Icons.workspace_premium,
                          ),
                          label: Text(
                            _isPremium
                                ? strings.premiumUnlocked
                                : strings.upgradeToPremium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_mode) {
      AppMode.settings => _SettingsView(
        target: _target,
        rule: _rule,
        alarmSound: _alarmSound,
        alarmVibration: _alarmVibration,
        isPremium: _premiumFeaturesEnabled && _isPremium,
        countdownSeconds: _countdownSeconds,
        movingAverageStrength: _movingAverageStrength,
        dangerAlertStrength: _dangerAlertStrength,
        dangerAlertMode: _dangerAlertMode,
        dangerAlertAcceleration: _dangerAlertAcceleration,
        threshold: _threshold,
        dangerAlertWidth: _dangerAlertWidth,
        alertStateEnabled: _isAlertStateEnabled,
        currentValue: _currentValue,
        history: List.unmodifiable(_history),
        minThreshold: _minThreshold,
        maxThreshold: _maxThreshold,
        unit: _unit,
        strings: _strings,
        targetLabel: _targetLabel,
        ruleLabel: _ruleLabel,
        errorMessage: _errorMessage,
        onTargetChanged: _changeTarget,
        onRuleChanged: (selected) {
          setState(() {
            _rule = selected.first;
          });
        },
        onAlarmSoundChanged: (value) {
          if (!_isPremium && !_isFreeAlarmSound(value)) {
            _showPremiumDialog();
            setState(() {});
            return;
          }
          setState(() {
            _alarmSound = value;
          });
        },
        onAlarmVibrationChanged: (value) {
          setState(() {
            _alarmVibration = value;
          });
        },
        onCountdownSecondsChanged: (value) {
          setState(() {
            _countdownSeconds = value;
          });
        },
        onMovingAverageStrengthChanged: (value) {
          setState(() {
            _movingAverageStrength = value;
            _movingAverageSamples.clear();
          });
        },
        onDangerAlertStrengthChanged: (value) {
          if (!_premiumFeaturesEnabled) {
            return;
          }
          if (!_isPremium && value > 0) {
            _showPremiumDialog();
            setState(() {});
            return;
          }
          setState(() {
            _dangerAlertStrength = value;
            _lastDangerAlertAt = null;
          });
        },
        onDangerAlertModeChanged: (value) {
          setState(() {
            _dangerAlertMode = value;
          });
        },
        onDangerAlertAccelerationChanged: (value) {
          if (!_isPremium && value) {
            _showPremiumDialog();
            return;
          }
          setState(() {
            _dangerAlertAcceleration = value;
            _lastDangerAlertAt = null;
          });
        },
        onThresholdChanged: (value) {
          setState(() {
            _threshold = value;
          });
        },
        onAlarmSoundPreview: _previewAlarmSound,
        onScreenshotFreezeToggle: _toggleScreenshotFreeze,
        onStart: _startCountdownOrMonitoring,
      ),
      AppMode.countdown => Stack(
        children: [
          _MonitoringView(
            targetLabel: _targetLabel,
            rule: _rule,
            ruleLabel: _ruleLabel,
            currentValue: _currentValue,
            threshold: _threshold,
            dangerAlertWidth: _dangerAlertWidth,
            alertStateEnabled: _isAlertStateEnabled,
            history: List.unmodifiable(_history),
            minThreshold: _minThreshold,
            maxThreshold: _maxThreshold,
            unit: _unit,
            strings: _strings,
            onCancel: _backToSettings,
            requireHoldToCancel: false,
          ),
          _CountdownOverlay(
            remainingSeconds: _countdownRemaining,
            totalSeconds: _countdownSeconds,
            isPaused: _isTriggered,
            strings: _strings,
          ),
        ],
      ),
      AppMode.monitoring => _MonitoringView(
        targetLabel: _targetLabel,
        rule: _rule,
        ruleLabel: _ruleLabel,
        currentValue: _currentValue,
        threshold: _threshold,
        dangerAlertWidth: _dangerAlertWidth,
        alertStateEnabled: _isAlertStateEnabled,
        history: List.unmodifiable(_history),
        minThreshold: _minThreshold,
        maxThreshold: _maxThreshold,
        unit: _unit,
        strings: _strings,
        onCancel: _backToSettings,
        requireHoldToCancel: true,
      ),
      AppMode.alerting => _AlertView(
        targetLabel: _targetLabel,
        ruleLabel: _ruleLabel,
        currentValue: _currentValue,
        threshold: _threshold,
        unit: _unit,
        strings: _strings,
        onBack: _backToSettings,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Par-alarm'),
        actions: [
          IconButton(
            tooltip: _strings.settings,
            onPressed: _openSettingsMenu,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1113), _charcoal],
          ),
        ),
        child: SafeArea(child: body),
      ),
      bottomNavigationBar: _premiumFeaturesEnabled && _isPremium
          ? null
          : _AdMobBanner(placeholderLabel: _strings.adPlaceholder),
    );
  }
}

class _LanguageMenuRow extends StatelessWidget {
  const _LanguageMenuRow({
    required this.strings,
    required this.language,
    required this.onChanged,
  });

  final AppStrings strings;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            strings.languageLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<AppLanguage>(
            initialValue: language,
            dropdownColor: _panelGray,
            iconEnabledColor: _neonLime,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _charcoal.withValues(alpha: 0.72),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _neonLime.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: _neonLime),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: AppLanguage.japanese,
                child: Text(strings.japanese),
              ),
              DropdownMenuItem(
                value: AppLanguage.english,
                child: Text(strings.english),
              ),
              DropdownMenuItem(
                value: AppLanguage.chinese,
                child: Text(strings.chinese),
              ),
              DropdownMenuItem(
                value: AppLanguage.traditionalChinese,
                child: Text(strings.traditionalChinese),
              ),
              DropdownMenuItem(
                value: AppLanguage.spanish,
                child: Text(strings.spanish),
              ),
              DropdownMenuItem(
                value: AppLanguage.german,
                child: Text(strings.german),
              ),
              DropdownMenuItem(
                value: AppLanguage.french,
                child: Text(strings.french),
              ),
              DropdownMenuItem(
                value: AppLanguage.italian,
                child: Text(strings.italian),
              ),
              DropdownMenuItem(
                value: AppLanguage.korean,
                child: Text(strings.korean),
              ),
              DropdownMenuItem(
                value: AppLanguage.portuguese,
                child: Text(strings.portuguese),
              ),
            ],
            onChanged: (value) {
              if (value != null && value != language) {
                onChanged(value);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _PresetSlotTile extends StatelessWidget {
  const _PresetSlotTile({
    required this.slotLabel,
    required this.presetName,
    required this.isEmpty,
    required this.saveLabel,
    required this.loadLabel,
    required this.renameLabel,
    required this.qrLabel,
    required this.isPremium,
    required this.onSave,
    required this.onLoad,
    required this.onRename,
    required this.onShowQr,
  });

  final String slotLabel;
  final String presetName;
  final bool isEmpty;
  final String saveLabel;
  final String loadLabel;
  final String renameLabel;
  final String qrLabel;
  final bool isPremium;
  final VoidCallback onSave;
  final VoidCallback? onLoad;
  final VoidCallback? onRename;
  final VoidCallback? onShowQr;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _charcoal.withValues(alpha: 0.44),
        border: Border.all(color: _neonLime.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    presetName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isEmpty
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : _neonLime,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: renameLabel,
                  onPressed: onRename,
                  icon: const Icon(Icons.edit, size: 18),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(36),
                    foregroundColor: _electricYellow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save, size: 18),
                  label: Text(saveLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onLoad,
                  icon: const Icon(Icons.upload, size: 18),
                  label: Text(loadLabel),
                ),
                if (_premiumFeaturesEnabled)
                  OutlinedButton.icon(
                    onPressed: isPremium ? onShowQr : null,
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: Text(qrLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RenamePresetDialog extends StatefulWidget {
  const _RenamePresetDialog({required this.strings, required this.initialName});

  final AppStrings strings;
  final String initialName;

  @override
  State<_RenamePresetDialog> createState() => _RenamePresetDialogState();
}

class _RenamePresetDialogState extends State<_RenamePresetDialog> {
  late final TextEditingController _controller;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _closeWithName() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    final value = _controller.text;
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.strings.rename),
      content: TextField(
        controller: _controller,
        autofocus: false,
        decoration: InputDecoration(labelText: widget.strings.presetName),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _closeWithName(),
      ),
      actions: [
        TextButton(
          onPressed: _isClosing ? null : () => Navigator.of(context).pop(),
          child: Text(widget.strings.close),
        ),
        FilledButton(
          onPressed: _isClosing ? null : _closeWithName,
          child: Text(widget.strings.rename),
        ),
      ],
    );
  }
}

class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog({required this.strings});

  final AppStrings strings;

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  final PageController _controller = PageController();
  int _page = 0;

  late final List<_TutorialPageData> _pages = [
    _TutorialPageData(
      icon: Icons.tune,
      title: widget.strings.tutorialStartTitle,
      body: widget.strings.tutorialStartBody,
    ),
    _TutorialPageData(
      icon: Icons.show_chart,
      title: widget.strings.tutorialGraphTitle,
      body: widget.strings.tutorialGraphBody,
    ),
    _TutorialPageData(
      icon: Icons.notification_important_outlined,
      title: widget.strings.tutorialAlertTitle,
      body: widget.strings.tutorialAlertBody,
    ),
    _TutorialPageData(
      icon: Icons.health_and_safety_outlined,
      title: widget.strings.tutorialSafetyTitle,
      body: widget.strings.tutorialSafetyBody,
    ),
    _TutorialPageData(
      icon: Icons.privacy_tip_outlined,
      title: widget.strings.tutorialPrivacyTitle,
      body: widget.strings.tutorialPrivacyBody,
    ),
    if (_premiumFeaturesEnabled)
      _TutorialPageData(
        icon: Icons.workspace_premium_outlined,
        title: widget.strings.tutorialPremiumTitle,
        body: widget.strings.tutorialPremiumBody,
      ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _close();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = min(MediaQuery.sizeOf(context).width - 40, 460.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _panelGray.withValues(alpha: 0.98),
          border: Border.all(color: _neonLime.withValues(alpha: 0.34)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _neonLime.withValues(alpha: 0.18),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SizedBox(
          width: width,
          height: 440,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.strings.tutorial,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _neonLime,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: widget.strings.close,
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (value) {
                    setState(() {
                      _page = value;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _TutorialPage(data: _pages[index]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Row(
                  children: [
                    Row(
                      children: [
                        for (var index = 0; index < _pages.length; index++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: index == _page ? 22 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 7),
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? _neonLime
                                  : Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      child: Text(
                        _page == _pages.length - 1
                            ? widget.strings.begin
                            : widget.strings.next,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPageData {
  const _TutorialPageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({required this.data});

  final _TutorialPageData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 300),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _charcoal,
                border: Border.all(color: _neonLime.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: _neonLime.withValues(alpha: 0.22),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: SizedBox(
                width: 96,
                height: 96,
                child: Icon(data.icon, size: 48, color: _neonLime),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.42,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({
    required this.target,
    required this.rule,
    required this.alarmSound,
    required this.alarmVibration,
    required this.isPremium,
    required this.countdownSeconds,
    required this.movingAverageStrength,
    required this.dangerAlertStrength,
    required this.dangerAlertMode,
    required this.dangerAlertAcceleration,
    required this.threshold,
    required this.dangerAlertWidth,
    required this.alertStateEnabled,
    required this.currentValue,
    required this.history,
    required this.minThreshold,
    required this.maxThreshold,
    required this.unit,
    required this.strings,
    required this.targetLabel,
    required this.ruleLabel,
    required this.errorMessage,
    required this.onTargetChanged,
    required this.onRuleChanged,
    required this.onAlarmSoundChanged,
    required this.onAlarmVibrationChanged,
    required this.onCountdownSecondsChanged,
    required this.onMovingAverageStrengthChanged,
    required this.onDangerAlertStrengthChanged,
    required this.onDangerAlertModeChanged,
    required this.onDangerAlertAccelerationChanged,
    required this.onThresholdChanged,
    required this.onAlarmSoundPreview,
    required this.onScreenshotFreezeToggle,
    required this.onStart,
  });

  final MonitorTarget target;
  final ThresholdRule rule;
  final AlarmSoundOption alarmSound;
  final AlarmVibrationOption alarmVibration;
  final bool isPremium;
  final int countdownSeconds;
  final int movingAverageStrength;
  final int dangerAlertStrength;
  final DangerAlertMode dangerAlertMode;
  final bool dangerAlertAcceleration;
  final double threshold;
  final double dangerAlertWidth;
  final bool alertStateEnabled;
  final double currentValue;
  final List<double> history;
  final double minThreshold;
  final double maxThreshold;
  final String unit;
  final AppStrings strings;
  final String targetLabel;
  final String ruleLabel;
  final String? errorMessage;
  final ValueChanged<Set<MonitorTarget>> onTargetChanged;
  final ValueChanged<Set<ThresholdRule>> onRuleChanged;
  final ValueChanged<AlarmSoundOption> onAlarmSoundChanged;
  final ValueChanged<AlarmVibrationOption> onAlarmVibrationChanged;
  final ValueChanged<int> onCountdownSecondsChanged;
  final ValueChanged<int> onMovingAverageStrengthChanged;
  final ValueChanged<int> onDangerAlertStrengthChanged;
  final ValueChanged<DangerAlertMode> onDangerAlertModeChanged;
  final ValueChanged<bool> onDangerAlertAccelerationChanged;
  final ValueChanged<double> onThresholdChanged;
  final VoidCallback onAlarmSoundPreview;
  final VoidCallback onScreenshotFreezeToggle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SettingControlRow(
                label: strings.target,
                child: SegmentedButton<MonitorTarget>(
                  segments: [
                    ButtonSegment(
                      value: MonitorTarget.sound,
                      icon: const Icon(Icons.graphic_eq),
                      label: Text(strings.sound),
                    ),
                    ButtonSegment(
                      value: MonitorTarget.vibration,
                      icon: const Icon(Icons.vibration),
                      label: Text(strings.vibration),
                    ),
                  ],
                  selected: {target},
                  onSelectionChanged: onTargetChanged,
                ),
              ),
              const SizedBox(height: 24),
              _SettingControlRow(
                label: strings.condition,
                child: SegmentedButton<ThresholdRule>(
                  segments: [
                    ButtonSegment(
                      value: ThresholdRule.above,
                      label: Text(strings.above),
                    ),
                    ButtonSegment(
                      value: ThresholdRule.below,
                      label: Text(strings.below),
                    ),
                  ],
                  selected: {rule},
                  onSelectionChanged: onRuleChanged,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.threshold,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${threshold.toStringAsFixed(1)} $unit',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              _ThresholdSlider(
                min: minThreshold,
                max: maxThreshold,
                value: threshold,
                rule: rule,
                onChanged: onThresholdChanged,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${minThreshold.toStringAsFixed(1)} $unit'),
                  Text('${maxThreshold.toStringAsFixed(1)} $unit'),
                ],
              ),
              const SizedBox(height: 24),
              _TrendChartPanel(
                title: strings.currentTarget(targetLabel),
                rule: rule,
                history: history,
                currentValue: currentValue,
                threshold: threshold,
                dangerAlertWidth: dangerAlertWidth,
                alertStateEnabled: alertStateEnabled,
                minValue: minThreshold,
                maxValue: maxThreshold,
                unit: unit,
                currentLabel: strings.currentValue,
                thresholdLabel: strings.threshold,
                ruleLabel: ruleLabel,
              ),
              const SizedBox(height: 20),
              _AdvancedSettingsPanel(
                strings: strings,
                alarmSound: alarmSound,
                alarmVibration: alarmVibration,
                isPremium: isPremium,
                countdownSeconds: countdownSeconds,
                movingAverageStrength: movingAverageStrength,
                dangerAlertStrength: dangerAlertStrength,
                dangerAlertValueLabel: _dangerAlertValueLabel,
                dangerAlertMode: dangerAlertMode,
                dangerAlertAcceleration: dangerAlertAcceleration,
                onAlarmSoundChanged: onAlarmSoundChanged,
                onAlarmVibrationChanged: onAlarmVibrationChanged,
                onCountdownSecondsChanged: onCountdownSecondsChanged,
                onMovingAverageStrengthChanged: onMovingAverageStrengthChanged,
                onDangerAlertStrengthChanged: onDangerAlertStrengthChanged,
                onDangerAlertModeChanged: onDangerAlertModeChanged,
                onDangerAlertAccelerationChanged:
                    onDangerAlertAccelerationChanged,
                onAlarmSoundPreview: onAlarmSoundPreview,
                onScreenshotFreezeToggle: onScreenshotFreezeToggle,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _charcoal.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: _neonLime.withValues(alpha: 0.22)),
            ),
            boxShadow: [
              BoxShadow(
                color: _neonLime.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: errorMessage == null
                ? FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(strings.start),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                : _MessagePanel(message: errorMessage!),
          ),
        ),
      ],
    );
  }

  String get _dangerAlertValueLabel {
    if (dangerAlertStrength == 0) {
      return strings.off;
    }

    final sign = rule == ThresholdRule.above ? '-' : '+';
    final fixedValue = dangerAlertWidth.toStringAsFixed(1);
    final compactValue = fixedValue.endsWith('.0')
        ? fixedValue.substring(0, fixedValue.length - 2)
        : fixedValue;
    return '$sign$compactValue$unit';
  }
}

class _SettingControlRow extends StatelessWidget {
  const _SettingControlRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(width: 12),
        child,
      ],
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.min,
    required this.max,
    required this.value,
    required this.rule,
    required this.onChanged,
  });

  final double min;
  final double max;
  final double value;
  final ThresholdRule rule;
  final ValueChanged<double> onChanged;

  void _updateFromDx(double dx, double width) {
    final normalized = (dx / width).clamp(0.0, 1.0);
    final rawValue = min + (max - min) * normalized;
    onChanged((rawValue * 2).round() / 2);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              _updateFromDx(details.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (details) {
              _updateFromDx(details.localPosition.dx, width);
            },
            child: CustomPaint(
              painter: _ThresholdSliderPainter(
                min: min,
                max: max,
                value: value,
                rule: rule,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThresholdSliderPainter extends CustomPainter {
  const _ThresholdSliderPainter({
    required this.min,
    required this.max,
    required this.value,
    required this.rule,
  });

  final double min;
  final double max;
  final double value;
  final ThresholdRule rule;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalInset = 12.0;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        horizontalInset,
        size.height / 2 - 6,
        size.width - horizontalInset * 2,
        12,
      ),
      const Radius.circular(8),
    );
    final normalized = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final thumbX = horizontalInset + trackRect.width * normalized;

    canvas.drawRRect(trackRect, Paint()..color = _panelBorder);

    final dangerRect = rule == ThresholdRule.above
        ? Rect.fromLTRB(
            thumbX,
            trackRect.top,
            trackRect.right,
            trackRect.bottom,
          )
        : Rect.fromLTRB(
            trackRect.left,
            trackRect.top,
            thumbX,
            trackRect.bottom,
          );
    final safeRect = rule == ThresholdRule.above
        ? Rect.fromLTRB(trackRect.left, trackRect.top, thumbX, trackRect.bottom)
        : Rect.fromLTRB(
            thumbX,
            trackRect.top,
            trackRect.right,
            trackRect.bottom,
          );

    canvas.save();
    canvas.clipRRect(trackRect);
    canvas.drawRect(
      safeRect,
      Paint()..color = _neonLime.withValues(alpha: 0.38),
    );
    canvas.drawRect(
      dangerRect,
      Paint()..color = const Color(0xFFFF3B30).withValues(alpha: 0.22),
    );

    final stripePaint = Paint()
      ..color = const Color(0xFFFF3B30).withValues(alpha: 0.58)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipRect(dangerRect);
    for (var x = dangerRect.left - 18; x < dangerRect.right + 18; x += 9) {
      canvas.drawLine(
        Offset(x, dangerRect.bottom),
        Offset(x + 18, dangerRect.top),
        stripePaint,
      );
    }
    canvas.restore();
    canvas.restore();

    final glowPaint = Paint()
      ..color = _neonLime.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(thumbX, size.height / 2), 18, glowPaint);
    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      12,
      Paint()..color = _electricYellow,
    );
    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      5,
      Paint()..color = _charcoal,
    );
  }

  @override
  bool shouldRepaint(covariant _ThresholdSliderPainter oldDelegate) {
    return oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.value != value ||
        oldDelegate.rule != rule;
  }
}

class _AdMobBanner extends StatefulWidget {
  const _AdMobBanner({required this.placeholderLabel});

  final String placeholderLabel;

  @override
  State<_AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<_AdMobBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  static const _androidTestAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const _iosTestAdUnitId = 'ca-app-pub-3940256099942544/2934735716';

  String get _adUnitId {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => _iosTestAdUnitId,
      _ => _androidTestAdUnitId,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd != null) {
      return;
    }

    final ad = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoaded = false;
            });
          }
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E10),
          border: Border.all(color: _panelBorder),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: _neonLime.withValues(alpha: 0.08), blurRadius: 14),
          ],
        ),
        alignment: Alignment.center,
        child: _isLoaded && _bannerAd != null
            ? SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt,
                    size: 18,
                    color: _neonLime.withValues(alpha: 0.72),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.placeholderLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AdvancedSettingsPanel extends StatelessWidget {
  const _AdvancedSettingsPanel({
    required this.strings,
    required this.alarmSound,
    required this.alarmVibration,
    required this.isPremium,
    required this.countdownSeconds,
    required this.movingAverageStrength,
    required this.dangerAlertStrength,
    required this.dangerAlertValueLabel,
    required this.dangerAlertMode,
    required this.dangerAlertAcceleration,
    required this.onAlarmSoundChanged,
    required this.onAlarmVibrationChanged,
    required this.onCountdownSecondsChanged,
    required this.onMovingAverageStrengthChanged,
    required this.onDangerAlertStrengthChanged,
    required this.onDangerAlertModeChanged,
    required this.onDangerAlertAccelerationChanged,
    required this.onAlarmSoundPreview,
    required this.onScreenshotFreezeToggle,
  });

  final AppStrings strings;
  final AlarmSoundOption alarmSound;
  final AlarmVibrationOption alarmVibration;
  final bool isPremium;
  final int countdownSeconds;
  final int movingAverageStrength;
  final int dangerAlertStrength;
  final String dangerAlertValueLabel;
  final DangerAlertMode dangerAlertMode;
  final bool dangerAlertAcceleration;
  final ValueChanged<AlarmSoundOption> onAlarmSoundChanged;
  final ValueChanged<AlarmVibrationOption> onAlarmVibrationChanged;
  final ValueChanged<int> onCountdownSecondsChanged;
  final ValueChanged<int> onMovingAverageStrengthChanged;
  final ValueChanged<int> onDangerAlertStrengthChanged;
  final ValueChanged<DangerAlertMode> onDangerAlertModeChanged;
  final ValueChanged<bool> onDangerAlertAccelerationChanged;
  final VoidCallback onAlarmSoundPreview;
  final VoidCallback onScreenshotFreezeToggle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panelGray.withValues(alpha: 0.9),
        border: Border.all(color: _neonLime.withValues(alpha: 0.26)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _neonLime.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: _neonLime,
          collapsedIconColor: _neonLime,
          title: Text(
            strings.advancedSettings,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _neonLime,
              fontWeight: FontWeight.w700,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _DropdownSetting<AlarmSoundOption>(
              label: strings.alarmSound,
              value: alarmSound,
              values: _premiumFeaturesEnabled && isPremium
                  ? AlarmSoundOption.values
                  : const [AlarmSoundOption.loudBeep, AlarmSoundOption.off],
              labelFor: strings.alarmSoundLabel,
              onChanged: onAlarmSoundChanged,
              trailing: _PreviewIconButton(
                tooltip: strings.previewSound,
                enabled: alarmSound != AlarmSoundOption.off,
                icon: Icons.play_arrow,
                onPressed: onAlarmSoundPreview,
              ),
            ),
            const SizedBox(height: 14),
            _DropdownSetting<AlarmVibrationOption>(
              label: strings.vibrationPattern,
              value: alarmVibration,
              values: AlarmVibrationOption.values,
              labelFor: strings.alarmVibrationLabel,
              onChanged: onAlarmVibrationChanged,
            ),
            const SizedBox(height: 14),
            _DropdownSetting<int>(
              label: strings.countdownTime,
              value: countdownSeconds,
              values: const [0, 1, 3, 5, 10],
              labelFor: strings.countdownLabel,
              onChanged: onCountdownSecondsChanged,
            ),
            const SizedBox(height: 16),
            _MovingAverageSetting(
              label: strings.movingAverage,
              value: movingAverageStrength,
              valueLabel: strings.movingAverageLabel(movingAverageStrength),
              onChanged: onMovingAverageStrengthChanged,
            ),
            if (_premiumFeaturesEnabled) ...[
              const SizedBox(height: 16),
              if (!isPremium) ...[
                _PremiumHint(label: strings.premiumRequired),
                const SizedBox(height: 10),
              ],
              _MovingAverageSetting(
                label: strings.dangerAlert,
                value: dangerAlertStrength,
                valueLabel: dangerAlertValueLabel,
                max: _maxDangerAlertTicks,
                onChanged: onDangerAlertStrengthChanged,
              ),
              const SizedBox(height: 14),
              _DropdownSetting<DangerAlertMode>(
                label: strings.dangerAlertMethod,
                value: dangerAlertMode,
                values: DangerAlertMode.values,
                labelFor: strings.dangerAlertModeLabel,
                enabled: dangerAlertStrength > 0,
                onChanged: onDangerAlertModeChanged,
              ),
              const SizedBox(height: 14),
              _CheckboxSetting(
                label: strings.dangerAlertAcceleration,
                value: dangerAlertAcceleration,
                enabled: dangerAlertStrength > 0,
                onChanged: onDangerAlertAccelerationChanged,
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onScreenshotFreezeToggle,
                onLongPress: onScreenshotFreezeToggle,
                child: const SizedBox(width: 56, height: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckboxSetting extends StatelessWidget {
  const _CheckboxSetting({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: enabled
                  ? null
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Checkbox(
          value: value,
          onChanged: enabled
              ? (next) {
                  onChanged(next ?? false);
                }
              : null,
          activeColor: _neonLime,
          checkColor: const Color(0xFF111500),
        ),
      ],
    );
  }
}

class _PremiumHint extends StatelessWidget {
  const _PremiumHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.lock, size: 16, color: _electricYellow),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _electricYellow,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MovingAverageSetting extends StatelessWidget {
  const _MovingAverageSetting({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.onChanged,
    this.max = 10,
  });

  final String label;
  final int value;
  final String valueLabel;
  final ValueChanged<int> onChanged;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _electricYellow,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          min: 0,
          max: max.toDouble(),
          divisions: max,
          value: value.clamp(0, max).toDouble(),
          label: valueLabel,
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }
}

class _DropdownSetting<T> extends StatelessWidget {
  const _DropdownSetting({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
    this.enabled = true,
    this.trailing,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: enabled
                  ? null
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 132, maxWidth: 180),
            child: DropdownButtonFormField<T>(
              key: ValueKey(value),
              initialValue: value,
              dropdownColor: _panelGray,
              iconEnabledColor: _neonLime,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: _charcoal.withValues(alpha: 0.72),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _neonLime.withValues(alpha: 0.35),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: _neonLime),
                ),
              ),
              items: [
                for (final item in values)
                  DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      labelFor(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: enabled
                  ? (value) {
                      if (value != null) {
                        onChanged(value);
                      }
                    }
                  : null,
              selectedItemBuilder: (context) => [
                for (final item in values)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      labelFor(item),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
              isExpanded: true,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _PreviewIconButton extends StatelessWidget {
  const _PreviewIconButton({
    required this.tooltip,
    required this.enabled,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final bool enabled;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: _neonLime.withValues(alpha: 0.12),
        disabledBackgroundColor: _panelBorder.withValues(alpha: 0.35),
        foregroundColor: _neonLime,
        disabledForegroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _QrScanDialog extends StatefulWidget {
  const _QrScanDialog({required this.strings});

  final AppStrings strings;

  @override
  State<_QrScanDialog> createState() => _QrScanDialogState();
}

class _QrScanDialogState extends State<_QrScanDialog> {
  bool _didRead = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.strings.qrScan),
      content: SizedBox(
        width: 320,
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: MobileScanner(
            onDetect: (capture) {
              if (_didRead) {
                return;
              }
              final value = capture.barcodes
                  .map((barcode) => barcode.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (value == null) {
                return;
              }
              _didRead = true;
              Navigator.of(context).pop(value);
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.strings.cancel),
        ),
      ],
    );
  }
}

class _CountdownOverlay extends StatefulWidget {
  const _CountdownOverlay({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.isPaused,
    required this.strings,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final bool isPaused;
  final AppStrings strings;

  @override
  State<_CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<_CountdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    )..value = 1 - widget.remainingSeconds / widget.totalSeconds;
    if (!widget.isPaused) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _CountdownOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalSeconds != widget.totalSeconds ||
        oldWidget.remainingSeconds != widget.remainingSeconds) {
      _controller
        ..duration = Duration(seconds: widget.totalSeconds)
        ..value = 1 - widget.remainingSeconds / widget.totalSeconds;
    }

    if (widget.isPaused) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _charcoal.withValues(alpha: 0.56),
            boxShadow: [
              BoxShadow(
                color: _neonLime.withValues(alpha: 0.12),
                blurRadius: 60,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final progress = 1 - _controller.value;
                      final displaySeconds = (widget.totalSeconds * progress)
                          .ceil()
                          .clamp(1, widget.totalSeconds);
                      return CustomPaint(
                        painter: _CountdownRingPainter(progress: progress),
                        child: Center(
                          child: Text(
                            '$displaySeconds',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  color: _neonLime,
                                  fontSize: 112,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(
                                      color: _neonLime.withValues(alpha: 0.86),
                                      blurRadius: 34,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = _panelBorder
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final glowPaint = Paint()
      ..color = _neonLime.withValues(alpha: 0.28)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final arcSweep = 2 * pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, -pi / 2, arcSweep, false, glowPaint);

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [_neonLime, _electricYellow, _neonLime],
      ).createShader(rect)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, arcSweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MonitoringView extends StatelessWidget {
  const _MonitoringView({
    required this.targetLabel,
    required this.rule,
    required this.ruleLabel,
    required this.currentValue,
    required this.threshold,
    required this.dangerAlertWidth,
    required this.alertStateEnabled,
    required this.history,
    required this.minThreshold,
    required this.maxThreshold,
    required this.unit,
    required this.strings,
    required this.onCancel,
    this.requireHoldToCancel = true,
  });

  final String targetLabel;
  final ThresholdRule rule;
  final String ruleLabel;
  final double currentValue;
  final double threshold;
  final double dangerAlertWidth;
  final bool alertStateEnabled;
  final List<double> history;
  final double minThreshold;
  final double maxThreshold;
  final String unit;
  final AppStrings strings;
  final VoidCallback onCancel;
  final bool requireHoldToCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _TrendChartPanel(
                title: strings.realtimeTrend,
                rule: rule,
                history: history,
                currentValue: currentValue,
                threshold: threshold,
                dangerAlertWidth: dangerAlertWidth,
                alertStateEnabled: alertStateEnabled,
                minValue: minThreshold,
                maxValue: maxThreshold,
                unit: unit,
                currentLabel: strings.currentValue,
                thresholdLabel: strings.threshold,
                ruleLabel: ruleLabel,
                showChrome: false,
                showCurrentValue: true,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _charcoal.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: _neonLime.withValues(alpha: 0.22)),
            ),
            boxShadow: [
              BoxShadow(
                color: _neonLime.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: requireHoldToCancel
                ? _HoldToReturnButton(label: strings.back, onComplete: onCancel)
                : OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(strings.back),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _HoldToReturnButton extends StatefulWidget {
  const _HoldToReturnButton({required this.label, required this.onComplete});

  final String label;
  final VoidCallback onComplete;

  @override
  State<_HoldToReturnButton> createState() => _HoldToReturnButtonState();
}

class _HoldToReturnButtonState extends State<_HoldToReturnButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && !_completed) {
              _completed = true;
              widget.onComplete();
            }
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold() {
    _completed = false;
    _controller.forward(from: 0);
  }

  void _cancelHold() {
    if (_completed) {
      return;
    }
    _controller.animateBack(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            height: 52,
            decoration: BoxDecoration(
              color: _panelGray.withValues(alpha: 0.92),
              border: Border.all(color: _neonLime),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: _neonLime.withValues(
                    alpha: 0.12 + 0.28 * _controller.value,
                  ),
                  blurRadius: 18 + 16 * _controller.value,
                  spreadRadius: 1 + 2 * _controller.value,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: _controller.value,
                  heightFactor: 1,
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _neonLime,
                      boxShadow: [
                        BoxShadow(
                          color: _neonLime.withValues(alpha: 0.65),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: IconTheme(
                    data: IconThemeData(
                      color: Color.lerp(
                        _neonLime,
                        scheme.onPrimary,
                        _controller.value,
                      ),
                    ),
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: Color.lerp(
                          _neonLime,
                          scheme.onPrimary,
                          _controller.value,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back),
                          const SizedBox(width: 8),
                          Text(widget.label),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AlertView extends StatelessWidget {
  const _AlertView({
    required this.targetLabel,
    required this.ruleLabel,
    required this.currentValue,
    required this.threshold,
    required this.unit,
    required this.strings,
    required this.onBack,
  });

  final String targetLabel;
  final String ruleLabel;
  final double currentValue;
  final double threshold;
  final String unit;
  final AppStrings strings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _charcoal,
        boxShadow: [
          BoxShadow(
            color: scheme.error.withValues(alpha: 0.2),
            blurRadius: 42,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        color: scheme.errorContainer.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.notifications_active, size: 80, color: scheme.error),
            const SizedBox(height: 20),
            Text(
              strings.alerting,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              strings.alertMessage(targetLabel, ruleLabel),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 28),
            _ValuePanel(
              title: strings.detectedValue,
              value: currentValue,
              unit: unit,
              icon: Icons.warning,
            ),
            const SizedBox(height: 16),
            _ValuePanel(
              title: strings.threshold,
              value: threshold,
              unit: unit,
              icon: Icons.flag,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: Text(strings.back),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _electricYellow,
                foregroundColor: scheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartPanel extends StatelessWidget {
  const _TrendChartPanel({
    required this.title,
    required this.rule,
    required this.history,
    required this.currentValue,
    required this.threshold,
    required this.dangerAlertWidth,
    required this.alertStateEnabled,
    required this.minValue,
    required this.maxValue,
    required this.unit,
    required this.currentLabel,
    required this.thresholdLabel,
    required this.ruleLabel,
    this.showChrome = true,
    this.showCurrentValue = true,
  });

  final String title;
  final ThresholdRule rule;
  final List<double> history;
  final double currentValue;
  final double threshold;
  final double dangerAlertWidth;
  final bool alertStateEnabled;
  final double minValue;
  final double maxValue;
  final String unit;
  final String currentLabel;
  final String thresholdLabel;
  final String ruleLabel;
  final bool showChrome;
  final bool showCurrentValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panelGray.withValues(alpha: 0.92),
        border: Border.all(color: _neonLime.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _neonLime.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showChrome) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (showCurrentValue) ...[
              _MetricReadout(value: currentValue, unit: unit),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 170,
              child: CustomPaint(
                painter: _TrendChartPainter(
                  rule: rule,
                  history: history.isEmpty ? [currentValue] : history,
                  threshold: threshold,
                  dangerAlertWidth: dangerAlertWidth,
                  alertStateEnabled: alertStateEnabled,
                  minValue: minValue,
                  maxValue: max(maxValue, currentValue),
                  lineColor: theme.colorScheme.primary,
                  thresholdColor: _electricYellow,
                  gridColor: _neonLime.withValues(alpha: 0.16),
                  labelColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (showChrome) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _LegendDot(
                    color: theme.colorScheme.primary,
                    label: currentLabel,
                  ),
                  _LegendDot(
                    color: _electricYellow,
                    label:
                        '$thresholdLabel $ruleLabel ${threshold.toStringAsFixed(1)} $unit',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricReadout extends StatelessWidget {
  const _MetricReadout({required this.value, required this.unit});

  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _charcoal.withValues(alpha: 0.45),
        border: Border.all(color: _neonLime.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value.toStringAsFixed(1),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: _neonLime,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                shadows: [
                  Shadow(
                    color: _neonLime.withValues(alpha: 0.62),
                    blurRadius: 22,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                unit,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _electricYellow,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({
    required this.rule,
    required this.history,
    required this.threshold,
    required this.dangerAlertWidth,
    required this.alertStateEnabled,
    required this.minValue,
    required this.maxValue,
    required this.lineColor,
    required this.thresholdColor,
    required this.gridColor,
    required this.labelColor,
  });

  final ThresholdRule rule;
  final List<double> history;
  final double threshold;
  final double dangerAlertWidth;
  final bool alertStateEnabled;
  final double minValue;
  final double maxValue;
  final Color lineColor;
  final Color thresholdColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const leftInset = 4.0;
    const topInset = 8.0;
    const bottomInset = 8.0;
    final chartWidth = max(1.0, size.width - leftInset);
    final chartHeight = max(1.0, size.height - topInset - bottomInset);
    final low = min(minValue, min(threshold, _minHistory));
    final high = max(maxValue, max(threshold, _maxHistory));
    final range = max(0.1, high - low);

    double yFor(double value) {
      final normalized = ((value - low) / range).clamp(0.0, 1.0);
      return topInset + chartHeight - normalized * chartHeight;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = topInset + chartHeight * i / 4;
      canvas.drawLine(Offset(leftInset, y), Offset(size.width, y), gridPaint);
    }

    final thresholdY = yFor(threshold);
    final alertRect = rule == ThresholdRule.above
        ? Rect.fromLTRB(leftInset, topInset, size.width, thresholdY)
        : Rect.fromLTRB(
            leftInset,
            thresholdY,
            size.width,
            topInset + chartHeight,
          );
    _drawAlertArea(canvas, alertRect, alertStateEnabled: alertStateEnabled);

    if (dangerAlertWidth > 0) {
      final dangerEdgeY = yFor(
        rule == ThresholdRule.above
            ? threshold - dangerAlertWidth
            : threshold + dangerAlertWidth,
      );
      final dangerRect = rule == ThresholdRule.above
          ? Rect.fromLTRB(leftInset, thresholdY, size.width, dangerEdgeY)
          : Rect.fromLTRB(leftInset, dangerEdgeY, size.width, thresholdY);
      _drawDangerZoneArea(canvas, dangerRect);
    }

    final thresholdGlowPaint = Paint()
      ..color = thresholdColor.withValues(alpha: 0.28)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawLine(
      Offset(leftInset, thresholdY),
      Offset(size.width, thresholdY),
      thresholdGlowPaint,
    );
    final thresholdPaint = Paint()
      ..color = thresholdColor
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(leftInset, thresholdY),
      Offset(size.width, thresholdY),
      thresholdPaint,
    );

    const visibleSampleCount = 80;
    final values = history.length == 1
        ? [history.first, history.first]
        : history;
    final visibleValues = values.length > visibleSampleCount
        ? values.sublist(values.length - visibleSampleCount)
        : values;
    final firstSlot = max(0, visibleSampleCount - visibleValues.length);
    final path = Path();
    for (var i = 0; i < visibleValues.length; i++) {
      final slot = firstSlot + i;
      final x = leftInset + chartWidth * slot / (visibleSampleCount - 1);
      final y = yFor(visibleValues[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.32)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    final currentPoint = Offset(size.width, yFor(visibleValues.last));
    canvas.drawCircle(
      currentPoint,
      12,
      Paint()
        ..color = lineColor.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(currentPoint, 5, Paint()..color = lineColor);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: threshold.toStringAsFixed(1),
        style: TextStyle(color: labelColor, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelY = (thresholdY - labelPainter.height - 3).clamp(
      0.0,
      size.height - labelPainter.height,
    );
    labelPainter.paint(canvas, Offset(size.width - labelPainter.width, labelY));
  }

  double get _minHistory => history.fold<double>(
    history.first,
    (previous, value) => min(previous, value),
  );

  double get _maxHistory => history.fold<double>(
    history.first,
    (previous, value) => max(previous, value),
  );

  void _drawAlertArea(
    Canvas canvas,
    Rect rect, {
    required bool alertStateEnabled,
  }) {
    if (rect.height <= 2 || rect.width <= 2) {
      return;
    }

    final fillPaint = Paint()
      ..color = (alertStateEnabled ? const Color(0xFFFF3B30) : _electricYellow)
          .withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    final stripePaint = Paint()
      ..color = (alertStateEnabled ? const Color(0xFFFF3B30) : _electricYellow)
          .withValues(alpha: alertStateEnabled ? 0.34 : 0.58)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const spacing = 12.0;
    final start = rect.left - rect.height;
    final end = rect.right + rect.height;

    canvas.save();
    canvas.clipRect(rect);
    for (var x = start; x < end; x += spacing) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        stripePaint,
      );
    }
    canvas.restore();
  }

  void _drawDangerZoneArea(Canvas canvas, Rect rect) {
    final normalizedRect = rect.top <= rect.bottom
        ? rect
        : Rect.fromLTRB(rect.left, rect.bottom, rect.right, rect.top);
    if (normalizedRect.height <= 2 || normalizedRect.width <= 2) {
      return;
    }

    final fillPaint = Paint()
      ..color = _electricYellow.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(normalizedRect, fillPaint);

    final stripePaint = Paint()
      ..color = _electricYellow.withValues(alpha: 0.58)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const spacing = 10.0;
    final start = normalizedRect.left - normalizedRect.height;
    final end = normalizedRect.right + normalizedRect.height;

    canvas.save();
    canvas.clipRect(normalizedRect);
    for (var x = start; x < end; x += spacing) {
      canvas.drawLine(
        Offset(x, normalizedRect.bottom),
        Offset(x + normalizedRect.height, normalizedRect.top),
        stripePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.rule != rule ||
        oldDelegate.history != history ||
        oldDelegate.threshold != threshold ||
        oldDelegate.dangerAlertWidth != dangerAlertWidth ||
        oldDelegate.alertStateEnabled != alertStateEnabled ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.thresholdColor != thresholdColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}

class _ValuePanel extends StatelessWidget {
  const _ValuePanel({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String title;
  final double value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panelGray.withValues(alpha: 0.9),
        border: Border.all(color: _neonLime.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _neonLime.withValues(alpha: 0.1),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)} $unit',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _neonLime,
                shadows: [
                  Shadow(
                    color: _neonLime.withValues(alpha: 0.75),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.86),
        border: Border.all(color: _electricYellow.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _electricYellow.withValues(alpha: 0.12),
            blurRadius: 18,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
