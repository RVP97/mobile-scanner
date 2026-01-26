import { Stack } from "expo-router";
import { PlatformColor } from "react-native";

export default function ExploreLayout() {
  return (
    <Stack
      screenOptions={{
        headerTransparent: true,
        headerBlurEffect: "systemMaterial",
        headerShadowVisible: false,
        headerTitleStyle: { color: PlatformColor("label") },
        headerLargeTitle: true,
        headerLargeStyle: { backgroundColor: "transparent" },
      }}
    >
      <Stack.Screen
        name="index"
        options={{
          title: "History",
          headerLargeTitle: true,
        }}
      />
    </Stack>
  );
}
