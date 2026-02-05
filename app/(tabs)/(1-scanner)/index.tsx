import { useStorage } from "@/hooks/useStorage";
import { useTranslations } from "@/hooks/useTranslations";
import { saveScanToHistory } from "@/utils/scanHistory";
import { useRouter } from "expo-router";
import BarcodeScanning, {
  BarcodeFormat,
} from "@react-native-ml-kit/barcode-scanning";
import { useAudioPlayer } from "expo-audio";
import { Barcode } from "expo-barcode-generator";
import { BlurView } from "expo-blur";
import {
  type BarcodeScanningResult,
  type CameraType,
  CameraView,
  useCameraPermissions,
} from "expo-camera";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import * as ImagePicker from "expo-image-picker";
import * as Sharing from "expo-sharing";
import * as StoreReview from "expo-store-review";
import { SymbolView } from "expo-symbols";
import QRCodeUtil from "qrcode";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  Alert,
  Linking,
  Modal,
  PlatformColor,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TextInput,
  useColorScheme,
  View,
} from "react-native";
import Animated, { FadeIn, FadeInDown } from "react-native-reanimated";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { captureRef } from "react-native-view-shot";

// QR Code component for preview
function QRCode({ value, size = 200 }: { value: string; size?: number }) {
  const modules = useMemo(() => {
    try {
      const qr = QRCodeUtil.create(value, { errorCorrectionLevel: "M" });
      const data = qr.modules.data;
      const moduleSize = qr.modules.size;

      const matrix: boolean[][] = [];
      for (let row = 0; row < moduleSize; row++) {
        const rowData: boolean[] = [];
        for (let col = 0; col < moduleSize; col++) {
          rowData.push(data[row * moduleSize + col] === 1);
        }
        matrix.push(rowData);
      }
      return matrix;
    } catch {
      return null;
    }
  }, [value]);

  if (!modules) return null;

  const moduleCount = modules.length;
  const cellSize = Math.floor(size / moduleCount);
  const actualSize = cellSize * moduleCount;

  return (
    <View
      style={{
        width: actualSize,
        height: actualSize,
        backgroundColor: "#fff",
        overflow: "hidden",
      }}
    >
      {modules.map((row, rowIndex) => (
        <View
          key={`qr-row-${rowIndex * moduleCount}`}
          style={{ flexDirection: "row", height: cellSize }}
        >
          {row.map((cell, colIndex) => (
            <View
              key={`qr-${rowIndex * moduleCount + colIndex}`}
              style={{
                width: cellSize,
                height: cellSize + 1,
                backgroundColor: cell ? "#000" : "#fff",
              }}
            />
          ))}
        </View>
      ))}
    </View>
  );
}

// 2D Barcode placeholder for Data Matrix, Aztec, PDF417
function Barcode2D({
  value,
  type,
  size = 200,
}: {
  value: string;
  type: "datamatrix" | "aztec" | "pdf417";
  size?: number;
}) {
  const typeLabels: Record<string, string> = {
    datamatrix: "Data Matrix",
    aztec: "Aztec",
    pdf417: "PDF417",
  };

  return (
    <View
      style={{
        width: size,
        height: type === "pdf417" ? size * 0.5 : size,
        backgroundColor: "#F5F5F5",
        justifyContent: "center",
        alignItems: "center",
        borderRadius: 8,
        padding: 12,
      }}
    >
      <Text
        style={{
          color: "#666",
          fontSize: 14,
          fontWeight: "600",
          marginBottom: 4,
        }}
      >
        {typeLabels[type]}
      </Text>
      <Text
        style={{ color: "#999", fontSize: 11, textAlign: "center" }}
        numberOfLines={2}
      >
        {value.length > 50 ? `${value.substring(0, 50)}...` : value}
      </Text>
    </View>
  );
}

// Check if type is a 2D barcode that needs special handling
function is2DBarcode(type: string): type is "datamatrix" | "aztec" | "pdf417" {
  return ["datamatrix", "aztec", "pdf417"].includes(type.toLowerCase());
}

// Map scan type to barcode format for rendering
function getBarcodeFormat(type: string): string | null {
  const formatMap: Record<string, string> = {
    code128: "CODE128",
    code39: "CODE39",
    code93: "CODE93",
    ean13: "EAN13",
    ean8: "EAN8",
    upc_a: "UPC",
    upc_e: "UPCE",
    itf14: "ITF14",
    itf: "ITF",
    codabar: "codabar",
  };
  return formatMap[type.toLowerCase()] || null;
}

// Static colors for Reanimated (PlatformColor not supported)
const colors = {
  light: {
    background: "#F2F2F7",
    secondaryBackground: "#FFFFFF",
    tertiaryBackground: "#F2F2F7",
    label: "#000000",
    secondaryLabel: "#3C3C43",
    blue: "#007AFF",
    green: "#34C759",
    orange: "#FF9500",
    indigo: "#5856D6",
  },
  dark: {
    background: "#000000",
    secondaryBackground: "#1C1C1E",
    tertiaryBackground: "#2C2C2E",
    label: "#FFFFFF",
    secondaryLabel: "#EBEBF5",
    blue: "#0A84FF",
    green: "#30D158",
    orange: "#FF9F0A",
    indigo: "#5E5CE6",
  },
};

// Local scan sound asset
const scanSound = require("@/assets/sounds/scan.m4a");

// Map ML Kit BarcodeFormat enum to readable strings
const barcodeFormatToString: Record<BarcodeFormat, string> = {
  [BarcodeFormat.UNKNOWN]: "unknown",
  [BarcodeFormat.ALL_FORMATS]: "all",
  [BarcodeFormat.CODE_128]: "code128",
  [BarcodeFormat.CODE_39]: "code39",
  [BarcodeFormat.CODE_93]: "code93",
  [BarcodeFormat.CODABAR]: "codabar",
  [BarcodeFormat.DATA_MATRIX]: "datamatrix",
  [BarcodeFormat.EAN_13]: "ean13",
  [BarcodeFormat.EAN_8]: "ean8",
  [BarcodeFormat.ITF]: "itf14",
  [BarcodeFormat.QR_CODE]: "qr",
  [BarcodeFormat.UPC_A]: "upc_a",
  [BarcodeFormat.UPC_E]: "upc_e",
  [BarcodeFormat.PDF417]: "pdf417",
  [BarcodeFormat.AZTEC]: "aztec",
};

interface ScannedItem {
  id: string;
  data: string;
  type: string;
  timestamp: number;
}

export default function ScannerScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [scannedData, setScannedData] = useState<string>("");
  const [scannedType, setScannedType] = useState<string>("");
  const [cameraType, setCameraType] = useState<CameraType>("back");
  const [flashOn, setFlashOn] = useState(false);
  const [showPreview, setShowPreview] = useState(false);
  const insets = useSafeAreaInsets();
  const colorScheme = useColorScheme();
  const theme = colors[colorScheme ?? "light"];
  const previewCodeRef = useRef<View>(null);
  const t = useTranslations();
  const router = useRouter();
  const [hasScannedBefore, setHasScannedBefore] = useStorage(
    "hasScannedBefore",
    false,
  );

  // Multi-scan state
  const [scannedItems, setScannedItems] = useState<ScannedItem[]>([]);
  const [showMultiResults, setShowMultiResults] = useState(false);
  const [selectedItem, setSelectedItem] = useState<ScannedItem | null>(null);
  const scannedDataSetRef = useRef<Set<string>>(new Set());

  // Settings
  const [hapticEnabled] = useStorage("hapticEnabled", true);
  const [soundEnabled] = useStorage("soundEnabled", true);
  const [saveHistory] = useStorage("saveHistory", true);
  const [autoCopy] = useStorage("autoCopy", false);
  const [autoOpenUrl] = useStorage("autoOpenUrl", false);
  const [multiScan] = useStorage("multiScan", false);
  const [hasPromptedReview, setHasPromptedReview] = useStorage(
    "hasPromptedReview",
    false,
  );

  // Audio player for scan sound
  const player = useAudioPlayer(scanSound);

  // Reset player position when sound finishes
  useEffect(() => {
    if (player.currentTime > 0 && !player.playing) {
      player.seekTo(0);
    }
  }, [player.playing, player.currentTime, player.seekTo]);

  const isValidUrl = (string: string): boolean => {
    // First, check if it's already a valid URL with protocol
    try {
      const url = new URL(string);
      return url.protocol === "http:" || url.protocol === "https:";
    } catch {
      // Check if it looks like a domain without protocol
      // Must have at least one dot, no spaces, and a valid TLD pattern
      const domainPattern =
        /^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+(\/.*)?\s*$/;
      return domainPattern.test(string.trim());
    }
  };

  const normalizeUrl = (string: string): string => {
    // If already has protocol, return as-is
    if (string.startsWith("http://") || string.startsWith("https://")) {
      return string;
    }
    // Otherwise, prepend https://
    return `https://${string.trim()}`;
  };

  const handleOpenUrl = () => {
    if (isValidUrl(scannedData)) {
      if (hapticEnabled) {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      }
      Linking.openURL(normalizeUrl(scannedData)).catch(() => {
        Alert.alert(t.common.error, t.scanner.unableToOpenUrl);
      });
    }
  };

  const handleBarCodeScanned = async ({
    type,
    data,
  }: BarcodeScanningResult) => {
    // Multi-scan mode
    if (multiScan) {
      // Check if already scanned - prevent duplicates using Set (synchronous, no race condition)
      if (scannedDataSetRef.current.has(data)) return;

      // Add to Set immediately to prevent rapid-fire duplicates
      scannedDataSetRef.current.add(data);

      // Play sound if enabled
      if (soundEnabled) {
        player.seekTo(0);
        player.play();
      }

      // Haptic feedback if enabled
      if (hapticEnabled) {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }

      const newItem: ScannedItem = {
        id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        data,
        type,
        timestamp: Date.now(),
      };

      setScannedItems((prev) => [...prev, newItem]);

      // Save to history if enabled
      if (saveHistory) {
        saveScanToHistory(data, type);
      }

      return;
    }

    // Single scan mode (original behavior)
    if (!scanned) {
      // Play sound if enabled
      if (soundEnabled) {
        player.seekTo(0);
        player.play();
      }

      // Haptic feedback if enabled
      if (hapticEnabled) {
        await Haptics.notificationAsync(
          Haptics.NotificationFeedbackType.Success,
        );
      }

      setScanned(true);
      setScannedData(data);
      setScannedType(type);

      // Mark that user has scanned before
      if (!hasScannedBefore) {
        setHasScannedBefore(true);
      }

      // Save to history if enabled
      if (saveHistory) {
        await saveScanToHistory(data, type);
      }

      // Auto-copy if enabled
      if (autoCopy) {
        await Clipboard.setStringAsync(data);
      }

      // Auto-open URL if enabled (Scan and Go)
      if (autoOpenUrl && isValidUrl(data)) {
        Linking.openURL(normalizeUrl(data)).catch(() => {
          // Silently fail if URL can't be opened
        });
      }

      // Prompt for review after first scan (follows Apple guidelines - after meaningful interaction)
      if (!hasPromptedReview) {
        // Small delay to let the user see the result first
        setTimeout(async () => {
          try {
            if (await StoreReview.isAvailableAsync()) {
              await StoreReview.requestReview();
              setHasPromptedReview(true);
            }
          } catch {
            // Silently fail if review request fails
          }
        }, 1500);
      }
    }
  };

  const copyToClipboard = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    await Clipboard.setStringAsync(scannedData);
    Alert.alert(t.alerts.copied, t.alerts.textCopiedToClipboard);
  };

  const shareData = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    await Share.share({ message: scannedData });
  };

  const resetScanner = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    setScanned(false);
    setScannedData("");
    setScannedType("");
    setScannedItems([]);
    setShowMultiResults(false);
    setSelectedItem(null);
    scannedDataSetRef.current.clear();
  };

  const handleOpenPreview = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setShowPreview(true);
  };

  // Multi-scan handlers
  const handleFinishMultiScan = () => {
    if (hapticEnabled) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    if (scannedItems.length > 0) {
      setShowMultiResults(true);
    }
  };

  const handleCopyItem = async (data: string) => {
    if (hapticEnabled) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    await Clipboard.setStringAsync(data);
    Alert.alert(t.alerts.copied, t.alerts.textCopiedToClipboard);
  };

  const handleShareItem = async (data: string) => {
    if (hapticEnabled) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    await Share.share({ message: data });
  };

  const handleOpenItemUrl = (data: string) => {
    if (isValidUrl(data)) {
      if (hapticEnabled) {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      }
      Linking.openURL(normalizeUrl(data)).catch(() => {
        Alert.alert(t.common.error, t.scanner.unableToOpenUrl);
      });
    }
  };

  const handleRemoveItem = (id: string) => {
    if (hapticEnabled) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setScannedItems((prev) => {
      const item = prev.find((i) => i.id === id);
      if (item) {
        scannedDataSetRef.current.delete(item.data);
      }
      return prev.filter((i) => i.id !== id);
    });
  };

  const handlePreviewCopy = async () => {
    if (!previewCodeRef.current || !scannedData) return;
    try {
      const uri = await captureRef(previewCodeRef, {
        format: "png",
        quality: 1,
      });
      await Clipboard.setImageAsync(uri);
      if (hapticEnabled) {
        await Haptics.notificationAsync(
          Haptics.NotificationFeedbackType.Success,
        );
      }
      Alert.alert(t.alerts.copied, t.scanner.imageCopied);
    } catch {
      await Clipboard.setStringAsync(scannedData);
      if (hapticEnabled) {
        await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      }
      Alert.alert(t.alerts.copied, t.alerts.textCopiedToClipboard);
    }
  };

  const handlePreviewShare = async () => {
    if (!previewCodeRef.current || !scannedData) return;
    try {
      const uri = await captureRef(previewCodeRef, {
        format: "png",
        quality: 1,
      });
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(uri);
      } else {
        Alert.alert(t.common.error, t.scanner.sharingNotAvailable);
      }
    } catch {
      Alert.alert(t.common.error, t.scanner.failedToShare);
    }
  };

  // Determine if we can render a preview for this barcode type
  const canRenderPreview =
    scannedType === "qr" ||
    is2DBarcode(scannedType) ||
    getBarcodeFormat(scannedType) !== null;

  // Get display name for the code type
  const getCodeTypeName = (type: string): string => {
    const nameMap: Record<string, string> = {
      qr: "QR Code",
      code128: "CODE 128",
      code39: "CODE 39",
      code93: "CODE 93",
      ean13: "EAN-13",
      ean8: "EAN-8",
      upc_a: "UPC-A",
      upc_e: "UPC-E",
      itf14: "ITF-14",
      itf: "ITF",
      codabar: "Codabar",
      pdf417: "PDF417",
      aztec: "Aztec",
      datamatrix: "Data Matrix",
    };
    return nameMap[type.toLowerCase()] || type.toUpperCase();
  };

  const toggleFlash = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setFlashOn(!flashOn);
  };

  const toggleCamera = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setCameraType((current) => (current === "back" ? "front" : "back"));
  };

  const pickFromGallery = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: "images",
      allowsEditing: false,
      quality: 1,
    });

    if (!result.canceled && result.assets?.[0]) {
      const imageUri = result.assets[0].uri;

      try {
        // Use ML Kit for scanning barcodes from images (works on both iOS and Android)
        const barcodes = await BarcodeScanning.scan(imageUri);

        if (barcodes.length > 0) {
          const barcode = barcodes[0];
          const formatString =
            barcodeFormatToString[barcode.format] || "unknown";

          // Play sound if enabled
          if (soundEnabled) {
            player.seekTo(0);
            player.play();
          }

          // Haptic feedback if enabled
          if (hapticEnabled) {
            await Haptics.notificationAsync(
              Haptics.NotificationFeedbackType.Success,
            );
          }

          setScanned(true);
          setScannedData(barcode.value);
          setScannedType(formatString);

          // Save to history if enabled
          if (saveHistory) {
            await saveScanToHistory(barcode.value, formatString);
          }

          // Auto-copy if enabled
          if (autoCopy) {
            await Clipboard.setStringAsync(barcode.value);
          }

          // Auto-open URL if enabled (Scan and Go)
          if (autoOpenUrl && isValidUrl(barcode.value)) {
            Linking.openURL(normalizeUrl(barcode.value)).catch(() => {
              // Silently fail if URL can't be opened
            });
          }

          // Prompt for review after first scan (follows Apple guidelines - after meaningful interaction)
          if (!hasPromptedReview) {
            setTimeout(async () => {
              try {
                if (await StoreReview.isAvailableAsync()) {
                  await StoreReview.requestReview();
                  setHasPromptedReview(true);
                }
              } catch {
                // Silently fail if review request fails
              }
            }, 1500);
          }
        } else {
          Alert.alert(t.scanner.noCodeFound, t.scanner.noCodeFoundMessage);
        }
      } catch (error) {
        // ML Kit requires a development build, not Expo Go
        const errorMessage =
          error instanceof Error && error.message.includes("linked")
            ? "Image scanning requires a development build. Please run 'npx expo run:ios' or 'npx expo run:android'."
            : "Failed to scan the image. Please try another.";
        Alert.alert("Error", errorMessage);
      }
    }
  };

  if (!permission) {
    return (
      <View style={styles.centerContainer}>
        <SymbolView
          name="camera"
          tintColor={PlatformColor("secondaryLabel")}
          style={{ width: 48, height: 48 }}
        />
        <Text style={styles.loadingText}>{t.scanner.requestingPermission}</Text>
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={styles.centerContainer}>
        <Animated.View
          entering={FadeInDown.duration(400)}
          style={styles.permissionContent}
        >
          <SymbolView
            name="camera.fill"
            tintColor={PlatformColor("systemBlue")}
            style={{ width: 64, height: 64, marginBottom: 20 }}
          />
          <Text style={styles.permissionTitle}>{t.scanner.cameraAccess}</Text>
          <Text style={styles.permissionText}>
            {t.scanner.cameraPermissionText}
          </Text>
          <Pressable
            style={({ pressed }) => [
              styles.permissionButton,
              pressed && styles.buttonPressed,
            ]}
            onPress={requestPermission}
          >
            <Text style={styles.permissionButtonText}>
              {t.scanner.grantPermission}
            </Text>
          </Pressable>
        </Animated.View>
      </View>
    );
  }

  // Multi-scan results view
  if (showMultiResults && scannedItems.length > 0) {
    return (
      <ScrollView
        style={[styles.container, { backgroundColor: theme.background }]}
        contentContainerStyle={[
          styles.resultContent,
          { paddingBottom: insets.bottom + 100 },
        ]}
        contentInsetAdjustmentBehavior="automatic"
      >
        {/* Success Header */}
        <Animated.View
          entering={FadeInDown.duration(500).springify()}
          style={styles.successHeader}
        >
          <View
            style={[
              styles.successIconRing,
              { borderColor: theme.green + "30" },
            ]}
          >
            <View
              style={[
                styles.successIconInner,
                { backgroundColor: theme.green + "15" },
              ]}
            >
              <SymbolView
                name="checkmark.circle.fill"
                tintColor={theme.green}
                style={{ width: 64, height: 64 }}
                animationSpec={{
                  effect: { type: "bounce", direction: "up" },
                }}
              />
            </View>
          </View>
          <Text style={[styles.successTitle, { color: theme.label }]}>
            {scannedItems.length}{" "}
            {scannedItems.length === 1
              ? t.scanner.codeScanned
              : t.scanner.codesScanned}
          </Text>
          <Text
            style={[styles.successSubtitle, { color: theme.secondaryLabel }]}
          >
            {t.scanner.tapForOptions}
          </Text>
        </Animated.View>

        {/* Scan Again Button */}
        <Animated.View entering={FadeInDown.delay(100).duration(400)}>
          <Pressable
            style={({ pressed }) => [
              styles.scanAgainTopButton,
              { backgroundColor: theme.blue },
              pressed && { opacity: 0.85, transform: [{ scale: 0.98 }] },
            ]}
            onPress={resetScanner}
          >
            <SymbolView
              name="camera.fill"
              tintColor="#fff"
              style={{ width: 20, height: 20 }}
            />
            <Text style={styles.scanAgainTopText}>{t.scanner.scanAgain}</Text>
          </Pressable>
        </Animated.View>

        {/* Section Header */}
        <Animated.View entering={FadeInDown.delay(140).duration(400)}>
          <Text style={[styles.sectionLabel, { color: theme.secondaryLabel }]}>
            {t.scanner.scannedItems}
          </Text>
        </Animated.View>

        {/* Scanned Items List - Grouped */}
        <Animated.View
          entering={FadeInDown.delay(150).duration(400)}
          style={[
            styles.itemsGroup,
            { backgroundColor: theme.secondaryBackground },
          ]}
        >
          {scannedItems.map((item, index) => (
            <View key={item.id}>
              {index > 0 && (
                <View
                  style={[
                    styles.itemSeparator,
                    { backgroundColor: theme.tertiaryBackground },
                  ]}
                />
              )}
              <Pressable
                style={({ pressed }) => [
                  styles.multiItemRow,
                  pressed && { backgroundColor: theme.tertiaryBackground },
                ]}
                onPress={() => setSelectedItem(item)}
              >
                <View style={styles.multiItemContent}>
                  <View style={styles.multiItemHeader}>
                    <View
                      style={[
                        styles.multiItemBadge,
                        { backgroundColor: theme.blue + "15" },
                      ]}
                    >
                      <SymbolView
                        name={item.type === "qr" ? "qrcode" : "barcode"}
                        tintColor={theme.blue}
                        style={{ width: 12, height: 12 }}
                      />
                      <Text
                        style={[styles.multiItemType, { color: theme.blue }]}
                      >
                        {getCodeTypeName(item.type)}
                      </Text>
                    </View>
                    {isValidUrl(item.data) && (
                      <SymbolView
                        name="link"
                        tintColor={theme.indigo}
                        style={{ width: 12, height: 12 }}
                      />
                    )}
                  </View>
                  <Text
                    style={[
                      styles.multiItemData,
                      { color: theme.label },
                      isValidUrl(item.data) && { color: theme.blue },
                    ]}
                    numberOfLines={1}
                  >
                    {item.data}
                  </Text>
                </View>
                <View style={styles.multiItemActions}>
                  <Pressable
                    style={({ pressed }) => [
                      styles.multiItemButton,
                      pressed && { opacity: 0.5 },
                    ]}
                    onPress={(e) => {
                      e.stopPropagation();
                      handleCopyItem(item.data);
                    }}
                    hitSlop={8}
                  >
                    <SymbolView
                      name="doc.on.doc"
                      tintColor={theme.blue}
                      style={{ width: 18, height: 18 }}
                    />
                  </Pressable>
                  {isValidUrl(item.data) && (
                    <Pressable
                      style={({ pressed }) => [
                        styles.multiItemButton,
                        pressed && { opacity: 0.5 },
                      ]}
                      onPress={(e) => {
                        e.stopPropagation();
                        handleOpenItemUrl(item.data);
                      }}
                      hitSlop={8}
                    >
                      <SymbolView
                        name="safari"
                        tintColor={theme.indigo}
                        style={{ width: 18, height: 18 }}
                      />
                    </Pressable>
                  )}
                  <Pressable
                    style={({ pressed }) => [
                      styles.multiItemButton,
                      pressed && { opacity: 0.5 },
                    ]}
                    onPress={(e) => {
                      e.stopPropagation();
                      handleRemoveItem(item.id);
                    }}
                    hitSlop={8}
                  >
                    <SymbolView
                      name="xmark.circle.fill"
                      tintColor={theme.secondaryLabel + "80"}
                      style={{ width: 20, height: 20 }}
                    />
                  </Pressable>
                </View>
              </Pressable>
            </View>
          ))}
        </Animated.View>

        {/* Continue Scanning Button */}
        <Animated.View
          entering={FadeInDown.delay(200 + scannedItems.length * 50).duration(
            400,
          )}
        >
          <Pressable
            style={({ pressed }) => [
              styles.continueButton,
              { borderColor: theme.blue },
              pressed && { opacity: 0.7 },
            ]}
            onPress={() => setShowMultiResults(false)}
          >
            <SymbolView
              name="plus.circle.fill"
              tintColor={theme.blue}
              style={{ width: 20, height: 20 }}
            />
            <Text style={[styles.continueButtonText, { color: theme.blue }]}>
              {t.scanner.addMoreCodes}
            </Text>
          </Pressable>
        </Animated.View>

        {/* Item Detail Modal */}
        <Modal
          visible={selectedItem !== null}
          animationType="fade"
          transparent
          onRequestClose={() => setSelectedItem(null)}
        >
          <Pressable
            style={styles.previewModalOverlay}
            onPress={() => setSelectedItem(null)}
          >
            <Pressable
              style={[
                styles.previewModalContent,
                { backgroundColor: theme.secondaryBackground },
              ]}
              onPress={(e) => e.stopPropagation()}
            >
              {selectedItem && (
                <>
                  <View style={styles.previewHeader}>
                    <Text style={[styles.previewTitle, { color: theme.label }]}>
                      {getCodeTypeName(selectedItem.type)}
                    </Text>
                    <Pressable
                      onPress={() => setSelectedItem(null)}
                      hitSlop={10}
                      style={({ pressed }) => pressed && { opacity: 0.6 }}
                    >
                      <SymbolView
                        name="xmark.circle.fill"
                        tintColor={theme.secondaryLabel}
                        style={{ width: 28, height: 28 }}
                      />
                    </Pressable>
                  </View>

                  <TextInput
                    style={[
                      styles.selectedItemData,
                      {
                        color: theme.label,
                        backgroundColor: theme.tertiaryBackground,
                      },
                      isValidUrl(selectedItem.data) && { color: theme.blue },
                    ]}
                    value={selectedItem.data}
                    editable={false}
                    multiline
                    scrollEnabled={false}
                  />

                  <View style={styles.previewActions}>
                    <Pressable
                      style={[
                        styles.previewButton,
                        { backgroundColor: theme.blue },
                      ]}
                      onPress={() => handleCopyItem(selectedItem.data)}
                    >
                      <SymbolView
                        name="doc.on.doc"
                        tintColor="#FFFFFF"
                        style={{ width: 18, height: 18 }}
                      />
                      <Text style={styles.previewButtonText}>
                        {t.common.copy}
                      </Text>
                    </Pressable>

                    <Pressable
                      style={[
                        styles.previewButton,
                        { backgroundColor: theme.green },
                      ]}
                      onPress={() => handleShareItem(selectedItem.data)}
                    >
                      <SymbolView
                        name="square.and.arrow.up"
                        tintColor="#FFFFFF"
                        style={{ width: 18, height: 18 }}
                      />
                      <Text style={styles.previewButtonText}>
                        {t.common.share}
                      </Text>
                    </Pressable>

                    {isValidUrl(selectedItem.data) && (
                      <Pressable
                        style={[
                          styles.previewButton,
                          { backgroundColor: theme.indigo },
                        ]}
                        onPress={() => {
                          handleOpenItemUrl(selectedItem.data);
                          setSelectedItem(null);
                        }}
                      >
                        <SymbolView
                          name="safari"
                          tintColor="#FFFFFF"
                          style={{ width: 18, height: 18 }}
                        />
                        <Text style={styles.previewButtonText}>
                          {t.common.open}
                        </Text>
                      </Pressable>
                    )}
                  </View>
                </>
              )}
            </Pressable>
          </Pressable>
        </Modal>
      </ScrollView>
    );
  }

  if (scanned && scannedData) {
    return (
      <ScrollView
        style={[styles.container, { backgroundColor: theme.background }]}
        contentContainerStyle={[
          styles.resultContent,
          { paddingBottom: insets.bottom + 100 },
        ]}
        contentInsetAdjustmentBehavior="automatic"
      >
        {/* Success Header */}
        <Animated.View
          entering={FadeInDown.duration(500).springify()}
          style={styles.successHeader}
        >
          <View
            style={[
              styles.successIconRing,
              { borderColor: theme.green + "30" },
            ]}
          >
            <View
              style={[
                styles.successIconInner,
                { backgroundColor: theme.green + "15" },
              ]}
            >
              <SymbolView
                name="checkmark.circle.fill"
                tintColor={theme.green}
                style={{ width: 64, height: 64 }}
                animationSpec={{
                  effect: { type: "bounce", direction: "up" },
                }}
              />
            </View>
          </View>
          <Text style={[styles.successTitle, { color: theme.label }]}>
            {t.scanner.scanComplete}
          </Text>
          <Text
            style={[styles.successSubtitle, { color: theme.secondaryLabel }]}
          >
            {isValidUrl(scannedData)
              ? t.scanner.urlDetected
              : t.scanner.contentCaptured}
          </Text>
        </Animated.View>

        {/* Content Card */}
        <Animated.View
          entering={FadeInDown.delay(100).duration(400)}
          style={[
            styles.contentCard,
            { backgroundColor: theme.secondaryBackground },
          ]}
        >
          <View style={styles.contentHeader}>
            <SymbolView
              name={isValidUrl(scannedData) ? "link" : "doc.text"}
              tintColor={theme.blue}
              style={{ width: 18, height: 18 }}
            />
            <Text
              style={[styles.contentLabel, { color: theme.secondaryLabel }]}
            >
              {isValidUrl(scannedData) ? t.scanner.url : t.scanner.content}
            </Text>
          </View>
          <TextInput
            style={[
              styles.contentText,
              { color: theme.label },
              isValidUrl(scannedData) && { color: theme.blue },
            ]}
            value={scannedData}
            editable={false}
            multiline
            scrollEnabled={false}
          />
        </Animated.View>

        {/* Action Buttons */}
        <Animated.View
          entering={FadeInDown.delay(200).duration(400)}
          style={styles.actionsContainer}
        >
          <View style={styles.actionGrid}>
            <Pressable
              style={({ pressed }) => [
                styles.gridButton,
                { backgroundColor: theme.secondaryBackground },
                pressed && styles.gridButtonPressed,
              ]}
              onPress={copyToClipboard}
            >
              <View
                style={[
                  styles.gridIconWrap,
                  { backgroundColor: theme.blue + "15" },
                ]}
              >
                <SymbolView
                  name="doc.on.doc.fill"
                  tintColor={theme.blue}
                  style={{ width: 24, height: 24 }}
                />
              </View>
              <Text style={[styles.gridButtonLabel, { color: theme.label }]}>
                {t.common.copy}
              </Text>
            </Pressable>

            <Pressable
              style={({ pressed }) => [
                styles.gridButton,
                { backgroundColor: theme.secondaryBackground },
                pressed && styles.gridButtonPressed,
              ]}
              onPress={shareData}
            >
              <View
                style={[
                  styles.gridIconWrap,
                  { backgroundColor: theme.green + "15" },
                ]}
              >
                <SymbolView
                  name="square.and.arrow.up.fill"
                  tintColor={theme.green}
                  style={{ width: 24, height: 24 }}
                />
              </View>
              <Text style={[styles.gridButtonLabel, { color: theme.label }]}>
                {t.common.share}
              </Text>
            </Pressable>

            {isValidUrl(scannedData) && (
              <Pressable
                style={({ pressed }) => [
                  styles.gridButton,
                  { backgroundColor: theme.secondaryBackground },
                  pressed && styles.gridButtonPressed,
                ]}
                onPress={handleOpenUrl}
              >
                <View
                  style={[
                    styles.gridIconWrap,
                    { backgroundColor: theme.indigo + "15" },
                  ]}
                >
                  <SymbolView
                    name="safari.fill"
                    tintColor={theme.indigo}
                    style={{ width: 24, height: 24 }}
                  />
                </View>
                <Text style={[styles.gridButtonLabel, { color: theme.label }]}>
                  {t.scanner.openUrl}
                </Text>
              </Pressable>
            )}
          </View>

          {/* Preview Button - separate row */}
          {canRenderPreview && (
            <Pressable
              style={({ pressed }) => [
                styles.previewButtonRow,
                { backgroundColor: theme.secondaryBackground },
                pressed && styles.gridButtonPressed,
              ]}
              onPress={handleOpenPreview}
            >
              <View
                style={[
                  styles.gridIconWrap,
                  { backgroundColor: theme.orange + "15" },
                ]}
              >
                <SymbolView
                  name="eye.fill"
                  tintColor={theme.orange}
                  style={{ width: 24, height: 24 }}
                />
              </View>
              <Text style={[styles.gridButtonLabel, { color: theme.label }]}>
                {t.scanner.previewCode}
              </Text>
            </Pressable>
          )}
        </Animated.View>

        {/* Scan Again Button */}
        <Animated.View entering={FadeInDown.delay(300).duration(400)}>
          <Pressable
            style={({ pressed }) => [
              styles.scanAgainButton,
              { backgroundColor: theme.blue },
              pressed && styles.scanAgainPressed,
            ]}
            onPress={resetScanner}
          >
            <SymbolView
              name="camera.fill"
              tintColor="#fff"
              style={{ width: 22, height: 22 }}
            />
            <Text style={styles.scanAgainText}>{t.scanner.scanAnother}</Text>
          </Pressable>
        </Animated.View>

        {/* Preview Modal */}
        <Modal
          visible={showPreview}
          animationType="fade"
          transparent
          onRequestClose={() => setShowPreview(false)}
        >
          <Pressable
            style={styles.previewModalOverlay}
            onPress={() => setShowPreview(false)}
          >
            <Pressable
              style={[
                styles.previewModalContent,
                { backgroundColor: theme.secondaryBackground },
              ]}
              onPress={(e) => e.stopPropagation()}
            >
              <View style={styles.previewHeader}>
                <Text style={[styles.previewTitle, { color: theme.label }]}>
                  {getCodeTypeName(scannedType)}
                </Text>
                <Pressable
                  onPress={() => setShowPreview(false)}
                  hitSlop={10}
                  style={({ pressed }) => pressed && { opacity: 0.6 }}
                >
                  <SymbolView
                    name="xmark.circle.fill"
                    tintColor={theme.secondaryLabel}
                    style={{ width: 28, height: 28 }}
                  />
                </Pressable>
              </View>

              <View
                ref={previewCodeRef}
                style={styles.previewCodeContainer}
                collapsable={false}
              >
                {scannedType === "qr" ? (
                  <QRCode value={scannedData} size={200} />
                ) : is2DBarcode(scannedType) ? (
                  <Barcode2D
                    value={scannedData}
                    type={
                      scannedType.toLowerCase() as
                        | "datamatrix"
                        | "aztec"
                        | "pdf417"
                    }
                    size={200}
                  />
                ) : getBarcodeFormat(scannedType) ? (
                  <Barcode
                    value={scannedData}
                    options={{
                      format: getBarcodeFormat(scannedType),
                      background: "#fff",
                      lineColor: "#000",
                      width: 1.5,
                      height: 80,
                      displayValue: true,
                      fontSize: 12,
                    }}
                  />
                ) : null}
              </View>

              <Text
                style={[styles.previewData, { color: theme.secondaryLabel }]}
                numberOfLines={3}
                selectable
              >
                {scannedData}
              </Text>

              <View style={styles.previewActions}>
                <Pressable
                  style={[
                    styles.previewButton,
                    { backgroundColor: theme.blue },
                  ]}
                  onPress={handlePreviewCopy}
                >
                  <SymbolView
                    name="photo.on.rectangle"
                    tintColor="#FFFFFF"
                    style={{ width: 18, height: 18 }}
                  />
                  <Text style={styles.previewButtonText}>{t.common.copy}</Text>
                </Pressable>

                <Pressable
                  style={[
                    styles.previewButton,
                    { backgroundColor: theme.blue },
                  ]}
                  onPress={handlePreviewShare}
                >
                  <SymbolView
                    name="square.and.arrow.up"
                    tintColor="#FFFFFF"
                    style={{ width: 18, height: 18 }}
                  />
                  <Text style={styles.previewButtonText}>{t.common.share}</Text>
                </Pressable>
              </View>
            </Pressable>
          </Pressable>
        </Modal>
      </ScrollView>
    );
  }

  return (
    <View style={styles.container}>
      <CameraView
        style={StyleSheet.absoluteFill}
        facing={cameraType}
        enableTorch={flashOn}
        onBarcodeScanned={handleBarCodeScanned}
        barcodeScannerSettings={{
          barcodeTypes: [
            "qr",
            "pdf417",
            "aztec",
            "ean13",
            "ean8",
            "upc_e",
            "datamatrix",
            "code128",
            "code39",
            "code93",
            "itf14",
            "codabar",
            "upc_a",
          ],
        }}
      />

      <View style={styles.overlay}>
        {/* Top Controls */}
        <View style={[styles.topControls, { top: insets.top + 16 }]}>
          <Pressable
            style={({ pressed }) => [
              styles.controlButton,
              flashOn && styles.controlButtonActive,
              pressed && styles.controlButtonPressed,
            ]}
            onPress={toggleFlash}
          >
            <SymbolView
              name={flashOn ? "bolt.fill" : "bolt.slash"}
              tintColor={flashOn ? "#FFD60A" : "#fff"}
              style={{ width: 22, height: 22 }}
            />
          </Pressable>

          <Pressable
            style={({ pressed }) => [
              styles.controlButton,
              pressed && styles.controlButtonPressed,
            ]}
            onPress={toggleCamera}
          >
            <SymbolView
              name="arrow.triangle.2.circlepath.camera"
              tintColor="#fff"
              style={{ width: 22, height: 22 }}
            />
          </Pressable>
        </View>

        {/* Scan Frame */}
        <Animated.View entering={FadeIn.duration(600)} style={styles.scanFrame}>
          <View style={[styles.corner, styles.topLeft]} />
          <View style={[styles.corner, styles.topRight]} />
          <View style={[styles.corner, styles.bottomLeft]} />
          <View style={[styles.corner, styles.bottomRight]} />
        </Animated.View>

        {/* Helpful Info Card - Show when user hasn't scanned before */}
        {!hasScannedBefore && !multiScan && (
          <Animated.View
            entering={FadeInDown.delay(800).duration(500)}
            style={[styles.helpCard, { top: insets.top + 80 }]}
          >
            <BlurView
              tint="systemMaterialDark"
              intensity={90}
              style={styles.helpCardInner}
            >
              <SymbolView
                name="lightbulb.fill"
                tintColor="#FFD60A"
                style={{ width: 24, height: 24 }}
              />
              <View style={styles.helpCardContent}>
                <Text style={styles.helpCardTitle}>
                  {t.scanner.noCodeToScan}
                </Text>
                <Text style={styles.helpCardText}>
                  {t.scanner.generateYourOwn}
                </Text>
              </View>
              <Pressable
                style={({ pressed }) => [
                  styles.helpCardButton,
                  pressed && { opacity: 0.7 },
                ]}
                onPress={() => {
                  if (hapticEnabled) {
                    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                  }
                  router.push("/(tabs)/(4-generator)");
                }}
              >
                <Text style={styles.helpCardButtonText}>
                  {t.scanner.tryGenerator}
                </Text>
              </Pressable>
            </BlurView>
          </Animated.View>
        )}

        {/* Multi-scan counter badge */}
        {multiScan && scannedItems.length > 0 && (
          <Animated.View
            entering={FadeIn.duration(200)}
            style={[styles.multiScanBadge, { top: insets.top + 80 }]}
          >
            <BlurView
              tint="systemMaterialDark"
              intensity={80}
              style={styles.multiScanBadgeInner}
            >
              <SymbolView
                name="checkmark.circle.fill"
                tintColor={theme.green}
                style={{ width: 20, height: 20 }}
              />
              <Text style={styles.multiScanBadgeText}>
                {scannedItems.length}{" "}
                {scannedItems.length === 1
                  ? t.scanner.codeScanned.toLowerCase()
                  : t.scanner.codesScanned.toLowerCase()}
              </Text>
            </BlurView>
          </Animated.View>
        )}

        {/* Bottom Area */}
        <View style={[styles.bottomArea, { bottom: insets.bottom + 100 }]}>
          <BlurView
            tint="systemMaterialDark"
            intensity={80}
            style={styles.instructionBlur}
          >
            <SymbolView
              name="viewfinder"
              tintColor="rgba(255,255,255,0.8)"
              style={{ width: 20, height: 20 }}
            />
            <Text style={styles.instructionText}>
              {multiScan ? t.scanner.scanMultipleCodes : t.scanner.pointAtCode}
            </Text>
          </BlurView>

          {/* Multi-scan Done button */}
          {multiScan && scannedItems.length > 0 && (
            <Pressable
              style={({ pressed }) => [
                styles.doneButton,
                pressed && styles.controlButtonPressed,
              ]}
              onPress={handleFinishMultiScan}
            >
              <BlurView
                tint="light"
                intensity={90}
                style={styles.doneButtonInner}
              >
                <SymbolView
                  name="checkmark.circle.fill"
                  tintColor={theme.blue}
                  style={{ width: 20, height: 20 }}
                />
                <Text style={[styles.doneButtonText, { color: theme.blue }]}>
                  {t.common.done}
                </Text>
                <View
                  style={[
                    styles.doneButtonBadge,
                    { backgroundColor: theme.blue },
                  ]}
                >
                  <Text style={styles.doneButtonBadgeText}>
                    {scannedItems.length}
                  </Text>
                </View>
              </BlurView>
            </Pressable>
          )}

          {/* Gallery Button */}
          <Pressable
            style={({ pressed }) => [
              styles.galleryButton,
              pressed && styles.controlButtonPressed,
            ]}
            onPress={pickFromGallery}
          >
            <BlurView
              tint="systemMaterialDark"
              intensity={80}
              style={styles.galleryButtonInner}
            >
              <SymbolView
                name="photo.on.rectangle"
                tintColor="rgba(255,255,255,0.9)"
                style={{ width: 22, height: 22 }}
              />
              <Text style={styles.galleryButtonText}>
                {t.scanner.fromGallery}
              </Text>
            </BlurView>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#000",
  },
  centerContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: PlatformColor("systemBackground"),
    padding: 40,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: PlatformColor("secondaryLabel"),
  },
  permissionContent: {
    alignItems: "center",
  },
  permissionTitle: {
    fontSize: 24,
    fontWeight: "700",
    color: PlatformColor("label"),
    marginBottom: 8,
  },
  permissionText: {
    fontSize: 16,
    color: PlatformColor("secondaryLabel"),
    textAlign: "center",
    lineHeight: 22,
    marginBottom: 32,
  },
  permissionButton: {
    backgroundColor: PlatformColor("systemBlue"),
    paddingVertical: 14,
    paddingHorizontal: 32,
    borderRadius: 14,
    borderCurve: "continuous",
  },
  permissionButtonText: {
    color: "#fff",
    fontSize: 17,
    fontWeight: "600",
  },
  buttonPressed: {
    opacity: 0.7,
    transform: [{ scale: 0.98 }],
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: "center",
    alignItems: "center",
  },
  topControls: {
    position: "absolute",
    left: 20,
    right: 20,
    flexDirection: "row",
    justifyContent: "space-between",
  },
  controlButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: "rgba(0, 0, 0, 0.5)",
    justifyContent: "center",
    alignItems: "center",
    borderWidth: 1,
    borderColor: "rgba(255, 255, 255, 0.15)",
  },
  controlButtonActive: {
    backgroundColor: "rgba(255, 214, 10, 0.25)",
    borderColor: "rgba(255, 214, 10, 0.5)",
  },
  controlButtonPressed: {
    transform: [{ scale: 0.92 }],
  },
  scanFrame: {
    width: 280,
    height: 280,
  },
  corner: {
    position: "absolute",
    width: 40,
    height: 40,
    borderColor: "#fff",
    borderWidth: 4,
    borderRadius: 4,
  },
  topLeft: {
    top: 0,
    left: 0,
    borderRightWidth: 0,
    borderBottomWidth: 0,
    borderTopLeftRadius: 16,
  },
  topRight: {
    top: 0,
    right: 0,
    borderLeftWidth: 0,
    borderBottomWidth: 0,
    borderTopRightRadius: 16,
  },
  bottomLeft: {
    bottom: 0,
    left: 0,
    borderRightWidth: 0,
    borderTopWidth: 0,
    borderBottomLeftRadius: 16,
  },
  bottomRight: {
    bottom: 0,
    right: 0,
    borderLeftWidth: 0,
    borderTopWidth: 0,
    borderBottomRightRadius: 16,
  },
  bottomArea: {
    position: "absolute",
    left: 24,
    right: 24,
    gap: 12,
  },
  galleryButton: {
    alignSelf: "center",
    borderRadius: 12,
    borderCurve: "continuous",
    overflow: "hidden",
  },
  galleryButtonInner: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingVertical: 12,
    paddingHorizontal: 20,
  },
  galleryButtonText: {
    color: "rgba(255, 255, 255, 0.9)",
    fontSize: 15,
    fontWeight: "500",
  },
  instructionBlur: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 10,
    paddingVertical: 14,
    paddingHorizontal: 20,
    borderRadius: 16,
    borderCurve: "continuous",
    overflow: "hidden",
  },
  instructionText: {
    color: "rgba(255, 255, 255, 0.9)",
    fontSize: 16,
    fontWeight: "500",
  },
  resultContent: {
    padding: 24,
    paddingTop: 60,
  },
  successHeader: {
    alignItems: "center",
    marginBottom: 32,
  },
  successIconRing: {
    width: 120,
    height: 120,
    borderRadius: 60,
    borderWidth: 3,
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 20,
  },
  successIconInner: {
    width: 96,
    height: 96,
    borderRadius: 48,
    justifyContent: "center",
    alignItems: "center",
  },
  successTitle: {
    fontSize: 28,
    fontWeight: "700",
    marginBottom: 6,
  },
  successSubtitle: {
    fontSize: 16,
  },
  contentCard: {
    borderRadius: 16,
    borderCurve: "continuous",
    padding: 20,
    marginBottom: 24,
    boxShadow: "0 2px 8px rgba(0, 0, 0, 0.06)",
  },
  contentHeader: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    marginBottom: 12,
  },
  contentLabel: {
    fontSize: 14,
    fontWeight: "600",
    textTransform: "uppercase",
    letterSpacing: 0.5,
  },
  contentText: {
    fontSize: 17,
    lineHeight: 26,
    fontFamily: "Menlo",
  },
  actionsContainer: {
    marginBottom: 20,
  },
  actionGrid: {
    flexDirection: "row",
    gap: 12,
  },
  gridButton: {
    flex: 1,
    alignItems: "center",
    paddingVertical: 20,
    paddingHorizontal: 12,
    borderRadius: 16,
    borderCurve: "continuous",
    boxShadow: "0 2px 8px rgba(0, 0, 0, 0.06)",
  },
  gridButtonPressed: {
    opacity: 0.8,
    transform: [{ scale: 0.96 }],
  },
  gridIconWrap: {
    width: 56,
    height: 56,
    borderRadius: 16,
    borderCurve: "continuous",
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 10,
  },
  gridButtonLabel: {
    fontSize: 14,
    fontWeight: "600",
  },
  scanAgainButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 12,
    paddingVertical: 18,
    borderRadius: 16,
    borderCurve: "continuous",
    boxShadow: "0 4px 12px rgba(0, 122, 255, 0.3)",
  },
  scanAgainPressed: {
    opacity: 0.9,
    transform: [{ scale: 0.98 }],
  },
  scanAgainText: {
    color: "#fff",
    fontSize: 18,
    fontWeight: "700",
  },
  previewButtonRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingVertical: 16,
    paddingHorizontal: 20,
    borderRadius: 16,
    borderCurve: "continuous",
    marginTop: 12,
    boxShadow: "0 2px 8px rgba(0, 0, 0, 0.06)",
  },
  previewModalOverlay: {
    flex: 1,
    backgroundColor: "rgba(0, 0, 0, 0.5)",
    justifyContent: "center",
    alignItems: "center",
    padding: 20,
  },
  previewModalContent: {
    width: "90%",
    maxWidth: 360,
    borderRadius: 20,
    borderCurve: "continuous",
    padding: 20,
    alignItems: "center",
  },
  previewHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    width: "100%",
    marginBottom: 20,
  },
  previewTitle: {
    fontSize: 20,
    fontWeight: "700",
  },
  previewCodeContainer: {
    padding: 16,
    backgroundColor: "#FFFFFF",
    borderRadius: 12,
    borderCurve: "continuous",
    marginBottom: 16,
    alignItems: "center",
    justifyContent: "center",
  },
  previewData: {
    fontSize: 14,
    textAlign: "center",
    marginBottom: 20,
  },
  previewActions: {
    flexDirection: "row",
    gap: 12,
  },
  previewButton: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 12,
    borderCurve: "continuous",
  },
  previewButtonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "600",
  },
  // Multi-scan styles
  multiScanBadge: {
    position: "absolute",
    alignSelf: "center",
  },
  multiScanBadgeInner: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 20,
    borderCurve: "continuous",
    overflow: "hidden",
  },
  multiScanBadgeText: {
    color: "rgba(255, 255, 255, 0.9)",
    fontSize: 15,
    fontWeight: "600",
  },
  doneButton: {
    alignSelf: "center",
    borderRadius: 14,
    borderCurve: "continuous",
    overflow: "hidden",
  },
  doneButtonInner: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingVertical: 14,
    paddingHorizontal: 24,
  },
  doneButtonText: {
    fontSize: 17,
    fontWeight: "600",
  },
  doneButtonBadge: {
    minWidth: 24,
    height: 24,
    borderRadius: 12,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 8,
  },
  doneButtonBadgeText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "700",
  },
  scanAgainTopButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 10,
    paddingVertical: 16,
    borderRadius: 14,
    borderCurve: "continuous",
    marginBottom: 24,
  },
  scanAgainTopText: {
    color: "#FFFFFF",
    fontSize: 17,
    fontWeight: "600",
  },
  sectionLabel: {
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 0.5,
    marginBottom: 8,
    marginLeft: 4,
  },
  itemsGroup: {
    borderRadius: 12,
    borderCurve: "continuous",
    overflow: "hidden",
    marginBottom: 24,
  },
  itemSeparator: {
    height: StyleSheet.hairlineWidth,
    marginLeft: 16,
  },
  multiItemRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 12,
    paddingHorizontal: 16,
    gap: 12,
  },
  multiItemContent: {
    flex: 1,
    gap: 4,
  },
  multiItemHeader: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  multiItemBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    paddingVertical: 2,
    paddingHorizontal: 6,
    borderRadius: 4,
    borderCurve: "continuous",
  },
  multiItemType: {
    fontSize: 10,
    fontWeight: "700",
    letterSpacing: 0.3,
  },
  multiItemData: {
    fontSize: 15,
    fontFamily: "Menlo",
  },
  multiItemActions: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
  },
  multiItemButton: {
    padding: 6,
  },
  continueButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingVertical: 14,
    borderRadius: 12,
    borderCurve: "continuous",
    borderWidth: 1.5,
  },
  continueButtonText: {
    fontSize: 16,
    fontWeight: "600",
  },
  selectedItemData: {
    width: "100%",
    fontSize: 15,
    lineHeight: 22,
    fontFamily: "Menlo",
    padding: 16,
    borderRadius: 12,
    borderCurve: "continuous",
    marginBottom: 20,
  },
  helpCard: {
    position: "absolute",
    left: 20,
    right: 20,
    alignSelf: "center",
  },
  helpCardInner: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    padding: 16,
    borderRadius: 16,
    borderCurve: "continuous",
    overflow: "hidden",
  },
  helpCardContent: {
    flex: 1,
    gap: 4,
  },
  helpCardTitle: {
    color: "rgba(255, 255, 255, 0.95)",
    fontSize: 15,
    fontWeight: "600",
  },
  helpCardText: {
    color: "rgba(255, 255, 255, 0.8)",
    fontSize: 13,
  },
  helpCardButton: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    backgroundColor: "rgba(255, 255, 255, 0.2)",
    borderRadius: 8,
    borderCurve: "continuous",
  },
  helpCardButtonText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "600",
  },
});
