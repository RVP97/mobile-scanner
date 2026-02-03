import { useTranslations } from "@/hooks/useTranslations";
import { Icon, Label, NativeTabs } from "expo-router/unstable-native-tabs";

export default function TabLayout() {
  const t = useTranslations();

  return (
    <NativeTabs minimizeBehavior="onScrollDown">
      <NativeTabs.Trigger name="(1-scanner)">
        <Icon sf={{ default: "camera", selected: "camera.fill" }} />
        <Label>{t.tabs.scanner}</Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(2-history)">
        <Icon sf={{ default: "clock", selected: "clock.fill" }} />
        <Label>{t.tabs.history}</Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(4-generator)">
        <Icon sf={{ default: "qrcode", selected: "qrcode" }} />
        <Label>{t.tabs.generator}</Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(3-settings)">
        <Icon sf={{ default: "gearshape", selected: "gearshape.fill" }} />
        <Label>{t.tabs.settings}</Label>
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
