import { useStorage } from "@/hooks/useStorage";
import { useTranslations } from "@/hooks/useTranslations";
import { type Language, languageNames } from "@/utils/i18n";
import {
  clearScanHistory,
  exportHistoryToCSV,
  getScanHistory,
} from "@/utils/scanHistory";
import * as Application from "expo-application";
import { File, Paths } from "expo-file-system";
import * as Haptics from "expo-haptics";
import * as Linking from "expo-linking";
import * as LocalAuthentication from "expo-local-authentication";
import * as Sharing from "expo-sharing";
import { SymbolView } from "expo-symbols";
import { useEffect, useState } from "react";
import {
  Alert,
  Modal,
  PlatformColor,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Switch,
  Text,
  useColorScheme,
  View,
} from "react-native";

const ITUNES_ITEM_ID = "6758315540";

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
    orange: "#FF9500",
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
    orange: "#FF9F0A",
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
  const t = useTranslations();

  const [hapticEnabled, setHapticEnabled] = useStorage("hapticEnabled", true);
  const [soundEnabled, setSoundEnabled] = useStorage("soundEnabled", true);
  const [saveHistory, setSaveHistory] = useStorage("saveHistory", true);
  const [autoCopy, setAutoCopy] = useStorage("autoCopy", false);
  const [autoOpenUrl, setAutoOpenUrl] = useStorage("autoOpenUrl", false);
  const [multiScan, setMultiScan] = useStorage("multiScan", false);
  const [requireAuth, setRequireAuth] = useStorage(
    "requireAuthForHistory",
    false,
  );
  const [language, setLanguage] = useStorage<Language>("language", "en");
  const [biometricType, setBiometricType] = useState<string>("Face ID");
  const [showHelp, setShowHelp] = useState(false);

  // Check available biometric type
  useEffect(() => {
    async function checkBiometrics() {
      const types =
        await LocalAuthentication.supportedAuthenticationTypesAsync();
      if (
        types.includes(
          LocalAuthentication.AuthenticationType.FACIAL_RECOGNITION,
        )
      ) {
        setBiometricType("Face ID");
      } else if (
        types.includes(LocalAuthentication.AuthenticationType.FINGERPRINT)
      ) {
        setBiometricType("Touch ID");
      } else {
        setBiometricType("Passcode");
      }
    }
    checkBiometrics();
  }, []);

  const handleRequireAuthChange = async (value: boolean) => {
    if (value) {
      // Verify biometrics work before enabling
      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const isEnrolled = await LocalAuthentication.isEnrolledAsync();

      if (!hasHardware || !isEnrolled) {
        Alert.alert(
          t.settings.notAvailable,
          `${biometricType} ${t.settings.authNotSetup}`,
        );
        return;
      }

      // Authenticate to enable
      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: `${t.settings.authenticateTo} ${biometricType}`,
        cancelLabel: t.common.cancel,
      });

      if (result.success) {
        if (hapticEnabled) {
          await Haptics.notificationAsync(
            Haptics.NotificationFeedbackType.Success,
          );
        }
        setRequireAuth(true);
      }
    } else {
      setRequireAuth(false);
    }
  };

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
      Alert.alert(t.settings.noHistory, t.settings.noHistoryToExport);
      return;
    }

    const csvContent = await exportHistoryToCSV();
    if (!csvContent) {
      Alert.alert(t.common.error, t.settings.exportError);
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
          dialogTitle: t.settings.exportCsv,
          UTI: "public.comma-separated-values-text",
        });
      } else {
        Alert.alert(t.common.error, t.alerts.sharingNotAvailable);
      }
    } catch (error) {
      console.error("Error exporting CSV:", error);
      Alert.alert(t.common.error, t.settings.exportError);
    }
  };

  const handleClearHistory = () => {
    Alert.alert(t.settings.clearHistoryTitle, t.settings.clearHistoryMessage, [
      { text: t.common.cancel, style: "cancel" },
      {
        text: t.common.clearAll,
        style: "destructive",
        onPress: async () => {
          if (hapticEnabled) {
            await Haptics.notificationAsync(
              Haptics.NotificationFeedbackType.Warning,
            );
          }
          await clearScanHistory();
          Alert.alert(t.settings.cleared, t.settings.allHistoryCleared);
        },
      },
    ]);
  };

  const handleRateApp = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }

    // Note: Don't use StoreReview.requestReview() from a button per Apple guidelines.
    // Instead, open the App Store "Write a Review" page directly.
    try {
      // Open the iOS App Store directly to the "Write a Review" screen
      await Linking.openURL(
        `itms-apps://itunes.apple.com/app/viewContentsUserReviews/id${ITUNES_ITEM_ID}?action=write-review`,
      );
    } catch (error) {
      console.error("Error opening App Store:", error);
      // Fallback: try opening via HTTPS URL (redirects to App Store on iOS)
      try {
        await Linking.openURL(
          `https://apps.apple.com/app/apple-store/id${ITUNES_ITEM_ID}?action=write-review`,
        );
      } catch {
        Alert.alert(t.common.error, t.common.error);
      }
    }
  };

  const handleShareApp = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    const appUrl = `https://apps.apple.com/app/id${ITUNES_ITEM_ID}`;
    await Share.share({
      message: `${t.settings.shareAppMessage}\n${appUrl}`,
    });
  };

  const handleLanguageChange = async () => {
    if (hapticEnabled) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    Alert.alert(t.settings.language, t.settings.selectLanguage, [
      {
        text: "English",
        onPress: () => setLanguage("en"),
      },
      {
        text: "Español",
        onPress: () => setLanguage("es"),
      },
      {
        text: "Français",
        onPress: () => setLanguage("fr"),
      },
      {
        text: t.common.cancel,
        style: "cancel",
      },
    ]);
  };

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: theme.background }]}
      contentContainerStyle={styles.content}
      contentInsetAdjustmentBehavior="automatic"
      bounces={false}
    >
      {/* General Settings */}
      <View style={styles.section}>
        <Text style={[styles.sectionHeader, { color: theme.secondaryLabel }]}>
          {t.settings.general}
        </Text>
        <View
          style={[
            styles.sectionContent,
            { backgroundColor: theme.secondaryBackground },
          ]}
        >
          <SettingsRow
            icon="globe"
            iconColor={theme.blue}
            title={t.settings.language}
            subtitle={languageNames[language]}
            onPress={handleLanguageChange}
            showChevron
            theme={theme}
          />
        </View>
      </View>

      {/* Scanner Settings */}
      <View style={styles.section}>
        <Text style={[styles.sectionHeader, { color: theme.secondaryLabel }]}>
          {t.settings.scanner}
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
            title={t.settings.hapticFeedback}
            subtitle={t.settings.vibrateWhenScanning}
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
            title={t.settings.sound}
            subtitle={t.settings.playSoundWhenScanning}
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
            title={t.settings.autoCopy}
            subtitle={t.settings.autoCopyDescription}
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
            title={t.settings.scanAndGo}
            subtitle={t.settings.scanAndGoDescription}
            value={autoOpenUrl}
            onValueChange={setAutoOpenUrl}
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="square.stack.3d.up.fill"
            iconColor="#5856D6"
            title={t.settings.multiCodeScanning}
            subtitle={t.settings.multiCodeDescription}
            value={multiScan}
            onValueChange={setMultiScan}
            theme={theme}
          />
        </View>
      </View>

      {/* History Settings */}
      <View style={styles.section}>
        <Text style={[styles.sectionHeader, { color: theme.secondaryLabel }]}>
          {t.settings.historySection}
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
            title={t.settings.saveHistory}
            subtitle={t.settings.saveHistoryDescription}
            value={saveHistory}
            onValueChange={setSaveHistory}
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="faceid"
            iconColor={theme.green}
            title={`${t.settings.requireAuth} ${biometricType}`}
            subtitle={t.settings.requireAuthDescription}
            value={requireAuth}
            onValueChange={handleRequireAuthChange}
            theme={theme}
          />
          <View
            style={[styles.separator, { backgroundColor: theme.separator }]}
          />
          <SettingsRow
            icon="square.and.arrow.up"
            iconColor={theme.blue}
            title={t.settings.exportCsv}
            subtitle={t.settings.exportCsvDescription}
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
            title={t.settings.clearAllHistory}
            onPress={handleClearHistory}
            isDestructive
            theme={theme}
          />
        </View>
      </View>

      {/* Help */}
      <View style={styles.section}>
        <Text style={[styles.sectionHeader, { color: theme.secondaryLabel }]}>
          HELP
        </Text>
        <View
          style={[
            styles.sectionContent,
            { backgroundColor: theme.secondaryBackground },
          ]}
        >
          <SettingsRow
            icon="questionmark.circle.fill"
            iconColor={theme.blue}
            title={t.help.title}
            subtitle="Learn how to use the app"
            onPress={() => {
              if (hapticEnabled) {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
              }
              setShowHelp(true);
            }}
            showChevron
            theme={theme}
          />
        </View>
      </View>

      {/* About */}
      <View style={styles.section}>
        <Text style={[styles.sectionHeader, { color: theme.secondaryLabel }]}>
          {t.settings.about}
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
            title={t.settings.rateApp}
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
            title={t.settings.shareApp}
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
          {t.settings.version} {Application.nativeApplicationVersion ?? "1.0.0"}{" "}
          ({Application.nativeBuildVersion ?? "1"})
        </Text>
      </View>

      {/* Help Modal */}
      <Modal
        visible={showHelp}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowHelp(false)}
      >
        <View style={[styles.modalContainer, { backgroundColor: theme.background }]}>
          <View style={styles.modalHeader}>
            <Text style={[styles.modalTitle, { color: theme.label }]}>
              {t.help.title}
            </Text>
            <Pressable
              onPress={() => {
                if (hapticEnabled) {
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                }
                setShowHelp(false);
              }}
              hitSlop={10}
            >
              <SymbolView
                name="xmark.circle.fill"
                tintColor={theme.secondaryLabel}
                style={{ width: 28, height: 28 }}
              />
            </Pressable>
          </View>

          <ScrollView
            style={styles.modalContent}
            contentContainerStyle={styles.modalScrollContent}
            showsVerticalScrollIndicator={false}
          >
            {/* How to Scan */}
            <View style={styles.helpSection}>
              <View style={styles.helpSectionHeader}>
                <SymbolView
                  name="camera.fill"
                  tintColor={theme.blue}
                  style={{ width: 24, height: 24 }}
                />
                <Text style={[styles.helpSectionTitle, { color: theme.label }]}>
                  {t.help.howToScanTitle}
                </Text>
              </View>
              <Text style={[styles.helpStep, { color: theme.secondaryLabel }]}>
                {t.help.howToScanStep1}
              </Text>
              <Text style={[styles.helpStep, { color: theme.secondaryLabel }]}>
                {t.help.howToScanStep2}
              </Text>
              <Text style={[styles.helpStep, { color: theme.secondaryLabel }]}>
                {t.help.howToScanStep3}
              </Text>
            </View>

            {/* How to Generate */}
            <View style={styles.helpSection}>
              <View style={styles.helpSectionHeader}>
                <SymbolView
                  name="qrcode"
                  tintColor={theme.green}
                  style={{ width: 24, height: 24 }}
                />
                <Text style={[styles.helpSectionTitle, { color: theme.label }]}>
                  {t.help.howToGenerateTitle}
                </Text>
              </View>
              <Text style={[styles.helpStep, { color: theme.secondaryLabel }]}>
                {t.help.howToGenerateStep1}
              </Text>
              <Text style={[styles.helpStep, { color: theme.secondaryLabel }]}>
                {t.help.howToGenerateStep2}
              </Text>
              <Text style={[styles.helpStep, { color: theme.secondaryLabel }]}>
                {t.help.howToGenerateStep3}
              </Text>
            </View>

            {/* Where to Find */}
            <View style={styles.helpSection}>
              <View style={styles.helpSectionHeader}>
                <SymbolView
                  name="magnifyingglass"
                  tintColor={theme.orange}
                  style={{ width: 24, height: 24 }}
                />
                <Text style={[styles.helpSectionTitle, { color: theme.label }]}>
                  {t.help.whereToFindTitle}
                </Text>
              </View>
              <Text style={[styles.helpText, { color: theme.secondaryLabel }]}>
                {t.help.whereToFindDescription}
              </Text>
            </View>

            {/* Tips */}
            <View style={styles.helpSection}>
              <View style={styles.helpSectionHeader}>
                <SymbolView
                  name="lightbulb.fill"
                  tintColor="#FFD60A"
                  style={{ width: 24, height: 24 }}
                />
                <Text style={[styles.helpSectionTitle, { color: theme.label }]}>
                  {t.help.tipsTitle}
                </Text>
              </View>
              <Text style={[styles.helpTip, { color: theme.secondaryLabel }]}>
                {t.help.tip1}
              </Text>
              <Text style={[styles.helpTip, { color: theme.secondaryLabel }]}>
                {t.help.tip2}
              </Text>
              <Text style={[styles.helpTip, { color: theme.secondaryLabel }]}>
                {t.help.tip3}
              </Text>
              <Text style={[styles.helpTip, { color: theme.secondaryLabel }]}>
                {t.help.tip4}
              </Text>
            </View>
          </ScrollView>
        </View>
      </Modal>
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
  modalContainer: {
    flex: 1,
  },
  modalHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 20,
    paddingTop: 60,
    paddingBottom: 20,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: PlatformColor("separator"),
  },
  modalTitle: {
    fontSize: 28,
    fontWeight: "700",
  },
  modalContent: {
    flex: 1,
  },
  modalScrollContent: {
    padding: 20,
    paddingBottom: 40,
  },
  helpSection: {
    marginBottom: 32,
  },
  helpSectionHeader: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    marginBottom: 16,
  },
  helpSectionTitle: {
    fontSize: 20,
    fontWeight: "700",
  },
  helpStep: {
    fontSize: 16,
    lineHeight: 24,
    marginBottom: 8,
  },
  helpText: {
    fontSize: 16,
    lineHeight: 24,
  },
  helpTip: {
    fontSize: 16,
    lineHeight: 24,
    marginBottom: 8,
  },
});
