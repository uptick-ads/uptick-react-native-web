import React, { useCallback, useEffect, useRef, useState } from "react";
import { Linking, Platform, Pressable, ScrollView, StatusBar, StyleSheet, Text, View } from "react-native";
import { SafeAreaProvider, SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { UptickFlow } from "@uptick/react-native-web-sdk";

// Demo app for @uptick/react-native-web-sdk: a mock order confirmation screen with one UptickFlow mounted in the flow of the page.
// Whether it renders inline or as a popup is decided by the placement's template on the Uptick side; the chips only pick which placement to load.

const DEFAULT_HOST = process.env.EXPO_PUBLIC_UPTICK_HOST || "api.uptick.com";

const SHARED_INTEGRATION_ID = process.env.EXPO_PUBLIC_UPTICK_INTEGRATION_ID || "";
// Two placements to demonstrate both presentations: one whose template is inline, one whose template is a popup.
const TARGETS = [
  {
    key: "inline",
    label: "Inline placement",
    integrationId: process.env.EXPO_PUBLIC_UPTICK_INLINE_INTEGRATION_ID || SHARED_INTEGRATION_ID,
    placement: process.env.EXPO_PUBLIC_UPTICK_INLINE_PLACEMENT || "checkout",
  },
  {
    key: "popup",
    label: "Popup placement",
    integrationId: process.env.EXPO_PUBLIC_UPTICK_POPUP_INTEGRATION_ID || SHARED_INTEGRATION_ID,
    placement: process.env.EXPO_PUBLIC_UPTICK_POPUP_PLACEMENT || "order_confirmation",
  },
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

// Headless control for testing: exp://host:port/--/?target=popup&host=api.example.test&id=<integration id>&placement=order_confirmation
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
  const [targetKey, setTargetKey] = useState("inline");
  const [host, setHost] = useState(DEFAULT_HOST);
  // Launch-URL overrides for the current session; null means "use the selected target".
  const [overrides, setOverrides] = useState({ integrationId: null, placement: null });
  const [renderedType, setRenderedType] = useState(null);
  const target = TARGETS.find((t) => t.key === targetKey);
  const integrationId = overrides.integrationId || target.integrationId;
  const placement = overrides.placement || target.placement;
  const [reloadKey, setReloadKey] = useState(0);
  const [events, setEvents] = useState([]);
  const mountedAt = useRef(Date.now());
  const firstOfferAt = useRef(null);

  const log = useCallback((name, data) => {
    console.log(`[uptick-demo] ${Platform.OS} ${name} ${data == null ? "" : JSON.stringify(data)}`);
    setEvents((prev) => [{ t: Date.now(), name, data }, ...prev].slice(0, 60));
  }, []);

  const reset = useCallback((nextTarget) => {
    mountedAt.current = Date.now();
    firstOfferAt.current = null;
    setEvents([]);
    setRenderedType(null);
    if (nextTarget) {
      setTargetKey(nextTarget);
      // Switching targets returns to that target's own placement; launch-URL overrides apply to one session only.
      setOverrides({ integrationId: null, placement: null });
    }
    setReloadKey((k) => k + 1);
  }, []);

  useEffect(() => {
    const apply = (url) => {
      const params = parseLaunchParams(url);
      const key = params.target;
      if (!key && !params.host && !params.id && !params.placement) return;
      log("launch_params", params);
      if (params.host) setHost(params.host);
      if (params.id || params.placement) setOverrides({ integrationId: params.id || null, placement: params.placement || null });
      reset(TARGETS.some((t) => t.key === key) ? key : null);
    };
    Linking.getInitialURL().then(apply);
    const subscription = Linking.addEventListener("url", ({ url }) => apply(url));
    return () => subscription.remove();
  }, [log, reset]);

  const callback = useCallback(
    (event, data) => {
      if (event === "offer_viewed" && firstOfferAt.current == null) {
        firstOfferAt.current = Date.now();
        log("time_to_first_offer_ms", firstOfferAt.current - mountedAt.current);
      }
      if (event === "render_type" && data) setRenderedType(data.rendered);
      log(event, data);
    },
    [log]
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

          {/* One mount point. Inline placements render here; popup placements present a modal over the screen from this same spot. */}
          <UptickFlow
            key={`${host}-${integrationId}-${placement}-${reloadKey}`}
            integrationId={integrationId}
            placement={placement}
            host={host}
            callback={callback}
            style={styles.slot}
            modal={{ insets: { top: insets.top + 16, bottom: insets.bottom + 16 } }}
            {...ORDER}
          />

          <View style={styles.card}>
            <Text style={styles.cardTitle}>Shipping to</Text>
            <Text style={styles.body}>742 Evergreen Terrace</Text>
            <Text style={styles.body}>Springfield, IL {ORDER.zip}</Text>
            <Text style={styles.bodyMuted}>Estimated delivery: 5 to 10 business days</Text>
          </View>

          <View style={styles.controls}>
            <Text style={styles.controlsTitle}>Demo controls</Text>
            <View style={styles.chips}>
              {TARGETS.map((t) => (
                <Chip key={t.key} active={t.key === targetKey} label={t.label} onPress={() => reset(t.key)} />
              ))}
              <Chip label="Reload" onPress={() => reset()} />
            </View>
            <Text style={styles.controlsMeta}>
              {Platform.OS} · {host} · {integrationId ? integrationId.slice(0, 8) : "no integration id"} · {placement} · rendered {renderedType || "..."}
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
