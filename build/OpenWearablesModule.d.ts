import { NativeModule } from "expo-modules-core";
import { HealthDataType, OpenWearablesModuleEvents, HealthDataProvider, DailyStepTotal, OWLogLevel } from "./OpenWearables.types";
declare class OpenWearablesModule extends NativeModule<OpenWearablesModuleEvents> {
    configure(host: string, customSyncURL?: string): void;
    signIn(userId: string, accessToken: string | null, refreshToken: string | null, apiKey: string | null): Promise<void>;
    signOut(): Promise<void>;
    updateTokens(accessToken: string, refreshToken: string): void;
    restoreSession(): string;
    isSessionValid(): boolean;
    requestAuthorization(types: HealthDataType[]): Promise<boolean>;
    getDailyStepTotals(daysBack: number): Promise<DailyStepTotal[]>;
    setSyncInterval(minutes: number): void;
    startBackgroundSync(syncDaysBack: number | null): Promise<boolean>;
    stopBackgroundSync(): Promise<void>;
    syncNow(): Promise<void>;
    isSyncActive(): boolean;
    getSyncStatus(): Record<string, any>;
    resumeSync(): Promise<boolean>;
    resetAnchors(): void;
    getStoredCredentials(): Record<string, any | null>;
    getAvailableProviders(): HealthDataProvider[];
    setProvider(providerId: string): boolean;
    setLogLevel(logLevel: OWLogLevel): void;
    getLogLevel(): OWLogLevel;
}
declare const _default: OpenWearablesModule;
export default _default;
