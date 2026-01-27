import { useStorage } from "@/hooks/useStorage";
import {
  clearGenerationHistory,
  deleteGenerationFromHistory,
  getGenerationHistory,
  type GenerationHistoryItem,
} from "@/utils/generationHistory";
import {
  clearScanHistory,
  deleteScanFromHistory,
  getScanHistory,
  type ScanHistoryItem,
} from "@/utils/scanHistory";
import { useFocusEffect, useNavigation } from "@react-navigation/native";
import { useLayoutEffect } from "react";
// @ts-expect-error - no types available
import { Barcode } from "expo-barcode-generator";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import * as LocalAuthentication from "expo-local-authentication";
import * as Sharing from "expo-sharing";
import { SymbolView } from "expo-symbols";
import QRCodeUtil from "qrcode";
import { useCallback, useMemo, useRef, useState } from "react";
import {
  Alert,
  FlatList,
  Modal,
  Pressable,
  RefreshControl,
  Share,
  StyleSheet,
  Text,
  TextInput,
  useColorScheme,
  useWindowDimensions,
  View,
} from "react-native";
import Animated, {
  FadeIn,
  FadeInDown,
  FadeOut,
  LinearTransition,
} from "react-native-reanimated";
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

// Static colors for Reanimated (PlatformColor not supported)
const colors = {
  light: {
    background: "#F2F2F7",
    secondaryBackground: "#FFFFFF",
    tertiaryBackground: "#F2F2F7",
    label: "#000000",
    secondaryLabel: "#3C3C43",
    tertiaryLabel: "#8E8E93",
    blue: "#007AFF",
    red: "#FF3B30",
  },
  dark: {
    background: "#000000",
    secondaryBackground: "#1C1C1E",
    tertiaryBackground: "#2C2C2E",
    label: "#FFFFFF",
    secondaryLabel: "#EBEBF5",
    tertiaryLabel: "#636366",
    blue: "#0A84FF",
    red: "#FF453A",
  },
};

export default function ScanHistoryScreen() {
  const navigation = useNavigation();
  const [selectedTab, setSelectedTab] = useState(0);
  const [history, setHistory] = useState<ScanHistoryItem[]>([]);
  const [generations, setGenerations] = useState<GenerationHistoryItem[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isAuthenticating, setIsAuthenticating] = useState(false);
  const hasAttemptedAuthRef = useRef(false);
  const colorScheme = useColorScheme();
  const theme = colors[colorScheme ?? "light"];
  const { height: windowHeight } = useWindowDimensions();
  const [saveHistory, setSaveHistory] = useStorage("saveHistory", true);
  const [requireAuth] = useStorage("requireAuthForHistory", false);
  const [search, setSearch] = useState("");
  const [previewItem, setPreviewItem] = useState<GenerationHistoryItem | null>(
    null,
  );
  const [previewScanItem, setPreviewScanItem] = useState<ScanHistoryItem | null>(
    null,
  );
  const previewCodeRef = useRef<View>(null);
  const previewScanCodeRef = useRef<View>(null);

  // Hidden capture refs for copy/share without modal (using refs to avoid re-renders)
  const [, forceRenderCapture] = useState(0);
  const captureItemRef = useRef<GenerationHistoryItem | null>(null);
  const captureActionRef = useRef<"copy" | "share" | null>(null);
  const hiddenCaptureRef = useRef<View>(null);

  // Configure native search bar
  useLayoutEffect(() => {
    navigation.setOptions({
      headerSearchBarOptions: {
        placeholder: selectedTab === 0 ? "Search scans..." : "Search generations...",
        hideWhenScrolling: false,
        onChangeText: (event: { nativeEvent: { text: string } }) => {
          setSearch(event.nativeEvent.text);
        },
        onCancelButtonPress: () => {
          setSearch("");
        },
      },
    });
  }, [navigation, selectedTab]);

  // Handlers for preview modal image actions
  const handlePreviewCopy = useCallback(async () => {
    if (!previewCodeRef.current || !previewItem) return;
    try {
      const uri = await captureRef(previewCodeRef, {
        format: "png",
        quality: 1,
      });
      await Clipboard.setImageAsync(uri);
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert("Copied", "Image copied to clipboard");
    } catch {
      if (previewItem) {
        await Clipboard.setStringAsync(previewItem.data);
        await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        Alert.alert("Copied", "Text copied to clipboard");
      }
    }
  }, [previewItem]);

  const handlePreviewShare = useCallback(async () => {
    if (!previewCodeRef.current || !previewItem) return;
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
  }, [previewItem]);

  // Handlers for scan preview modal
  const handleScanPreviewCopy = useCallback(async () => {
    if (!previewScanCodeRef.current || !previewScanItem) return;
    try {
      const uri = await captureRef(previewScanCodeRef, {
        format: "png",
        quality: 1,
      });
      await Clipboard.setImageAsync(uri);
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert("Copied", "Image copied to clipboard");
    } catch {
      if (previewScanItem) {
        await Clipboard.setStringAsync(previewScanItem.data);
        await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        Alert.alert("Copied", "Text copied to clipboard");
      }
    }
  }, [previewScanItem]);

  const handleScanPreviewShare = useCallback(async () => {
    if (!previewScanCodeRef.current || !previewScanItem) return;
    try {
      const uri = await captureRef(previewScanCodeRef, {
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
  }, [previewScanItem]);

  // Map scan type to barcode format for rendering
  const getBarcodeFormat = (type: string): string | null => {
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
  };

  // Check if we can render a preview for this barcode type
  const canRenderScanPreview = (type: string): boolean => {
    return type === "qr" || getBarcodeFormat(type) !== null;
  };

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

  // Copy/Share from list (hidden capture)
  const handleGenerationCopy = (item: GenerationHistoryItem) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    captureItemRef.current = item;
    captureActionRef.current = "copy";
    forceRenderCapture((n) => n + 1);

    // Use requestAnimationFrame for minimal delay
    requestAnimationFrame(() => {
      requestAnimationFrame(async () => {
        if (!hiddenCaptureRef.current || !captureItemRef.current) return;
        const itemData = captureItemRef.current.data;
        try {
          const uri = await captureRef(hiddenCaptureRef, {
            format: "png",
            quality: 1,
          });
          captureItemRef.current = null;
          captureActionRef.current = null;
          try {
            await Clipboard.setImageAsync(uri);
            await Haptics.notificationAsync(
              Haptics.NotificationFeedbackType.Success,
            );
            Alert.alert("Copied", "Image copied to clipboard");
          } catch {
            await Clipboard.setStringAsync(itemData);
            Alert.alert("Copied", "Text copied to clipboard");
          }
        } catch {
          captureItemRef.current = null;
          captureActionRef.current = null;
          Alert.alert("Error", "Failed to capture the code");
        }
      });
    });
  };

  const handleGenerationShare = (item: GenerationHistoryItem) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    captureItemRef.current = item;
    captureActionRef.current = "share";
    forceRenderCapture((n) => n + 1);

    // Use requestAnimationFrame for minimal delay
    requestAnimationFrame(() => {
      requestAnimationFrame(async () => {
        if (!hiddenCaptureRef.current || !captureItemRef.current) return;
        try {
          const uri = await captureRef(hiddenCaptureRef, {
            format: "png",
            quality: 1,
          });
          captureItemRef.current = null;
          captureActionRef.current = null;
          if (await Sharing.isAvailableAsync()) {
            await Sharing.shareAsync(uri);
          } else {
            Alert.alert("Error", "Sharing is not available on this device");
          }
        } catch {
          captureItemRef.current = null;
          captureActionRef.current = null;
          Alert.alert("Error", "Failed to capture the code");
        }
      });
    });
  };

  // Filter history based on search
  const filteredHistory = useMemo(() => {
    if (!search) return history;
    const query = search.toLowerCase();
    return history.filter(
      (item) =>
        item.data.toLowerCase().includes(query) ||
        item.type.toLowerCase().includes(query) ||
        item.formattedDate.toLowerCase().includes(query),
    );
  }, [history, search]);

  // Filter generations based on search
  const filteredGenerations = useMemo(() => {
    if (!search) return generations;
    const query = search.toLowerCase();
    return generations.filter(
      (item) =>
        item.data.toLowerCase().includes(query) ||
        item.formatName.toLowerCase().includes(query) ||
        item.formattedDate.toLowerCase().includes(query),
    );
  }, [generations, search]);

  const loadHistory = useCallback(async () => {
    const [scanHistory, genHistory] = await Promise.all([
      getScanHistory(),
      getGenerationHistory(),
    ]);
    setHistory(scanHistory);
    setGenerations(genHistory);
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadHistory();
    setRefreshing(false);
  };

  const performAuth = useCallback(async () => {
    setIsAuthenticating(true);

    try {
      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: "Authenticate to view history",
        cancelLabel: "Cancel",
        fallbackLabel: "Use Passcode",
      });

      if (result.success) {
        setIsAuthenticated(true);
        const scanHistory = await getScanHistory();
        setHistory(scanHistory);
      }
    } finally {
      setIsAuthenticating(false);
    }
  }, []);

  // Auto-authenticate on focus (only once)
  const autoAuthenticate = useCallback(async () => {
    if (hasAttemptedAuthRef.current) return;
    hasAttemptedAuthRef.current = true;
    await performAuth();
  }, [performAuth]);

  // Manual unlock button handler
  const handleUnlock = useCallback(async () => {
    if (isAuthenticating) return;
    await performAuth();
  }, [isAuthenticating, performAuth]);

  // Handle focus - load history or authenticate
  useFocusEffect(
    useCallback(() => {
      if (requireAuth) {
        autoAuthenticate();
      } else {
        loadHistory();
      }

      // Cleanup when leaving tab
      return () => {
        if (requireAuth) {
          setIsAuthenticated(false);
          hasAttemptedAuthRef.current = false;
        }
      };
    }, [requireAuth, loadHistory, autoAuthenticate]),
  );

  const handleCopyItem = async (data: string) => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await Clipboard.setStringAsync(data);
    Alert.alert("Copied", "Text copied to clipboard");
  };

  const handleShareItem = async (data: string) => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await Share.share({ message: data });
  };

  const handleDeleteItem = async (id: string) => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    Alert.alert("Delete Scan", "Are you sure you want to delete this scan?", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Delete",
        style: "destructive",
        onPress: async () => {
          await Haptics.notificationAsync(
            Haptics.NotificationFeedbackType.Success,
          );
          await deleteScanFromHistory(id);
          await loadHistory();
        },
      },
    ]);
  };

  const handleClearAll = () => {
    const isScans = selectedTab === 0;
    Alert.alert(
      isScans ? "Clear Scan History" : "Clear Generation History",
      isScans
        ? "Delete all scan history? This cannot be undone."
        : "Delete all generation history? This cannot be undone.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Clear All",
          style: "destructive",
          onPress: async () => {
            await Haptics.notificationAsync(
              Haptics.NotificationFeedbackType.Warning,
            );
            if (isScans) {
              await clearScanHistory();
            } else {
              await clearGenerationHistory();
            }
            await loadHistory();
          },
        },
      ],
    );
  };

  const handleDeleteGeneration = async (id: string) => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    Alert.alert(
      "Delete Generation",
      "Are you sure you want to delete this generation?",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: async () => {
            await Haptics.notificationAsync(
              Haptics.NotificationFeedbackType.Success,
            );
            await deleteGenerationFromHistory(id);
            await loadHistory();
          },
        },
      ],
    );
  };

  const renderScanItem = ({
    item,
    index,
  }: {
    item: ScanHistoryItem;
    index: number;
  }) => (
    <Animated.View
      entering={FadeInDown.delay(index * 50).duration(300)}
      exiting={FadeOut.duration(200)}
      layout={LinearTransition}
    >
      <View
        style={[
          styles.scanCard,
          { backgroundColor: theme.secondaryBackground },
        ]}
      >
        <View style={styles.cardHeader}>
          <View
            style={[styles.typeBadge, { backgroundColor: theme.blue + "20" }]}
          >
            <SymbolView
              name="qrcode"
              tintColor={theme.blue}
              style={{ width: 14, height: 14 }}
            />
            <Text style={[styles.typeText, { color: theme.blue }]}>
              {item.type.toUpperCase()}
            </Text>
          </View>
          <Text style={[styles.dateText, { color: theme.tertiaryLabel }]}>
            {item.formattedDate}
          </Text>
        </View>

        <TextInput
          style={[styles.dataText, { color: theme.label }]}
          value={item.data}
          editable={false}
          multiline
          scrollEnabled={false}
        />

        <View style={styles.cardActions}>
          <Pressable
            style={({ pressed }) => [
              styles.cardButton,
              { backgroundColor: theme.tertiaryBackground },
              pressed && styles.buttonPressed,
            ]}
            onPress={() => handleCopyItem(item.data)}
          >
            <SymbolView
              name="doc.on.doc"
              tintColor={theme.blue}
              style={{ width: 16, height: 16 }}
            />
            <Text style={[styles.cardButtonText, { color: theme.blue }]}>
              Copy
            </Text>
          </Pressable>

          <Pressable
            style={({ pressed }) => [
              styles.cardButton,
              { backgroundColor: theme.tertiaryBackground },
              pressed && styles.buttonPressed,
            ]}
            onPress={() => handleShareItem(item.data)}
          >
            <SymbolView
              name="square.and.arrow.up"
              tintColor={theme.blue}
              style={{ width: 16, height: 16 }}
            />
            <Text style={[styles.cardButtonText, { color: theme.blue }]}>
              Share
            </Text>
          </Pressable>

          {canRenderScanPreview(item.type) && (
            <Pressable
              style={({ pressed }) => [
                styles.cardButton,
                { backgroundColor: theme.tertiaryBackground },
                pressed && styles.buttonPressed,
              ]}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                setPreviewScanItem(item);
              }}
            >
              <SymbolView
                name="eye"
                tintColor={theme.blue}
                style={{ width: 16, height: 16 }}
              />
              <Text style={[styles.cardButtonText, { color: theme.blue }]}>
                Preview
              </Text>
            </Pressable>
          )}

          <Pressable
            style={({ pressed }) => [
              styles.cardButton,
              styles.deleteButton,
              { backgroundColor: theme.tertiaryBackground },
              pressed && styles.buttonPressed,
            ]}
            onPress={() => handleDeleteItem(item.id)}
          >
            <SymbolView
              name="trash"
              tintColor={theme.red}
              style={{ width: 16, height: 16 }}
            />
          </Pressable>
        </View>
      </View>
    </Animated.View>
  );

  const renderGenerationItem = ({
    item,
    index,
  }: {
    item: GenerationHistoryItem;
    index: number;
  }) => (
    <Animated.View
      entering={FadeInDown.delay(index * 50).duration(300)}
      exiting={FadeOut.duration(200)}
      layout={LinearTransition}
    >
      <View
        style={[
          styles.scanCard,
          { backgroundColor: theme.secondaryBackground },
        ]}
      >
        <View style={styles.cardHeader}>
          <View
            style={[styles.typeBadge, { backgroundColor: theme.blue + "20" }]}
          >
            <SymbolView
              name="barcode"
              tintColor={theme.blue}
              style={{ width: 14, height: 14 }}
            />
            <Text style={[styles.typeText, { color: theme.blue }]}>
              {item.formatName}
            </Text>
          </View>
          <Text style={[styles.dateText, { color: theme.tertiaryLabel }]}>
            {item.formattedDate}
          </Text>
        </View>

        <TextInput
          style={[styles.dataText, { color: theme.label }]}
          value={item.data}
          editable={false}
          multiline
          scrollEnabled={false}
        />

        <View style={styles.cardActions}>
          <Pressable
            style={({ pressed }) => [
              styles.cardButton,
              { backgroundColor: theme.tertiaryBackground },
              pressed && styles.buttonPressed,
            ]}
            onPress={() => handleGenerationCopy(item)}
          >
            <SymbolView
              name="photo.on.rectangle"
              tintColor={theme.blue}
              style={{ width: 16, height: 16 }}
            />
            <Text style={[styles.cardButtonText, { color: theme.blue }]}>
              Copy
            </Text>
          </Pressable>

          <Pressable
            style={({ pressed }) => [
              styles.cardButton,
              { backgroundColor: theme.tertiaryBackground },
              pressed && styles.buttonPressed,
            ]}
            onPress={() => handleGenerationShare(item)}
          >
            <SymbolView
              name="square.and.arrow.up"
              tintColor={theme.blue}
              style={{ width: 16, height: 16 }}
            />
            <Text style={[styles.cardButtonText, { color: theme.blue }]}>
              Share
            </Text>
          </Pressable>

          <Pressable
            style={({ pressed }) => [
              styles.cardButton,
              { backgroundColor: theme.tertiaryBackground },
              pressed && styles.buttonPressed,
            ]}
            onPress={() => {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
              setPreviewItem(item);
            }}
          >
            <SymbolView
              name="eye"
              tintColor={theme.blue}
              style={{ width: 16, height: 16 }}
            />
            <Text style={[styles.cardButtonText, { color: theme.blue }]}>
              Preview
            </Text>
          </Pressable>

          <Pressable
            style={({ pressed }) => [
              styles.cardButton,
              styles.deleteButton,
              { backgroundColor: theme.tertiaryBackground },
              pressed && styles.buttonPressed,
            ]}
            onPress={() => handleDeleteGeneration(item.id)}
          >
            <SymbolView
              name="trash"
              tintColor={theme.red}
              style={{ width: 16, height: 16 }}
            />
          </Pressable>
        </View>
      </View>
    </Animated.View>
  );

  const handleEnableHistory = async () => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setSaveHistory(true);
  };

  // Calculate height for empty state (account for header ~140pt and tab bar ~83pt)
  const emptyStateHeight = windowHeight - 223;

  const renderDisabledState = () => (
    <Animated.View
      entering={FadeIn.duration(400)}
      style={[styles.emptyContainer, { height: emptyStateHeight }]}
    >
      <View
        style={[
          styles.disabledIconContainer,
          { backgroundColor: theme.tertiaryBackground },
        ]}
      >
        <SymbolView
          name="clock.badge.xmark"
          tintColor={theme.tertiaryLabel}
          style={{ width: 56, height: 56 }}
        />
      </View>
      <Text style={[styles.emptyTitle, { color: theme.label }]}>
        History Disabled
      </Text>
      <Text style={[styles.emptyDescription, { color: theme.secondaryLabel }]}>
        Scan history is turned off. Enable it to keep a record of your scans.
      </Text>
      <Pressable
        style={({ pressed }) => [
          styles.enableButton,
          { backgroundColor: theme.blue },
          pressed && styles.enableButtonPressed,
        ]}
        onPress={handleEnableHistory}
      >
        <SymbolView
          name="clock.arrow.circlepath"
          tintColor="#FFFFFF"
          style={{ width: 18, height: 18 }}
        />
        <Text style={styles.enableButtonText}>Enable History</Text>
      </Pressable>
    </Animated.View>
  );

  const renderEmptyState = () => {
    const isScansTab = selectedTab === 0;
    const currentList = isScansTab ? history : generations;

    // Show no results state when searching
    if (search && currentList.length > 0) {
      return (
        <Animated.View
          entering={FadeIn.duration(400)}
          style={[styles.emptyContainer, { height: emptyStateHeight }]}
        >
          <View style={styles.emptyIconContainer}>
            <SymbolView
              name="magnifyingglass"
              tintColor={theme.tertiaryLabel}
              style={{ width: 60, height: 60 }}
            />
          </View>
          <Text style={[styles.emptyTitle, { color: theme.label }]}>
            No Results
          </Text>
          <Text
            style={[styles.emptyDescription, { color: theme.secondaryLabel }]}
          >
            No {isScansTab ? "scans" : "generations"} found for "{search}"
          </Text>
        </Animated.View>
      );
    }

    // For scans tab, show disabled state if history is turned off
    if (isScansTab && !saveHistory) {
      return renderDisabledState();
    }

    // Empty state for scans
    if (isScansTab) {
      return (
        <Animated.View
          entering={FadeIn.duration(400)}
          style={[styles.emptyContainer, { height: emptyStateHeight }]}
        >
          <View style={styles.emptyIconContainer}>
            <SymbolView
              name="qrcode.viewfinder"
              tintColor={theme.tertiaryLabel}
              style={{ width: 80, height: 80 }}
            />
          </View>
          <Text style={[styles.emptyTitle, { color: theme.label }]}>
            No Scans Yet
          </Text>
          <Text
            style={[styles.emptyDescription, { color: theme.secondaryLabel }]}
          >
            Scanned barcodes and QR codes will appear here
          </Text>
        </Animated.View>
      );
    }

    // Empty state for generations
    return (
      <Animated.View
        entering={FadeIn.duration(400)}
        style={[styles.emptyContainer, { height: emptyStateHeight }]}
      >
        <View style={styles.emptyIconContainer}>
          <SymbolView
            name="barcode"
            tintColor={theme.tertiaryLabel}
            style={{ width: 80, height: 80 }}
          />
        </View>
        <Text style={[styles.emptyTitle, { color: theme.label }]}>
          No Generations Yet
        </Text>
        <Text
          style={[styles.emptyDescription, { color: theme.secondaryLabel }]}
        >
          Generated QR codes and barcodes will appear here
        </Text>
      </Animated.View>
    );
  };

  const renderDisabledBanner = () => {
    if (saveHistory) return null;
    return (
      <Animated.View
        entering={FadeIn}
        style={[
          styles.disabledBanner,
          { backgroundColor: theme.secondaryBackground },
        ]}
      >
        <View style={styles.disabledBannerContent}>
          <SymbolView
            name="exclamationmark.circle.fill"
            tintColor="#FF9500"
            style={{ width: 24, height: 24 }}
          />
          <View style={styles.disabledBannerText}>
            <Text style={[styles.disabledBannerTitle, { color: theme.label }]}>
              History Paused
            </Text>
            <Text
              style={[
                styles.disabledBannerDescription,
                { color: theme.secondaryLabel },
              ]}
            >
              New scans won't be saved
            </Text>
          </View>
        </View>
        <Pressable
          style={({ pressed }) => [
            styles.enableBannerButton,
            { backgroundColor: theme.blue },
            pressed && styles.buttonPressed,
          ]}
          onPress={handleEnableHistory}
        >
          <Text style={styles.enableBannerButtonText}>Enable</Text>
        </Pressable>
      </Animated.View>
    );
  };

  const renderHeader = () => {
    const banner = renderDisabledBanner();
    const isScans = selectedTab === 0;
    const currentList = isScans ? history : generations;
    const currentFiltered = isScans ? filteredHistory : filteredGenerations;
    const hasItems = currentList.length > 0;
    const isSearching = search.length > 0;
    const itemName = isScans ? "scan" : "generation";
    const itemNamePlural = isScans ? "scans" : "generations";

    return (
      <View>
        {/* Segmented Control */}
        <View
          style={[
            styles.segmentedControlContainer,
            { backgroundColor: theme.tertiaryBackground },
          ]}
        >
          <Pressable
            style={[
              styles.segmentedButton,
              selectedTab === 0 && [
                styles.segmentedButtonActive,
                { backgroundColor: theme.secondaryBackground },
              ],
            ]}
            onPress={() => {
              if (selectedTab !== 0) {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                setSelectedTab(0);
                setSearch("");
              }
            }}
          >
            <Text
              style={[
                styles.segmentedButtonText,
                { color: selectedTab === 0 ? theme.label : theme.secondaryLabel },
              ]}
            >
              Scans
            </Text>
          </Pressable>
          <Pressable
            style={[
              styles.segmentedButton,
              selectedTab === 1 && [
                styles.segmentedButtonActive,
                { backgroundColor: theme.secondaryBackground },
              ],
            ]}
            onPress={() => {
              if (selectedTab !== 1) {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                setSelectedTab(1);
                setSearch("");
              }
            }}
          >
            <Text
              style={[
                styles.segmentedButtonText,
                { color: selectedTab === 1 ? theme.label : theme.secondaryLabel },
              ]}
            >
              Generations
            </Text>
          </Pressable>
        </View>
        {banner}
        {hasItems && (
          <View style={styles.listHeader}>
            <Text
              style={[styles.listHeaderText, { color: theme.secondaryLabel }]}
            >
              {isSearching
                ? `${currentFiltered.length} of ${currentList.length} ${itemNamePlural}`
                : `${currentList.length} ${currentList.length === 1 ? itemName : itemNamePlural}`}
            </Text>
            {!isSearching && (
              <Pressable
                style={({ pressed }) => [
                  styles.clearAllButton,
                  { backgroundColor: theme.red + "20" },
                  pressed && styles.buttonPressed,
                ]}
                onPress={handleClearAll}
              >
                <SymbolView
                  name="trash"
                  tintColor={theme.red}
                  style={{ width: 14, height: 14 }}
                />
                <Text style={[styles.clearAllText, { color: theme.red }]}>
                  Clear All
                </Text>
              </Pressable>
            )}
          </View>
        )}
      </View>
    );
  };

  // Show locked screen when authentication is required but not authenticated
  if (requireAuth && !isAuthenticated) {
    return (
      <View style={[styles.container, { backgroundColor: theme.background }]}>
        <Animated.View
          entering={FadeIn.duration(400)}
          style={styles.lockedContainer}
        >
          <View
            style={[
              styles.lockedIconContainer,
              { backgroundColor: theme.blue + "15" },
            ]}
          >
            <SymbolView
              name="lock.fill"
              tintColor={theme.blue}
              style={{ width: 48, height: 48 }}
            />
          </View>
          <Text style={[styles.lockedTitle, { color: theme.label }]}>
            History Locked
          </Text>
          <Text style={[styles.lockedSubtitle, { color: theme.secondaryLabel }]}>
            Authenticate to view your scan history
          </Text>
          <Pressable
            style={({ pressed }) => [
              styles.unlockButton,
              { backgroundColor: theme.blue },
              pressed && styles.buttonPressed,
            ]}
            onPress={handleUnlock}
            disabled={isAuthenticating}
          >
            <SymbolView
              name="faceid"
              tintColor="#FFFFFF"
              style={{ width: 22, height: 22 }}
            />
            <Text style={styles.unlockButtonText}>
              {isAuthenticating ? "Authenticating..." : "Unlock"}
            </Text>
          </Pressable>
        </Animated.View>
      </View>
    );
  }

  const isScans = selectedTab === 0;
  const currentList = isScans ? history : generations;
  const currentFilteredList = isScans ? filteredHistory : filteredGenerations;
  const isEmpty = currentList.length === 0;

  return (
    <>
      <FlatList<ScanHistoryItem | GenerationHistoryItem>
        style={[styles.container, { backgroundColor: theme.background }]}
        data={currentFilteredList}
        renderItem={({ item, index }) =>
          isScans
            ? renderScanItem({ item: item as ScanHistoryItem, index })
            : renderGenerationItem({
                item: item as GenerationHistoryItem,
                index,
              })
        }
        keyExtractor={(item) => item.id}
        contentContainerStyle={[
          styles.listContent,
          isEmpty && styles.listContentEmpty,
        ]}
        contentInsetAdjustmentBehavior="automatic"
        ListHeaderComponent={renderHeader}
        ListEmptyComponent={renderEmptyState}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            tintColor={theme.blue}
          />
        }
        showsVerticalScrollIndicator={false}
        keyboardDismissMode="on-drag"
        keyboardShouldPersistTaps="handled"
        removeClippedSubviews={false}
        ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
        bounces={!isEmpty}
        scrollEnabled={!isEmpty || refreshing}
      />

      {/* Preview Modal */}
      <Modal
        visible={previewItem !== null}
        animationType="fade"
        transparent
        onRequestClose={() => setPreviewItem(null)}
      >
        <Pressable
          style={styles.previewModalOverlay}
          onPress={() => setPreviewItem(null)}
        >
          <Pressable
            style={[
              styles.previewModalContent,
              { backgroundColor: theme.secondaryBackground },
            ]}
            onPress={(e) => e.stopPropagation()}
          >
            {previewItem && (
              <>
                <View style={styles.previewHeader}>
                  <Text style={[styles.previewTitle, { color: theme.label }]}>
                    {previewItem.formatName}
                  </Text>
                  <Pressable
                    onPress={() => setPreviewItem(null)}
                    hitSlop={10}
                    style={({ pressed }) => pressed && { opacity: 0.6 }}
                  >
                    <SymbolView
                      name="xmark.circle.fill"
                      tintColor={theme.tertiaryLabel}
                      style={{ width: 28, height: 28 }}
                    />
                  </Pressable>
                </View>

                <View
                  ref={previewCodeRef}
                  style={styles.previewCodeContainer}
                  collapsable={false}
                >
                  {previewItem.format === "qr" ? (
                    <QRCode value={previewItem.data} size={200} />
                  ) : (
                    <Barcode
                      value={previewItem.data}
                      options={{
                        format: previewItem.format.toUpperCase(),
                        background: "#fff",
                        lineColor: "#000",
                        width: 1.5,
                        height: 80,
                        displayValue: true,
                        fontSize: 12,
                      }}
                    />
                  )}
                </View>

                <Text
                  style={[styles.previewData, { color: theme.secondaryLabel }]}
                  numberOfLines={3}
                  selectable
                >
                  {previewItem.data}
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
              </>
            )}
          </Pressable>
        </Pressable>
      </Modal>

      {/* Scan Preview Modal */}
      <Modal
        visible={previewScanItem !== null}
        animationType="fade"
        transparent
        onRequestClose={() => setPreviewScanItem(null)}
      >
        <Pressable
          style={styles.previewModalOverlay}
          onPress={() => setPreviewScanItem(null)}
        >
          <Pressable
            style={[
              styles.previewModalContent,
              { backgroundColor: theme.secondaryBackground },
            ]}
            onPress={(e) => e.stopPropagation()}
          >
            {previewScanItem && (
              <>
                <View style={styles.previewHeader}>
                  <Text style={[styles.previewTitle, { color: theme.label }]}>
                    {getCodeTypeName(previewScanItem.type)}
                  </Text>
                  <Pressable
                    onPress={() => setPreviewScanItem(null)}
                    hitSlop={10}
                    style={({ pressed }) => pressed && { opacity: 0.6 }}
                  >
                    <SymbolView
                      name="xmark.circle.fill"
                      tintColor={theme.tertiaryLabel}
                      style={{ width: 28, height: 28 }}
                    />
                  </Pressable>
                </View>

                <View
                  ref={previewScanCodeRef}
                  style={styles.previewCodeContainer}
                  collapsable={false}
                >
                  {previewScanItem.type === "qr" ? (
                    <QRCode value={previewScanItem.data} size={200} />
                  ) : getBarcodeFormat(previewScanItem.type) ? (
                    <Barcode
                      value={previewScanItem.data}
                      options={{
                        format: getBarcodeFormat(previewScanItem.type),
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
                  {previewScanItem.data}
                </Text>

                <View style={styles.previewActions}>
                  <Pressable
                    style={[
                      styles.previewButton,
                      { backgroundColor: theme.blue },
                    ]}
                    onPress={handleScanPreviewCopy}
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
                    onPress={handleScanPreviewShare}
                  >
                    <SymbolView
                      name="square.and.arrow.up"
                      tintColor="#FFFFFF"
                      style={{ width: 18, height: 18 }}
                    />
                    <Text style={styles.previewButtonText}>Share</Text>
                  </Pressable>
                </View>
              </>
            )}
          </Pressable>
        </Pressable>
      </Modal>

      {/* Hidden view for capturing codes without showing modal */}
      {captureItemRef.current && (
        <View
          style={{
            position: "absolute",
            left: -9999,
            top: -9999,
          }}
        >
          <View
            ref={hiddenCaptureRef}
            style={{
              padding: 16,
              backgroundColor: "#FFFFFF",
            }}
            collapsable={false}
          >
            {captureItemRef.current.format === "qr" ? (
              <QRCode value={captureItemRef.current.data} size={220} />
            ) : (
              <Barcode
                value={captureItemRef.current.data}
                options={{
                  format: captureItemRef.current.format.toUpperCase(),
                  background: "#fff",
                  lineColor: "#000",
                  width: 2,
                  height: 100,
                  displayValue: true,
                  fontSize: 16,
                }}
              />
            )}
          </View>
        </View>
      )}
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  listContent: {
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 20,
  },
  listContentEmpty: {
    flexGrow: 1,
    paddingTop: 0,
    paddingBottom: 0,
  },
  segmentedControlContainer: {
    flexDirection: "row",
    padding: 3,
    borderRadius: 10,
    borderCurve: "continuous",
    marginBottom: 16,
  },
  segmentedButton: {
    flex: 1,
    paddingVertical: 8,
    alignItems: "center",
    borderRadius: 8,
    borderCurve: "continuous",
  },
  segmentedButtonActive: {
    boxShadow: "0 1px 3px rgba(0, 0, 0, 0.1)",
  },
  segmentedButtonText: {
    fontSize: 13,
    fontWeight: "600",
  },
  disabledBanner: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    padding: 14,
    borderRadius: 12,
    borderCurve: "continuous",
    marginBottom: 16,
  },
  disabledBannerContent: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    flex: 1,
  },
  disabledBannerText: {
    flex: 1,
  },
  disabledBannerTitle: {
    fontSize: 15,
    fontWeight: "600",
  },
  disabledBannerDescription: {
    fontSize: 13,
    marginTop: 2,
  },
  enableBannerButton: {
    paddingVertical: 8,
    paddingHorizontal: 14,
    borderRadius: 8,
    borderCurve: "continuous",
  },
  enableBannerButtonText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "600",
  },
  listHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 16,
  },
  listHeaderText: {
    fontSize: 14,
    fontWeight: "500",
    textTransform: "uppercase",
    letterSpacing: 0.5,
  },
  clearAllButton: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderCurve: "continuous",
  },
  clearAllText: {
    fontSize: 14,
    fontWeight: "600",
  },
  scanCard: {
    borderRadius: 16,
    borderCurve: "continuous",
    padding: 16,
    boxShadow: "0 1px 4px rgba(0, 0, 0, 0.06)",
  },
  cardPressed: {
    opacity: 0.8,
    transform: [{ scale: 0.98 }],
  },
  cardHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 12,
  },
  typeBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingVertical: 4,
    paddingHorizontal: 8,
    borderRadius: 6,
    borderCurve: "continuous",
  },
  typeText: {
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 0.5,
  },
  dateText: {
    fontSize: 13,
  },
  dataText: {
    fontSize: 15,
    lineHeight: 22,
    fontFamily: "Menlo",
    marginBottom: 14,
  },
  cardActions: {
    flexDirection: "row",
    gap: 8,
  },
  cardButton: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderCurve: "continuous",
  },
  deleteButton: {
    marginLeft: "auto",
    paddingHorizontal: 10,
  },
  cardButtonText: {
    fontSize: 14,
    fontWeight: "500",
  },
  buttonPressed: {
    opacity: 0.7,
    transform: [{ scale: 0.96 }],
  },
  emptyContainer: {
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 40,
  },
  emptyIconContainer: {
    marginBottom: 24,
    opacity: 0.6,
  },
  disabledIconContainer: {
    width: 100,
    height: 100,
    borderRadius: 50,
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 24,
  },
  emptyTitle: {
    fontSize: 22,
    fontWeight: "700",
    marginBottom: 8,
  },
  emptyDescription: {
    fontSize: 16,
    textAlign: "center",
    lineHeight: 22,
  },
  enableButton: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    marginTop: 24,
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 14,
    borderCurve: "continuous",
  },
  enableButtonPressed: {
    opacity: 0.8,
    transform: [{ scale: 0.98 }],
  },
  enableButtonText: {
    color: "#FFFFFF",
    fontSize: 17,
    fontWeight: "600",
  },
  lockedContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    padding: 40,
  },
  lockedIconContainer: {
    width: 100,
    height: 100,
    borderRadius: 50,
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 24,
  },
  lockedTitle: {
    fontSize: 24,
    fontWeight: "700",
    marginBottom: 8,
  },
  lockedSubtitle: {
    fontSize: 16,
    textAlign: "center",
    marginBottom: 32,
  },
  unlockButton: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingVertical: 14,
    paddingHorizontal: 28,
    borderRadius: 14,
    borderCurve: "continuous",
  },
  unlockButtonText: {
    color: "#FFFFFF",
    fontSize: 17,
    fontWeight: "600",
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
