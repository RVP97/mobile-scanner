import LanguageSelectionScreen from "@/components/LanguageSelectionScreen";
import { useStorage } from "@/hooks/useStorage";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useEffect, useState } from "react";
import "react-native-reanimated";

export default function RootLayout() {
  const [hasSelectedLanguage] = useStorage("hasSelectedLanguage", false);
  const [hasSeenWelcome] = useStorage("hasSeenWelcome", false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Small delay to check storage
    const timer = setTimeout(() => {
      setIsLoading(false);
    }, 100);
    return () => clearTimeout(timer);
  }, []);

  // Show loading screen while checking storage
  if (isLoading) {
    return null;
  }

  // Show language selection first if not selected
  if (!hasSelectedLanguage) {
    return (
      <>
        <LanguageSelectionScreen />
        <StatusBar style="auto" />
      </>
    );
  }

  // Show welcome screen if language selected but welcome not seen
  if (!hasSeenWelcome) {
    return (
      <>
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="welcome" />
          <Stack.Screen name="(tabs)" />
        </Stack>
        <StatusBar style="auto" />
      </>
    );
  }

  return (
    <>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="+not-found" />
      </Stack>
      <StatusBar style="auto" />
    </>
  );
}
