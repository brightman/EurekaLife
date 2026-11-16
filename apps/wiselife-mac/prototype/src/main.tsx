import React from "react";
import { createRoot } from "react-dom/client";
import { MantineProvider, createTheme } from "@mantine/core";
import App from "./App";
import "./app.css";
const theme = createTheme({
  fontFamily: '-apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif',
  primaryColor: "blue",
  defaultRadius: "md",
  headings: { fontFamily: "inherit" },
});
createRoot(document.getElementById("root")!).render(
  <MantineProvider theme={theme} forceColorScheme="light">
    <App />
  </MantineProvider>,
);
