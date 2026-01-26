import { Icon, Label, NativeTabs } from "expo-router/unstable-native-tabs";

export default function TabLayout() {
  return (
    <NativeTabs minimizeBehavior="onScrollDown">
      <NativeTabs.Trigger name="(scanner)">
        <Icon sf={{ default: "camera", selected: "camera.fill" }} />
        <Label>Scanner</Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(explore)">
        <Icon sf={{ default: "clock", selected: "clock.fill" }} />
        <Label>History</Label>
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
