import { Stack } from "expo-router";
import { PlatformColor } from "react-native";

export default function SettingsLayout() {
  return (
    <Stack
      screenOptions={{
        headerTransparent: true,
        headerBlurEffect: "systemMaterial",
        headerShadowVisible: false,
        headerLargeTitleShadowVisible: false,
        headerTitleStyle: { color: PlatformColor("label") },
        headerLargeTitle: true,
        headerLargeStyle: { backgroundColor: "transparent" },
      }}
    >
      <Stack.Screen
        name="index"
        options={{
          title: "Settings",
        }}
      />
    </Stack>
  );
}
