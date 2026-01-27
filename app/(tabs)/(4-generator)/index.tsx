import { saveGenerationToHistory } from "@/utils/generationHistory";
import { Picker } from "@react-native-picker/picker";
// @ts-expect-error - no types available
import { Barcode } from "expo-barcode-generator";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import { SymbolView } from "expo-symbols";
import { Component, useMemo, useRef, useState, type ReactNode } from "react";
import {
  Alert,
  Keyboard,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  useColorScheme,
  View,
} from "react-native";
import { captureRef } from "react-native-view-shot";
import * as Sharing from "expo-sharing";
import QRCodeUtil from "qrcode";

const colors = {
  light: {
    background: "#F2F2F7",
    secondaryBackground: "#FFFFFF",
    label: "#000000",
    secondaryLabel: "#3C3C43",
    tertiaryLabel: "#8E8E93",
    separator: "#C6C6C8",
    blue: "#007AFF",
  },
  dark: {
    background: "#000000",
    secondaryBackground: "#1C1C1E",
    label: "#FFFFFF",
    secondaryLabel: "#EBEBF5",
    tertiaryLabel: "#636366",
    separator: "#38383A",
    blue: "#0A84FF",
  },
};

// Custom QR Code component - renders using Views
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
  // Use floor to avoid sub-pixel gaps, add 1 to cell height to eliminate row gaps
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

// EAN/UPC checksum validation helpers
function calculateEAN13Checksum(digits: string): number {
  let sum = 0;
  for (let i = 0; i < 12; i++) {
    const digit = Number.parseInt(digits[i], 10);
    sum += i % 2 === 0 ? digit : digit * 3;
  }
  return (10 - (sum % 10)) % 10;
}

function isValidEAN13(value: string): boolean {
  if (!/^\d{13}$/.test(value)) return false;
  const checkDigit = Number.parseInt(value[12], 10);
  return calculateEAN13Checksum(value) === checkDigit;
}

function isValidEAN8(value: string): boolean {
  if (!/^\d{8}$/.test(value)) return false;
  let sum = 0;
  for (let i = 0; i < 7; i++) {
    const digit = Number.parseInt(value[i], 10);
    sum += i % 2 === 0 ? digit * 3 : digit;
  }
  const checkDigit = (10 - (sum % 10)) % 10;
  return checkDigit === Number.parseInt(value[7], 10);
}

function isValidUPCA(value: string): boolean {
  if (!/^\d{12}$/.test(value)) return false;
  let sum = 0;
  for (let i = 0; i < 11; i++) {
    const digit = Number.parseInt(value[i], 10);
    sum += i % 2 === 0 ? digit * 3 : digit;
  }
  const checkDigit = (10 - (sum % 10)) % 10;
  return checkDigit === Number.parseInt(value[11], 10);
}

function isValidUPCE(value: string): boolean {
  // UPC-E must be 6, 7, or 8 digits
  // 6 digits: just the code
  // 7 digits: with number system (0 or 1)
  // 8 digits: with number system and check digit
  if (!/^\d{6,8}$/.test(value)) return false;
  
  // Basic format validation - UPC-E has specific patterns
  if (value.length === 8) {
    // Must start with 0 or 1
    if (value[0] !== '0' && value[0] !== '1') return false;
  }
  if (value.length === 7) {
    // Must start with 0 or 1
    if (value[0] !== '0' && value[0] !== '1') return false;
  }
  return true;
}

function isValidITF14(value: string): boolean {
  if (!/^\d{14}$/.test(value)) return false;
  // ITF-14 uses same checksum as EAN-13
  let sum = 0;
  for (let i = 0; i < 13; i++) {
    const digit = Number.parseInt(value[i], 10);
    sum += i % 2 === 0 ? digit * 3 : digit;
  }
  const checkDigit = (10 - (sum % 10)) % 10;
  return checkDigit === Number.parseInt(value[13], 10);
}

// Error Boundary for Barcode rendering errors
interface ErrorBoundaryProps {
  children: ReactNode;
  onError: () => void;
  fallback: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
}

class BarcodeErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(): void {
    this.props.onError();
  }

  render(): ReactNode {
    if (this.state.hasError) {
      return this.props.fallback;
    }
    return this.props.children;
  }
}

interface CodeFormat {
  id: string;
  name: string;
  type: "qr" | "barcode";
  format?: string;
  placeholder: string;
  maxLength?: number;
  keyboardType?: "default" | "numeric" | "ascii-capable";
  validation?: (value: string) => boolean;
  validationMessage?: string;
}

const CODE_FORMATS: CodeFormat[] = [
  {
    id: "qr",
    name: "QR Code",
    type: "qr",
    placeholder: "Enter any text or URL",
    keyboardType: "default",
  },
  {
    id: "code128",
    name: "CODE 128",
    type: "barcode",
    format: "CODE128",
    placeholder: "Enter any text",
    keyboardType: "ascii-capable",
    validation: (v) => v.length > 0 && v.length <= 80,
    validationMessage: "CODE 128 requires 1-80 characters",
  },
  {
    id: "ean13",
    name: "EAN-13",
    type: "barcode",
    format: "EAN13",
    placeholder: "Enter 13 digits (with valid checksum)",
    maxLength: 13,
    keyboardType: "numeric",
    validation: (v) => /^\d{12,13}$/.test(v) && (v.length === 12 || isValidEAN13(v)),
    validationMessage: "EAN-13 requires 12 digits (auto checksum) or 13 with valid checksum",
  },
  {
    id: "ean8",
    name: "EAN-8",
    type: "barcode",
    format: "EAN8",
    placeholder: "Enter 8 digits (with valid checksum)",
    maxLength: 8,
    keyboardType: "numeric",
    validation: (v) => /^\d{7,8}$/.test(v) && (v.length === 7 || isValidEAN8(v)),
    validationMessage: "EAN-8 requires 7 digits (auto checksum) or 8 with valid checksum",
  },
  {
    id: "upca",
    name: "UPC-A",
    type: "barcode",
    format: "UPC",
    placeholder: "Enter 12 digits (with valid checksum)",
    maxLength: 12,
    keyboardType: "numeric",
    validation: (v) => /^\d{11,12}$/.test(v) && (v.length === 11 || isValidUPCA(v)),
    validationMessage: "UPC-A requires 11 digits (auto checksum) or 12 with valid checksum",
  },
  {
    id: "upce",
    name: "UPC-E",
    type: "barcode",
    format: "UPCE",
    placeholder: "Enter 6-8 digits (start with 0)",
    maxLength: 8,
    keyboardType: "numeric",
    validation: isValidUPCE,
    validationMessage: "UPC-E requires 6-8 digits, must start with 0 or 1 if 7-8 digits",
  },
  {
    id: "code39",
    name: "CODE 39",
    type: "barcode",
    format: "CODE39",
    placeholder: "Enter alphanumeric text",
    keyboardType: "ascii-capable",
    validation: (v) => /^[A-Z0-9\-. $/+%]+$/i.test(v),
    validationMessage: "CODE 39 supports A-Z, 0-9, and -. $/+%",
  },
  {
    id: "itf14",
    name: "ITF-14",
    type: "barcode",
    format: "ITF14",
    placeholder: "Enter 13-14 digits",
    maxLength: 14,
    keyboardType: "numeric",
    validation: (v) => /^\d{13,14}$/.test(v) && (v.length === 13 || isValidITF14(v)),
    validationMessage: "ITF-14 requires 13 digits (auto checksum) or 14 with valid checksum",
  },
  {
    id: "itf",
    name: "ITF",
    type: "barcode",
    format: "ITF",
    placeholder: "Enter even number of digits",
    keyboardType: "numeric",
    validation: (v) => /^\d+$/.test(v) && v.length % 2 === 0,
    validationMessage: "ITF requires an even number of digits",
  },
  {
    id: "msi",
    name: "MSI",
    type: "barcode",
    format: "MSI",
    placeholder: "Enter digits",
    keyboardType: "numeric",
    validation: (v) => /^\d+$/.test(v),
    validationMessage: "MSI requires only digits",
  },
  {
    id: "pharmacode",
    name: "Pharmacode",
    type: "barcode",
    format: "pharmacode",
    placeholder: "Enter number 3-131070",
    keyboardType: "numeric",
    validation: (v) => {
      const num = Number.parseInt(v, 10);
      return !Number.isNaN(num) && num >= 3 && num <= 131070;
    },
    validationMessage: "Pharmacode requires a number between 3 and 131070",
  },
  {
    id: "codabar",
    name: "Codabar",
    type: "barcode",
    format: "codabar",
    placeholder: "A1234B (start/end with A-D)",
    keyboardType: "ascii-capable",
    validation: (v) => /^[A-Da-d][0-9\-$:/.+]+[A-Da-d]$/.test(v),
    validationMessage: "Codabar must start/end with A-D",
  },
];

export default function GeneratorScreen() {
  const colorScheme = useColorScheme();
  const theme = colors[colorScheme ?? "light"];

  const [selectedFormat, setSelectedFormat] = useState<CodeFormat>(CODE_FORMATS[0]);
  const [inputValue, setInputValue] = useState("");
  const [generatedValue, setGeneratedValue] = useState("");
  const [barcodeError, setBarcodeError] = useState(false);
  const [showPicker, setShowPicker] = useState(false);
  const [tempSelectedId, setTempSelectedId] = useState(selectedFormat.id);
  const codeRef = useRef<View>(null);
  const inputRef = useRef<TextInput>(null);

  const handlePickerDone = () => {
    const format = CODE_FORMATS.find((f) => f.id === tempSelectedId);
    if (format && format.id !== selectedFormat.id) {
      setSelectedFormat(format);
      setGeneratedValue("");
      setInputValue("");
      setBarcodeError(false);
    }
    setShowPicker(false);
  };

  const handlePickerCancel = () => {
    setTempSelectedId(selectedFormat.id);
    setShowPicker(false);
  };

  const handleGenerate = () => {
    if (!inputValue.trim()) {
      Alert.alert("Error", "Please enter a value to generate");
      return;
    }

    if (selectedFormat.validation && !selectedFormat.validation(inputValue)) {
      Alert.alert("Invalid Input", selectedFormat.validationMessage);
      return;
    }

    if (Platform.OS === "ios") {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }

    Keyboard.dismiss();
    setBarcodeError(false);
    setGeneratedValue(inputValue);

    // Save to generation history (use format for barcodes, id for QR)
    saveGenerationToHistory(
      inputValue,
      selectedFormat.format || selectedFormat.id,
      selectedFormat.name,
    );
  };

  const handleCopy = async () => {
    if (!codeRef.current || !generatedValue) return;

    try {
      const uri = await captureRef(codeRef, {
        format: "png",
        quality: 1,
      });
      await Clipboard.setImageAsync(uri);
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert("Copied", "Image copied to clipboard");
    } catch {
      // Fallback to copying text
      await Clipboard.setStringAsync(generatedValue);
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      Alert.alert("Copied", "Text copied to clipboard");
    }
  };

  const handleShare = async () => {
    if (!codeRef.current || !generatedValue) return;

    try {
      const uri = await captureRef(codeRef, {
        format: "png",
        quality: 1,
      });

      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(uri);
      } else {
        Alert.alert("Error", "Sharing is not available on this device");
      }
    } catch {
      Alert.alert("Error", "Failed to share the code");
    }
  };

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: theme.background }]}
      contentContainerStyle={styles.contentContainer}
      contentInsetAdjustmentBehavior="automatic"
      keyboardDismissMode="on-drag"
    >
      {/* Format Selector */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: theme.secondaryLabel }]}>
          CODE TYPE
        </Text>
        <Pressable
          style={[styles.selector, { backgroundColor: theme.secondaryBackground }]}
          onPress={() => {
            setTempSelectedId(selectedFormat.id);
            setShowPicker(true);
          }}
        >
          <View style={styles.selectorContent}>
            <SymbolView
              name={selectedFormat.type === "qr" ? "qrcode" : "barcode"}
              size={22}
              tintColor={theme.blue}
            />
            <Text style={[styles.selectorText, { color: theme.label }]}>
              {selectedFormat.name}
            </Text>
          </View>
          <SymbolView
            name="chevron.up.chevron.down"
            size={14}
            tintColor={theme.tertiaryLabel}
          />
        </Pressable>
      </View>

      {/* Native Picker Modal */}
      <Modal
        visible={showPicker}
        transparent
        animationType="slide"
      >
        <View style={styles.pickerModal}>
          <View style={[styles.pickerContainer, { backgroundColor: theme.secondaryBackground }]}>
            <View style={[styles.pickerHeader, { borderBottomColor: theme.separator }]}>
              <Pressable onPress={handlePickerCancel} hitSlop={10}>
                <Text style={[styles.pickerButton, { color: theme.blue }]}>Cancel</Text>
              </Pressable>
              <Text style={[styles.pickerTitle, { color: theme.label }]}>Code Type</Text>
              <Pressable onPress={handlePickerDone} hitSlop={10}>
                <Text style={[styles.pickerButton, styles.pickerButtonDone, { color: theme.blue }]}>Done</Text>
              </Pressable>
            </View>
            <Picker
              selectedValue={tempSelectedId}
              onValueChange={(value) => setTempSelectedId(value)}
              itemStyle={{ color: theme.label }}
            >
              {CODE_FORMATS.map((format) => (
                <Picker.Item
                  key={format.id}
                  label={format.name}
                  value={format.id}
                />
              ))}
            </Picker>
          </View>
        </View>
      </Modal>

      {/* Input Section - Native TextInput */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: theme.secondaryLabel }]}>
          CONTENT
        </Text>
        <TextInput
          key={selectedFormat.id}
          ref={inputRef}
          style={[
            styles.textInput,
            {
              color: theme.label,
              backgroundColor: theme.secondaryBackground,
            },
          ]}
          placeholder={selectedFormat.placeholder}
          placeholderTextColor={theme.tertiaryLabel}
          value={inputValue}
          onChangeText={setInputValue}
          maxLength={selectedFormat.maxLength}
          keyboardType={selectedFormat.keyboardType === "numeric" ? "number-pad" : "default"}
          autoCapitalize={selectedFormat.type === "qr" ? "none" : "characters"}
          autoCorrect={false}
          returnKeyType="done"
          onSubmitEditing={handleGenerate}
          clearButtonMode="while-editing"
          enablesReturnKeyAutomatically
        />
      </View>

      {/* Generate Button */}
      <Pressable
        style={[styles.generateButton, { backgroundColor: theme.blue }]}
        onPress={handleGenerate}
      >
        <SymbolView name="sparkles" size={20} tintColor="#fff" />
        <Text style={styles.generateButtonText}>Generate</Text>
      </Pressable>

      {/* Generated Code Display */}
      {generatedValue && (
        <View style={styles.section}>
          <Text style={[styles.sectionTitle, { color: theme.secondaryLabel }]}>
            GENERATED CODE
          </Text>
          <View
            ref={codeRef}
            style={[styles.codeContainer, { backgroundColor: "#FFFFFF" }]}
            collapsable={false}
          >
            {barcodeError ? (
              <View style={styles.errorContainer}>
                <SymbolView name="exclamationmark.triangle" size={40} tintColor="#FF3B30" />
                <Text style={styles.errorText}>Invalid barcode data</Text>
                <Text style={styles.errorSubtext}>Please check the input format</Text>
              </View>
            ) : selectedFormat.type === "qr" ? (
              <QRCode value={generatedValue} size={200} />
            ) : (
              <BarcodeErrorBoundary
                key={`${selectedFormat.id}-${generatedValue}`}
                onError={() => setBarcodeError(true)}
                fallback={
                  <View style={styles.errorContainer}>
                    <SymbolView name="exclamationmark.triangle" size={40} tintColor="#FF3B30" />
                    <Text style={styles.errorText}>Invalid barcode data</Text>
                    <Text style={styles.errorSubtext}>Please check the input format</Text>
                  </View>
                }
              >
                <Barcode
                  value={generatedValue}
                  options={{
                    format: selectedFormat.format,
                    background: "#fff",
                    lineColor: "#000",
                    width: 2,
                    height: 100,
                    displayValue: true,
                    fontSize: 16,
                  }}
                />
              </BarcodeErrorBoundary>
            )}
          </View>

          {/* Action Buttons */}
          <View style={styles.actionButtons}>
            <Pressable
              style={[styles.actionButton, { backgroundColor: theme.secondaryBackground }]}
              onPress={handleCopy}
            >
              <SymbolView
                name="photo.on.rectangle"
                size={20}
                tintColor={theme.blue}
              />
              <Text style={[styles.actionButtonText, { color: theme.blue }]}>
                Copy
              </Text>
            </Pressable>
            <Pressable
              style={[styles.actionButton, { backgroundColor: theme.secondaryBackground }]}
              onPress={handleShare}
            >
              <SymbolView
                name="square.and.arrow.up"
                size={20}
                tintColor={theme.blue}
              />
              <Text style={[styles.actionButtonText, { color: theme.blue }]}>
                Share
              </Text>
            </Pressable>
          </View>
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  contentContainer: {
    padding: 16,
    paddingBottom: 100,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: "600",
    marginBottom: 8,
    marginLeft: 4,
    letterSpacing: 0.5,
    textTransform: "uppercase",
  },
  selector: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    padding: 12,
    paddingHorizontal: 16,
    borderRadius: 10,
    borderCurve: "continuous",
  },
  selectorContent: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  selectorText: {
    fontSize: 17,
  },
  textInput: {
    fontSize: 17,
    padding: 12,
    paddingHorizontal: 16,
    borderRadius: 10,
    borderCurve: "continuous",
  },
  generateButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    padding: 16,
    borderRadius: 12,
    borderCurve: "continuous",
    marginBottom: 24,
  },
  generateButtonText: {
    color: "#fff",
    fontSize: 17,
    fontWeight: "600",
  },
  codeContainer: {
    alignItems: "center",
    justifyContent: "center",
    padding: 32,
    borderRadius: 12,
    borderCurve: "continuous",
    backgroundColor: "#fff",
    minHeight: 200,
  },
  actionButtons: {
    flexDirection: "row",
    gap: 12,
    marginTop: 12,
  },
  actionButton: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    padding: 14,
    borderRadius: 10,
    borderCurve: "continuous",
  },
  actionButtonText: {
    fontSize: 17,
    fontWeight: "600",
  },
  pickerModal: {
    flex: 1,
    justifyContent: "flex-end",
    backgroundColor: "rgba(0, 0, 0, 0.4)",
  },
  pickerContainer: {
    borderTopLeftRadius: 12,
    borderTopRightRadius: 12,
    overflow: "hidden",
  },
  pickerHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  pickerTitle: {
    fontSize: 17,
    fontWeight: "600",
  },
  pickerButton: {
    fontSize: 17,
  },
  pickerButtonDone: {
    fontWeight: "600",
  },
  errorContainer: {
    alignItems: "center",
    gap: 8,
  },
  errorText: {
    fontSize: 17,
    fontWeight: "600",
    color: "#FF3B30",
  },
  errorSubtext: {
    fontSize: 15,
    color: "#8E8E93",
  },
});
