import {
  getTranslations,
  type Language,
  type Translations,
} from "@/utils/i18n";
import { useStorage } from "./useStorage";

export function useTranslations(): Translations {
  const [language] = useStorage<Language>("language", "en");
  return getTranslations(language);
}

export function useLanguage(): [Language, (lang: Language) => void] {
  const [language, setLanguage] = useStorage<Language>("language", "en");
  return [language, setLanguage];
}
