import { QueryClient, QueryClientProvider } from "react-query";
import { ReactQueryDevtools } from "react-query/devtools";
import { CssVarsProvider } from "@mui/joy/styles";
import { SnackbarProvider } from "notistack";
import CssBaseline from "@mui/joy/CssBaseline";
import GlobalStyles from "@mui/joy/GlobalStyles";
import "@fontsource/inter";

import { IdentityProvider } from "@fe/integration/identity";
import Root from "@fe/components/root";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: false,
      staleTime: Infinity,
    },
    mutations: { retry: false },
  },
});

const App = () => {
  return (
    <QueryClientProvider client={queryClient}>
      <CssVarsProvider defaultMode="light">
        <CssBaseline />
        <GlobalStyles
          styles={{
            ul: {
              margin: "0",
              padding: "0",
              paddingLeft: "16px",
            },
          }}
        />
        <SnackbarProvider
          anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
        >
          <IdentityProvider>
            <Root />
          </IdentityProvider>
        </SnackbarProvider>
      </CssVarsProvider>
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
};

export default App;
