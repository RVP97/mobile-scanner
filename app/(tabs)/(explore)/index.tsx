import { useStorage } from "@/hooks/useStorage";
import {
  clearScanHistory,
  deleteScanFromHistory,
  getScanHistory,
  type ScanHistoryItem,
} from "@/utils/scanHistory";
import { useFocusEffect } from "@react-navigation/native";
import { BlurView } from "expo-blur";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import * as LocalAuthentication from "expo-local-authentication";
import { SymbolView } from "expo-symbols";
import { useCallback, useMemo, useRef, useState } from "react";
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
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isAuthenticating, setIsAuthenticating] = useState(false);
  const hasAttemptedAuthRef = useRef(false);
  const colorScheme = useColorScheme();
  const theme = colors[colorScheme ?? "light"];
  const [saveHistory, setSaveHistory] = useStorage("saveHistory", true);
  const [requireAuth] = useStorage("requireAuthForHistory", false);
  const [search, setSearch] = useState("");
  const searchInputRef = useRef<TextInput>(null);

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

  const loadHistory = useCallback(async () => {
    const scanHistory = await getScanHistory();
    setHistory(scanHistory);
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

  const handleEnableHistory = async () => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setSaveHistory(true);
  };

  const renderDisabledState = () => (
    <Animated.View
      entering={FadeIn.duration(400)}
      style={styles.emptyContainer}
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
    // Show no results state when searching
    if (search && history.length > 0) {
      return (
        <Animated.View
          entering={FadeIn.duration(400)}
          style={styles.emptyContainer}
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
            No scans found for "{search}"
          </Text>
        </Animated.View>
      );
    }

    if (!saveHistory) {
      return renderDisabledState();
    }

    return (
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

  const handleClearSearch = () => {
    setSearch("");
    searchInputRef.current?.blur();
  };

  const renderSearchBar = () => {
    if (history.length === 0) return null;

    return (
      <View style={styles.searchContainer}>
        <BlurView
          tint={colorScheme === "dark" ? "systemMaterialDark" : "systemMaterial"}
          intensity={80}
          style={styles.searchBlur}
        >
          <SymbolView
            name="magnifyingglass"
            tintColor={theme.tertiaryLabel}
            style={styles.searchIcon}
          />
          <TextInput
            ref={searchInputRef}
            style={[styles.searchInput, { color: theme.label }]}
            placeholder="Search scans..."
            placeholderTextColor={theme.tertiaryLabel}
            value={search}
            onChangeText={setSearch}
            autoCapitalize="none"
            autoCorrect={false}
            returnKeyType="search"
            clearButtonMode="never"
          />
          {search.length > 0 && (
            <Animated.View entering={FadeIn.duration(150)} exiting={FadeOut.duration(150)}>
              <Pressable
                onPress={handleClearSearch}
                style={styles.clearSearchButton}
                hitSlop={8}
              >
                <SymbolView
                  name="xmark.circle.fill"
                  tintColor={theme.tertiaryLabel}
                  style={styles.clearSearchIcon}
                />
              </Pressable>
            </Animated.View>
          )}
        </BlurView>
      </View>
    );
  };

  const renderHeader = () => {
    const banner = renderDisabledBanner();
    const hasItems = history.length > 0;
    const isSearching = search.length > 0;

    return (
      <View>
        {renderSearchBar()}
        {banner}
        {hasItems && (
          <Animated.View entering={FadeIn} style={styles.listHeader}>
            <Text
              style={[styles.listHeaderText, { color: theme.secondaryLabel }]}
            >
              {isSearching
                ? `${filteredHistory.length} of ${history.length} scans`
                : `${history.length} ${history.length === 1 ? "scan" : "scans"}`}
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
          </Animated.View>
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

  return (
    <FlatList
      style={[styles.container, { backgroundColor: theme.background }]}
      data={filteredHistory}
      renderItem={renderScanItem}
      keyExtractor={(item) => item.id}
      contentContainerStyle={[
        styles.listContent,
        filteredHistory.length === 0 && styles.listContentEmpty,
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
      ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
    />
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  listContent: {
    padding: 20,
  },
  listContentEmpty: {
    flexGrow: 1,
  },
  searchContainer: {
    marginBottom: 16,
  },
  searchBlur: {
    flexDirection: "row",
    alignItems: "center",
    borderRadius: 12,
    borderCurve: "continuous",
    overflow: "hidden",
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
  },
  searchIcon: {
    width: 18,
    height: 18,
  },
  searchInput: {
    flex: 1,
    fontSize: 17,
    padding: 0,
  },
  clearSearchButton: {
    padding: 2,
  },
  clearSearchIcon: {
    width: 18,
    height: 18,
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
    flex: 1,
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
});
