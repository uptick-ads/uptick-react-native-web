import React, { useCallback, useEffect, useRef, useState } from "react";
import { Linking, Platform, Pressable, ScrollView, StatusBar, StyleSheet, Text, View } from "react-native";
import { SafeAreaProvider, SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { UptickOffers } from "@uptick/react-native-web-sdk";

// Demo app for @uptick/react-native-web-sdk: a mock order confirmation screen with the offer inline or as a native modal.

const DEFAULT_HOST = process.env.EXPO_PUBLIC_UPTICK_HOST || "api.uptick.com";
const INTEGRATION_ID = process.env.EXPO_PUBLIC_UPTICK_INTEGRATION_ID || "";
const PLACEMENT = process.env.EXPO_PUBLIC_UPTICK_PLACEMENT || "order_confirmation";

const MODES = [
  { key: "inline", label: "Inline" },
  { key: "modal", label: "Modal" },
];

const ORDER = {
  first_name: "Nate",
  total_price: "$89.00",
  shipping_price: "$5.99",
  currency: "USD",
  order_id: "SGC-1847",
  zip: "62704",
  customer_id: "demo-customer-1",
};

// Headless control for testing: exp://host:port/--/?mode=modal&host=api.example.test&id=<integration id>&placement=order_confirmation
function parseLaunchParams(url) {
  if (!url) return {};
  const query = url.split("?")[1];
  if (!query) return {};
  const out = {};
  query.split("&").forEach((pair) => {
    const [key, value] = pair.split("=");
    if (key) out[decodeURIComponent(key)] = decodeURIComponent(value || "");
  });
  return out;
}

function clock(t) {
  const d = new Date(t);
  return `${String(d.getMinutes()).padStart(2, "0")}:${String(d.getSeconds()).padStart(2, "0")}.${String(d.getMilliseconds()).padStart(3, "0")}`;
}

export default function App() {
  return (
    <SafeAreaProvider>
      <Demo />
    </SafeAreaProvider>
  );
}

function Demo() {
  const insets = useSafeAreaInsets();
  const [mode, setMode] = useState("inline");
  const [host, setHost] = useState(DEFAULT_HOST);
  const [integrationId, setIntegrationId] = useState(INTEGRATION_ID);
  const [placement, setPlacement] = useState(PLACEMENT);
  const [reloadKey, setReloadKey] = useState(0);
  const [events, setEvents] = useState([]);
  const mountedAt = useRef(Date.now());
  const firstOfferAt = useRef(null);

  const log = useCallback((name, data) => {
    console.log(`[uptick-demo] ${Platform.OS} ${name} ${data == null ? "" : JSON.stringify(data)}`);
    setEvents((prev) => [{ t: Date.now(), name, data }, ...prev].slice(0, 60));
  }, []);

  const reset = useCallback((nextMode) => {
    mountedAt.current = Date.now();
    firstOfferAt.current = null;
    setEvents([]);
    if (nextMode) setMode(nextMode);
    setReloadKey((k) => k + 1);
  }, []);

  useEffect(() => {
    const apply = (url) => {
      const params = parseLaunchParams(url);
      if (!params.mode && !params.host && !params.id && !params.placement) return;
      log("launch_params", params);
      if (params.host) setHost(params.host);
      if (params.id) setIntegrationId(params.id);
      if (params.placement) setPlacement(params.placement);
      reset(MODES.some((m) => m.key === params.mode) ? params.mode : null);
    };
    Linking.getInitialURL().then(apply);
    const subscription = Linking.addEventListener("url", ({ url }) => apply(url));
    return () => subscription.remove();
  }, [log, reset]);

  const onEvent = useCallback(
    (name, data) => {
      if (name === "offer_viewed" && firstOfferAt.current == null) {
        firstOfferAt.current = Date.now();
        log("time_to_first_offer_ms", firstOfferAt.current - mountedAt.current);
      }
      log(name, data);
    },
    [log]
  );

  const offers = (
    <UptickOffers
      key={`${host}-${integrationId}-${placement}-${mode}-${reloadKey}`}
      integrationId={integrationId}
      placement={placement}
      mode={mode}
      order={ORDER}
      host={host}
      onEvent={onEvent}
      insets={{ top: insets.top + 16, bottom: insets.bottom + 16 }}
      style={mode === "inline" ? styles.slot : undefined}
    />
  );

  return (
    <View style={styles.root}>
      <StatusBar barStyle="dark-content" />
      <SafeAreaView style={styles.safe} edges={["top"]}>
        <ScrollView style={styles.screen} contentContainerStyle={styles.screenContent} nestedScrollEnabled>
          <Text style={styles.brand}>Summit Gear Co.</Text>
          <Text style={styles.h1}>Thanks, {ORDER.first_name}!</Text>
          <Text style={styles.sub}>Order {ORDER.order_id} is confirmed. A receipt is on its way to your inbox.</Text>

          <View style={styles.card}>
            <Row label="Trail Runner Jacket x2" value="$64.00" />
            <Row label="Merino Crew Socks x1" value="$19.01" />
            <Row label="Shipping" value={ORDER.shipping_price} />
            <Row label="Total" value={ORDER.total_price} bold />
          </View>

          {mode === "inline" && offers}

          <View style={styles.card}>
            <Text style={styles.cardTitle}>Shipping to</Text>
            <Text style={styles.body}>742 Evergreen Terrace</Text>
            <Text style={styles.body}>Springfield, IL {ORDER.zip}</Text>
            <Text style={styles.bodyMuted}>Estimated delivery: 5 to 10 business days</Text>
          </View>

          <View style={styles.controls}>
            <Text style={styles.controlsTitle}>Demo controls</Text>
            <View style={styles.chips}>
              {MODES.map((m) => (
                <Chip key={m.key} active={m.key === mode} label={m.label} onPress={() => reset(m.key)} />
              ))}
              <Chip label="Reload" onPress={() => reset()} />
            </View>
            <Text style={styles.controlsMeta}>
              {Platform.OS} · {host} · {integrationId ? integrationId.slice(0, 8) : "no integration id"} · {placement}
            </Text>
          </View>

          <View style={styles.log}>
            <Text style={styles.controlsTitle}>Events (newest first)</Text>
            {events.length === 0 && <Text style={styles.logLine}>waiting for the SDK...</Text>}
            {events.map((e, i) => (
              <Text key={`${e.t}-${i}`} style={styles.logLine} numberOfLines={3}>
                {clock(e.t)} {e.name} {e.data == null ? "" : typeof e.data === "string" ? e.data : JSON.stringify(e.data)}
              </Text>
            ))}
          </View>
        </ScrollView>
      </SafeAreaView>

      {mode === "modal" && offers}
    </View>
  );
}

function Row({ label, value, bold }) {
  return (
    <View style={styles.row}>
      <Text style={[styles.body, bold && styles.bold]}>{label}</Text>
      <Text style={[styles.body, bold && styles.bold]}>{value}</Text>
    </View>
  );
}

function Chip({ active, label, onPress }) {
  return (
    <Pressable onPress={onPress} style={[styles.chip, active && styles.chipActive]}>
      <Text style={[styles.chipText, active && styles.chipTextActive]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: "#f4f4f5" },
  safe: { flex: 1 },
  screen: { flex: 1 },
  screenContent: { padding: 16, paddingBottom: 48 },
  brand: { fontSize: 13, letterSpacing: 2, textTransform: "uppercase", color: "#71717a", marginBottom: 8 },
  h1: { fontSize: 28, fontWeight: "700", color: "#18181b" },
  sub: { fontSize: 15, color: "#52525b", marginTop: 6, marginBottom: 16, lineHeight: 21 },
  card: { backgroundColor: "#fff", borderRadius: 12, padding: 16, marginBottom: 16, borderWidth: 1, borderColor: "#e4e4e7" },
  cardTitle: { fontSize: 13, fontWeight: "600", color: "#71717a", marginBottom: 6, textTransform: "uppercase", letterSpacing: 1 },
  row: { flexDirection: "row", justifyContent: "space-between", paddingVertical: 4 },
  body: { fontSize: 15, color: "#27272a" },
  bodyMuted: { fontSize: 13, color: "#71717a", marginTop: 6 },
  bold: { fontWeight: "700" },
  slot: { marginBottom: 16 },
  controls: { backgroundColor: "#fff", borderRadius: 12, padding: 12, marginBottom: 16, borderWidth: 1, borderColor: "#e4e4e7" },
  controlsTitle: { fontSize: 12, fontWeight: "700", color: "#3f3f46", marginBottom: 8, textTransform: "uppercase", letterSpacing: 1 },
  controlsMeta: { fontSize: 12, color: "#71717a", marginTop: 8 },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 6 },
  chip: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 999, borderWidth: 1, borderColor: "#d4d4d8", backgroundColor: "#fafafa" },
  chipActive: { backgroundColor: "#18181b", borderColor: "#18181b" },
  chipText: { fontSize: 12, color: "#27272a" },
  chipTextActive: { color: "#fff" },
  log: { backgroundColor: "#0f172a", borderRadius: 12, padding: 12 },
  logLine: { fontFamily: Platform.select({ ios: "Menlo", android: "monospace" }), fontSize: 10, color: "#e2e8f0", marginBottom: 3 },
});
