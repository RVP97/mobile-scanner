import { useStorage } from "@/hooks/useStorage";
import { type Language, languageNames, getTranslations } from "@/utils/i18n";
import * as Haptics from "expo-haptics";
import { SymbolView } from "expo-symbols";
import { useRouter } from "expo-router";
import { useEffect } from "react";
import {
  Pressable,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from "react-native";
import Animated, { FadeInDown } from "react-native-reanimated";
import { useSafeAreaInsets } from "react-native-safe-area-context";

const colors = {
  light: {
    background: "#F2F2F7",
    secondaryBackground: "#FFFFFF",
    label: "#000000",
    secondaryLabel: "#3C3C43",
    tertiaryLabel: "#8E8E93",
    blue: "#007AFF",
  },
  dark: {
    background: "#000000",
    secondaryBackground: "#1C1C1E",
    label: "#FFFFFF",
    secondaryLabel: "#EBEBF5",
    tertiaryLabel: "#636366",
    blue: "#0A84FF",
  },
};

const languages: Language[] = ["en", "es", "fr"];

export default function LanguageSelectionScreen() {
  const colorScheme = useColorScheme();
  const theme = colors[colorScheme ?? "light"];
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const [language, setLanguage] = useStorage<Language>("language", "en");
  const [hasSelectedLanguage, setHasSelectedLanguage] = useStorage(
    "hasSelectedLanguage",
    false,
  );
  // Get translations for current language (will update when language changes)
  const t = getTranslations(language);

  const handleLanguageSelect = async (lang: Language) => {
    if (await Haptics.impactAsync) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setLanguage(lang);
  };

  const handleContinue = async () => {
    if (await Haptics.impactAsync) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    setHasSelectedLanguage(true);
    // Small delay to ensure language is set before navigating
    setTimeout(() => {
      router.replace("/welcome" as never);
    }, 100);
  };

  // Auto-dismiss if already selected (shouldn't happen, but safety check)
  useEffect(() => {
    if (hasSelectedLanguage) {
      router.replace("/welcome" as never);
    }
  }, [hasSelectedLanguage, router]);

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <Animated.View
        entering={FadeInDown.duration(500)}
        style={[styles.content, { paddingTop: insets.top + 60 }]}
      >
        {/* Header */}
        <View style={styles.header}>
          <View
            style={[
              styles.iconContainer,
              { backgroundColor: theme.blue + "15" },
            ]}
          >
            <SymbolView
              name="globe"
              tintColor={theme.blue}
              style={{ width: 48, height: 48 }}
            />
          </View>
          <Text style={[styles.title, { color: theme.label }]}>
            {t.languageSelection.title}
          </Text>
          <Text style={[styles.subtitle, { color: theme.secondaryLabel }]}>
            {t.languageSelection.subtitle}
          </Text>
        </View>

        {/* Language Options */}
        <View style={styles.languagesContainer}>
          {languages.map((lang, index) => (
            <Animated.View
              key={lang}
              entering={FadeInDown.delay(100 + index * 100).duration(400)}
            >
              <Pressable
                style={({ pressed }) => [
                  styles.languageButton,
                  {
                    backgroundColor: theme.secondaryBackground,
                    borderColor:
                      language === lang ? theme.blue : theme.tertiaryLabel + "30",
                  },
                  pressed && styles.languageButtonPressed,
                ]}
                onPress={() => handleLanguageSelect(lang)}
              >
                <View style={styles.languageContent}>
                  <View
                    style={[
                      styles.languageIcon,
                      {
                        backgroundColor:
                          language === lang
                            ? theme.blue + "15"
                            : theme.tertiaryLabel + "10",
                      },
                    ]}
                  >
                    <Text
                      style={[
                        styles.languageFlag,
                        { color: language === lang ? theme.blue : theme.tertiaryLabel },
                      ]}
                    >
                      {lang === "en" ? "🇺🇸" : lang === "es" ? "🇪🇸" : "🇫🇷"}
                    </Text>
                  </View>
                  <View style={styles.languageTextContainer}>
                    <Text
                      style={[
                        styles.languageName,
                        {
                          color: language === lang ? theme.label : theme.secondaryLabel,
                        },
                      ]}
                    >
                      {languageNames[lang]}
                    </Text>
                    {lang === "en" && (
                      <Text
                        style={[
                          styles.languageNative,
                          { color: theme.tertiaryLabel },
                        ]}
                      >
                        English
                      </Text>
                    )}
                    {lang === "es" && (
                      <Text
                        style={[
                          styles.languageNative,
                          { color: theme.tertiaryLabel },
                        ]}
                      >
                        Español
                      </Text>
                    )}
                    {lang === "fr" && (
                      <Text
                        style={[
                          styles.languageNative,
                          { color: theme.tertiaryLabel },
                        ]}
                      >
                        Français
                      </Text>
                    )}
                  </View>
                </View>
                {language === lang && (
                  <SymbolView
                    name="checkmark.circle.fill"
                    tintColor={theme.blue}
                    style={{ width: 24, height: 24 }}
                  />
                )}
              </Pressable>
            </Animated.View>
          ))}
        </View>
      </Animated.View>

      {/* Continue Button */}
      <Animated.View
        entering={FadeInDown.delay(400).duration(400)}
        style={[styles.buttonContainer, { paddingBottom: insets.bottom + 20 }]}
      >
        <Pressable
          style={({ pressed }) => [
            styles.continueButton,
            {
              backgroundColor: language ? theme.blue : theme.tertiaryLabel,
              opacity: language ? 1 : 0.5,
            },
            pressed && styles.buttonPressed,
          ]}
          onPress={handleContinue}
          disabled={!language}
        >
          <Text style={styles.continueButtonText}>
            {t.languageSelection.continue}
          </Text>
          <SymbolView
            name="arrow.right"
            tintColor="#FFFFFF"
            style={{ width: 20, height: 20 }}
          />
        </Pressable>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
    justifyContent: "space-between",
  },
  header: {
    alignItems: "center",
    marginBottom: 48,
  },
  iconContainer: {
    width: 96,
    height: 96,
    borderRadius: 24,
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 24,
  },
  title: {
    fontSize: 32,
    fontWeight: "700",
    marginBottom: 8,
    textAlign: "center",
  },
  subtitle: {
    fontSize: 17,
    textAlign: "center",
    lineHeight: 24,
  },
  languagesContainer: {
    gap: 12,
  },
  languageButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    padding: 20,
    borderRadius: 16,
    borderCurve: "continuous",
    borderWidth: 2,
  },
  languageButtonPressed: {
    opacity: 0.7,
    transform: [{ scale: 0.98 }],
  },
  languageContent: {
    flexDirection: "row",
    alignItems: "center",
    gap: 16,
    flex: 1,
  },
  languageIcon: {
    width: 56,
    height: 56,
    borderRadius: 14,
    justifyContent: "center",
    alignItems: "center",
  },
  languageFlag: {
    fontSize: 32,
  },
  languageTextContainer: {
    flex: 1,
    gap: 4,
  },
  languageName: {
    fontSize: 18,
    fontWeight: "600",
  },
  languageNative: {
    fontSize: 15,
  },
  buttonContainer: {
    paddingHorizontal: 24,
    paddingTop: 20,
  },
  continueButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 10,
    paddingVertical: 18,
    borderRadius: 16,
    borderCurve: "continuous",
  },
  buttonPressed: {
    opacity: 0.85,
    transform: [{ scale: 0.98 }],
  },
  continueButtonText: {
    color: "#FFFFFF",
    fontSize: 18,
    fontWeight: "700",
  },
});
