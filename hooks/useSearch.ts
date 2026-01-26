import { useNavigation } from "expo-router";
import { useCallback, useEffect, useRef, useState } from "react";

interface SearchOptions {
  placeholder?: string;
  autoCapitalize?: "none" | "sentences" | "words" | "characters";
}

export function useSearch(options: SearchOptions = {}) {
  const [search, setSearch] = useState("");
  const navigation = useNavigation();
  const optionsRef = useRef(options);
  optionsRef.current = options;

  const handleChangeText = useCallback(
    (e: { nativeEvent: { text: string } }) => {
      setSearch(e.nativeEvent.text);
    },
    [],
  );

  const handleSearchButtonPress = useCallback(
    (e: { nativeEvent: { text: string } }) => {
      setSearch(e.nativeEvent.text);
    },
    [],
  );

  const handleCancelButtonPress = useCallback(() => {
    setSearch("");
  }, []);

  useEffect(() => {
    navigation.setOptions({
      headerShown: true,
      headerSearchBarOptions: {
        placeholder: optionsRef.current.placeholder,
        autoCapitalize: optionsRef.current.autoCapitalize,
        onChangeText: handleChangeText,
        onSearchButtonPress: handleSearchButtonPress,
        onCancelButtonPress: handleCancelButtonPress,
      },
    });
  }, [
    navigation,
    handleChangeText,
    handleSearchButtonPress,
    handleCancelButtonPress,
  ]);

  return search;
}
