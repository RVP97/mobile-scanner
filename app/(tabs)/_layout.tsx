import { Icon, Label, NativeTabs } from "expo-router/unstable-native-tabs";

export default function TabLayout() {
  return (
    <NativeTabs minimizeBehavior="onScrollDown">
      <NativeTabs.Trigger name="(1-scanner)">
        <Icon sf={{ default: "camera", selected: "camera.fill" }} />
        <Label>Scanner</Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(2-history)">
        <Icon sf={{ default: "clock", selected: "clock.fill" }} />
        <Label>History</Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(4-generator)">
        <Icon sf={{ default: "qrcode", selected: "qrcode" }} />
        <Label>Generator</Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(3-settings)">
        <Icon sf={{ default: "gearshape", selected: "gearshape.fill" }} />
        <Label>Settings</Label>
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
