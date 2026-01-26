import { useStorage } from "@/hooks/useStorage";
import {
  clearScanHistory,
  exportHistoryToCSV,
  getScanHistory,
} from "@/utils/scanHistory";
import * as Application from "expo-application";
import { File, Paths } from "expo-file-system";
import * as Haptics from "expo-haptics";
import * as Sharing from "expo-sharing";
import { SymbolView } from "expo-symbols";
import {
  Alert,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Switch,
  Text,
  useColorScheme,
  View,
} from "react-native";

const colors = {
  light: {
    background: "#F2F2F7",
    secondaryBackground: "#FFFFFF",
    label: "#000000",
    secondaryLabel: "#3C3C43",
    tertiaryLabel: "#8E8E93",
    separator: "#C6C6C8",
    blue: "#007AFF",
    red: "#FF3B30",
    green: "#34C759",
    purple: "#AF52DE",
  },
  dark: {
    background: "#000000",
    secondaryBackground: "#1C1C1E",
    label: "#FFFFFF",
    secondaryLabel: "#EBEBF5",
    tertiaryLabel: "#636366",
    separator: "#38383A",
    blue: "#0A84FF",
    red: "#FF453A",
    green: "#30D158",
    purple: "#BF5AF2",
  },
};

interface SettingsRowProps {
  icon: string;
  iconColor: string;
  title: string;
  subtitle?: string;
  value?: boolean;
  onValueChange?: (value: boolean) => void;
  onPress?: () => void;
  isDestructive?: boolean;
  showChevron?: boolean;
  theme: typeof colors.light;
}

function SettingsRow({
  icon,
  iconColor,
  title,
  subtitle,
  value,
  onValueChange,
  onPress,
  isDestructive,
  showChevron,
  theme,
}: SettingsRowProps) {
  // biome-ignore lint/suspicious/noExplicitAny: SF Symbol names are dynamic
  const iconName = icon as any;
  const isToggle = value !== undefined && onValueChange;

  const content = (
    <View style={[styles.row, { backgroundColor: theme.secondaryBackground }]}>
      <View style={[styles.iconContainer, { backgroundColor: iconColor }]}>
        <SymbolView
          name={iconName}
          tintColor="#FFFFFF"
          style={{ width: 18, height: 18 }}
        />
      </View>
      <View style={styles.rowContent}>
        <Text
          style={[
            styles.rowTitle,
            { color: isDestructive ? theme.red : theme.label },
          ]}
        >
          {title}
        </Text>
        {subtitle && (
          <Text style={[styles.rowSubtitle, { color: theme.tertiaryLabel }]}>
            {subtitle}
          </Text>
        )}
      </View>
      {isToggle && (
        <Switch
          value={value}
          onValueChange={onValueChange}
          trackColor={{ false: theme.separator, true: theme.green }}
        />
      )}
      {showChevron && (
        <SymbolView
          name="chevron.right"
          tintColor={theme.tertiaryLabel}
          style={{ width: 14, height: 14 }}
        />
      )}
    </View>
  );

  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        style={({ pressed }) => pressed && styles.rowPressed}
      >
        {content}
      </Pressable>
    );
  }

  return content;
}

export default function SettingsScreen() {
  const colorScheme = useColorScheme();
  const theme = colors[colorScheme ?? "light"];

  const [hapticEnabled, setHapticEnabled] = useStorage("hapticEnabled", true);
  const [soundEnabled, setSoundEnabled] = useStorage("soundEnabled", true);
  const [saveHistory, setSaveHistory] = useStorage("saveHistory", true);
  const [autoCopy, setAutoCopy] = useStorage("autoCopy", false);
  const [autoOpenUrl, setAutoOpenUrl] = useStorage("autoOpenUrl", false);
  const [scanOnLaunch, setScanOnLaunch] = useStorage("scanOnLaunch", false);

  const handleHapticChange = async (value: boolean) => {
    if (value) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setHapticEnabled(value);
  };

  const handleSoundChange = async (value: boolean) => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setSoundEnabled(value);
  };

  const handleExportCSV = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }

    const history = await getScanHistory();
    if (history.length === 0) {
      Alert.alert("No History", "There is no scan history to export.");
      return;
    }

    const csvContent = await exportHistoryToCSV();
    if (!csvContent) {
      Alert.alert("Error", "Failed to export history.");
      return;
    }

    try {
      const fileName = `scan_history_${Date.now()}.csv`;
      const file = new File(Paths.cache, fileName);
      file.create();
      file.write(csvContent);

      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(file.uri, {
          mimeType: "text/csv",
          dialogTitle: "Export Scan History",
          UTI: "public.comma-separated-values-text",
        });
      } else {
        Alert.alert("Error", "Sharing is not available on this device.");
      }
    } catch (error) {
      console.error("Error exporting CSV:", error);
      Alert.alert("Error", "Failed to export history.");
    }
  };

  const handleClearHistory = () => {
    Alert.alert(
      "Clear All History",
      "This will permanently delete all your scan history. This action cannot be undone.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Clear All",
          style: "destructive",
          onPress: async () => {
            if (hapticEnabled) {
              await Haptics.notificationAsync(
                Haptics.NotificationFeedbackType.Warning,
              );
            }
            await clearScanHistory();
            Alert.alert("Done", "All scan history has been cleared");
          },
        },
      ],
    );
  };

  const handleRateApp = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    Alert.alert("Rate App", "This would open the App Store review page");
  };

  const handleShareApp = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    await Share.share({
      message: "Check out this awesome scanner app!",
    });
  };

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: theme.background }]}
      contentContainerStyle={styles.content}
      contentInsetAdjustmentBehavior="automatic"
      bounces={false}
    >
      {/* Scanner Settings */}
      <View style={styles.section}>
        <Text style={[styles.sectionHeader, { color: theme.secondaryLabel }]}>
          SCANNER
        </Text>
        <View
          style={[
            styles.sectionContent,
            { backgroundColor: theme.secondaryBackground },
          ]}
        >
          <SettingsRow
            icon="hand.tap.fill"
            iconColor={theme.blue}
            title="Haptic Feedback"
            subtitle="Vibrate when scanning"
            value={hapticEnabled}
            onValueChange={handleHapticChange}
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="speaker.wave.2.fill"
            iconColor={theme.purple}
            title="Sound"
            subtitle="Play sound when scanning"
            value={soundEnabled}
            onValueChange={handleSoundChange}
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="doc.on.doc.fill"
            iconColor={theme.green}
            title="Auto-Copy"
            subtitle="Copy scanned content automatically"
            value={autoCopy}
            onValueChange={setAutoCopy}
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="arrow.up.forward.app.fill"
            iconColor="#FF9500"
            title="Scan and Go"
            subtitle="Open URLs automatically after scanning"
            value={autoOpenUrl}
            onValueChange={setAutoOpenUrl}
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="camera.viewfinder"
            iconColor="#5856D6"
            title="Scan on Launch"
            subtitle="Open scanner when app starts"
            value={scanOnLaunch}
            onValueChange={setScanOnLaunch}
            theme={theme}
          />
        </View>
      </View>

      {/* History Settings */}
      <View style={styles.section}>
        <Text style={[styles.sectionHeader, { color: theme.secondaryLabel }]}>
          HISTORY
        </Text>
        <View
          style={[
            styles.sectionContent,
            { backgroundColor: theme.secondaryBackground },
          ]}
        >
          <SettingsRow
            icon="clock.fill"
            iconColor="#FF9500"
            title="Save Scan History"
            subtitle="Keep a record of scanned items"
            value={saveHistory}
            onValueChange={setSaveHistory}
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="square.and.arrow.up"
            iconColor={theme.blue}
            title="Export to CSV"
            subtitle="Save history as spreadsheet"
            onPress={handleExportCSV}
            showChevron
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="trash.fill"
            iconColor={theme.red}
            title="Clear All History"
            onPress={handleClearHistory}
            isDestructive
            theme={theme}
          />
        </View>
      </View>

      {/* About */}
      <View style={styles.section}>
        <Text style={[styles.sectionHeader, { color: theme.secondaryLabel }]}>
          ABOUT
        </Text>
        <View
          style={[
            styles.sectionContent,
            { backgroundColor: theme.secondaryBackground },
          ]}
        >
          <SettingsRow
            icon="star.fill"
            iconColor="#FFD60A"
            title="Rate App"
            onPress={handleRateApp}
            showChevron
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="square.and.arrow.up.fill"
            iconColor={theme.blue}
            title="Share App"
            onPress={handleShareApp}
            showChevron
            theme={theme}
          />
        </View>
      </View>

      {/* App Info */}
      <View style={styles.appInfo}>
        <Text style={[styles.appName, { color: theme.label }]}>Scanner</Text>
        <Text style={[styles.appVersion, { color: theme.tertiaryLabel }]}>
          Version {Application.nativeApplicationVersion ?? "1.0.0"} (
          {Application.nativeBuildVersion ?? "1"})
        </Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    paddingBottom: 20,
  },
  section: {
    marginTop: 20,
  },
  sectionHeader: {
    fontSize: 13,
    fontWeight: "600",
    marginLeft: 20,
    marginBottom: 8,
    letterSpacing: 0.5,
  },
  sectionContent: {
    marginHorizontal: 16,
    borderRadius: 12,
    borderCurve: "continuous",
    overflow: "hidden",
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 12,
    paddingHorizontal: 16,
    gap: 14,
  },
  rowPressed: {
    opacity: 0.6,
  },
  iconContainer: {
    width: 30,
    height: 30,
    borderRadius: 7,
    borderCurve: "continuous",
    justifyContent: "center",
    alignItems: "center",
  },
  rowContent: {
    flex: 1,
  },
  rowTitle: {
    fontSize: 17,
  },
  rowSubtitle: {
    fontSize: 13,
    marginTop: 2,
  },
  separator: {
    height: StyleSheet.hairlineWidth,
    marginLeft: 60,
  },
  appInfo: {
    alignItems: "center",
    marginTop: 40,
    marginBottom: 20,
  },
  appName: {
    fontSize: 17,
    fontWeight: "600",
    marginBottom: 4,
  },
  appVersion: {
    fontSize: 14,
  },
});
