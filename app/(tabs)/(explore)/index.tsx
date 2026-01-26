import { useFocusEffect } from "@react-navigation/native";
import * as Burnt from "burnt";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import { SymbolView } from "expo-symbols";
import { useCallback, useState } from "react";
import {
  Alert,
  FlatList,
  Pressable,
  RefreshControl,
  Share,
  StyleSheet,
  Text,
  TextInput,
  useColorScheme,
  View,
} from "react-native";
import Animated, {
  FadeIn,
  FadeInDown,
  FadeOut,
  LinearTransition,
} from "react-native-reanimated";
import {
  clearScanHistory,
  deleteScanFromHistory,
  getScanHistory,
  type ScanHistoryItem,
} from "@/utils/scanHistory";

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
  const [history, setHistory] = useState<ScanHistoryItem[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const colorScheme = useColorScheme();
  const theme = colors[colorScheme ?? "light"];

  const loadHistory = useCallback(async () => {
    const scanHistory = await getScanHistory();
    setHistory(scanHistory);
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
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await Clipboard.setStringAsync(data);
    Burnt.toast({
      title: "Copied",
      preset: "done",
      haptic: "success",
    });
  };

  const handleShareItem = async (data: string) => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await Share.share({ message: data });
  };

  const handleDeleteItem = async (id: string) => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    Alert.alert(
      "Delete Scan",
      "Are you sure you want to delete this scan?",
      [
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
      ],
    );
  };

  const handleClearAll = () => {
    Alert.alert(
      "Clear History",
      "Delete all scan history? This cannot be undone.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Clear All",
          style: "destructive",
          onPress: async () => {
            await Haptics.notificationAsync(
              Haptics.NotificationFeedbackType.Warning,
            );
            await clearScanHistory();
            await loadHistory();
          },
        },
      ],
    );
  };

  const renderScanItem = ({
    item,
    index,
  }: { item: ScanHistoryItem; index: number }) => (
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
          <View style={[styles.typeBadge, { backgroundColor: theme.blue + "20" }]}>
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
            <Text style={[styles.cardButtonText, { color: theme.blue }]}>Copy</Text>
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
            <Text style={[styles.cardButtonText, { color: theme.blue }]}>Share</Text>
          </Pressable>

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

  const renderEmptyState = () => (
    <Animated.View
      entering={FadeIn.duration(400)}
      style={styles.emptyContainer}
    >
      <View style={styles.emptyIconContainer}>
        <SymbolView
          name="qrcode.viewfinder"
          tintColor={theme.tertiaryLabel}
          style={{ width: 80, height: 80 }}
        />
      </View>
      <Text style={[styles.emptyTitle, { color: theme.label }]}>No Scans Yet</Text>
      <Text style={[styles.emptyDescription, { color: theme.secondaryLabel }]}>
        Scanned barcodes and QR codes will appear here
      </Text>
    </Animated.View>
  );

  const renderHeader = () => {
    if (history.length === 0) return null;
    return (
      <Animated.View
        entering={FadeIn}
        style={styles.listHeader}
      >
        <Text style={[styles.listHeaderText, { color: theme.secondaryLabel }]}>
          {history.length} {history.length === 1 ? "scan" : "scans"}
        </Text>
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
          <Text style={[styles.clearAllText, { color: theme.red }]}>Clear All</Text>
        </Pressable>
      </Animated.View>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <FlatList
        data={history}
        renderItem={renderScanItem}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContent}
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
        ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  listContent: {
    padding: 20,
    paddingBottom: 120,
    flexGrow: 1,
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
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 40,
    paddingBottom: 100,
  },
  emptyIconContainer: {
    marginBottom: 24,
    opacity: 0.6,
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
});
