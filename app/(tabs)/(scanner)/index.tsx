import {
  type BarcodeScanningResult,
  type CameraType,
  CameraView,
  useCameraPermissions,
} from "expo-camera";
import * as Burnt from "burnt";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import { SymbolView } from "expo-symbols";
import { useState } from "react";
import {
  Linking,
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
import { BlurView } from "expo-blur";
import { saveScanToHistory } from "@/utils/scanHistory";

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

export default function ScannerScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [scannedData, setScannedData] = useState<string>("");
  const [cameraType, setCameraType] = useState<CameraType>("back");
  const [flashOn, setFlashOn] = useState(false);
  const insets = useSafeAreaInsets();
  const colorScheme = useColorScheme();
  const theme = colors[colorScheme ?? "light"];

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
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      const supported = await Linking.canOpenURL(scannedData);
      if (supported) {
        await Linking.openURL(scannedData);
      }
    }
  };

  const handleBarCodeScanned = async ({
    type,
    data,
  }: BarcodeScanningResult) => {
    if (!scanned) {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setScanned(true);
      setScannedData(data);
      await saveScanToHistory(data, type);
    }
  };

  const copyToClipboard = async () => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await Clipboard.setStringAsync(scannedData);
    Burnt.toast({
      title: "Copied",
      preset: "done",
      haptic: "success",
    });
  };

  const shareData = async () => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await Share.share({ message: scannedData });
  };

  const resetScanner = async () => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setScanned(false);
    setScannedData("");
  };

  const toggleFlash = async () => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setFlashOn(!flashOn);
  };

  const toggleCamera = async () => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setCameraType((current) => (current === "back" ? "front" : "back"));
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
        <Animated.View entering={FadeInDown.duration(400)} style={styles.permissionContent}>
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
          <View style={[styles.successIconRing, { borderColor: theme.green + "30" }]}>
            <View style={[styles.successIconInner, { backgroundColor: theme.green + "15" }]}>
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
          <Text style={[styles.successSubtitle, { color: theme.secondaryLabel }]}>
            {isValidUrl(scannedData) ? "Website URL detected" : "Content captured"}
          </Text>
        </Animated.View>

        {/* Content Card */}
        <Animated.View
          entering={FadeInDown.delay(100).duration(400)}
          style={[styles.contentCard, { backgroundColor: theme.secondaryBackground }]}
        >
          <View style={styles.contentHeader}>
            <SymbolView
              name={isValidUrl(scannedData) ? "link" : "doc.text"}
              tintColor={theme.blue}
              style={{ width: 18, height: 18 }}
            />
            <Text style={[styles.contentLabel, { color: theme.secondaryLabel }]}>
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
              <View style={[styles.gridIconWrap, { backgroundColor: theme.blue + "15" }]}>
                <SymbolView
                  name="doc.on.doc.fill"
                  tintColor={theme.blue}
                  style={{ width: 24, height: 24 }}
                />
              </View>
              <Text style={[styles.gridButtonLabel, { color: theme.label }]}>Copy</Text>
            </Pressable>

            <Pressable
              style={({ pressed }) => [
                styles.gridButton,
                { backgroundColor: theme.secondaryBackground },
                pressed && styles.gridButtonPressed,
              ]}
              onPress={shareData}
            >
              <View style={[styles.gridIconWrap, { backgroundColor: theme.green + "15" }]}>
                <SymbolView
                  name="square.and.arrow.up.fill"
                  tintColor={theme.green}
                  style={{ width: 24, height: 24 }}
                />
              </View>
              <Text style={[styles.gridButtonLabel, { color: theme.label }]}>Share</Text>
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
                <View style={[styles.gridIconWrap, { backgroundColor: theme.indigo + "15" }]}>
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

        {/* Bottom Instruction */}
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
});
