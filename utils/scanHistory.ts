import AsyncStorage from "@react-native-async-storage/async-storage";

export interface ScanHistoryItem {
  id: string;
  data: string;
  type: string;
  timestamp: number;
  formattedDate: string;
}

const SCAN_HISTORY_KEY = "scanHistory";

export async function saveScanToHistory(
  data: string,
  type: string,
): Promise<void> {
  try {
    const existingHistory = await getScanHistory();

    // Remove any existing scan with the same data (duplicate removal)
    const filteredHistory = existingHistory.filter(
      (item) => item.data !== data,
    );

    const timestamp = Date.now();
    const newScan: ScanHistoryItem = {
      id: `scan_${timestamp}`,
      data,
      type,
      timestamp,
      formattedDate: new Date(timestamp).toLocaleString(),
    };

    // Add to beginning of array (most recent first)
    const updatedHistory = [newScan, ...filteredHistory];

    // Limit to 100 most recent scans
    const limitedHistory = updatedHistory.slice(0, 100);

    await AsyncStorage.setItem(
      SCAN_HISTORY_KEY,
      JSON.stringify(limitedHistory),
    );
  } catch (error) {
    console.error("Error saving scan to history:", error);
  }
}

export async function getScanHistory(): Promise<ScanHistoryItem[]> {
  try {
    const historyData = await AsyncStorage.getItem(SCAN_HISTORY_KEY);
    return historyData ? JSON.parse(historyData) : [];
  } catch (error) {
    console.error("Error getting scan history:", error);
    return [];
  }
}

export async function deleteScanFromHistory(id: string): Promise<void> {
  try {
    const existingHistory = await getScanHistory();
    const updatedHistory = existingHistory.filter((item) => item.id !== id);
    await AsyncStorage.setItem(
      SCAN_HISTORY_KEY,
      JSON.stringify(updatedHistory),
    );
  } catch (error) {
    console.error("Error deleting scan from history:", error);
  }
}

export async function clearScanHistory(): Promise<void> {
  try {
    await AsyncStorage.removeItem(SCAN_HISTORY_KEY);
  } catch (error) {
    console.error("Error clearing scan history:", error);
  }
}

export function formatScanData(data: string, maxLength: number = 50): string {
  if (data.length <= maxLength) return data;
  return `${data.substring(0, maxLength)}...`;
}
