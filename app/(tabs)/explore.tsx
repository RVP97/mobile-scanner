import { useFocusEffect } from "@react-navigation/native";
import * as Clipboard from "expo-clipboard";
import { useCallback, useState } from "react";
import {
  Alert,
  FlatList,
  RefreshControl,
  Share,
  StyleSheet,
  TouchableOpacity,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { ThemedText } from "@/components/ThemedText";
import { ThemedView } from "@/components/ThemedView";
import { IconSymbol } from "@/components/ui/IconSymbol";
import { Colors } from "@/constants/Colors";
import { useColorScheme } from "@/hooks/useColorScheme";
import {
  clearScanHistory,
  deleteScanFromHistory,
  getScanHistory,
  type ScanHistoryItem,
} from "../../utils/scanHistory";

export default function ScanHistoryScreen() {
  const [history, setHistory] = useState<ScanHistoryItem[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const colorScheme = useColorScheme();
  const insets = useSafeAreaInsets();

  const loadHistory = useCallback(async () => {
    try {
      const scanHistory = await getScanHistory();
      setHistory(scanHistory);
    } catch (error) {
      console.error("Error loading scan history:", error);
    }
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadHistory();
    setRefreshing(false);
  };

  useFocusEffect(
    useCallback(() => {
      loadHistory();
    }, [loadHistory]),
  );

  const handleCopyItem = async (data: string) => {
    await Clipboard.setStringAsync(data);
    Alert.alert("Copied!", "Scan data has been copied to clipboard");
  };

  const handleShareItem = async (data: string) => {
    try {
      await Share.share({
        message: data,
      });
    } catch {
      Alert.alert("Error", "Unable to share the scan data");
    }
  };

  const handleDeleteItem = (id: string) => {
    Alert.alert(
      "Delete Scan",
      "Are you sure you want to delete this scan from history?",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: async () => {
            await deleteScanFromHistory(id);
            await loadHistory();
          },
        },
      ],
    );
  };

  const handleClearAll = () => {
    Alert.alert(
      "Clear All History",
      "Are you sure you want to delete all scan history? This action cannot be undone.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Clear All",
          style: "destructive",
          onPress: async () => {
            await clearScanHistory();
            await loadHistory();
          },
        },
      ],
    );
  };

  const renderScanItem = ({ item }: { item: ScanHistoryItem }) => (
    <ThemedView style={styles.scanItem}>
      <ThemedView style={styles.scanHeader}>
        <ThemedView style={styles.scanInfo}>
          <ThemedText style={styles.scanType}>
            {item.type.toUpperCase()}
          </ThemedText>
          <ThemedText style={styles.scanDate}>{item.formattedDate}</ThemedText>
        </ThemedView>
        <TouchableOpacity
          style={styles.deleteButton}
          onPress={() => handleDeleteItem(item.id)}
        >
          <IconSymbol size={20} name="trash" color="#FF3B30" />
        </TouchableOpacity>
      </ThemedView>

      <TouchableOpacity
        style={styles.scanDataContainer}
        onPress={() => handleCopyItem(item.data)}
        activeOpacity={0.7}
      >
        <ThemedText style={styles.scanData} numberOfLines={3}>
          {item.data}
        </ThemedText>
        <ThemedText style={styles.tapHint}>Tap to copy</ThemedText>
      </TouchableOpacity>

      <ThemedView style={styles.scanActions}>
        <TouchableOpacity
          style={[styles.actionButton, styles.copyButton]}
          onPress={() => handleCopyItem(item.data)}
        >
          <IconSymbol size={16} name="doc.on.doc" color="#FFFFFF" />
          <ThemedText style={styles.actionButtonText}>Copy</ThemedText>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.actionButton, styles.shareButton]}
          onPress={() => handleShareItem(item.data)}
        >
          <IconSymbol size={16} name="square.and.arrow.up" color="#FFFFFF" />
          <ThemedText style={styles.actionButtonText}>Share</ThemedText>
        </TouchableOpacity>
      </ThemedView>
    </ThemedView>
  );

  const renderEmptyState = () => (
    <ThemedView style={styles.emptyState}>
      <IconSymbol
        size={80}
        name="qrcode.viewfinder"
        color={Colors[colorScheme ?? "light"].text}
        style={styles.emptyIcon}
      />
      <ThemedText type="title" style={styles.emptyTitle}>
        No Scans Yet
      </ThemedText>
      <ThemedText style={styles.emptyDescription}>
        Your scan history will appear here after you scan your first barcode or
        QR code.
      </ThemedText>
    </ThemedView>
  );

  return (
    <ThemedView style={styles.container}>
      <ThemedView style={[styles.header, { paddingTop: insets.top + 20 }]}>
        <ThemedText type="title" style={styles.headerTitle}>
          Scan History
        </ThemedText>
        {history.length > 0 && (
          <TouchableOpacity style={styles.clearButton} onPress={handleClearAll}>
            <IconSymbol size={20} name="trash.fill" color="#FF3B30" />
            <ThemedText style={styles.clearButtonText}>Clear All</ThemedText>
          </TouchableOpacity>
        )}
      </ThemedView>

      {history.length === 0 ? (
        renderEmptyState()
      ) : (
        <FlatList
          data={history}
          renderItem={renderScanItem}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContainer}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={onRefresh}
              tintColor={Colors[colorScheme ?? "light"].tint}
            />
          }
          showsVerticalScrollIndicator={false}
        />
      )}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 20,
    paddingBottom: 10,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: "bold",
  },
  clearButton: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
    backgroundColor: "rgba(255, 59, 48, 0.1)",
  },
  clearButtonText: {
    color: "#FF3B30",
    marginLeft: 4,
    fontSize: 14,
    fontWeight: "600",
  },
  listContainer: {
    paddingHorizontal: 20,
    paddingBottom: 100,
  },
  scanItem: {
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: "rgba(0, 0, 0, 0.1)",
    backgroundColor: "rgba(0, 0, 0, 0.02)",
  },
  scanHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    marginBottom: 12,
  },
  scanInfo: {
    flex: 1,
  },
  scanType: {
    fontSize: 12,
    fontWeight: "600",
    color: "#007AFF",
    marginBottom: 2,
  },
  scanDate: {
    fontSize: 12,
    opacity: 0.6,
  },
  deleteButton: {
    padding: 4,
  },
  scanDataContainer: {
    backgroundColor: "rgba(0, 0, 0, 0.05)",
    borderRadius: 8,
    padding: 12,
    marginBottom: 12,
  },
  scanData: {
    fontSize: 14,
    lineHeight: 20,
    fontFamily: "monospace",
  },
  tapHint: {
    fontSize: 12,
    opacity: 0.5,
    marginTop: 4,
    fontStyle: "italic",
  },
  scanActions: {
    flexDirection: "row",
    justifyContent: "space-around",
  },
  actionButton: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 6,
    flex: 0.45,
    justifyContent: "center",
  },
  copyButton: {
    backgroundColor: "#007AFF",
  },
  shareButton: {
    backgroundColor: "#34C759",
  },
  actionButtonText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "600",
    marginLeft: 6,
  },
  emptyState: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 40,
  },
  emptyIcon: {
    opacity: 0.3,
    marginBottom: 20,
  },
  emptyTitle: {
    marginBottom: 12,
    textAlign: "center",
  },
  emptyDescription: {
    textAlign: "center",
    opacity: 0.6,
    lineHeight: 20,
  },
});
