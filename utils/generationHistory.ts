import AsyncStorage from "@react-native-async-storage/async-storage";

export interface GenerationHistoryItem {
  id: string;
  data: string;
  format: string;
  formatName: string;
  timestamp: number;
  formattedDate: string;
}

const GENERATION_HISTORY_KEY = "generationHistory";

export async function saveGenerationToHistory(
  data: string,
  format: string,
  formatName: string,
): Promise<void> {
  try {
    const existingHistory = await getGenerationHistory();

    // Remove any existing generation with the same data and format (duplicate removal)
    const filteredHistory = existingHistory.filter(
      (item) => !(item.data === data && item.format === format),
    );

    const timestamp = Date.now();
    const newGeneration: GenerationHistoryItem = {
      id: `gen_${timestamp}`,
      data,
      format,
      formatName,
      timestamp,
      formattedDate: new Date(timestamp).toLocaleString(),
    };

    // Add to beginning of array (most recent first)
    const updatedHistory = [newGeneration, ...filteredHistory];

    // Limit to 100 most recent generations
    const limitedHistory = updatedHistory.slice(0, 100);

    await AsyncStorage.setItem(
      GENERATION_HISTORY_KEY,
      JSON.stringify(limitedHistory),
    );
  } catch (error) {
    console.error("Error saving generation to history:", error);
  }
}

export async function getGenerationHistory(): Promise<GenerationHistoryItem[]> {
  try {
    const historyData = await AsyncStorage.getItem(GENERATION_HISTORY_KEY);
    return historyData ? JSON.parse(historyData) : [];
  } catch (error) {
    console.error("Error getting generation history:", error);
    return [];
  }
}

export async function deleteGenerationFromHistory(id: string): Promise<void> {
  try {
    const existingHistory = await getGenerationHistory();
    const updatedHistory = existingHistory.filter((item) => item.id !== id);
    await AsyncStorage.setItem(
      GENERATION_HISTORY_KEY,
      JSON.stringify(updatedHistory),
    );
  } catch (error) {
    console.error("Error deleting generation from history:", error);
  }
}

export async function clearGenerationHistory(): Promise<void> {
  try {
    await AsyncStorage.removeItem(GENERATION_HISTORY_KEY);
  } catch (error) {
    console.error("Error clearing generation history:", error);
  }
}
