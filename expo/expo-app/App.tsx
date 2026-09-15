import { StatusBar } from 'expo-status-bar'

import { DEFAULT_API_BASE_URL } from './src/api/github'
import { DEFAULT_KEYWORD, type RootProps } from './src/native/bridge'
import { RepoSearchScreen } from './src/screens/RepoSearchScreen'

/**
 * `keyword` and `apiBaseUrl` come from the native host app via `initialProps`,
 * e.g. `ReactNativeView(moduleName: "main", initialProps: ["keyword": "swift"])`.
 * They fall back to defaults so the app still runs standalone.
 */
export default function App({ keyword, apiBaseUrl }: RootProps) {
  return (
    <>
      <StatusBar style="dark" />
      <RepoSearchScreen
        apiBaseUrl={apiBaseUrl || DEFAULT_API_BASE_URL}
        initialKeyword={keyword ?? DEFAULT_KEYWORD}
      />
    </>
  )
}
