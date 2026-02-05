import { useStorage } from "@/hooks/useStorage";
import { useTranslations } from "@/hooks/useTranslations";
import * as Haptics from "expo-haptics";
import { SymbolView } from "expo-symbols";
import { useRouter } from "expo-router";
import { useEffect } from "react";
import {
  Pressable,
  ScrollView,
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
    green: "#34C759",
    orange: "#FF9500",
    indigo: "#5856D6",
  },
  dark: {
    background: "#000000",
    secondaryBackground: "#1C1C1E",
    label: "#FFFFFF",
    secondaryLabel: "#EBEBF5",
    tertiaryLabel: "#636366",
    blue: "#0A84FF",
    green: "#30D158",
    orange: "#FF9F0A",
    indigo: "#5E5CE6",
  },
};

interface FeatureCardProps {
  icon: string;
  title: string;
  description: string;
  iconColor: string;
  theme: typeof colors.light;
}

function FeatureCard({
  icon,
  title,
  description,
  iconColor,
  theme,
}: FeatureCardProps) {
  return (
    <Animated.View
      entering={FadeInDown.duration(400)}
      style={[
        styles.featureCard,
        { backgroundColor: theme.secondaryBackground },
      ]}
    >
      <View style={[styles.featureIcon, { backgroundColor: iconColor + "15" }]}>
        <SymbolView
          name={icon}
          tintColor={iconColor}
          style={{ width: 32, height: 32 }}
        />
      </View>
      <Text style={[styles.featureTitle, { color: theme.label }]}>{title}</Text>
      <Text style={[styles.featureDescription, { color: theme.secondaryLabel }]}>
        {description}
      </Text>
    </Animated.View>
  );
}

export default function WelcomeScreen() {
  const colorScheme = useColorScheme();
  const theme = colors[colorScheme ?? "light"];
  const t = useTranslations();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const [hasSeenWelcome, setHasSeenWelcome] = useStorage(
    "hasSeenWelcome",
    false,
  );
  const [, setHasSelectedLanguage] = useStorage("hasSelectedLanguage", false);

  const handleGetStarted = async () => {
    if (await Haptics.impactAsync) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
    setHasSeenWelcome(true);
    router.replace("/(tabs)/(1-scanner)" as never);
  };

  const handleBack = async () => {
    if (await Haptics.impactAsync) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    // Reset language selection flag to go back to language selection
    setHasSelectedLanguage(false);
    // Navigate back to language selection by replacing the route
    router.replace("/" as never);
  };

  // Auto-dismiss if already seen (shouldn't happen, but safety check)
  useEffect(() => {
    if (hasSeenWelcome) {
      router.replace("/(tabs)/(1-scanner)");
    }
  }, [hasSeenWelcome, router]);

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      {/* Back Button */}
      <Animated.View
        entering={FadeInDown.duration(300)}
        style={[styles.backButtonContainer, { top: insets.top + 16 }]}
      >
        <Pressable
          style={({ pressed }) => [
            styles.backButton,
            { backgroundColor: theme.secondaryBackground + "E6" },
            pressed && styles.buttonPressed,
          ]}
          onPress={handleBack}
        >
          <SymbolView
            name="chevron.left"
            tintColor={theme.label}
            style={{ width: 20, height: 20 }}
          />
          <Text style={[styles.backButtonText, { color: theme.label }]}>
            {t.welcome.back}
          </Text>
        </Pressable>
      </Animated.View>

      <ScrollView
        contentContainerStyle={[
          styles.content,
          { paddingTop: insets.top + 40, paddingBottom: insets.bottom + 40 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {/* Header */}
        <Animated.View
          entering={FadeInDown.duration(500)}
          style={styles.header}
        >
          <View
            style={[
              styles.logoContainer,
              { backgroundColor: theme.blue + "15" },
            ]}
          >
            <SymbolView
              name="qrcode.viewfinder"
              tintColor={theme.blue}
              style={{ width: 80, height: 80 }}
            />
          </View>
          <Text style={[styles.title, { color: theme.label }]}>
            {t.welcome.title}
          </Text>
          <Text style={[styles.subtitle, { color: theme.secondaryLabel }]}>
            {t.welcome.subtitle}
          </Text>
        </Animated.View>

        {/* Features */}
        <View style={styles.featuresContainer}>
          <FeatureCard
            icon="camera.fill"
            title={t.welcome.scanTitle}
            description={t.welcome.scanDescription}
            iconColor={theme.blue}
            theme={theme}
          />
          <FeatureCard
            icon="qrcode"
            title={t.welcome.generateTitle}
            description={t.welcome.generateDescription}
            iconColor={theme.green}
            theme={theme}
          />
          <FeatureCard
            icon="clock.fill"
            title={t.welcome.historyTitle}
            description={t.welcome.historyDescription}
            iconColor={theme.orange}
            theme={theme}
          />
        </View>

        {/* How to Get Started */}
        <Animated.View
          entering={FadeInDown.delay(200).duration(400)}
          style={[
            styles.infoCard,
            { backgroundColor: theme.secondaryBackground },
          ]}
        >
          <SymbolView
            name="lightbulb.fill"
            tintColor={theme.orange}
            style={{ width: 24, height: 24, marginBottom: 12 }}
          />
          <Text style={[styles.infoTitle, { color: theme.label }]}>
            {t.welcome.getStartedTitle}
          </Text>
          <Text style={[styles.infoText, { color: theme.secondaryLabel }]}>
            {t.welcome.getStartedDescription}
          </Text>
        </Animated.View>
      </ScrollView>

      {/* Get Started Button */}
      <Animated.View
        entering={FadeInDown.delay(300).duration(400)}
        style={[styles.buttonContainer, { paddingBottom: insets.bottom + 20 }]}
      >
        <Pressable
          style={({ pressed }) => [
            styles.getStartedButton,
            { backgroundColor: theme.blue },
            pressed && styles.buttonPressed,
          ]}
          onPress={handleGetStarted}
        >
          <Text style={styles.getStartedText}>{t.welcome.getStarted}</Text>
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
    paddingHorizontal: 24,
  },
  header: {
    alignItems: "center",
    marginBottom: 48,
  },
  logoContainer: {
    width: 120,
    height: 120,
    borderRadius: 30,
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
  featuresContainer: {
    gap: 16,
    marginBottom: 32,
  },
  featureCard: {
    padding: 20,
    borderRadius: 16,
    borderCurve: "continuous",
  },
  featureIcon: {
    width: 56,
    height: 56,
    borderRadius: 14,
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 12,
  },
  featureTitle: {
    fontSize: 18,
    fontWeight: "600",
    marginBottom: 6,
  },
  featureDescription: {
    fontSize: 15,
    lineHeight: 22,
  },
  infoCard: {
    padding: 20,
    borderRadius: 16,
    borderCurve: "continuous",
    alignItems: "center",
  },
  infoTitle: {
    fontSize: 18,
    fontWeight: "600",
    marginBottom: 8,
    textAlign: "center",
  },
  infoText: {
    fontSize: 15,
    lineHeight: 22,
    textAlign: "center",
  },
  buttonContainer: {
    paddingHorizontal: 24,
    paddingTop: 20,
  },
  getStartedButton: {
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
  getStartedText: {
    color: "#FFFFFF",
    fontSize: 18,
    fontWeight: "700",
  },
  backButtonContainer: {
    position: "absolute",
    left: 20,
    zIndex: 10,
  },
  backButton: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingVertical: 10,
    paddingHorizontal: 14,
    borderRadius: 12,
    borderCurve: "continuous",
  },
  backButtonText: {
    fontSize: 16,
    fontWeight: "600",
  },
});
