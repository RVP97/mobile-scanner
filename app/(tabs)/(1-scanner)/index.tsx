import { useStorage } from "@/hooks/useStorage";
import { saveScanToHistory } from "@/utils/scanHistory";
import BarcodeScanning, {
  BarcodeFormat,
} from "@react-native-ml-kit/barcode-scanning";
import { useAudioPlayer } from "expo-audio";
// @ts-expect-error - no types available
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

  // Settings
  const [hapticEnabled] = useStorage("hapticEnabled", true);
  const [soundEnabled] = useStorage("soundEnabled", true);
  const [saveHistory] = useStorage("saveHistory", true);
  const [autoCopy] = useStorage("autoCopy", false);
  const [autoOpenUrl] = useStorage("autoOpenUrl", false);

  // Audio player for scan sound
  const player = useAudioPlayer(scanSound);

  // Reset player position when sound finishes
  useEffect(() => {
    if (player.currentTime > 0 && !player.playing) {
      player.seekTo(0);
    }
  }, [player.playing, player.currentTime, player.seekTo]);

  const isValidUrl = (string: string): boolean => {
    try {
      const url = new URL(string);
      return url.protocol === "http:" || url.protocol === "https:";
    } catch {
      return false;
    }
  };

  const handleOpenUrl = async () => {
    if (isValidUrl(scannedData)) {
      if (hapticEnabled) {
        await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      }
      Linking.openURL(scannedData).catch(() => {
        Alert.alert("Error", "Unable to open this URL");
      });
    }
  };

  const handleBarCodeScanned = async ({
    type,
    data,
  }: BarcodeScanningResult) => {
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
        Linking.openURL(data).catch(() => {
          // Silently fail if URL can't be opened
        });
      }
    }
  };

  const copyToClipboard = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    await Clipboard.setStringAsync(scannedData);
    Alert.alert("Copied", "Text copied to clipboard");
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
  };

  const handleOpenPreview = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setShowPreview(true);
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
        await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }
      Alert.alert("Copied", "Image copied to clipboard");
    } catch {
      await Clipboard.setStringAsync(scannedData);
      if (hapticEnabled) {
        await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      }
      Alert.alert("Copied", "Text copied to clipboard");
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
        Alert.alert("Error", "Sharing is not available on this device");
      }
    } catch {
      Alert.alert("Error", "Failed to share the image");
    }
  };

  // Determine if we can render a preview for this barcode type
  const canRenderPreview = scannedType === "qr" || getBarcodeFormat(scannedType) !== null;

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
            Linking.openURL(barcode.value).catch(() => {
              // Silently fail if URL can't be opened
            });
          }
        } else {
          Alert.alert(
            "No Code Found",
            "No barcode or QR code was found in the selected image.",
          );
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
        <Text style={styles.loadingText}>Requesting camera permission...</Text>
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
          <Text style={styles.permissionTitle}>Camera Access</Text>
          <Text style={styles.permissionText}>
            We need camera access to scan barcodes and QR codes
          </Text>
          <Pressable
            style={({ pressed }) => [
              styles.permissionButton,
              pressed && styles.buttonPressed,
            ]}
            onPress={requestPermission}
          >
            <Text style={styles.permissionButtonText}>Grant Permission</Text>
          </Pressable>
        </Animated.View>
      </View>
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
            Scan Complete
          </Text>
          <Text
            style={[styles.successSubtitle, { color: theme.secondaryLabel }]}
          >
            {isValidUrl(scannedData)
              ? "Website URL detected"
              : "Content captured"}
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
              {isValidUrl(scannedData) ? "URL" : "Content"}
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
                Copy
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
                Share
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
                  Open URL
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
                Preview Code
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
            <Text style={styles.scanAgainText}>Scan Another</Text>
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
                  <Text style={styles.previewButtonText}>Copy</Text>
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
                  <Text style={styles.previewButtonText}>Share</Text>
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
              Point at a barcode or QR code
            </Text>
          </BlurView>

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
              <Text style={styles.galleryButtonText}>From Gallery</Text>
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
});
