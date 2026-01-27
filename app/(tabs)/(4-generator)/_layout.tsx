import { Stack } from "expo-router";
import { useColorScheme } from "react-native";

export default function GeneratorLayout() {
  const colorScheme = useColorScheme();
  const isDark = colorScheme === "dark";

  return (
    <Stack
      screenOptions={{
        headerTransparent: true,
        headerBlurEffect: "systemMaterial",
        headerShadowVisible: false,
        headerLargeTitleShadowVisible: false,
        headerLargeTitle: true,
        headerLargeStyle: { backgroundColor: "transparent" },
        headerTintColor: isDark ? "#FFFFFF" : "#000000",
      }}
    >
      <Stack.Screen
        name="index"
        options={{
          title: "Generator",
        }}
      />
    </Stack>
  );
}
