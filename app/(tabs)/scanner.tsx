import {
  type BarcodeScanningResult,
  type CameraType,
  CameraView,
  useCameraPermissions,
} from "expo-camera";
import * as Clipboard from "expo-clipboard";
import { useState } from "react";
import {
  Alert,
  Linking,
  Share,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { ThemedText } from "@/components/ThemedText";
import { ThemedView } from "@/components/ThemedView";
import { IconSymbol } from "@/components/ui/IconSymbol";
import { Colors } from "@/constants/Colors";
import { useColorScheme } from "@/hooks/useColorScheme";
import { saveScanToHistory } from "../../utils/scanHistory";

export default function ScannerScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [scannedData, setScannedData] = useState<string>("");
  const [cameraType, setCameraType] = useState<CameraType>("back");
  const [flashOn, setFlashOn] = useState(false);
  const colorScheme = useColorScheme();
  const insets = useSafeAreaInsets();

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
      try {
        const supported = await Linking.canOpenURL(scannedData);
        if (supported) {
          await Linking.openURL(scannedData);
        } else {
          Alert.alert("Error", "Cannot open this URL");
        }
      } catch {
        Alert.alert("Error", "Failed to open URL");
      }
    }
  };

  const handleBarCodeScanned = async ({
    type,
    data,
  }: BarcodeScanningResult) => {
    if (!scanned) {
      setScanned(true);
      setScannedData(data);
      // Save to history
      await saveScanToHistory(data, type);
    }
  };

  const copyToClipboard = async () => {
    await Clipboard.setStringAsync(scannedData);
    Alert.alert("Copied!", "Barcode data has been copied to clipboard");
  };

  const shareData = async () => {
    try {
      const result = await Share.share({
        message: scannedData,
      });

      if (result.action === Share.sharedAction) {
        if (result.activityType) {
          // shared with activity type of result.activityType
        } else {
          // shared
        }
      } else if (result.action === Share.dismissedAction) {
        // dismissed
      }
    } catch {
      Alert.alert("Error", "Unable to share the barcode data");
    }
  };

  const resetScanner = () => {
    setScanned(false);
    setScannedData("");
  };

  if (!permission) {
    return (
      <ThemedView style={styles.container}>
        <ThemedText>Requesting camera permission...</ThemedText>
      </ThemedView>
    );
  }

  if (!permission.granted) {
    return (
      <ThemedView style={styles.permissionContainer}>
        <ThemedText style={styles.permissionText}>
          We need your permission to show the camera
        </ThemedText>
        <TouchableOpacity
          style={[
            styles.button,
            { backgroundColor: Colors[colorScheme ?? "light"].tint },
          ]}
          onPress={requestPermission}
        >
          <ThemedText style={styles.buttonText}>Grant Permission</ThemedText>
        </TouchableOpacity>
      </ThemedView>
    );
  }

  if (scanned && scannedData) {
    return (
      <ThemedView style={styles.resultContainer}>
        <ThemedView style={styles.resultHeader}>
          <IconSymbol
            size={48}
            name="checkmark.circle.fill"
            color={Colors[colorScheme ?? "light"].tint}
          />
          <ThemedText type="title" style={styles.resultTitle}>
            Barcode Scanned!
          </ThemedText>
        </ThemedView>

        <ThemedView style={styles.dataContainer}>
          <ThemedText type="subtitle" style={styles.dataLabel}>
            Scanned Data:
          </ThemedText>
          <ThemedView style={styles.dataBox}>
            <TextInput
              style={[
                styles.dataText,
                isValidUrl(scannedData) && styles.urlText,
                styles.textInput,
              ]}
              value={scannedData}
              multiline
              editable={false}
              selectTextOnFocus
              selectionColor={Colors[colorScheme ?? "light"].tint}
            />
          </ThemedView>
        </ThemedView>

        <ThemedView
          style={
            isValidUrl(scannedData)
              ? styles.actionButtonsThree
              : styles.actionButtons
          }
        >
          <TouchableOpacity
            style={[styles.actionButton, styles.copyButton]}
            onPress={copyToClipboard}
          >
            <IconSymbol size={20} name="doc.on.doc" color="#FFFFFF" />
            <Text style={styles.actionButtonText}>Copy</Text>
          </TouchableOpacity>

          {isValidUrl(scannedData) && (
            <TouchableOpacity
              style={[styles.actionButton, styles.openButton]}
              onPress={handleOpenUrl}
            >
              <IconSymbol size={20} name="globe" color="#FFFFFF" />
              <Text style={styles.actionButtonText}>Open</Text>
            </TouchableOpacity>
          )}

          <TouchableOpacity
            style={[styles.actionButton, styles.shareButton]}
            onPress={shareData}
          >
            <IconSymbol size={20} name="square.and.arrow.up" color="#FFFFFF" />
            <Text style={styles.actionButtonText}>Share</Text>
          </TouchableOpacity>
        </ThemedView>

        <TouchableOpacity
          style={[styles.button, styles.scanAgainButton]}
          onPress={resetScanner}
        >
          <IconSymbol size={20} name="camera.fill" color="#FFFFFF" />
          <Text style={styles.buttonText}>Scan Again</Text>
        </TouchableOpacity>
      </ThemedView>
    );
  }

  return (
    <ThemedView style={styles.container}>
      <CameraView
        style={styles.camera}
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
      >
        <View style={styles.overlay}>
          <View style={styles.scanFrame}>
            <View style={[styles.corner, styles.topLeft]} />
            <View style={[styles.corner, styles.topRight]} />
            <View style={[styles.corner, styles.bottomLeft]} />
            <View style={[styles.corner, styles.bottomRight]} />
          </View>

          <ThemedView style={styles.instructionContainer}>
            <ThemedText style={styles.instructionText}>
              Point your camera at a barcode or QR code
            </ThemedText>
          </ThemedView>

          <View style={[styles.topControls, { top: insets.top + 20 }]}>
            <TouchableOpacity
              style={[
                styles.controlButton,
                flashOn && styles.controlButtonActive,
              ]}
              onPress={() => setFlashOn(!flashOn)}
              activeOpacity={0.7}
            >
              <IconSymbol
                size={20}
                name={flashOn ? "flashlight.on.fill" : "flashlight.off.fill"}
                color={flashOn ? "#FFD60A" : "#FFFFFF"}
              />
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.controlButton}
              onPress={() =>
                setCameraType((current) =>
                  current === "back" ? "front" : "back",
                )
              }
              activeOpacity={0.7}
            >
              <IconSymbol size={20} name="camera.rotate" color="#FFFFFF" />
            </TouchableOpacity>
          </View>
        </View>
      </CameraView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  permissionContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    padding: 20,
  },
  permissionText: {
    textAlign: "center",
    marginBottom: 20,
    fontSize: 16,
  },
  camera: {
    flex: 1,
  },
  overlay: {
    flex: 1,
    backgroundColor: "transparent",
    justifyContent: "center",
    alignItems: "center",
  },
  scanFrame: {
    width: 250,
    height: 250,
    position: "relative",
  },
  corner: {
    position: "absolute",
    width: 30,
    height: 30,
    borderColor: "#FFFFFF",
    borderWidth: 3,
  },
  topLeft: {
    top: 0,
    left: 0,
    borderRightWidth: 0,
    borderBottomWidth: 0,
  },
  topRight: {
    top: 0,
    right: 0,
    borderLeftWidth: 0,
    borderBottomWidth: 0,
  },
  bottomLeft: {
    bottom: 0,
    left: 0,
    borderRightWidth: 0,
    borderTopWidth: 0,
  },
  bottomRight: {
    bottom: 0,
    right: 0,
    borderLeftWidth: 0,
    borderTopWidth: 0,
  },
  instructionContainer: {
    position: "absolute",
    bottom: 100,
    left: 20,
    right: 20,
    backgroundColor: "rgba(0, 0, 0, 0.7)",
    borderRadius: 10,
    padding: 15,
  },
  instructionText: {
    color: "#FFFFFF",
    textAlign: "center",
    fontSize: 16,
  },
  topControls: {
    position: "absolute",
    left: 0,
    right: 0,
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: 20,
  },
  controlButton: {
    backgroundColor: "rgba(0, 0, 0, 0.6)",
    borderRadius: 22,
    width: 44,
    height: 44,
    justifyContent: "center",
    alignItems: "center",
    borderWidth: 1,
    borderColor: "rgba(255, 255, 255, 0.2)",
  },
  controlButtonActive: {
    backgroundColor: "rgba(255, 214, 10, 0.2)",
    borderColor: "#FFD60A",
  },
  resultContainer: {
    flex: 1,
    padding: 20,
    justifyContent: "center",
  },
  resultHeader: {
    alignItems: "center",
    marginBottom: 30,
  },
  resultTitle: {
    marginTop: 10,
    textAlign: "center",
  },
  dataContainer: {
    marginBottom: 30,
  },
  dataLabel: {
    marginBottom: 10,
  },
  dataBox: {
    borderWidth: 1,
    borderColor: "#DDD",
    borderRadius: 8,
    padding: 15,
    backgroundColor: "rgba(0, 0, 0, 0.05)",
  },
  dataText: {
    fontSize: 16,
    lineHeight: 24,
  },
  urlText: {
    color: "#007AFF",
    textDecorationLine: "underline",
  },
  textInput: {
    padding: 0,
    margin: 0,
    textAlignVertical: "top",
    color: "#FFFFFF",
  },
  actionButtons: {
    flexDirection: "row",
    justifyContent: "space-around",
    marginBottom: 30,
  },
  actionButtonsThree: {
    flexDirection: "row",
    justifyContent: "space-around",
    marginBottom: 30,
  },
  actionButton: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    flex: 1,
    marginHorizontal: 4,
    justifyContent: "center",
  },
  copyButton: {
    backgroundColor: "#007AFF",
  },
  shareButton: {
    backgroundColor: "#34C759",
  },
  openButton: {
    backgroundColor: "#007AFF",
  },
  actionButtonText: {
    color: "#FFFFFF",
    fontWeight: "600",
    marginLeft: 8,
    fontSize: 16,
  },
  button: {
    backgroundColor: "#007AFF",
    paddingVertical: 15,
    paddingHorizontal: 30,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
    flexDirection: "row",
  },
  scanAgainButton: {
    backgroundColor: "#FF9500",
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "600",
    marginLeft: 8,
  },
});
